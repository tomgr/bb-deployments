param(
    [Parameter(Mandatory=$true, ValueFromRemainingArguments=$true)]
    [string[]]$Command
)

# Import kernel32.dll for AllocConsole
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class ConsoleExt {
    [DllImport("kernel32.dll")]
    public static extern bool AllocConsole();
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
}
"@

# Allocate console if not already present
if ([ConsoleExt]::GetConsoleWindow() -eq [IntPtr]::Zero) {
    Write-Host "Allocating console..."
    [ConsoleExt]::AllocConsole() | Out-Null
} else {
    Write-Host "Console already allocated."
}

$exe = $Command[0]
$args = $Command[1..($Command.Length-1)]

if ($args.Length -gt 0) {
    $process = Start-Process -FilePath $exe -ArgumentList $args -Wait -PassThru -NoNewWindow
} else {
    $process = Start-Process -FilePath $exe -Wait -PassThru -NoNewWindow
}

exit $process.ExitCode
