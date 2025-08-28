$ErrorActionPreference = "Stop"

    # & "C:\Program Files\Git\bin\bash.EXE" "tools/test-interrupt.sh"

$var = [Console]::TreatControlCAsInput
Write-Host "Got $var"

& "C:\Program Files\Git\bin\bash.EXE" "tools/test-interrupt.sh"
