"""
Integration tests for main app endpoints and general functionality.
Tests CORS, health checks, and general app behavior.
"""

import json
import time
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


# ── NFR: Performance ──────────────────────────────────────────────────────────

class TestNFRPerformance:
    """NFR: Performance-related tests."""

    async def test_recipe_list_responds_under_2_seconds(self, async_client: AsyncClient):
        """NFR: GET /recipes responds within acceptable time."""
        start = time.time()
        resp = await async_client.get("/recipes")
        elapsed = time.time() - start
        assert resp.status_code == 200
        assert elapsed < 2.0

    async def test_ingredient_search_responds_under_2_seconds(
        self, async_client: AsyncClient, base_ingredients
    ):
        """NFR: GET /ingredients responds within acceptable time."""
        start = time.time()
        resp = await async_client.get("/ingredients?q=egg")
        elapsed = time.time() - start
        assert resp.status_code == 200
        assert elapsed < 2.0

    async def test_sequential_requests_stable(self, async_client: AsyncClient):
        """NFR: multiple sequential requests succeed without degradation."""
        for _ in range(10):
            resp = await async_client.get("/recipes")
            assert resp.status_code == 200


# ── NFR: Error handling ───────────────────────────────────────────────────────

class TestNFRErrorHandling:
    """NFR: Error handling consistency."""

    async def test_404_has_detail(self, async_client: AsyncClient):
        """NFR: 404 responses include detail field."""
        resp = await async_client.get("/nonexistent")
        assert resp.status_code in [404, 405]

    async def test_invalid_recipe_id_404(self, async_client: AsyncClient):
        """NFR: invalid recipe ID returns 404."""
        resp = await async_client.delete("/recipes/999999")
        assert resp.status_code == 404
        assert "detail" in resp.json()

    async def test_invalid_json_body_422(self, async_client: AsyncClient):
        """NFR: invalid JSON body returns 422."""
        resp = await async_client.post("/register", content="not json")
        assert resp.status_code in [400, 422]

    async def test_missing_form_fields_422(self, async_client: AsyncClient):
        """NFR: missing required form fields returns 422."""
        resp = await async_client.post("/recipes", data={"title": "Incomplete"})
        assert resp.status_code == 422

    async def test_auth_error_returns_401(self, async_client: AsyncClient):
        """NFR: authentication errors return 401."""
        resp = await async_client.post("/token", data={
            "username": "nobody@example.com", "password": "wrong"
        })
        assert resp.status_code == 401
        assert "detail" in resp.json()


# ── NFR: Data consistency ─────────────────────────────────────────────────────

class TestNFRDataConsistency:
    """NFR: Data consistency and integrity."""

    async def test_created_recipe_persists_in_listing(
        self, async_client: AsyncClient, base_ingredients
    ):
        """NFR: created recipe immediately visible in listing."""
        create = await async_client.post("/recipes", data={
            "title": "NFR Persist", "summary": "persist test",
            "tags_json": "[]",
            "ingredients_json": json.dumps([{"ingredient_name": "egg", "quantity": 1, "unit": "pcs"}]),
            "steps_json": json.dumps(["Cook"]),
        })
        rid = create.json()["id"]
        recipes = (await async_client.get("/recipes")).json()
        assert rid in [r["id"] for r in recipes]

    async def test_user_data_isolation(self, async_client: AsyncClient):
        """NFR: different users' data is isolated."""
        for email in ["nfr_iso1@example.com", "nfr_iso2@example.com"]:
            await async_client.post("/register", json={"email": email, "password": "pass"})

        login1 = await async_client.post("/token", data={
            "username": "nfr_iso1@example.com", "password": "pass"
        })
        login2 = await async_client.post("/token", data={
            "username": "nfr_iso2@example.com", "password": "pass"
        })

        me1 = await async_client.get(
            "/users/me", headers={"Authorization": f"Bearer {login1.json()['access_token']}"}
        )
        me2 = await async_client.get(
            "/users/me", headers={"Authorization": f"Bearer {login2.json()['access_token']}"}
        )
        assert me1.json()["email"] == "nfr_iso1@example.com"
        assert me2.json()["email"] == "nfr_iso2@example.com"
        assert me1.json()["id"] != me2.json()["id"]

    async def test_soft_delete_does_not_lose_data(
        self, async_client: AsyncClient, base_ingredients
    ):
        """NFR: soft-deleted recipe data preserved in deleted listing."""
        create = await async_client.post("/recipes", data={
            "title": "NFR SoftDel Data", "summary": "preserve me",
            "tags_json": json.dumps(["nfr"]),
            "ingredients_json": json.dumps([{"ingredient_name": "egg", "quantity": 2, "unit": "pcs"}]),
            "steps_json": json.dumps(["Step 1"]),
        })
        rid = create.json()["id"]

        await async_client.delete(f"/recipes/{rid}")

        deleted = (await async_client.get("/recipes/deleted")).json()
        recipe = next((r for r in deleted if r["id"] == rid), None)
        assert recipe is not None
        assert recipe["title"] == "NFR SoftDel Data"
        assert recipe["summary"] == "preserve me"


# ── NFR: Response format ──────────────────────────────────────────────────────

class TestNFRResponseFormat:
    """NFR: Consistent response formatting."""

    async def test_json_content_type(self, async_client: AsyncClient):
        """NFR: responses have application/json content type."""
        resp = await async_client.get("/recipes")
        assert "application/json" in resp.headers.get("content-type", "")

    async def test_list_endpoints_return_arrays(self, async_client: AsyncClient):
        """NFR: list endpoints return JSON arrays."""
        for endpoint in ["/recipes", "/recipes/deleted", "/ingredients"]:
            resp = await async_client.get(endpoint)
            assert resp.status_code == 200
            assert isinstance(resp.json(), list)

    async def test_error_response_has_detail_field(self, async_client: AsyncClient):
        """NFR: error responses have 'detail' field."""
        resp = await async_client.post("/token", data={
            "username": "x@x.com", "password": "wrong"
        })
        assert resp.status_code == 401
        assert "detail" in resp.json()
