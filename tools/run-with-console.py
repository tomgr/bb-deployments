import subprocess
import sys

result = subprocess.run(
    [sys.executable, "tools/test-interrupt.py"],
    creationflags=subprocess.CREATE_NEW_PROCESS_GROUP,
)
sys.exit(result.returncode)
