$ErrorActionPreference = "Stop"

Write-Host "Testing SIGINT with simple subcommand"

$test_script = "test-long-running-task.bat"
@'
echo Starting long running task...
ping -n 60 -w 1000 localhost
echo Task completed normally
'@ | Out-File -FilePath $test_script -Encoding ASCII

if ([Console]::TreatControlCAsInput) {
    Write-Host "Need to treat ctrl+c as a special marker"
    exit 1
}

Write-Host "Starting cmd.exe with subcommand..."
$cmd_process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c", $test_script -NoNewWindow -PassThru

$CMD_PID = $cmd_process.Id
Write-Host "Started cmd.exe with PID: $CMD_PID"

Start-Sleep -Seconds 2

if ($cmd_process.HasExited) {
    Write-Host "ERROR: cmd.exe process died unexpectedly"
    exit 1
}

Write-Host "Sending SIGINT to cmd.exe process..."

# import GenerateConsoleCtrlEvent:
$MethodDefinition = @'
[DllImport("Kernel32.dll", CharSet = CharSet.Unicode)]
public static extern bool GenerateConsoleCtrlEvent(uint dwCtrlEvent, uint dwProcessGroupId);
[DllImport("Kernel32.dll", CharSet = CharSet.Unicode)]
public static extern bool SetConsoleCtrlHandler(EventHandler handler, bool add);
'@

$Kernel32 = Add-Type -MemberDefinition $MethodDefinition -Name 'Kernel32' -Namespace 'Win32' -PassThru

# keep us alive!
$Kernel32::SetConsoleCtrlHandler($null, $true)
$Kernel32::GenerateConsoleCtrlEvent(0, 0)
# Write-Host "" -NoNewLine

# python3 ./tools/test-interrupt-pid.py $CMD_PID
# $encodedCommand = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes("Add-Type -Names 'w' -Name 'k' -M '[DllImport(""kernel32.dll"")]public static extern bool FreeConsole();[DllImport(""kernel32.dll"")]public static extern bool AttachConsole(uint p);[DllImport(""kernel32.dll"")]public static extern bool SetConsoleCtrlHandler(uint h, bool a);[DllImport(""kernel32.dll"")]public static extern bool GenerateConsoleCtrlEvent(uint e, uint p);public static void SendCtrlC(uint p){FreeConsole();AttachConsole(p);GenerateConsoleCtrlEvent(0, 0);}';[w.k]::SendCtrlC($CMD_PID)"))
# Write-Host "Running $encodedCommand"
# start-process powershell.exe -argument "-nologo -noprofile -executionpolicy bypass -EncodedCommand $encodedCommand"
# & windows-kill -SIGINT $CMD_PID

Write-Host "Waiting for SIGINT..."

try {
    $cmd_process.WaitForExit(10000)
} catch {
}

# Write-Host "Error log from test-interrupt-pid.py"
# if (Test-Path "err.log") {
#     Get-Content "err.log"
# }

if (!$cmd_process.HasExited) {
    Write-Host "ERROR: Process is still running after SIGINT"
    exit 1
} else {
    Write-Host "SUCCESS: Process terminated successfully with code ${cmd_process.ExitCode}"
    exit $cmd_process.ExitCode
}
