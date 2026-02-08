# To use this ps script simply save this script somewhere and then this in your powershell profile
# function ?? {
#     $args | & "C:\path\to\your\prompt.ps1"
# }
#
# Als the following api key need to be added to the system variables
# [System.Environment]::SetEnvironmentVariable("OPENAI_API_KEY", "sk-your-key-here", "User")

if (-not $env:OPENAI_API_KEY) {
    Write-Error "Error: OPENAI_API_KEY environment variable is not set."
    exit 1
}

$stdinData = ""
if ($input) {
    $stdinData = $input | Out-String
}

$prompt = $args -join " "

if (-not $prompt -and -not $stdinData) {
    Write-Host "Usage: 'Your question' | gpt"
    exit
}

$fullContent = if ([string]::IsNullOrWhiteSpace($stdinData)) {
    $prompt
} else {
    "$prompt`n`n--- INPUT DATA ---`n$stdinData"
}

$body = @{
    model = "gpt-4o-mini"
    messages = @(
        @{ role = "system"; content = "You are a CLI tool. Output raw text only. No markdown." }
        @{ role = "user"; content = $fullContent }
    )
} | ConvertTo-Json -Depth 10

Write-Progress -Activity "AI is thinking..." -Status "Querying OpenAI API"

try {
    $response = Invoke-RestMethod -Uri "https://api.openai.com/v1/chat/completions" `
        -Method Post `
        -Headers @{ "Authorization" = "Bearer $($env:OPENAI_API_KEY)" } `
        -ContentType "application/json" `
        -Body $body

    Write-Progress -Activity "AI is thinking..." -Completed
    
    Write-Output $response.choices[0].message.content
}
catch {
    Write-Progress -Activity "AI is thinking..." -Completed
    Write-Error "API Request failed: $_"
}
