"""Egregore Skill - Hive Mind Memory CLI."""

from .client import EgregoreClient
from .main import main
from .ui import UI, Colors, Spinner, MemoryFormatter

__version__ = "2.0.0"
__all__ = ["EgregoreClient", "main", "UI", "Colors", "Spinner", "MemoryFormatter"]
