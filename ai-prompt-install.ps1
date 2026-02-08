$defaultPath = "$HOME\scripts"
if (-not (Test-Path $defaultPath)) { New-Item -ItemType Directory -Path $defaultPath -Force | Out-Null }
$defaultPromptAlias = "gpt"

Write-Host "--- AI prompt CLI Tool Installation ---" -ForegroundColor Cyan

$installDir = Read-Host "Enter installation directory (Default: $defaultPath)"
if ([string]::IsNullOrWhiteSpace($installDir)) { $installDir = $defaultPath }
$promptName = Read-Host "How would you like to call your prompt "
if ([string]::IsNullOrWhiteSpace($promptName)) { $installDir = $defaultPromptAlias }

$scriptPath = Join-Path $installDir "prompt.ps1"

if (-not $env:OPENAI_API_KEY) {
    $key = Read-Host "Enter your OpenAI API Key (This will be saved to your User Environment)"
    if (-not [string]::IsNullOrWhiteSpace($key)) {
        [System.Environment]::SetEnvironmentVariable("OPENAI_API_KEY", $key, "User")
        $env:OPENAI_API_KEY = $key
    } else {
        Write-Error "API Key is required to run this tool."
        return
    }
}

$scriptContent = @'
param(
    [Parameter(ValueFromPipeline=$true)]
    [string]$InputObject,
    [Parameter(Position=0, ValueFromRemainingArguments=$true)]
    [string[]]$PromptArgs
)

$prompt = $PromptArgs -join " "
$stdinData = $InputObject

if (-not $prompt -and -not $stdinData) {
    Write-Host "Usage: 'command' | gpt 'your question'" -ForegroundColor Yellow
    return
}

$fullContent = if ([string]::IsNullOrWhiteSpace($stdinData)) { $prompt } 
               else { "$prompt`n`n--- INPUT DATA ---`n$stdinData" }

$body = @{
    model = "gpt-4o-mini"
    messages = @(
        @{ role = "system"; content = "You are a CLI tool. Output raw text only. No markdown." },
        @{ role = "user"; content = $fullContent }
    )
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri "https://api.openai.com/v1/chat/completions" `
        -Method Post `
        -Headers @{ "Authorization" = "Bearer $($env:OPENAI_API_KEY)" } `
        -ContentType "application/json" `
        -Body $body
    
    $response.choices[0].message.content
}
catch {
    Write-Error "API Request failed. Ensure your key is valid."
}
'@

$scriptContent | Out-File -FilePath $scriptPath -Encoding utf8
Write-Host "Script saved to: $scriptPath" -ForegroundColor Green

$profilePath = $PROFILE
if (-not (Test-Path $profilePath)) { New-Item -Type File -Path $profilePath -Force | Out-Null }

$functionCode = @"

function $promptName { 
    `$input | & '$scriptPath' `$args 
}
"@

if ((Get-Content $profilePath) -notcontains "function gpt") {
    Add-Content -Path $profilePath -Value $functionCode
    Write-Host "Function $promptName added to your PowerShell Profile!" -ForegroundColor Green
}

Write-Host "`nInstallation Complete! Restart PowerShell or run: . `$PROFILE" -ForegroundColor Cyan
