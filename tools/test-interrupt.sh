#!/usr/bin/env bash

# set -eux -o pipefail -E

echo "Testing SIGINT with simple subcommand"

test_script="test-long-running-task.bat"
cat > "$test_script" << 'EOF'
echo Starting long running task...
ping -n 60 -w 1000 localhost > nul
echo Task completed normally
EOF

echo "Starting cmd.exe with subcommand..."
cmd.exe //c $test_script </dev/null >test-subcommand-output.txt 2>&1 &
CMD_PID=$!

echo "Started cmd.exe with PID: $CMD_PID"

sleep 2

# Verify the process is still running
if ! kill -0 $CMD_PID 2>/dev/null; then
    echo "ERROR: cmd.exe process died unexpectedly"
    exit 1
fi

echo "Sending SIGINT to cmd.exe process..."

echo "Converting POSIX PID $CMD_PID to Windows PID..."
WIN_PID=$(cat /proc/$CMD_PID/winpid)
echo "Windows PID: $WIN_PID"

windows-kill -SIGINT $WIN_PID

exit_code=0
if ! wait $CMD_PID; then
    exit_code=$?
fi

echo "cmd.exe exited with code: $exit_code"

# Check if the process actually terminated
if kill -0 $CMD_PID 2>/dev/null; then
    echo "ERROR: Process is still running after SIGINT"
    exit 1
else
    echo "SUCCESS: Process terminated successfully"
fi

# Check the output
if [[ -f test-subcommand-output.txt ]]; then
    echo "Command output:"
    cat test-subcommand-output.txt
fi
