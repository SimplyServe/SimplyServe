"""
Tests for user profile endpoints: PATCH /users/me, PUT /users/me, POST /users/me/avatar.
"""

import io
import pytest
from httpx import AsyncClient


class TestPatchUserMe:
    """Tests for PATCH /users/me (partial update)."""

    async def test_update_name(
        self, async_client: AsyncClient, auth_headers: dict
    ):
        resp = await async_client.patch(
            "/users/me", json={"name": "Alice"}, headers=auth_headers
        )
        assert resp.status_code == 200
        assert resp.json()["name"] == "Alice"

    async def test_update_name_trims_whitespace(
        self, async_client: AsyncClient, auth_headers: dict
    ):
        resp = await async_client.patch(
            "/users/me", json={"name": "  Bob  "}, headers=auth_headers
        )
        assert resp.status_code == 200
        assert resp.json()["name"] == "Bob"

    async def test_update_persists(
        self, async_client: AsyncClient, auth_headers: dict
    ):
        await async_client.patch(
            "/users/me", json={"name": "Charlie"}, headers=auth_headers
        )

        me_resp = await async_client.get("/users/me", headers=auth_headers)
        assert me_resp.status_code == 200
        assert me_resp.json()["name"] == "Charlie"

    async def test_update_without_auth_401(self, async_client: AsyncClient):
        resp = await async_client.patch("/users/me", json={"name": "Hacker"})
        assert resp.status_code == 401

    async def test_null_name_keeps_existing(
        self, async_client: AsyncClient, auth_headers: dict
    ):
        # Set a name first
        await async_client.patch(
            "/users/me", json={"name": "Initial"}, headers=auth_headers
        )

        # Send null name — should leave it unchanged
        resp = await async_client.patch(
            "/users/me", json={"name": None}, headers=auth_headers
        )
        assert resp.status_code == 200
        assert resp.json()["name"] == "Initial"


class TestPutUserMe:
    """Tests for PUT /users/me (full name update)."""

    async def test_set_name(
        self, async_client: AsyncClient, auth_headers: dict
    ):
        resp = await async_client.put(
            "/users/me", json={"name": "Dave"}, headers=auth_headers
        )
        assert resp.status_code == 200
        assert resp.json()["name"] == "Dave"

    async def test_empty_name_rejected(
        self, async_client: AsyncClient, auth_headers: dict
    ):
        resp = await async_client.put(
            "/users/me", json={"name": "   "}, headers=auth_headers
        )
        assert resp.status_code == 400

    async def test_put_without_auth_401(self, async_client: AsyncClient):
        resp = await async_client.put("/users/me", json={"name": "Hacker"})
        assert resp.status_code == 401

    async def test_name_trims_whitespace(
        self, async_client: AsyncClient, auth_headers: dict
    ):
        resp = await async_client.put(
            "/users/me", json={"name": "  Eve  "}, headers=auth_headers
        )
        assert resp.status_code == 200
        assert resp.json()["name"] == "Eve"


class TestUploadAvatar:
    """Tests for POST /users/me/avatar."""

    async def test_upload_jpeg_avatar(
        self, async_client: AsyncClient, auth_headers: dict
    ):
        fake_image = io.BytesIO(b"\xff\xd8\xff\xe0" + b"\x00" * 100)
        resp = await async_client.post(
            "/users/me/avatar",
            files={"image": ("avatar.jpg", fake_image, "image/jpeg")},
            headers=auth_headers,
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["profile_image_url"] is not None
        assert "/uploads/" in data["profile_image_url"]

    async def test_upload_png_avatar(
        self, async_client: AsyncClient, auth_headers: dict
    ):
        fake_png = io.BytesIO(b"\x89PNG\r\n\x1a\n" + b"\x00" * 100)
        resp = await async_client.post(
            "/users/me/avatar",
            files={"image": ("avatar.png", fake_png, "image/png")},
            headers=auth_headers,
        )
        assert resp.status_code == 200
        assert "/uploads/" in resp.json()["profile_image_url"]

    async def test_unsupported_content_type_rejected(
        self, async_client: AsyncClient, auth_headers: dict
    ):
        fake_pdf = io.BytesIO(b"%PDF-1.4" + b"\x00" * 100)
        resp = await async_client.post(
            "/users/me/avatar",
            files={"image": ("doc.pdf", fake_pdf, "application/pdf")},
            headers=auth_headers,
        )
        assert resp.status_code == 400

    async def test_upload_without_auth_401(self, async_client: AsyncClient):
        fake_image = io.BytesIO(b"\xff\xd8\xff\xe0" + b"\x00" * 100)
        resp = await async_client.post(
            "/users/me/avatar",
            files={"image": ("avatar.jpg", fake_image, "image/jpeg")},
        )
        assert resp.status_code == 401

    async def test_avatar_url_persists(
        self, async_client: AsyncClient, auth_headers: dict
    ):
        fake_image = io.BytesIO(b"\xff\xd8\xff\xe0" + b"\x00" * 100)
        upload_resp = await async_client.post(
            "/users/me/avatar",
            files={"image": ("avatar.jpg", fake_image, "image/jpeg")},
            headers=auth_headers,
        )
        assert upload_resp.status_code == 200

        me_resp = await async_client.get("/users/me", headers=auth_headers)
        assert me_resp.status_code == 200
        assert me_resp.json()["profile_image_url"] == upload_resp.json()["profile_image_url"]


class TestGetUserMe:
    """Tests for GET /users/me."""

    async def test_get_current_user(
        self, async_client: AsyncClient, auth_headers: dict, registered_user: dict
    ):
        resp = await async_client.get("/users/me", headers=auth_headers)
        assert resp.status_code == 200
        data = resp.json()
        assert data["email"] == registered_user["user"]["email"]
        assert "id" in data
        assert data["is_active"] is True

    async def test_get_user_without_auth_401(self, async_client: AsyncClient):
        resp = await async_client.get("/users/me")
        assert resp.status_code == 401

    async def test_invalid_token_401(self, async_client: AsyncClient):
        resp = await async_client.get(
            "/users/me",
            headers={"Authorization": "Bearer invalid_token_here"},
        )
        assert resp.status_code == 401

    async def test_response_includes_profile_fields(
        self, async_client: AsyncClient, auth_headers: dict
    ):
        resp = await async_client.get("/users/me", headers=auth_headers)
        assert resp.status_code == 200
        data = resp.json()
        # These fields must exist in the response (even if None)
        assert "name" in data
        assert "profile_image_url" in data
        assert "email" in data
        assert "id" in data


class TestSR8UserProfile:
    """SR-8: User profile management."""

    async def test_patch_updates_name(self, async_client: AsyncClient, auth_headers: dict):
        """EP: PATCH /users/me updates display name."""
        resp = await async_client.patch(
            "/users/me", json={"name": "SR8 User"}, headers=auth_headers
        )
        assert resp.status_code == 200
        assert resp.json()["name"] == "SR8 User"

    async def test_put_replaces_name(self, async_client: AsyncClient, auth_headers: dict):
        """EP: PUT /users/me replaces display name."""
        resp = await async_client.put(
            "/users/me", json={"name": "SR8 New Name"}, headers=auth_headers
        )
        assert resp.status_code == 200
        assert resp.json()["name"] == "SR8 New Name"

    async def test_put_empty_name_rejected(self, async_client: AsyncClient, auth_headers: dict):
        """NT: empty name rejected with 400."""
        resp = await async_client.put(
            "/users/me", json={"name": "   "}, headers=auth_headers
        )
        assert resp.status_code == 400

    async def test_profile_includes_all_fields(self, async_client: AsyncClient, auth_headers: dict):
        """EP: GET /users/me includes all profile fields."""
        resp = await async_client.get("/users/me", headers=auth_headers)
        assert resp.status_code == 200
        data = resp.json()
        for field in ["id", "email", "name", "is_active", "profile_image_url"]:
            assert field in data


class TestSR8AvatarUpload:
    """SR-8: Avatar image upload."""

    async def test_upload_jpeg_avatar(self, async_client: AsyncClient, auth_headers: dict):
        """EP: JPEG avatar upload succeeds."""
        fake = io.BytesIO(b"\xff\xd8\xff\xe0" + b"\x00" * 100)
        resp = await async_client.post(
            "/users/me/avatar",
            files={"image": ("avatar.jpg", fake, "image/jpeg")},
            headers=auth_headers,
        )
        assert resp.status_code == 200
        assert "/uploads/" in resp.json()["profile_image_url"]

    async def test_upload_png_avatar(self, async_client: AsyncClient, auth_headers: dict):
        """EP: PNG avatar upload succeeds."""
        fake = io.BytesIO(b"\x89PNG\r\n\x1a\n" + b"\x00" * 100)
        resp = await async_client.post(
            "/users/me/avatar",
            files={"image": ("avatar.png", fake, "image/png")},
            headers=auth_headers,
        )
        assert resp.status_code == 200

    async def test_upload_webp_avatar(self, async_client: AsyncClient, auth_headers: dict):
        """EP: WebP avatar upload succeeds."""
        fake = io.BytesIO(b"RIFF" + b"\x00" * 100)
        resp = await async_client.post(
            "/users/me/avatar",
            files={"image": ("avatar.webp", fake, "image/webp")},
            headers=auth_headers,
        )
        assert resp.status_code == 200

    async def test_unsupported_type_rejected(self, async_client: AsyncClient, auth_headers: dict):
        """NT: unsupported file type rejected with 400."""
        fake = io.BytesIO(b"%PDF-1.4" + b"\x00" * 100)
        resp = await async_client.post(
            "/users/me/avatar",
            files={"image": ("doc.pdf", fake, "application/pdf")},
            headers=auth_headers,
        )
        assert resp.status_code == 400

    async def test_avatar_without_auth_rejected(self, async_client: AsyncClient):
        """NT: avatar upload without auth rejected."""
        fake = io.BytesIO(b"\xff\xd8\xff\xe0" + b"\x00" * 100)
        resp = await async_client.post(
            "/users/me/avatar",
            files={"image": ("avatar.jpg", fake, "image/jpeg")},
        )
        assert resp.status_code == 401

    async def test_avatar_url_persists_across_requests(
        self, async_client: AsyncClient, auth_headers: dict
    ):
        """IT: uploaded avatar URL persists on subsequent profile fetch."""
        fake = io.BytesIO(b"\xff\xd8\xff\xe0" + b"\x00" * 100)
        upload = await async_client.post(
            "/users/me/avatar",
            files={"image": ("avatar.jpg", fake, "image/jpeg")},
            headers=auth_headers,
        )
        assert upload.status_code == 200

        me = await async_client.get("/users/me", headers=auth_headers)
        assert me.json()["profile_image_url"] == upload.json()["profile_image_url"]
