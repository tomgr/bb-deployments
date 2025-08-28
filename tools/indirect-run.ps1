$ErrorActionPreference = "Stop"

& "C:\Program Files\Git\bin\bash.EXE" "tools/test-interrupt.sh"

# Write-Host "Starting"
# $proc = Start-Process -FilePath "C:\Program Files\Git\bin\bash.EXE" -ArgumentList @("tools/test-interrupt.sh") -Wait -PassThru
# $result = $proc.ExitCode
# Write-Host "Wrapper Finishing with $result"
# Exit $result
