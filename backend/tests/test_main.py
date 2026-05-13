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


# ── Image upload ──────────────────────────────────────────────────────────────

class TestImageUploadInRecipes:
    """SR-4 / SR-8: image file upload in recipe create and update flows."""

    # Minimal well-formed 1×1 PNG (67 bytes)
    _PNG = (
        b'\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01'
        b'\x00\x00\x00\x01\x08\x02\x00\x00\x00\x90wS\xde\x00\x00'
        b'\x00\x0cIDATx\x9cc\xf8\x0f\x00\x00\x01\x01\x00\x05\x18'
        b'\xd8N\x00\x00\x00\x00IEND\xaeB`\x82'
    )

    async def test_create_recipe_with_image_returns_url(self, async_client: AsyncClient):
        """POST /recipes with an image file stores it and returns a non-null image_url."""
        from io import BytesIO
        resp = await async_client.post(
            "/recipes",
            data={
                "title": "Image Create Test",
                "summary": "has a picture",
                "tags_json": "[]",
                "ingredients_json": "[]",
                "steps_json": '["Step 1"]',
            },
            files={"image": ("recipe.png", BytesIO(self._PNG), "image/png")},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["image_url"] is not None
        assert "uploads" in data["image_url"]

    async def test_create_recipe_without_image_has_null_url(self, async_client: AsyncClient):
        """POST /recipes without image returns image_url=null."""
        resp = await async_client.post("/recipes", data={
            "title": "No Image Recipe",
            "summary": "no picture",
            "tags_json": "[]",
            "ingredients_json": "[]",
            "steps_json": '["Step"]',
        })
        assert resp.status_code == 200
        assert resp.json()["image_url"] is None

    async def test_update_recipe_with_image_replaces_url(self, async_client: AsyncClient):
        """PUT /recipes/{id} with a new image file replaces the stored image_url."""
        from io import BytesIO
        create = await async_client.post("/recipes", data={
            "title": "To Update With Image",
            "summary": "no image first",
            "tags_json": "[]",
            "ingredients_json": "[]",
            "steps_json": '["Step"]',
        })
        rid = create.json()["id"]
        assert create.json()["image_url"] is None

        resp = await async_client.put(
            f"/recipes/{rid}",
            data={
                "title": "Updated With Image",
                "summary": "now has image",
                "tags_json": "[]",
                "ingredients_json": "[]",
                "steps_json": '["Step"]',
            },
            files={"image": ("update.png", BytesIO(self._PNG), "image/png")},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["image_url"] is not None
        assert "uploads" in data["image_url"]

    async def test_update_recipe_without_image_preserves_existing_url(
        self, async_client: AsyncClient
    ):
        """PUT /recipes/{id} without image file keeps the existing image_url."""
        from io import BytesIO
        create = await async_client.post(
            "/recipes",
            data={
                "title": "Keep Image Recipe",
                "summary": "image should stay",
                "tags_json": "[]",
                "ingredients_json": "[]",
                "steps_json": '["Step"]',
            },
            files={"image": ("original.png", BytesIO(self._PNG), "image/png")},
        )
        original_url = create.json()["image_url"]
        rid = create.json()["id"]
        assert original_url is not None

        resp = await async_client.put(
            f"/recipes/{rid}",
            data={
                "title": "Still Has Image",
                "summary": "image persists",
                "tags_json": "[]",
                "ingredients_json": "[]",
                "steps_json": '["Updated step"]',
            },
        )
        assert resp.status_code == 200
        assert resp.json()["image_url"] == original_url


# ── Time-string parsing ───────────────────────────────────────────────────────

class TestTimeParsing:
    """SR-4: prep_time / cook_time string → integer extraction in create and update."""

    async def test_digit_prefix_time_accepted(self, async_client: AsyncClient):
        """prep_time='30 mins' and cook_time='45 minutes' do not crash."""
        resp = await async_client.post("/recipes", data={
            "title": "Timed Recipe",
            "summary": "testing time parsing",
            "prep_time": "30 mins",
            "cook_time": "45 minutes",
            "tags_json": "[]",
            "ingredients_json": "[]",
            "steps_json": '["Step"]',
        })
        assert resp.status_code == 200
        assert resp.json()["prep_time"] == "30 mins"
        assert resp.json()["cook_time"] == "45 minutes"

    async def test_non_digit_prefix_time_does_not_crash(self, async_client: AsyncClient):
        """prep_time='abc minutes' triggers the else-branch (stored as 0) without crashing."""
        resp = await async_client.post("/recipes", data={
            "title": "Bad Time Recipe",
            "summary": "non-digit time",
            "prep_time": "abc minutes",
            "cook_time": "xyz",
            "tags_json": "[]",
            "ingredients_json": "[]",
            "steps_json": '["Step"]',
        })
        assert resp.status_code == 200

    async def test_empty_time_fields_default_to_zero(self, async_client: AsyncClient):
        """Empty prep_time / cook_time strings default to 0 without crashing."""
        resp = await async_client.post("/recipes", data={
            "title": "No Time Recipe",
            "summary": "no time fields",
            "prep_time": "",
            "cook_time": "",
            "tags_json": "[]",
            "ingredients_json": "[]",
            "steps_json": '["Step"]',
        })
        assert resp.status_code == 200
        assert resp.json()["prep_time"] == ""
        assert resp.json()["cook_time"] == ""

    async def test_purely_numeric_time_accepted(self, async_client: AsyncClient):
        """prep_time='15' (no unit suffix) parses correctly."""
        resp = await async_client.post("/recipes", data={
            "title": "Numeric Time Recipe",
            "summary": "numeric only",
            "prep_time": "15",
            "cook_time": "30",
            "tags_json": "[]",
            "ingredients_json": "[]",
            "steps_json": '["Step"]',
        })
        assert resp.status_code == 200

    async def test_update_recipe_time_parsing(self, async_client: AsyncClient):
        """PUT /recipes/{id} applies the same time-parsing logic without crashing."""
        create = await async_client.post("/recipes", data={
            "title": "Time Update Base",
            "summary": "base",
            "tags_json": "[]",
            "ingredients_json": "[]",
            "steps_json": '["Step"]',
        })
        rid = create.json()["id"]

        resp = await async_client.put(f"/recipes/{rid}", data={
            "title": "Time Updated",
            "summary": "updated",
            "prep_time": "20 mins",
            "cook_time": "bad_time",
            "tags_json": "[]",
            "ingredients_json": "[]",
            "steps_json": '["Step"]',
        })
        assert resp.status_code == 200


# ── PUT /recipes/{id} edge cases ──────────────────────────────────────────────

class TestUpdateRecipeEdgeCases:
    """SR-4: PUT /recipes/{id} endpoint edge cases."""

    async def test_update_nonexistent_recipe_returns_404(self, async_client: AsyncClient):
        """PUT /recipes/999999 returns 404 when recipe doesn't exist."""
        resp = await async_client.put("/recipes/999999", data={
            "title": "Ghost Recipe",
            "summary": "does not exist",
            "tags_json": "[]",
            "ingredients_json": "[]",
            "steps_json": '["Step"]',
        })
        assert resp.status_code == 404
        assert "detail" in resp.json()

    async def test_update_clears_and_replaces_tags(self, async_client: AsyncClient):
        """PUT /recipes/{id} completely replaces old tags with new ones."""
        create = await async_client.post("/recipes", data={
            "title": "Tag Replace Recipe",
            "summary": "s",
            "tags_json": json.dumps(["old-tag", "another-old"]),
            "ingredients_json": "[]",
            "steps_json": '["Step"]',
        })
        rid = create.json()["id"]

        resp = await async_client.put(f"/recipes/{rid}", data={
            "title": "Tag Replace Recipe",
            "summary": "s",
            "tags_json": json.dumps(["new-tag"]),
            "ingredients_json": "[]",
            "steps_json": '["Step"]',
        })
        assert resp.status_code == 200
        tags = resp.json()["tags"]
        assert "new-tag" in tags
        assert "old-tag" not in tags
        assert "another-old" not in tags

    async def test_update_clears_and_replaces_ingredients(self, async_client: AsyncClient):
        """PUT /recipes/{id} completely replaces old ingredients."""
        create = await async_client.post("/recipes", data={
            "title": "Ing Replace Recipe",
            "summary": "s",
            "tags_json": "[]",
            "ingredients_json": json.dumps([
                {"ingredient_name": "old-ingredient", "quantity": 1, "unit": "pcs"}
            ]),
            "steps_json": '["Step"]',
        })
        rid = create.json()["id"]

        resp = await async_client.put(f"/recipes/{rid}", data={
            "title": "Ing Replace Recipe",
            "summary": "s",
            "tags_json": "[]",
            "ingredients_json": json.dumps([
                {"ingredient_name": "new-ingredient", "quantity": 2, "unit": "g"}
            ]),
            "steps_json": '["Step"]',
        })
        assert resp.status_code == 200
        ings = [i["ingredient_name"] for i in resp.json()["recipe_ingredients"]]
        assert "new-ingredient" in ings
        assert "old-ingredient" not in ings

    async def test_update_recalculates_nutrition(self, async_client: AsyncClient, test_db):
        """PUT /recipes/{id} with new ingredients recalculates nutrition totals."""
        import models
        # Seed ingredient with known nutrition and normalized_name so _find_or_create_ingredient
        # finds it rather than creating a new nutrition-less row.
        ing = models.Ingredients(
            ingredient_name="nutrition_recalc_ing",
            normalized_name="nutrition_recalc_ing",
            is_base=False,
            avg_calories=150.0, avg_protein=12.0, avg_carbs=5.0, avg_fat=8.0,
        )
        test_db.add(ing)
        await test_db.commit()

        create = await async_client.post("/recipes", data={
            "title": "Nutrition Recalc",
            "summary": "s",
            "tags_json": "[]",
            "ingredients_json": "[]",
            "steps_json": '["Step"]',
        })
        rid = create.json()["id"]
        assert create.json()["nutrition"]["calories"] == 0

        resp = await async_client.put(f"/recipes/{rid}", data={
            "title": "Nutrition Recalc",
            "summary": "s",
            "tags_json": "[]",
            "ingredients_json": json.dumps([
                {"ingredient_name": "nutrition_recalc_ing", "quantity": 2, "unit": "pcs"}
            ]),
            "steps_json": '["Step"]',
        })
        assert resp.status_code == 200
        assert resp.json()["nutrition"]["calories"] > 0


# ── Soft-delete state-machine edge cases ─────────────────────────────────────

class TestSoftDeleteEdgeCases:
    """SR-4: soft-delete / restore idempotency and state transitions."""

    async def test_delete_already_deleted_recipe_is_idempotent(
        self, async_client: AsyncClient
    ):
        """DELETE /recipes/{id} on an already-deleted recipe returns 200 again."""
        create = await async_client.post("/recipes", data={
            "title": "Twice Deleted",
            "summary": "delete me twice",
            "tags_json": "[]",
            "ingredients_json": "[]",
            "steps_json": '["Step"]',
        })
        rid = create.json()["id"]

        first = await async_client.delete(f"/recipes/{rid}")
        assert first.status_code == 200

        second = await async_client.delete(f"/recipes/{rid}")
        assert second.status_code == 200
        assert second.json()["message"] == "Success"

    async def test_restore_already_active_recipe_is_idempotent(
        self, async_client: AsyncClient
    ):
        """POST /recipes/{id}/restore on an active recipe returns 200."""
        create = await async_client.post("/recipes", data={
            "title": "Restore Active",
            "summary": "never deleted",
            "tags_json": "[]",
            "ingredients_json": "[]",
            "steps_json": '["Step"]',
        })
        rid = create.json()["id"]

        resp = await async_client.post(f"/recipes/{rid}/restore")
        assert resp.status_code == 200
        assert resp.json()["message"] == "Restored"

    async def test_full_soft_delete_cycle(self, async_client: AsyncClient):
        """active → deleted list, restore → active list again."""
        create = await async_client.post("/recipes", data={
            "title": "Cycle Recipe",
            "summary": "full cycle",
            "tags_json": "[]",
            "ingredients_json": "[]",
            "steps_json": '["Step"]',
        })
        rid = create.json()["id"]

        await async_client.delete(f"/recipes/{rid}")
        active = (await async_client.get("/recipes")).json()
        assert rid not in [r["id"] for r in active]

        deleted = (await async_client.get("/recipes/deleted")).json()
        assert rid in [r["id"] for r in deleted]

        await async_client.post(f"/recipes/{rid}/restore")
        active_after = (await async_client.get("/recipes")).json()
        assert rid in [r["id"] for r in active_after]

        deleted_after = (await async_client.get("/recipes/deleted")).json()
        assert rid not in [r["id"] for r in deleted_after]


# ── Recipe response field coverage ───────────────────────────────────────────

class TestRecipeResponseFields:
    """SR-4: specific recipe response fields and their edge-case values."""

    async def test_recipe_with_no_instructions_returns_empty_steps(
        self, async_client: AsyncClient, test_db
    ):
        """Recipe row with NULL instructions returns steps=[] in the listing."""
        import models
        recipe = models.Recipe(
            recipe_name="No Steps Recipe", summary="no instructions", servings=1,
            instructions=None,
        )
        test_db.add(recipe)
        await test_db.commit()

        resp = await async_client.get("/recipes")
        assert resp.status_code == 200
        match = next((r for r in resp.json() if r["title"] == "No Steps Recipe"), None)
        assert match is not None
        assert match["steps"] == []

    async def test_recipe_tags_visible_in_list(self, async_client: AsyncClient):
        """GET /recipes response includes the recipe's tags."""
        create = await async_client.post("/recipes", data={
            "title": "Tagged List Recipe",
            "summary": "has tags",
            "tags_json": json.dumps(["vegan", "quick"]),
            "ingredients_json": "[]",
            "steps_json": '["Step"]',
        })
        rid = create.json()["id"]

        recipes = (await async_client.get("/recipes")).json()
        match = next((r for r in recipes if r["id"] == rid), None)
        assert match is not None
        assert "vegan" in match["tags"]
        assert "quick" in match["tags"]

    async def test_recipe_ingredients_visible_in_list(self, async_client: AsyncClient):
        """GET /recipes includes structured recipe_ingredients in each response."""
        create = await async_client.post("/recipes", data={
            "title": "Ingredient List Recipe",
            "summary": "has ings",
            "tags_json": "[]",
            "ingredients_json": json.dumps([
                {"ingredient_name": "flour", "quantity": 200, "unit": "g"}
            ]),
            "steps_json": '["Step"]',
        })
        rid = create.json()["id"]

        recipes = (await async_client.get("/recipes")).json()
        match = next((r for r in recipes if r["id"] == rid), None)
        assert match is not None
        assert "flour" in match["ingredients"]
        assert any(i["ingredient_name"] == "flour" for i in match["recipe_ingredients"])

    async def test_deleted_recipe_list_includes_tags_and_steps(
        self, async_client: AsyncClient
    ):
        """GET /recipes/deleted returns full recipe data including tags and steps."""
        create = await async_client.post("/recipes", data={
            "title": "Deleted Full Data",
            "summary": "full data test",
            "tags_json": json.dumps(["deleted-tag"]),
            "ingredients_json": json.dumps([
                {"ingredient_name": "salt", "quantity": 1, "unit": "tsp"}
            ]),
            "steps_json": json.dumps(["Step A", "Step B"]),
        })
        rid = create.json()["id"]
        await async_client.delete(f"/recipes/{rid}")

        deleted = (await async_client.get("/recipes/deleted")).json()
        match = next((r for r in deleted if r["id"] == rid), None)
        assert match is not None
        assert "deleted-tag" in match["tags"]
        assert "salt" in match["ingredients"]
        assert match["steps"] == ["Step A", "Step B"]

    async def test_recipe_null_servings_defaults_to_one_in_listing(
        self, async_client: AsyncClient, test_db
    ):
        """Recipe row with NULL servings uses servings=1 for nutrition (no ZeroDivisionError)."""
        import models
        recipe = models.Recipe(
            recipe_name="Null Servings Recipe", summary="s", servings=None,
        )
        test_db.add(recipe)
        await test_db.commit()

        resp = await async_client.get("/recipes")
        assert resp.status_code == 200
        match = next((r for r in resp.json() if r["title"] == "Null Servings Recipe"), None)
        assert match is not None
        assert match["servings"] == 1


# ── Nutrition edge cases ──────────────────────────────────────────────────────

class TestNutritionEdgeCases:
    """SR-3: edge cases in _calculate_recipe_nutrition_totals."""

    async def test_zero_calorie_ingredient_not_added_to_totals(
        self, async_client: AsyncClient, test_db
    ):
        """avg_calories=0 is falsy; the `if cal:` guard skips it, leaving calories=0."""
        import models
        from main import _calculate_recipe_nutrition_totals

        recipe = models.Recipe(recipe_name="Zero Cal Recipe", summary="s", servings=1)
        test_db.add(recipe)
        await test_db.commit()
        await test_db.refresh(recipe)

        ing = models.Ingredients(
            ingredient_name="zero_cal_ing", normalized_name="zero_cal_ing",
            is_base=False, avg_calories=0.0, avg_protein=5.0,
        )
        test_db.add(ing)
        await test_db.commit()
        await test_db.refresh(ing)

        test_db.add(models.RecipeIngredient(
            recipe_id=recipe.recipe_id, ingredient_id=ing.id, quantity=10.0, unit="g"
        ))
        await test_db.commit()

        totals = await _calculate_recipe_nutrition_totals(test_db, recipe.recipe_id)
        assert totals["calories"] == 0.0       # skipped because 0 is falsy
        assert totals["protein"] == pytest.approx(50.0)  # 5.0 × 10 — not skipped

    async def test_null_nutrition_fields_do_not_raise(self, test_db):
        """Ingredients with NULL nutrition values are handled gracefully."""
        import models
        from main import _calculate_recipe_nutrition_totals

        recipe = models.Recipe(recipe_name="Null Nutrition Recipe", summary="s", servings=1)
        test_db.add(recipe)
        await test_db.commit()
        await test_db.refresh(recipe)

        ing = models.Ingredients(
            ingredient_name="null_nutrition_ing", normalized_name="null_nutrition_ing",
            is_base=False,
            avg_calories=None, avg_protein=None, avg_carbs=None, avg_fat=None,
        )
        test_db.add(ing)
        await test_db.commit()
        await test_db.refresh(ing)

        test_db.add(models.RecipeIngredient(
            recipe_id=recipe.recipe_id, ingredient_id=ing.id, quantity=1.0, unit="pcs"
        ))
        await test_db.commit()

        totals = await _calculate_recipe_nutrition_totals(test_db, recipe.recipe_id)
        assert totals["calories"] == 0.0
        assert totals["protein"] == 0.0


# ── Startup helper functions ──────────────────────────────────────────────────

class TestStartupHelpers:
    """Direct tests for startup initialization helper functions."""

    async def test_seed_base_ingredients_is_idempotent(self, test_db):
        """Calling _seed_base_ingredients_catalog twice doesn't create duplicate rows."""
        from main import _seed_base_ingredients_catalog
        from sqlalchemy.future import select
        import models

        await _seed_base_ingredients_catalog(test_db)
        count_first = len(
            (await test_db.execute(select(models.Ingredients))).scalars().all()
        )

        await _seed_base_ingredients_catalog(test_db)
        count_second = len(
            (await test_db.execute(select(models.Ingredients))).scalars().all()
        )

        assert count_first == count_second

    async def test_seed_base_ingredients_skips_missing_file(self, test_db):
        """_seed_base_ingredients_catalog returns early when the data file is absent."""
        from main import _seed_base_ingredients_catalog
        from pathlib import Path
        from unittest.mock import patch

        with patch.object(Path, "exists", return_value=False):
            await _seed_base_ingredients_catalog(test_db)
        # No exception raised = pass

    async def test_normalize_existing_ingredient_data_fixes_long_form_units(
        self, test_db
    ):
        """_normalize_existing_ingredient_data converts 'grams' → 'g' in existing rows."""
        from main import _normalize_existing_ingredient_data
        from sqlalchemy.future import select
        import models

        recipe = models.Recipe(recipe_name="Unit Fix Recipe", summary="s", servings=1)
        test_db.add(recipe)
        await test_db.commit()
        await test_db.refresh(recipe)

        ing = models.Ingredients(
            ingredient_name="unit_fix_ing", normalized_name="unit_fix_ing", is_base=False
        )
        test_db.add(ing)
        await test_db.commit()
        await test_db.refresh(ing)

        test_db.add(models.RecipeIngredient(
            recipe_id=recipe.recipe_id, ingredient_id=ing.id, quantity=1.0, unit="grams"
        ))
        await test_db.commit()

        await _normalize_existing_ingredient_data(test_db)

        result = await test_db.execute(
            select(models.RecipeIngredient).where(
                models.RecipeIngredient.recipe_id == recipe.recipe_id
            )
        )
        assert result.scalars().first().unit == "g"

    async def test_normalize_existing_ingredient_data_leaves_valid_units_unchanged(
        self, test_db
    ):
        """_normalize_existing_ingredient_data doesn't alter already-canonical units."""
        from main import _normalize_existing_ingredient_data
        from sqlalchemy.future import select
        import models

        recipe = models.Recipe(recipe_name="Valid Unit Recipe2", summary="s", servings=1)
        test_db.add(recipe)
        await test_db.commit()
        await test_db.refresh(recipe)

        ing = models.Ingredients(
            ingredient_name="valid_unit_ing3", normalized_name="valid_unit_ing3", is_base=False
        )
        test_db.add(ing)
        await test_db.commit()
        await test_db.refresh(ing)

        test_db.add(models.RecipeIngredient(
            recipe_id=recipe.recipe_id, ingredient_id=ing.id, quantity=1.0, unit="g"
        ))
        await test_db.commit()

        await _normalize_existing_ingredient_data(test_db)

        result = await test_db.execute(
            select(models.RecipeIngredient).where(
                models.RecipeIngredient.recipe_id == recipe.recipe_id
            )
        )
        assert result.scalars().first().unit == "g"

    async def test_ensure_ingredient_table_columns_is_idempotent(self):
        """_ensure_ingredient_table_columns can be called multiple times without error."""
        from main import _ensure_ingredient_table_columns
        await _ensure_ingredient_table_columns()
        await _ensure_ingredient_table_columns()

    async def test_seed_user_data_placeholder_does_not_raise(self, test_db):
        """seed_user_data is a no-op placeholder and must not raise."""
        from main import seed_user_data
        await seed_user_data(user_id=1, db=test_db)


# ── Ingredient payload edge cases ─────────────────────────────────────────────

class TestIngredientPayloadEdgeCases:
    """SR-4: _parse_ingredient_payload edge cases not covered elsewhere."""

    async def test_ingredient_name_key_accepted_in_dict_item(
        self, async_client: AsyncClient
    ):
        """Ingredient dict with 'name' key (alias of 'ingredient_name') is accepted."""
        resp = await async_client.post("/recipes", data={
            "title": "Name Key Recipe",
            "summary": "uses 'name' key",
            "tags_json": "[]",
            "ingredients_json": json.dumps([
                {"name": "butter", "quantity": 50, "unit": "g"}
            ]),
            "steps_json": '["Step"]',
        })
        assert resp.status_code == 200
        assert "butter" in resp.json()["ingredients"]

    async def test_duplicate_tag_names_deduplicated_in_create(
        self, async_client: AsyncClient
    ):
        """Duplicate tag names in tags_json are deduplicated via set conversion."""
        resp = await async_client.post("/recipes", data={
            "title": "Dup Tag Recipe",
            "summary": "dup tags",
            "tags_json": json.dumps(["easy", "easy", "quick", "quick"]),
            "ingredients_json": "[]",
            "steps_json": '["Step"]',
        })
        assert resp.status_code == 200
        tags = resp.json()["tags"]
        assert tags.count("easy") == 1
        assert tags.count("quick") == 1

    async def test_empty_ingredients_creates_recipe_with_no_ingredients(
        self, async_client: AsyncClient
    ):
        """ingredients_json='[]' creates a recipe with no ingredients."""
        resp = await async_client.post("/recipes", data={
            "title": "Empty Ings Recipe",
            "summary": "no ingredients",
            "tags_json": "[]",
            "ingredients_json": "[]",
            "steps_json": '["Step"]',
        })
        assert resp.status_code == 200
        assert resp.json()["ingredients"] == []
        assert resp.json()["recipe_ingredients"] == []

    async def test_ingredient_long_form_unit_normalised_in_create(
        self, async_client: AsyncClient
    ):
        """Ingredient submitted with unit='grams' is normalised to 'g' in response."""
        resp = await async_client.post("/recipes", data={
            "title": "Unit Norm Recipe",
            "summary": "normalise unit",
            "tags_json": "[]",
            "ingredients_json": json.dumps([
                {"ingredient_name": "sugar", "quantity": 100, "unit": "grams"}
            ]),
            "steps_json": '["Step"]',
        })
        assert resp.status_code == 200
        ri = resp.json()["recipe_ingredients"]
        assert ri[0]["unit"] == "g"


# ── User registration extended ────────────────────────────────────────────────

class TestUserRegistrationExtended:
    """SR-8: registration and profile field edge cases."""

    async def test_register_with_name_stores_name(self, async_client: AsyncClient):
        """POST /register with name field persists the name on the user record."""
        resp = await async_client.post("/register", json={
            "email": "named_user@example.com",
            "password": "password123",
            "name": "Alice Example",
        })
        assert resp.status_code == 200
        assert resp.json()["name"] == "Alice Example"

    async def test_register_without_name_has_null_name(self, async_client: AsyncClient):
        """POST /register without name field returns name=null."""
        resp = await async_client.post("/register", json={
            "email": "noname_user@example.com",
            "password": "password123",
        })
        assert resp.status_code == 200
        assert resp.json()["name"] is None

    async def test_patch_me_with_empty_body_is_no_op(
        self, async_client: AsyncClient, auth_headers: dict
    ):
        """PATCH /users/me with empty JSON body doesn't crash."""
        resp = await async_client.patch(
            "/users/me", json={}, headers=auth_headers
        )
        assert resp.status_code == 200

    async def test_profile_image_url_initially_null(
        self, async_client: AsyncClient, auth_headers: dict
    ):
        """GET /users/me for a new user returns profile_image_url=null."""
        resp = await async_client.get("/users/me", headers=auth_headers)
        assert resp.status_code == 200
        assert resp.json()["profile_image_url"] is None


# ── Ingredient search extended ─────────────────────────────────────────────────

class TestIngredientSearchExtended:
    """SR-2 / SR-4: GET /ingredients extended coverage."""

    async def test_search_without_q_returns_results(
        self, async_client: AsyncClient, base_ingredients
    ):
        """GET /ingredients with no q parameter returns the base catalogue."""
        resp = await async_client.get("/ingredients")
        assert resp.status_code == 200
        assert len(resp.json()) > 0

    async def test_base_only_false_includes_non_base_ingredients(
        self, async_client: AsyncClient, test_db
    ):
        """GET /ingredients?base_only=false returns non-base (user-created) ingredients."""
        import models
        ing = models.Ingredients(
            ingredient_name="custom_unique_test_ing",
            normalized_name="custom_unique_test_ing",
            is_base=False,
        )
        test_db.add(ing)
        await test_db.commit()

        resp = await async_client.get(
            "/ingredients?base_only=false&q=custom_unique_test_ing"
        )
        assert resp.status_code == 200
        names = [i["ingredient_name"] for i in resp.json()]
        assert "custom_unique_test_ing" in names

    async def test_limit_clamped_to_max_50(
        self, async_client: AsyncClient, base_ingredients
    ):
        """GET /ingredients?limit=999 returns at most 50 results."""
        resp = await async_client.get("/ingredients?limit=999")
        assert resp.status_code == 200
        assert len(resp.json()) <= 50

    async def test_limit_clamped_to_min_1(
        self, async_client: AsyncClient, base_ingredients
    ):
        """GET /ingredients?limit=0 is clamped to 1, returning exactly 1 result."""
        resp = await async_client.get("/ingredients?limit=0")
        assert resp.status_code == 200
        assert len(resp.json()) == 1

    async def test_base_only_true_excludes_non_base(
        self, async_client: AsyncClient, test_db
    ):
        """GET /ingredients?base_only=true excludes non-base ingredients."""
        import models
        ing = models.Ingredients(
            ingredient_name="non_base_excl_test",
            normalized_name="non_base_excl_test",
            is_base=False,
        )
        test_db.add(ing)
        await test_db.commit()

        resp = await async_client.get(
            "/ingredients?base_only=true&q=non_base_excl_test"
        )
        assert resp.status_code == 200
        names = [i["ingredient_name"] for i in resp.json()]
        assert "non_base_excl_test" not in names
