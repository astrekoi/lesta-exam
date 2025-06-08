from typing import Optional
from pydantic import Field
from pydantic_settings import BaseSettings

class PostgreSQLConfig(BaseSettings):
    POSTGRES_HOST: str = Field(
        default="db",
        description="PostgreSQL host"
    )
    
    POSTGRES_PORT: int = Field(
        default=5432,
        description="PostgreSQL port"
    )
    
    POSTGRES_DB: str = Field(
        default="db",
        description="Database name"
    )
    
    POSTGRES_USER: str = Field(
        default="postgres",
        alias="PGUSER",
        description="Database user"
    )
    
    POSTGRES_PASSWORD: str = Field(
        default="postgres",
        description="Database password"
    )
    
    @property
    def database_url(self) -> str:
        """DATABASE_URL"""
        return (
            f"postgresql://{self.POSTGRES_USER}:{self.POSTGRES_PASSWORD}"
            f"@{self.POSTGRES_HOST}:{self.POSTGRES_PORT}/{self.POSTGRES_DB}"
        )
