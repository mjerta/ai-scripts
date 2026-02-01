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

function Show-Spinner {
    param (
        [string]$Message = "Working..."
    )

    $spinnerChars = "|", "/", "-", "\"
    $index = 0

    while (-not $script:SpinnerDone) {
        Write-Host -NoNewline -ForegroundColor Yellow "`r$Message $($spinnerChars[$index])"
        Start-Sleep -Milliseconds 100
        $index = ($index + 1) % $spinnerChars.Length
    }
    Write-Host -NoNewline -ForegroundColor Yellow "`r$Message - Done! "
    Write-Host
}


$script:SpinnerDone = $false

$job = Start-Job -ScriptBlock {
    param($body, $apiKey)
    try {
        $response = Invoke-RestMethod -Uri "https://api.openai.com/v1/chat/completions" `
            -Method Post `
            -Headers @{ "Authorization" = "Bearer $apiKey" } `
            -ContentType "application/json" `
            -Body $body
        return $response
    } catch {
        throw $_
    }
} -ArgumentList $body, $env:OPENAI_API_KEY

# Start spinner in background runspace
$spinnerTask = [System.Threading.Tasks.Task]::Run({ Show-Spinner -Message "AI is thinking..." })

while ($job.State -eq 'Running') {
    Start-Sleep -Milliseconds 200
}

$script:SpinnerDone = $true

# Wait for the spinner task to complete
$spinnerTask.Wait()

try {
    $response = Receive-Job -Job $job -ErrorAction Stop
    Write-Output $response.choices[0].message.content
} catch {
    Write-Error "API Request failed: $_"
}

Remove-Job -Job $job -Force

