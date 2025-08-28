#!/usr/bin/env bash

set -eux -o pipefail -E

echo "Testing SIGINT with simple subcommand"

test_script="test-long-running-task.bat"
cat > "$test_script" << 'EOF'
echo Starting long running task...
ping -n 30 -w 1000 localhost
echo Task completed normally
EOF

echo "Starting cmd.exe with subcommand..."
cmd.exe //c $test_script &
CMD_PID=$!

echo "Started cmd.exe with PID: $CMD_PID"

sleep 2

# Verify the process is still running
if ! kill -0 $CMD_PID 2>/dev/null; then
    echo "ERROR: cmd.exe process died unexpectedly"
    exit 1
fi

echo "Sending SIGINT to cmd.exe process..."

# CMD_WINDOWS_PID=$(cat /proc/$CMD_PID/winpid)
PGID=$(cat /proc/$CMD_PID/pgid)
echo "Going to kill pid $CMD_PID who is in group $PGID"
# echo "Current process PID: $$"
# echo "Current process PGID: $(cat /proc/$$/pgid)"
# powershell.exe ./tools/test-interrupt-pid.py $CMD_WINDOWS_PID
kill -SIGINT $CMD_PID

exit_code=0
if ! wait $CMD_PID; then
    exit_code=$?
fi

# echo "Error log from test-interrupt-pid.py"
# cat err.log

echo "cmd.exe exited with code: $exit_code"

# Check if the process actually terminated
if kill -0 $CMD_PID 2>/dev/null; then
    echo "ERROR: Process is still running after SIGINT"
    exit 1
else
    echo "SUCCESS: Process terminated successfully"
fi
