import subprocess
import sys
import select
import threading

def stream_output(stream, output_stream):
    """Stream output from subprocess to the specified output stream."""
    for line in iter(stream.readline, ''):
        output_stream.write(line)
        output_stream.flush()
    stream.close()

# Use Popen instead of run to enable streaming
process = subprocess.Popen(
    [sys.executable, "tools/test-deployment-bare.py"],
    creationflags=subprocess.CREATE_NEW_CONSOLE|subprocess.CREATE_NEW_PROCESS_GROUP|subprocess.CREATE_NO_WINDOW,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    startupinfo=subprocess.STARTUPINFO(dwFlags=subprocess.STARTF_USESHOWWINDOW, wShowWindow=subprocess.SW_HIDE),
    text=True,
    bufsize=1,  # Line buffered
)

# Create threads to stream stdout and stderr separately
stdout_thread = threading.Thread(target=stream_output, args=(process.stdout, sys.stdout))
stderr_thread = threading.Thread(target=stream_output, args=(process.stderr, sys.stderr))

# Start the streaming threads
stdout_thread.start()
stderr_thread.start()

# Wait for the process to complete
returncode = process.wait()

# Wait for all output to be streamed
stdout_thread.join()
stderr_thread.join()

sys.exit(returncode)
