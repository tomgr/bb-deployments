<#
.SYNOPSIS
This script runs the specified command via conhost to ensure that it has a
proper Windows Console available.

.DESCRIPTION
This script runs the specified command via conhost to ensure that it has a
proper Windows Console available. The reason for this script's existence is
that Github Actions executes Windows scripts in an environment without an
interactive console, and this breaks the sending of CTRL_C_EVENT which we
use to gracefully terminate buildbarn.

.PARAMETER Command
The command to execute in the console environment.

.PARAMETER TimeoutMinutes
The timeout in minutes after which the process will be force killed. Default is 10 minutes.
If set to 0, no timeout is applied and the process will run indefinitely.

.EXAMPLE
.\run-test-interrupt-with-console-v3.ps1 -Command "bash.exe -c ./test-interrupt.sh"

.EXAMPLE
.\run-test-interrupt-with-console-v3.ps1 -Command "bash.exe -c ./test-interrupt.sh" -TimeoutMinutes 5
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
        
        if ($TimeoutMinutes -eq 0) {
            # No timeout - wait indefinitely
            Write-Host "No timeout specified - process will run until completion"
            $Process.WaitForExit()
            Write-Host ""
            Write-Host "Process completed normally with exit code: $($Process.ExitCode)"
            exit $Process.ExitCode
        } else {
            # Wait for the process to complete with specified timeout
            $TimeoutMs = $TimeoutMinutes * 60 * 1000  # Convert minutes to milliseconds
            Write-Host "Process will timeout after $TimeoutMinutes minutes"
            $ProcessCompleted = $Process.WaitForExit($TimeoutMs)
            
            if ($ProcessCompleted) {
                Write-Host ""
                Write-Host "Process completed normally with exit code: $($Process.ExitCode)"
                exit $Process.ExitCode
            } else {
                Write-Host ""
                Write-Host "Process exceeded $TimeoutMinutes-minute timeout, force killing..." -ForegroundColor Yellow
                
                # Force kill the process tree
                try {
                    # Kill the main process and its children
                    $Process.Kill($true)  # $true kills the entire process tree
                    Write-Host "Force killed process and its children" -ForegroundColor Yellow
                    exit -1  # Indicate timeout/forced termination
                }
                catch {
                    Write-Warning "Failed to kill process gracefully: $_"
                    # Try alternative method using taskkill
                    try {
                        & taskkill /F /T /PID $Process.Id 2>$null
                        Write-Host "Force killed using taskkill" -ForegroundColor Yellow
                        exit -1
                    }
                    catch {
                        Write-Error "Failed to kill process with taskkill: $_"
                        exit -2
                    }
                }
            }
        }
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
