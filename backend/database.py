"""
database.py — Database engine and session factory for SimplyServe.

This module configures the async SQLAlchemy engine backed by SQLite and
exposes:
  - `engine`            : AsyncEngine used by startup migrations and tests.
  - `AsyncSessionLocal` : Session factory injected into every request via
                          the `get_db` FastAPI dependency.
  - `Base`              : Declarative base class imported by models.py to
                          define ORM table classes.
  - `get_db`            : Async generator dependency that yields a session
                          and tears it down after the request completes.

SQLite is chosen for local development simplicity. The `+aiosqlite` driver
prefix enables non-blocking I/O so the FastAPI async event loop is never
blocked by a database call.
"""

from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker, declarative_base

# SQLite database URL using the aiosqlite async driver.
# The file `main.db` is created in the backend working directory on first run.
SQLALCHEMY_DATABASE_URL = "sqlite+aiosqlite:///./main.db"

# `check_same_thread=False` is required for SQLite when the same connection
# may be accessed from multiple async coroutines within a single request.
engine = create_async_engine(
    SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False}
)

# Session factory bound to the async engine.
# `expire_on_commit=False` prevents SQLAlchemy from expiring ORM objects
# after a commit so they remain accessible without issuing extra SELECT
# queries — important in async contexts where implicit lazy loading is not
# allowed.
AsyncSessionLocal = sessionmaker(
    engine, class_=AsyncSession, expire_on_commit=False
)

# Declarative base class; all ORM model classes inherit from this.
# Calling `Base.metadata.create_all(conn)` during startup creates any
# tables that do not yet exist in main.db.
Base = declarative_base()


async def get_db():
    """FastAPI dependency that provides a database session for a single request.

    Yields:
        AsyncSession: An active database session scoped to the current request.
            The session is automatically closed when the request completes,
            whether or not an exception was raised.

    Usage:
        Declare as a FastAPI Depends parameter:
            db: AsyncSession = Depends(database.get_db)
    """
    # The `async with` block ensures the session is closed after the request,
    # even if an unhandled exception propagates out of the route handler.
    async with AsyncSessionLocal() as session:
        yield session
