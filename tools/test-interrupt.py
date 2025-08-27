#!/usr/bin/env python3

import subprocess
import time
import ctypes

def main():
    print("Testing Ctrl+C with simple subcommand")
    
    test_script = "test-long-running-task.bat"
    with open(test_script, 'w') as f:
        f.write("@echo off\n")
        f.write("echo Starting long running task...\n")
        f.write("ping -n 30 -w 1000 127.0.0.1\n") 
        f.write("if errorlevel 1 (\n")
        f.write("    echo Task was interrupted\n")
        f.write("    exit /b 1\n")
        f.write(")\n")
        f.write("echo Task completed normally\n")
    
    print("Starting cmd.exe with subcommand...")
    proc = subprocess.Popen(['cmd.exe', '/c', test_script], 
                           stdin=subprocess.DEVNULL,
                           text=True)
    
    print(f"Started cmd.exe with PID: {proc.pid}")
    
    time.sleep(3)
    
    if proc.poll() is not None:
        print("ERROR: cmd.exe process died unexpectedly")
        return 1
    
    print("Sending Ctrl+C to cmd.exe process...")
    
    kernel32 = ctypes.windll.kernel32
    
    print("Successfully attached to console")
    try:
        kernel32.GenerateConsoleCtrlEvent(0, 0)
        time.sleep(10)
    except KeyboardInterrupt:
        pass

    try:
        exit_code = proc.wait(timeout=5)
        print(f"cmd.exe exited with code: {exit_code}")
    except subprocess.TimeoutExpired:
        print("ERROR: Process did not terminate after Ctrl+C")
        proc.kill()
        return 1
    
    if proc.poll() is None:
        print("ERROR: Process is still running")
        return 1
    else:
        print("SUCCESS: Process terminated successfully")
    
    return 0

if __name__ == "__main__":
    exit(main())
