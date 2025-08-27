import ctypes
import sys
from typing import Optional
# import os
# import signal

def log(message: str) -> None:
    """Log error message to err.log file"""
    try:
        with open('err.log', 'a', encoding='utf-8') as f:
            f.write(f"{message}\n")
    except Exception as e:
        print(f"Failed to write to err.log: {e}")

def get_last_error() -> Optional[str]:
    error_code = ctypes.windll.kernel32.GetLastError()
    if error_code != 0:
        # Get error message from system
        buffer = ctypes.create_unicode_buffer(256)
        ctypes.windll.kernel32.FormatMessageW(
            0x00001000,  # FORMAT_MESSAGE_FROM_SYSTEM
            None,
            error_code,
            0,
            buffer,
            256,
            None
        )
        return f"Error {error_code}: {buffer.value.strip()}"
    return None

kernel = ctypes.windll.kernel32

try:
    pid = int(sys.argv[1])
    
    # FreeConsole
    result = kernel.FreeConsole()
    if not result:
        error_msg = f"FreeConsole failed: {get_last_error()}"
        log(error_msg)
        # print(error_msg)
    
    # AttachConsole
    result = kernel.AttachConsole(pid)
    if not result:
        error_msg = f"AttachConsole failed for PID {pid}: {get_last_error()}"
        log(error_msg)
        sys.exit(1)
    
    # SetConsoleCtrlHandler
    result = kernel.SetConsoleCtrlHandler(None, 1)
    if not result:
        error_msg = f"SetConsoleCtrlHandler failed: {get_last_error()}"
        log(error_msg)
    
    # GenerateConsoleCtrlEvent
    result = kernel.GenerateConsoleCtrlEvent(0, 0)
    if not result:
        error_msg = f"GenerateConsoleCtrlEvent failed: {get_last_error()}"
        log(error_msg)
        sys.exit(1)
    
    log(f"Successfully sent interrupt signal to PID {pid}")
    sys.exit(0)
    
except ValueError as e:
    error_msg = f"Invalid PID argument: {e}"
    log(error_msg)
    sys.exit(1)
except Exception as e:
    error_msg = f"Unexpected error: {e}"
    log(error_msg)
    sys.exit(1)

# os.kill(pid, signal.CTRL_C_EVENT)
