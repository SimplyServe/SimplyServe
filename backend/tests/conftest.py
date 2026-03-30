"""
Shared pytest fixtures for all tests.
Provides test database, async client, and test data loading.
"""

import asyncio
import json
import os
from pathlib import Path
from typing import AsyncGenerator

import pytest
from httpx import AsyncClient, ASGITransport
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import sessionmaker

from database import Base, get_db
from main import app


# Use in-memory SQLite database for testing
TEST_DATABASE_URL = "sqlite+aiosqlite:///:memory:"


@pytest.fixture(scope="session")
def event_loop_policy():
    """Set the event loop policy for the test session."""
    policy = asyncio.get_event_loop_policy()
    yield policy


@pytest.fixture
async def test_db() -> AsyncGenerator[AsyncSession, None]:
    """
    Create a test database and return an async session.
    Database is cleaned up after each test.
    """
    engine = create_async_engine(
        TEST_DATABASE_URL,
        echo=False,
        connect_args={"check_same_thread": False}
    )

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    async_session_maker = sessionmaker(
        engine, class_=AsyncSession, expire_on_commit=False
    )

    async with async_session_maker() as session:
        yield session

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)

    await engine.dispose()


@pytest.fixture
async def async_client(test_db: AsyncSession) -> AsyncGenerator[AsyncClient, None]:
    """
    Create an async HTTP client for testing the FastAPI app.
    Uses the test database instead of the production database.
    """
    async def override_get_db() -> AsyncGenerator[AsyncSession, None]:
        yield test_db

    app.dependency_overrides[get_db] = override_get_db

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        yield client

    app.dependency_overrides.clear()


@pytest.fixture
def load_json_data():
    """
    Helper function to load JSON data files from the data directory.
    """
    def _load(filename: str):
        data_dir = Path(__file__).parent.parent / "data"
        filepath = data_dir / filename
        if not filepath.exists():
            raise FileNotFoundError(f"Data file not found: {filepath}")
        with open(filepath, "r", encoding="utf-8") as f:
            return json.load(f)

    return _load


@pytest.fixture
async def base_ingredients(test_db: AsyncSession, load_json_data):
    """
    Load base ingredients from JSON file into test database.
    """
    from models import Ingredients
    from sqlalchemy import select

    ingredients_data = load_json_data("base_ingredients.json")

    existing = await test_db.execute(select(Ingredients))
    if existing.scalars().first():
        # Already seeded
        return

    for ing_data in ingredients_data:
        ingredient = Ingredients(
            ingredient_name=ing_data["ingredient_name"],
            avg_calories=ing_data["avg_calories"],
            avg_protein=ing_data["avg_protein"],
            avg_carbs=ing_data["avg_carbs"],
            avg_fat=ing_data["avg_fat"],
            avg_cost=ing_data["avg_cost"],
        )
        test_db.add(ingredient)

    await test_db.commit()


@pytest.fixture
async def test_user_data():
    """
    Provide test user data for registration and login tests.
    """
    return {
        "email": "testuser@example.com",
        "password": "testpassword123"
    }


@pytest.fixture
async def registered_user(async_client: AsyncClient, test_user_data: dict):
    """
    Create a registered test user and return user data with auth token.
    """
    # Register the user
    register_response = await async_client.post(
        "/register",
        json=test_user_data
    )

    if register_response.status_code != 200:
        raise RuntimeError(
            f"Failed to register test user: {register_response.text}"
        )

    # Login to get token
    login_response = await async_client.post(
        "/token",
        data={
            "username": test_user_data["email"],
            "password": test_user_data["password"]
        }
    )

    if login_response.status_code != 200:
        raise RuntimeError(
            f"Failed to login test user: {login_response.text}"
        )

    token_data = login_response.json()

    return {
        "user": test_user_data,
        "token": token_data["access_token"],
        "token_type": token_data["token_type"]
    }


@pytest.fixture
async def auth_headers(registered_user: dict) -> dict:
    """
    Provide authorization headers for protected endpoints.
    """
    token = registered_user["token"]
    return {
        "Authorization": f"Bearer {token}"
    }


@pytest.fixture
async def test_recipe_data():
    """
    Provide test recipe data for recipe creation tests.
    """
    return {
        "title": "Test Recipe",
        "summary": "This is a test recipe for testing purposes",
        "prep_time": "10 minutes",
        "cook_time": "20 minutes",
        "total_time": "30 minutes",
        "servings": 4,
        "difficulty": "Easy",
        "tags_json": json.dumps(["test", "easy"]),
        "ingredients_json": json.dumps([
            {
                "ingredient_name": "egg",
                "quantity": 2,
                "unit": "pcs"
            },
            {
                "ingredient_name": "milk",
                "quantity": 1,
                "unit": "cup"
            }
        ]),
        "steps_json": json.dumps([
            "Mix ingredients together",
            "Cook at 350F for 20 minutes",
            "Let cool before serving"
        ])
    }
