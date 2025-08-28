<#
.Description
This script runs the specified command via connhost to ensure that it has a
proper Windows Console available. The reason for this script's existence is
that Github Actions executes Windows scripts in an environment without an
interactive console, and this breaks the sending of CTRL_C_EVENT which we
use to gracefully terminate buildbarn. Without this, the kill -SIGINT has
no effect.

One downside of this approach is that, in practice, the subprocesses's
output is buffered until the subprocess terminates. Unfortunately there does
not appear to be a workaround for this.
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$Command,

    [Parameter(Mandatory=$false)]
    [int]$TimeoutMinutes = 10
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

        $ProcessCompleted = $Process.WaitForExit($TimeoutMinutes * 60 * 1000)

        if ($ProcessCompleted) {
            Write-Host "Process completed normally with exit code: $($Process.ExitCode)"
            exit $Process.ExitCode
        } else {
            Write-Error "Process exceeded timeout, force killing..."
            $Process.Kill($true)
            Write-Error "Force killed process and its children"
            exit -1
        }
    }
    finally {
        Unregister-Event -SourceIdentifier $OutputEvent.Name
        Unregister-Event -SourceIdentifier $ErrorEvent.Name
        $Process.Dispose()
    }
}
catch {
    Write-Error "Error running process: $_"
    exit 1
}
finally {
    Remove-Item $TempBatFile -Force -ErrorAction SilentlyContinue
}
