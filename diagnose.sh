#!/bin/bash
#
# Egregore Server Diagnosis Script
# Run this on the server to diagnose issues
#

echo "=== Egregore Server Diagnosis ==="
echo ""

# 1. Check if we're in the right directory
echo "1. Current directory:"
pwd
echo ""

# 2. Check if .venv exists
echo "2. Virtual environment:"
if [ -d ".venv" ]; then
    echo "✓ .venv exists"
    echo "  Python: $(.venv/bin/python --version 2>/dev/null || echo 'Not found')"
else
    echo "✗ .venv NOT found"
fi
echo ""

# 3. Check if .env exists
echo "3. Configuration (.env):"
if [ -f ".env" ]; then
    echo "✓ .env exists"
    echo "  EGREGORE_HOST: $(grep EGREGORE_HOST .env | cut -d= -f2)"
    echo "  EGREGORE_PORT: $(grep EGREGORE_PORT .env | cut -d= -f2)"
else
    echo "✗ .env NOT found"
fi
echo ""

# 4. Check Docker
echo "4. Docker services:"
if command -v docker >/dev/null 2>&1; then
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
else
    echo "✗ Docker not found"
fi
echo ""

# 5. Check if server is running
echo "5. Server process:"
if [ -f "/tmp/egregore.pid" ]; then
    PID=$(cat /tmp/egregore.pid)
    if ps -p "$PID" >/dev/null 2>&1; then
        echo "✓ Server running (PID: $PID)"
    else
        echo "✗ PID file exists but process dead (stale)"
        rm -f /tmp/egregore.pid
    fi
else
    echo "✗ No PID file found"
fi
echo ""

# 6. Check port 9000
echo "6. Port 9000:"
ss -tlnp | grep 9000 || echo "✗ Nothing listening on port 9000"
echo ""

# 7. Check logs
echo "7. Server logs (last 10 lines):"
if [ -f "/tmp/egregore.log" ]; then
    tail -10 /tmp/egregore.log
else
    echo "✗ No log file found"
fi
echo ""

# 8. Try to start server
echo "8. Attempting to start server:"
if [ -d ".venv" ]; then
    source .venv/bin/activate

    # Check EGREGORE_HOST in .env
    if [ -f ".env" ]; then
        HOST=$(grep EGREGORE_HOST .env | cut -d= -f2)
        PORT=$(grep EGREGORE_PORT .env | cut -d= -f2)
    else
        HOST="0.0.0.0"
        PORT="9000"
    fi

    echo "  Host: ${HOST:-0.0.0.0}"
    echo "  Port: ${PORT:-9000}"
    echo ""

    # Check if already listening
    if ss -tlnp | grep -q ":${PORT:-9000}"; then
        echo "  ✗ Port ${PORT:-9000} already in use"
        echo ""
        echo "Kill existing process first:"
        echo "  pkill -f 'python.*server'"
        exit 1
    fi

    echo "  Starting server..."
    export EGREGORE_HOST="${HOST:-0.0.0.0}"
    export EGREGORE_PORT="${PORT:-9000}"

    python -m src.server
else
    echo "  ✗ No .venv found - cannot start"
    exit 1
fi
