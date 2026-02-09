"""Configuration management for Egregore."""

from enum import Enum
from functools import lru_cache
from pathlib import Path

from pydantic import Field, SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict

# Get project root for .env file location
PROJECT_ROOT = Path(__file__).parent.parent


class EmbeddingProvider(str, Enum):
    """Supported embedding providers."""

    OPENAI = "openai"
    GEMINI = "gemini"


class Settings(BaseSettings):
    """Egregore configuration settings.

    Loads from environment variables and .env file.
    """

    model_config = SettingsConfigDict(
        env_file=str(PROJECT_ROOT / ".env"),
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    # Instance configuration
    instance_name: str = Field(
        default="egregore_collective",
        description="Name of this Egregore instance",
    )

    # Embedding configuration
    embedding_provider: EmbeddingProvider = Field(
        default=EmbeddingProvider.OPENAI,
        description="Embedding provider to use",
    )
    embedding_api_key: SecretStr = Field(
        description="API key for the embedding provider",
    )

    # Memgraph configuration
    memgraph_host: str = Field(default="localhost")
    memgraph_port: int = Field(default=7687)
    memgraph_user: str = Field(default="")
    memgraph_password: SecretStr = Field(default=SecretStr(""))

    # Qdrant configuration
    qdrant_host: str = Field(default="localhost")
    qdrant_port: int = Field(default=6333)

    @property
    def memgraph_uri(self) -> str:
        """Build Memgraph connection URI."""
        auth = ""
        if self.memgraph_user:
            auth = f"{self.memgraph_user}:{self.memgraph_password.get_secret_value()}@"
        return f"bolt://{auth}{self.memgraph_host}:{self.memgraph_port}"

    @property
    def qdrant_uri(self) -> str:
        """Build Qdrant connection URI."""
        return f"http://{self.qdrant_host}:{self.qdrant_port}"


@lru_cache
def get_settings() -> Settings:
    """Get cached settings instance."""
    return Settings()


# Export for convenient access
settings = get_settings()
