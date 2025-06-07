from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    """
    Настройки Flask приложения.
    Только то, что ДЕЙСТВИТЕЛЬНО нужно приложению для работы.
    """
    model_config = SettingsConfigDict(
        env_file='.env',
        env_file_encoding='utf-8',
        case_sensitive=False
    )

    postgres_host: str = Field(default="db", alias="POSTGRES_HOST")
    postgres_port: int = Field(default=5432, alias="POSTGRES_PORT")
    postgres_db: str = Field(default="db", alias="POSTGRES_DB")
    postgres_user: str = Field(default="postgres", alias="PGUSER")
    postgres_password: str = Field(default="postgres", alias="POSTGRES_PASSWORD")
    
    api_port: int = Field(default=5000, alias="API_PORT")
    log_level: str = Field(default="INFO", alias="LOG_LEVEL")
    
    @property
    def database_url(self) -> str:
        """Генерация URL для подключения к PostgreSQL"""
        return (
            f"postgresql://{self.postgres_user}:{self.postgres_password}"
            f"@{self.postgres_host}:{self.postgres_port}/{self.postgres_db}"
        )
    
    @property
    def is_development(self) -> bool:
        """Проверка режима разработки"""
        return self.flask_env.lower() == "development"

settings = Settings()
