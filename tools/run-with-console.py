import subprocess
import sys

result = subprocess.run(
    ["C:\\Program Files\\Git\\bin\\bash.EXE", "tools/test-interrupt.sh"],
    creationflags=subprocess.CREATE_NEW_CONSOLE|subprocess.CREATE_NEW_PROCESS_GROUP,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    # startupinfo=subprocess.STARTUPINFO(dwFlags=subprocess.STARTF_USESHOWWINDOW, wShowWindow=subprocess.SW_HIDE),
    text=True,
)

if result.stdout:
    sys.stdout.write(result.stdout)
    sys.stdout.flush()
if result.stderr:
    sys.stderr.write(result.stderr)
    sys.stderr.flush()
sys.exit(result.returncode)
