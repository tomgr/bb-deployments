import subprocess
import sys
import select
import threading
import signal
from typing import  TextIO
import ctypes

def stream_output(stream: TextIO, output_stream: TextIO):
    for line in iter(stream.readline, ''):
        output_stream.write(line)
        output_stream.flush()
    stream.close()

result = ctypes.windll.kernel32.SetConsoleCtrlHandler(None, 0)
if result:
    print("Restored console ctrl handler")
else:
    print(f"restore failed")

process = subprocess.Popen(
    ["C:\\Program Files\\Git\\bin\\bash.EXE", "tools/test-interrupt.sh"],
    # ["powershell.exe", "tools/indirect-run.ps1"],
    creationflags=subprocess.CREATE_NEW_CONSOLE|subprocess.CREATE_NEW_PROCESS_GROUP|subprocess.CREATE_NO_WINDOW,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    startupinfo=subprocess.STARTUPINFO(dwFlags=subprocess.STARTF_USESHOWWINDOW, wShowWindow=subprocess.SW_HIDE),
    text=True,
    bufsize=1,
)

stdout_thread = threading.Thread(target=stream_output, args=(process.stdout, sys.stdout))
stderr_thread = threading.Thread(target=stream_output, args=(process.stderr, sys.stderr))

stdout_thread.start()
stderr_thread.start()

# Poll the process instead of blocking wait
try:
    returncode = process.wait()
except KeyboardInterrupt:
    process.terminate()
    returncode = 1
    # break
    # except subprocess.TimeoutExpired:
    #     continue

stdout_thread.join()
stderr_thread.join()

sys.exit(returncode)
