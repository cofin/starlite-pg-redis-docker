from starlite import LoggingConfig, OpenAPIConfig, Starlite, get
from starlite.plugins.sql_alchemy import SQLAlchemyPlugin

from app.api import v1_router
from app.config import settings
from app.db import close_postgres_connection, get_postgres_connection


@get(path="/")
def health_check() -> dict:
    return {"status": "healthy"}


logging_conf = LoggingConfig(loggers={"app": {"level": "DEBUG", "handlers": ["console"]}})

app = Starlite(
    route_handlers=[health_check, v1_router],
    plugins=[SQLAlchemyPlugin()],
    on_startup=[get_postgres_connection],
    on_shutdown=[close_postgres_connection],
    openapi_config=OpenAPIConfig(title="Starlite Postgres Example API", version="1.0.0"),
)

# Seed db if in development and users dont exist
if settings.DEVELOPMENT:
    from app.utils.seed_db import seed_db

    seed_db()
