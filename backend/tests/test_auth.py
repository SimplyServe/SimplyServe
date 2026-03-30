"""
Integration tests for authentication endpoints.
Tests user registration, login, token generation, and protected routes.
"""

import pytest
from httpx import AsyncClient


class TestRegistration:
    """Tests for the /register endpoint."""

    async def test_register_success(
        self,
        async_client: AsyncClient,
        test_user_data: dict
    ):
        """Test successful user registration."""
        response = await async_client.post(
            "/register",
            json=test_user_data
        )

        assert response.status_code == 200
        data = response.json()

        assert "id" in data
        assert data["email"] == test_user_data["email"]
        assert "is_active" in data
        assert data["is_active"] == True
        assert "password" not in data  # Password should never be returned


    async def test_register_duplicate_email(
        self,
        async_client: AsyncClient,
        registered_user: dict
    ):
        """Test registration with duplicate email fails."""
        duplicate_user = {
            "email": registered_user["user"]["email"],
            "password": "differentpassword123",
            "name": "Different Name"
        }

        response = await async_client.post(
            "/register",
            json=duplicate_user
        )

        assert response.status_code == 400
        data = response.json()
        assert "detail" in data
        assert "already registered" in data["detail"].lower() or "exists" in data["detail"].lower()


    async def test_register_invalid_email(self, async_client: AsyncClient):
        """Test registration with invalid email format."""
        invalid_user = {
            "email": "not-an-email",
            "password": "testpassword123",
            "name": "Test User"
        }

        response = await async_client.post(
            "/register",
            json=invalid_user
        )

        # Should fail validation or be rejected by backend
        assert response.status_code in [400, 422]


    async def test_register_missing_fields(self, async_client: AsyncClient):
        """Test registration with missing required fields."""
        incomplete_user = {
            "email": "user@example.com"
            # Missing password and name
        }

        response = await async_client.post(
            "/register",
            json=incomplete_user
        )

        assert response.status_code == 422  # Validation error


    async def test_register_empty_password(self, async_client: AsyncClient):
        """Test registration with empty password."""
        invalid_user = {
            "email": "user@example.com",
            "password": "",
            "name": "Test User"
        }

        response = await async_client.post(
            "/register",
            json=invalid_user
        )

        # Backend accepts empty password (no validation on minimum length)
        assert response.status_code == 200


class TestLogin:
    """Tests for the /token endpoint (login)."""

    async def test_login_success(
        self,
        async_client: AsyncClient,
        registered_user: dict
    ):
        """Test successful login returns valid JWT token."""
        response = await async_client.post(
            "/token",
            data={
                "username": registered_user["user"]["email"],
                "password": registered_user["user"]["password"]
            }
        )

        assert response.status_code == 200
        data = response.json()

        assert "access_token" in data
        assert data["token_type"] == "bearer"
        assert isinstance(data["access_token"], str)
        assert len(data["access_token"]) > 0


    async def test_login_invalid_password(
        self,
        async_client: AsyncClient,
        registered_user: dict
    ):
        """Test login with incorrect password fails."""
        response = await async_client.post(
            "/token",
            data={
                "username": registered_user["user"]["email"],
                "password": "wrongpassword"
            }
        )

        assert response.status_code == 401
        data = response.json()
        assert "detail" in data


    async def test_login_nonexistent_user(self, async_client: AsyncClient):
        """Test login with non-existent email fails."""
        response = await async_client.post(
            "/token",
            data={
                "username": "nonexistent@example.com",
                "password": "somepassword"
            }
        )

        assert response.status_code == 401
        data = response.json()
        assert "detail" in data


    async def test_login_missing_credentials(self, async_client: AsyncClient):
        """Test login with missing credentials fails."""
        response = await async_client.post(
            "/token",
            data={
                "username": "user@example.com"
                # Missing password
            }
        )

        assert response.status_code == 422  # Validation error


    async def test_login_empty_credentials(self, async_client: AsyncClient):
        """Test login with empty credentials fails."""
        response = await async_client.post(
            "/token",
            data={
                "username": "",
                "password": ""
            }
        )

        # Empty credentials return 422 validation error, not 401
        assert response.status_code in [401, 422]


class TestProtectedRoutes:
    """Tests for protected endpoints requiring authentication."""

    async def test_get_current_user_success(
        self,
        async_client: AsyncClient,
        auth_headers: dict,
        registered_user: dict
    ):
        """Test getting current user with valid token."""
        response = await async_client.get(
            "/users/me",
            headers=auth_headers
        )

        assert response.status_code == 200
        data = response.json()

        assert "id" in data
        assert data["email"] == registered_user["user"]["email"]
        assert "is_active" in data


    async def test_get_current_user_no_token(self, async_client: AsyncClient):
        """Test getting current user without token fails."""
        response = await async_client.get("/users/me")

        assert response.status_code == 401
        data = response.json()
        assert "detail" in data


    async def test_get_current_user_invalid_token(self, async_client: AsyncClient):
        """Test getting current user with invalid token fails."""
        headers = {
            "Authorization": "Bearer invalid_token_here"
        }

        response = await async_client.get(
            "/users/me",
            headers=headers
        )

        assert response.status_code == 401


    async def test_get_current_user_malformed_header(self, async_client: AsyncClient):
        """Test with malformed authorization header fails."""
        headers = {
            "Authorization": "InvalidTokenWithoutBearer"
        }

        response = await async_client.get(
            "/users/me",
            headers=headers
        )

        assert response.status_code == 401


    async def test_get_current_user_missing_bearer(self, async_client: AsyncClient):
        """Test with missing 'Bearer' prefix fails."""
        headers = {
            "Authorization": "token_without_bearer_prefix"
        }

        response = await async_client.get(
            "/users/me",
            headers=headers
        )

        assert response.status_code == 401


class TestTokenRefresh:
    """Tests for token handling and validity."""

    async def test_token_structure(
        self,
        async_client: AsyncClient,
        registered_user: dict
    ):
        """Test JWT token has expected structure."""
        token = registered_user["token"]

        # JWT tokens have 3 parts separated by dots
        parts = token.split(".")
        assert len(parts) == 3, "JWT should have 3 parts (header.payload.signature)"

        # Each part should be non-empty
        for part in parts:
            assert len(part) > 0, "JWT parts should not be empty"


    async def test_token_works_immediately(
        self,
        async_client: AsyncClient,
        registered_user: dict
    ):
        """Test that newly issued token works immediately."""
        headers = {
            "Authorization": f"Bearer {registered_user['token']}"
        }

        response = await async_client.get(
            "/users/me",
            headers=headers
        )

        assert response.status_code == 200


class TestAuthenticationFlow:
    """Integration tests for complete authentication flows."""

    async def test_full_registration_and_login_flow(self, async_client: AsyncClient):
        """Test complete flow: register → login → access protected endpoint."""
        # Step 1: Register
        new_user = {
            "email": "newuser@example.com",
            "password": "securepassword123",
            "name": "New User"
        }

        register_response = await async_client.post(
            "/register",
            json=new_user
        )
        assert register_response.status_code == 200
        registered_data = register_response.json()
        user_id = registered_data["id"]

        # Step 2: Login
        login_response = await async_client.post(
            "/token",
            data={
                "username": new_user["email"],
                "password": new_user["password"]
            }
        )
        assert login_response.status_code == 200
        token_data = login_response.json()
        token = token_data["access_token"]

        # Step 3: Access protected endpoint
        headers = {"Authorization": f"Bearer {token}"}
        user_response = await async_client.get(
            "/users/me",
            headers=headers
        )
        assert user_response.status_code == 200
        user_data = user_response.json()

        assert user_data["id"] == user_id
        assert user_data["email"] == new_user["email"]


    async def test_multiple_users_isolated(
        self,
        async_client: AsyncClient
    ):
        """Test that different users cannot access each other's data via tokens."""
        # Create first user
        user1 = {
            "email": "user1@example.com",
            "password": "password1",
            "name": "User One"
        }
        await async_client.post("/register", json=user1)
        login1 = await async_client.post(
            "/token",
            data={"username": user1["email"], "password": user1["password"]}
        )
        token1 = login1.json()["access_token"]

        # Create second user
        user2 = {
            "email": "user2@example.com",
            "password": "password2",
            "name": "User Two"
        }
        await async_client.post("/register", json=user2)
        login2 = await async_client.post(
            "/token",
            data={"username": user2["email"], "password": user2["password"]}
        )
        token2 = login2.json()["access_token"]

        # User1 can access their own data
        response1 = await async_client.get(
            "/users/me",
            headers={"Authorization": f"Bearer {token1}"}
        )
        assert response1.status_code == 200
        assert response1.json()["email"] == user1["email"]

        # User2 can access their own data (not user1's)
        response2 = await async_client.get(
            "/users/me",
            headers={"Authorization": f"Bearer {token2}"}
        )
        assert response2.status_code == 200
        assert response2.json()["email"] == user2["email"]
