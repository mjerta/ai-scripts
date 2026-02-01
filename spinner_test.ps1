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
    Start-Sleep -Seconds 5
}

$spinnerTask = [System.Threading.Tasks.Task]::Run({ Show-Spinner -Message "Simulating work..." })

while ($job.State -eq 'Running') {
    Start-Sleep -Milliseconds 200
}

$script:SpinnerDone = $true

$spinnerTask.Wait()

Write-Output "Job completed!"

Remove-Job -Job $job -Force
