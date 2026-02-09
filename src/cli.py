"""Egregore Server CLI - Lifecycle management for the SSE MCP server."""

from __future__ import annotations

import argparse
import os
import signal
import subprocess
import sys
import time
from pathlib import Path
from typing import NoReturn

import psutil

from src.config import get_settings

# Constants
PID_FILE = Path("/tmp/egregore.pid")
LOCK_FILE = Path("/tmp/egregore.lock")
LOG_FILE = Path("/tmp/egregore.log")


def get_pid() -> int | None:
    """Get the PID of the running Egregore server if it exists."""
    if not PID_FILE.exists():
        return None
    try:
        pid = int(PID_FILE.read_text().strip())
        # Check if process actually exists and is egregore
        if psutil.pid_exists(pid):
            proc = psutil.Process(pid)
            if "egregore" in proc.name().lower() or any(
                "egregore" in cmd.lower() for cmd in proc.cmdline()
            ):
                return pid
        # Stale PID file
        PID_FILE.unlink(missing_ok=True)
        return None
    except (ValueError, psutil.NoSuchProcess):
        PID_FILE.unlink(missing_ok=True)
        return None


def is_running() -> bool:
    """Check if the Egregore server is currently running."""
    return get_pid() is not None


def start_server(host: str, port: int, daemon: bool = True) -> int | None:
    """Start the Egregore SSE server.

    Args:
        host: Host address to bind to
        port: Port to listen on
        daemon: Whether to run as a background daemon

    Returns:
        Process PID if started successfully, None otherwise
    """
    if is_running():
        pid = get_pid()
        print(f"Egregore server is already running (PID: {pid})")
        return pid

    settings = get_settings()
    server_script = Path(__file__).parent / "server.py"

    # Environment for the server
    env = os.environ.copy()
    env["EGREGORE_HOST"] = host
    env["EGREGORE_PORT"] = str(port)

    if daemon:
        # Start as daemon process
        with open(LOG_FILE, "a") as log:
            process = subprocess.Popen(
                [sys.executable, str(server_script)],
                stdout=log,
                stderr=subprocess.STDOUT,
                start_new_session=True,
                env=env,
            )
    else:
        # Start in foreground
        process = subprocess.Popen(
            [sys.executable, str(server_script)],
            stdout=sys.stdout,
            stderr=sys.stderr,
            env=env,
        )

    # Wait a moment to verify it started
    time.sleep(2)

    if process.poll() is not None:
        print(f"Failed to start Egregore server (exit code: {process.returncode})")
        if LOG_FILE.exists():
            print("Last log entries:")
            print(LOG_FILE.read_text()[-500:])
        return None

    print(f"Egregore server started successfully")
    print(f"  PID: {process.pid}")
    print(f"  URL: http://{host}:{port}/sse")
    return process.pid


def stop_server() -> bool:
    """Stop the running Egregore server.

    Returns:
        True if stopped successfully, False otherwise
    """
    pid = get_pid()
    if pid is None:
        print("Egregore server is not running")
        # Clean up any stale files
        PID_FILE.unlink(missing_ok=True)
        LOCK_FILE.unlink(missing_ok=True)
        return True

    try:
        # Try graceful shutdown first
        os.kill(pid, signal.SIGTERM)

        # Wait for process to terminate
        for _ in range(10):
            if not psutil.pid_exists(pid):
                break
            time.sleep(0.5)

        # Force kill if still running
        if psutil.pid_exists(pid):
            os.kill(pid, signal.SIGKILL)
            time.sleep(0.5)

        # Clean up PID file
        PID_FILE.unlink(missing_ok=True)
        LOCK_FILE.unlink(missing_ok=True)

        print(f"Egregore server stopped (PID: {pid})")
        return True

    except (ProcessLookupError, PermissionError) as e:
        print(f"Error stopping server: {e}")
        # Clean up stale files anyway
        PID_FILE.unlink(missing_ok=True)
        LOCK_FILE.unlink(missing_ok=True)
        return False


def get_status() -> dict:
    """Get detailed status of the Egregore server.

    Returns:
        Dictionary with status information
    """
    pid = get_pid()
    settings = get_settings()

    if pid is None:
        return {
            "running": False,
            "pid": None,
            "host": settings.egregore_host,
            "port": settings.egregore_port,
            "url": f"http://{settings.egregore_host}:{settings.egregore_port}/sse",
        }

    try:
        proc = psutil.Process(pid)
        memory_info = proc.memory_info()

        return {
            "running": True,
            "pid": pid,
            "host": settings.egregore_host,
            "port": settings.egregore_port,
            "url": f"http://{settings.egregore_host}:{settings.egregore_port}/sse",
            "cpu_percent": proc.cpu_percent(interval=0.1),
            "memory_mb": memory_info.rss / 1024 / 1024,
            "create_time": proc.create_time(),
            "connections": len(proc.connections()),
        }
    except psutil.NoSuchProcess:
        return {
            "running": False,
            "pid": None,
            "host": settings.egregore_host,
            "port": settings.egregore_port,
            "url": f"http://{settings.egregore_host}:{settings.egregore_port}/sse",
        }


def show_status() -> None:
    """Display the current server status."""
    status = get_status()

    if not status["running"]:
        print("Egregore server is not running")
        print(f"  Configured URL: {status['url']}")
        print("")
        print("To start the server:")
        print("  egregore-server start")
        return

    print("Egregore server is running")
    print(f"  PID:        {status['pid']}")
    print(f"  URL:        {status['url']}")
    print(f"  Memory:     {status['memory_mb']:.1f} MB")
    print(f"  CPU:        {status['cpu_percent']:.1f}%")
    print(f"  Connections: {status['connections']}")


def show_logs(follow: bool = False, lines: int = 50) -> None:
    """Show server logs.

    Args:
        follow: Whether to follow logs in real-time (like tail -f)
        lines: Number of lines to show from the end
    """
    if not LOG_FILE.exists():
        print("No log file found")
        return

    if follow:
        print(f"Following logs from {LOG_FILE} (Ctrl+C to exit)...")
        try:
            subprocess.run(["tail", "-f", str(LOG_FILE)])
        except KeyboardInterrupt:
            print("")
    else:
        try:
            # Get last N lines
            result = subprocess.run(
                ["tail", "-n", str(lines), str(LOG_FILE)],
                capture_output=True,
                text=True,
            )
            print(result.stdout)
        except subprocess.CalledProcessError:
            print(f"Could not read log file: {LOG_FILE}")


def restart_server(host: str, port: int) -> int | None:
    """Restart the Egregore server.

    Args:
        host: Host address to bind to
        port: Port to listen on

    Returns:
        Process PID if restarted successfully, None otherwise
    """
    print("Restarting Egregore server...")
    stop_server()
    time.sleep(1)
    return start_server(host, port)


def main() -> NoReturn:
    """Main CLI entry point."""
    parser = argparse.ArgumentParser(
        description="Egregore Server - Manage the SSE MCP server",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  egregore-server start           # Start server as daemon
  egregore-server start --no-daemon  # Start in foreground
  egregore-server stop            # Stop server
  egregore-server status          # Show server status
  egregore-server restart         # Restart server
  egregore-server logs            # Show recent logs
  egregore-server logs -f         # Follow logs in real-time
        """,
    )

    subparsers = parser.add_subparsers(dest="command", help="Available commands")

    # Start command
    start_parser = subparsers.add_parser("start", help="Start the Egregore server")
    start_parser.add_argument(
        "--host",
        default=None,
        help="Host address to bind to (default: from env or 0.0.0.0)",
    )
    start_parser.add_argument(
        "--port",
        type=int,
        default=None,
        help="Port to listen on (default: from env or 9000)",
    )
    start_parser.add_argument(
        "--no-daemon",
        action="store_true",
        help="Run in foreground (don't detach)",
    )

    # Stop command
    subparsers.add_parser("stop", help="Stop the Egregore server")

    # Status command
    subparsers.add_parser("status", help="Show server status")

    # Restart command
    restart_parser = subparsers.add_parser("restart", help="Restart the Egregore server")
    restart_parser.add_argument(
        "--host",
        default=None,
        help="Host address to bind to (default: from env or 0.0.0.0)",
    )
    restart_parser.add_argument(
        "--port",
        type=int,
        default=None,
        help="Port to listen on (default: from env or 9000)",
    )

    # Logs command
    logs_parser = subparsers.add_parser("logs", help="Show server logs")
    logs_parser.add_argument(
        "-f", "--follow",
        action="store_true",
        help="Follow logs in real-time",
    )
    logs_parser.add_argument(
        "-n", "--lines",
        type=int,
        default=50,
        help="Number of lines to show (default: 50)",
    )

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        sys.exit(1)

    settings = get_settings()
    host = args.host if hasattr(args, "host") and args.host else settings.egregore_host
    port = args.port if hasattr(args, "port") and args.port else settings.egregore_port

    if args.command == "start":
        daemon = not args.no_daemon
        pid = start_server(host, port, daemon=daemon)
        sys.exit(0 if pid else 1)

    elif args.command == "stop":
        success = stop_server()
        sys.exit(0 if success else 1)

    elif args.command == "status":
        show_status()
        sys.exit(0)

    elif args.command == "restart":
        pid = restart_server(host, port)
        sys.exit(0 if pid else 1)

    elif args.command == "logs":
        show_logs(follow=args.follow, lines=args.lines)
        sys.exit(0)

    else:
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
