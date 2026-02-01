# To use this ps script simply save this script somewhere and then this in your powershell profile
# function ?? {
#     $args | & "C:\path\to\your\prompt.ps1"
# }
#
# Als the following api key need to be added to the system variables
# [System.Environment]::SetEnvironmentVariable("OPENAI_API_KEY", "sk-your-key-here", "User")
#
# 
# 1. Check for API Key
if (-not $env:OPENAI_API_KEY) {
    Write-Error "Error: OPENAI_API_KEY environment variable is not set."
    exit 1
}

# 2. Capture Piped Input (stdin)
$stdinData = ""
if ($input) {
    # $input is a special automatic variable in PowerShell for piped data
    $stdinData = $input | Out-String
}

# 3. Capture All Arguments (the prompt)
$prompt = $args -join " "

if (-not $prompt -and -not $stdinData) {
    Write-Host "Usage: 'Your question' | gpt"
    exit
}

# 4. Prepare the Message
$fullContent = if ([string]::IsNullOrWhiteSpace($stdinData)) {
    $prompt
} else {
    "$prompt`n`n--- INPUT DATA ---`n$stdinData"
}

# 5. Define the Request Payload
$body = @{
    model = "gpt-4o-mini"
    messages = @(
        @{ role = "system"; content = "You are a CLI tool. Output raw text only. No markdown." }
        @{ role = "user"; content = $fullContent }
    )
} | ConvertTo-Json -Depth 10

# 6. Execute with a simple Progress Bar (PowerShell's version of a spinner)
Write-Progress -Activity "AI is thinking..." -Status "Querying OpenAI API"

try {
    $response = Invoke-RestMethod -Uri "https://api.openai.com/v1/chat/completions" `
        -Method Post `
        -Headers @{ "Authorization" = "Bearer $($env:OPENAI_API_KEY)" } `
        -ContentType "application/json" `
        -Body $body

    Write-Progress -Activity "AI is thinking..." -Completed
    
    # 7. Output the result
    Write-Output $response.choices[0].message.content
}
catch {
    Write-Progress -Activity "AI is thinking..." -Completed
    Write-Error "API Request failed: $_"
}
