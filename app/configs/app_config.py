from pydantic_settings import BaseSettings, PydanticBaseSettingsSource, SettingsConfigDict
from .postgres_config import PostgreSQLConfig

class AppConfig(PostgreSQLConfig):
    FLASK_ENV: str = "development"
    FLASK_DEBUG: bool = False
    API_PORT: int = 5000
    
    model_config = SettingsConfigDict(
        env_file=".env", 
        env_file_encoding="utf-8",
        extra="ignore",
    )

    @classmethod
    def settings_customise_sources(
        cls,
        settings_cls: type[BaseSettings],
        init_settings: PydanticBaseSettingsSource,
        env_settings: PydanticBaseSettingsSource,
        dotenv_settings: PydanticBaseSettingsSource,
        file_secret_settings: PydanticBaseSettingsSource,
    ) -> tuple[PydanticBaseSettingsSource, ...]:
        return (
            init_settings,
            dotenv_settings,
            env_settings,
            file_secret_settings,
        )
