param(
    [Parameter(Mandatory=$true)]
    [string]$Command
)

$TempBatFile = Join-Path ([System.IO.Path]::GetTempPath()) "run_bash_$(Get-Random).bat"
$CurrentWorkingDirectory = Get-Location
$BatchContent = @"
@echo off
echo %cd%
cd "$CurrentWorkingDirectory"
$Command
exit /b %ERRORLEVEL%
"@

try {
    $BatchContent | Out-File -FilePath $TempBatFile -Encoding ASCII

    # Use conhost.exe to run the batch file with output capture
    $ProcessStartInfo = New-Object System.Diagnostics.ProcessStartInfo
    $ProcessStartInfo.FileName = "conhost.exe"
    $ProcessStartInfo.Arguments = "`"$TempBatFile`""
    $ProcessStartInfo.RedirectStandardOutput = $true
    $ProcessStartInfo.RedirectStandardError = $true
    $ProcessStartInfo.UseShellExecute = $false
    $ProcessStartInfo.CreateNoWindow = $false

    $Process = New-Object System.Diagnostics.Process
    $Process.StartInfo = $ProcessStartInfo
    $OutputAction = {
        if ($Event.SourceEventArgs.Data -ne $null) {
            Write-Host $Event.SourceEventArgs.Data
        }
    }
    $ErrorAction = {
        if ($Event.SourceEventArgs.Data -ne $null) {
            Write-Error $Event.SourceEventArgs.Data
        }
    }
    $OutputEvent = Register-ObjectEvent -InputObject $Process -EventName OutputDataReceived -Action $OutputAction
    $ErrorEvent = Register-ObjectEvent -InputObject $Process -EventName ErrorDataReceived -Action $ErrorAction

    try {
        $Process.Start() | Out-Null
        $Process.BeginOutputReadLine()
        $Process.BeginErrorReadLine()
        Write-Host "Started conhost process with PID: $($Process.Id)"
        $Process.WaitForExit()
        Write-Host ""
        Write-Host "Process completed with exit code: $($Process.ExitCode)"
        exit $Process.ExitCode
    }
    finally {
        Unregister-Event -SourceIdentifier $OutputEvent.Name
        Unregister-Event -SourceIdentifier $ErrorEvent.Name
        $Process.Dispose()
    }
}
catch {
    Write-Error "Error starting process: $_"
    exit 1
}
finally {
    Remove-Item $TempBatFile -Force -ErrorAction SilentlyContinue
}
