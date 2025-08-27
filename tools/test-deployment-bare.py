#!/usr/bin/env python3

import os
import sys
import subprocess
import time
import shutil
import platform
import tempfile
import ctypes
import stat
import signal
from pathlib import Path
from typing import Optional, List, Union

def log_error(message: str) -> None:
    """Log error message to stderr"""
    print(message, file=sys.stderr,flush=True)

def run_command(cmd: Union[str, List[str]], check: bool = True, capture_output: bool = False, **kwargs) -> subprocess.CompletedProcess:
    """Run a command with error handling"""
    print(f"Running: {' '.join(cmd) if isinstance(cmd, list) else cmd}",flush=True)
    try:
        return subprocess.run(cmd, capture_output=capture_output, check=check, **kwargs)
    except subprocess.CalledProcessError as e:
        log_error(f"Command failed: {e}")
        raise

def terminate_process_windows(proc: subprocess.Popen) -> None:
    """Terminate process using the same mechanism as test-interrupt.py"""
    print("Sending Ctrl+C to process...",flush=True)
    
    try:
        ctypes.windll.kernel32.GenerateConsoleCtrlEvent(0, 0)
        time.sleep(10)
    except KeyboardInterrupt:
        pass

    try:
        exit_code = proc.wait(timeout=120)
        print(f"Process exited with code: {exit_code}",flush=True)
    except subprocess.TimeoutExpired:
        print("ERROR: Process did not terminate after Ctrl+C",flush=True)
        proc.kill()
        raise RuntimeError("Process termination failed")

def remove_readonly(func, path, _):
   "Clear the readonly bit and reattempt the removal"
   os.chmod(path, stat.S_IWRITE)
   func(path)

def main() -> int:
    print("Starting bare deployment test",flush=True)
    
    script_dir = Path(__file__).parent
    root: Path = script_dir.parent

    working_directory: Path = root / "tmp-test-bare"
    if working_directory.exists():
        shutil.rmtree(working_directory, onexc=remove_readonly)
    working_directory.mkdir()
    
    abseil_output_base = working_directory / "abseil_output_base"
    bare_output = working_directory / "bb-output.txt"
    data_dir = working_directory /"bb-data"
    data_dir.mkdir()
    
    # Determine platform-specific parameters
    system: str = platform.system()
    remote_exec_config: List[str] = ['--config=remote-local']
    if system == "Windows":
        script_name = working_directory/"run_bare.cmd"
        script_exec = ["cmd.exe", "/c",str( script_name)]
        remote_exec_config.append('--config=remote-exec-windows')
        os.environ["OS"] = "Windows"
    else:
        script_name =working_directory/ "run_bare.sh"
        script_exec = [str(script_name)]
        os.environ["OS"] = platform.system()
    
    buildbarn_pid: Optional[subprocess.Popen] = None
    
    def cleanup() -> None:
        """Cleanup function to be called on exit"""
        print("Cleaning up...",flush=True)
        
        # Terminate buildbarn process if running
        if buildbarn_pid and buildbarn_pid.poll() is None:
            if system == "Windows":
                terminate_process_windows(buildbarn_pid)
            else:
                buildbarn_pid.send_signal(signal.SIGTERM)
                buildbarn_pid.wait()
            try:
                buildbarn_pid.kill()
                buildbarn_pid.wait(timeout=10)
            except Exception as e:
                log_error(f"Failed to terminate buildbarn process: {e}")

        # Shutdown bazel
        try:
            run_command(["bazel",f"--output_base={abseil_output_base}", "shutdown"], check=True, cwd=root)
        except Exception as e:
            log_error(f"Failed to terminate Bazel process: {e}")

        try:
            shutil.rmtree(working_directory, onexc=remove_readonly)
        except Exception as e:
            log_error(f"Failed to cleanup directory: {e}")

    try:
        # Generate the bare deployment script
        run_command([
            "bazel", "run", f"--script_path={script_name}", "--", 
            "//bare", str(data_dir)
        ], cwd=root)
        run_command(["bazel", "shutdown"], cwd=root)
        
        # Start the buildbarn server
        print("Starting buildbarn server...",flush=True)
        with open(bare_output, 'w') as output_file:
            buildbarn_pid = subprocess.Popen(
                script_exec,
                stdin=subprocess.DEVNULL,
                stdout=output_file,
                stderr=subprocess.STDOUT,
                cwd=working_directory
            )
              # Give some time for the server to start
            time.sleep(5)
        
        print(f"Started buildbarn with PID: {buildbarn_pid.pid}",flush=True)
        
        # --- Run remote execution ---
        print("Running first remote execution test...",flush=True)
        
        run_command([
            "bazel", f"--output_base={abseil_output_base}", "--nohome_rc", "clean"
        ], cwd=root)
        cmd = [
            "bazel", f"--output_base={abseil_output_base}", "--nohome_rc",
            "test", "--color=no", "--curses=no", "--disk_cache="
        ] + remote_exec_config + ["@abseil-hello//:hello_test"]
        run_command(cmd, cwd=root)
        
        # Check for remote executions but no cache hits
        command_log: Path = Path(root) / abseil_output_base / "command.log"
        if command_log.exists():
            with open(command_log, 'r') as f:
                log_content: str = f.read()
                
            # Look for remote executions
            remote_found: bool = False
            for line in log_content.split('\n'):
                if line.startswith('INFO:') and 'processes:' in line and 'remote' in line:
                    if 'remote cache hit' not in line:
                        print(f"Found remote execution: {line}",flush=True)
                        remote_found = True
                        break
            
            if not remote_found:
                raise RuntimeError("Expected remote executions but found none")
        
        # --- Check that we get cache hit even after rebooting the server ---
        print("Restarting server to test cache persistence...",flush=True)
        
        # Terminate the buildbarn process using the same mechanism as test-interrupt.py
        if system == "Windows":
            terminate_process_windows(buildbarn_pid)
        else:
            buildbarn_pid.send_signal(signal.SIGTERM)
            buildbarn_pid.wait()
        
        # Restart the server
        print("Restarting buildbarn server...",flush=True)
        with open(bare_output, 'w') as output_file:
            buildbarn_pid = subprocess.Popen(
                script_exec,
                stdin=subprocess.DEVNULL,
                stdout=output_file,
                stderr=subprocess.STDOUT,
                cwd=working_directory
            )
            # Give some time for the server to start
            time.sleep(5)
        
        # Clean bazel cache again
        run_command([
            "bazel", f"--output_base={abseil_output_base}", "--nohome_rc", "clean"
        ], cwd=root)
        
        # Run test again - should get cache hits
        print("Running second test (expecting cache hits)...",flush=True)
        run_command(cmd, cwd=root)
        
        # Check for remote cache hits but no remote executions
        if command_log.exists():
            with open(command_log, 'r') as f:
                log_content = f.read()
            
            cache_hit_found: bool = False
            for line in log_content.split('\n'):
                if (line.startswith('INFO:') and 'processes:' in line and 
                    'remote cache hit' in line and 'remote,' not in line and 'remote.' not in line):
                    print(f"Found cache hit: {line}",flush=True)
                    cache_hit_found = True
                    break
            
            if not cache_hit_found:
                raise RuntimeError("Expected remote cache hits but found none")
        
        print("SUCCESS: Bare deployment test completed successfully",flush=True)
        return 0
        
    except Exception as e:
        log_error(f"Test failed: {e}")
        
        # Show output on failure
        if os.path.exists(working_directory / bare_output):
            print("Server output:",flush=True)
            with open(working_directory / bare_output, 'r') as f:
                print(f.read(),flush=True)
        
        return 1
        
    finally:
        cleanup()

if __name__ == "__main__":
    sys.exit(main())
