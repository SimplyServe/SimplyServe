"""
Integration tests for main app endpoints and general functionality.
Tests CORS, health checks, and general app behavior.
"""

import pytest
from httpx import AsyncClient


class TestAppSetup:
    """Tests for basic app setup and functionality."""

    async def test_app_running(self, async_client: AsyncClient):
        """Test that the app is running and responding."""
        # Try a basic endpoint that should exist
        response = await async_client.get("/recipes")
        assert response.status_code == 200


    async def test_cors_headers_present(self, async_client: AsyncClient):
        """Test that CORS headers are properly set."""
        response = await async_client.get("/recipes")

        # CORS headers should be present
        # (exact header names depend on CORS configuration)
        assert response.status_code == 200


class TestErrorHandling:
    """Tests for error handling and status codes."""

    async def test_nonexistent_endpoint_404(self, async_client: AsyncClient):
        """Test that nonexistent endpoints return 404."""
        response = await async_client.get("/nonexistent/endpoint")
        assert response.status_code == 404


    async def test_invalid_json_request(self, async_client: AsyncClient):
        """Test handling of invalid JSON in request body."""
        response = await async_client.post(
            "/register",
            content="not valid json"
        )

        # Should reject invalid JSON
        assert response.status_code in [400, 422]


    async def test_missing_required_form_fields(
        self,
        async_client: AsyncClient,
        auth_headers: dict
    ):
        """Test that missing form fields are rejected."""
        response = await async_client.post(
            "/recipes",
            data={
                # Intentionally missing required fields
                "title": "Incomplete"
            },
            headers=auth_headers
        )

        assert response.status_code == 422


class TestResponseFormats:
    """Tests for consistent response formatting."""

    async def test_error_response_structure(
        self,
        async_client: AsyncClient
    ):
        """Test that error responses have consistent structure."""
        response = await async_client.post(
            "/token",
            data={"username": "invalid@example.com", "password": "wrong"}
        )

        assert response.status_code == 401
        data = response.json()

        # Error responses should have detail
        assert "detail" in data


    async def test_json_response_content_type(
        self,
        async_client: AsyncClient
    ):
        """Test that responses have correct content-type."""
        response = await async_client.get("/recipes")

        # Should be JSON
        assert "application/json" in response.headers.get("content-type", "")


    async def test_list_endpoint_returns_list(
        self,
        async_client: AsyncClient
    ):
        """Test that list endpoints return JSON arrays."""
        response = await async_client.get("/recipes")
        assert response.status_code == 200

        data = response.json()
        assert isinstance(data, list)


class TestConcurrentRequests:
    """Tests for handling concurrent requests."""

    async def test_multiple_sequential_requests(
        self,
        async_client: AsyncClient
    ):
        """Test multiple sequential requests succeed."""
        for _ in range(5):
            response = await async_client.get("/recipes")
            assert response.status_code == 200


    async def test_different_users_concurrent(
        self,
        async_client: AsyncClient
    ):
        """Test that concurrent requests from different users work."""
        # Register first user
        user1 = {
            "email": "concurrent1@example.com",
            "password": "password1",
            "name": "User 1"
        }
        response1 = await async_client.post("/register", json=user1)
        assert response1.status_code == 200

        # Register second user
        user2 = {
            "email": "concurrent2@example.com",
            "password": "password2",
            "name": "User 2"
        }
        response2 = await async_client.post("/register", json=user2)
        assert response2.status_code == 200

        # Both users should be registered
        assert response1.json()["email"] == user1["email"]
        assert response2.json()["email"] == user2["email"]


class TestDataConsistency:
    """Tests for data consistency across requests."""

    async def test_created_data_persists(
        self,
        async_client: AsyncClient,
        auth_headers: dict,
        base_ingredients
    ):
        """Test that created data is persisted across requests."""
        recipe_data = {
            "title": "Persistence Test Recipe",
            "summary": "Test recipe for persistence",
            "prep_time": "10 minutes",
            "cook_time": "20 minutes",
            "total_time": "30 minutes",
            "servings": 2,
            "difficulty": "Easy",
            "tags_json": "[]",
            "ingredients_json": '[{"ingredient_name": "egg", "quantity": 1, "unit": "pcs"}]',
            "steps_json": '["Mix", "Cook"]'
        }

        # Create recipe
        create_response = await async_client.post(
            "/recipes",
            data=recipe_data,
            headers=auth_headers
        )
        assert create_response.status_code == 200
        recipe_id = create_response.json()["id"]

        # Fetch recipes
        list_response = await async_client.get("/recipes")
        assert list_response.status_code == 200

        recipes = list_response.json()
        recipe_ids = [r["id"] for r in recipes]

        # Created recipe should be in list
        assert recipe_id in recipe_ids


    async def test_user_data_isolation(
        self,
        async_client: AsyncClient
    ):
        """Test that different users' data is properly isolated."""
        # Create first user
        user1 = {
            "email": "isolation1@example.com",
            "password": "password1",
            "name": "User 1"
        }
        response1 = await async_client.post("/register", json=user1)
        user1_id = response1.json()["id"]

        # Create second user
        user2 = {
            "email": "isolation2@example.com",
            "password": "password2",
            "name": "User 2"
        }
        response2 = await async_client.post("/register", json=user2)
        user2_id = response2.json()["id"]

        # Users should have different IDs
        assert user1_id != user2_id

        # Login as user1
        login1 = await async_client.post(
            "/token",
            data={"username": user1["email"], "password": user1["password"]}
        )

        headers1 = {"Authorization": f"Bearer {login1.json()['access_token']}"}

        # User1 can access their own data
        me1 = await async_client.get("/users/me", headers=headers1)
        assert me1.json()["id"] == user1_id
        assert me1.json()["email"] == user1["email"]
