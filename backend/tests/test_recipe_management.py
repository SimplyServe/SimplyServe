"""
Tests for recipe management: update, soft-delete, restore, permanent delete.
"""

import json
import pytest
from httpx import AsyncClient


# ── helper ──────────────────────────────────────────────────────────────────

async def _create_recipe(client: AsyncClient, headers: dict, **overrides) -> dict:
    """Create a recipe and return its JSON response."""
    data = {
        "title": overrides.get("title", "Mgmt Test Recipe"),
        "summary": overrides.get("summary", "A test recipe"),
        "prep_time": "10 minutes",
        "cook_time": "20 minutes",
        "total_time": "30 minutes",
        "servings": overrides.get("servings", 2),
        "difficulty": "Easy",
        "tags_json": json.dumps(overrides.get("tags", ["test"])),
        "ingredients_json": json.dumps(
            overrides.get("ingredients", [
                {"ingredient_name": "egg", "quantity": 2, "unit": "pcs"}
            ])
        ),
        "steps_json": json.dumps(overrides.get("steps", ["Mix", "Cook"])),
    }
    resp = await client.post("/recipes", data=data, headers=headers)
    assert resp.status_code == 200
    return resp.json()


# ── DELETE /recipes/{id}  (soft-delete) ─────────────────────────────────────

class TestSoftDeleteRecipe:

    async def test_soft_delete_success(
        self, async_client: AsyncClient, auth_headers: dict, base_ingredients
    ):
        recipe = await _create_recipe(async_client, auth_headers)
        recipe_id = recipe["id"]

        resp = await async_client.delete(f"/recipes/{recipe_id}")
        assert resp.status_code == 200
        assert resp.json()["message"] == "Success"

    async def test_soft_deleted_recipe_hidden_from_list(
        self, async_client: AsyncClient, auth_headers: dict, base_ingredients
    ):
        recipe = await _create_recipe(async_client, auth_headers, title="HideMe")
        recipe_id = recipe["id"]

        await async_client.delete(f"/recipes/{recipe_id}")

        list_resp = await async_client.get("/recipes")
        ids = [r["id"] for r in list_resp.json()]
        assert recipe_id not in ids

    async def test_soft_delete_nonexistent_404(self, async_client: AsyncClient):
        resp = await async_client.delete("/recipes/999999")
        assert resp.status_code == 404

    async def test_soft_deleted_recipe_appears_in_deleted_list(
        self, async_client: AsyncClient, auth_headers: dict, base_ingredients
    ):
        recipe = await _create_recipe(async_client, auth_headers, title="Deleted Visible")
        recipe_id = recipe["id"]

        await async_client.delete(f"/recipes/{recipe_id}")

        deleted_resp = await async_client.get("/recipes/deleted")
        assert deleted_resp.status_code == 200
        ids = [r["id"] for r in deleted_resp.json()]
        assert recipe_id in ids


# ── POST /recipes/{id}/restore ──────────────────────────────────────────────

class TestRestoreRecipe:

    async def test_restore_success(
        self, async_client: AsyncClient, auth_headers: dict, base_ingredients
    ):
        recipe = await _create_recipe(async_client, auth_headers, title="RestoreMe")
        recipe_id = recipe["id"]

        await async_client.delete(f"/recipes/{recipe_id}")

        resp = await async_client.post(f"/recipes/{recipe_id}/restore")
        assert resp.status_code == 200
        assert resp.json()["message"] == "Restored"

    async def test_restored_recipe_visible_in_list(
        self, async_client: AsyncClient, auth_headers: dict, base_ingredients
    ):
        recipe = await _create_recipe(async_client, auth_headers, title="Resurrect")
        recipe_id = recipe["id"]

        await async_client.delete(f"/recipes/{recipe_id}")
        await async_client.post(f"/recipes/{recipe_id}/restore")

        list_resp = await async_client.get("/recipes")
        ids = [r["id"] for r in list_resp.json()]
        assert recipe_id in ids

    async def test_restored_recipe_gone_from_deleted_list(
        self, async_client: AsyncClient, auth_headers: dict, base_ingredients
    ):
        recipe = await _create_recipe(async_client, auth_headers, title="UnTrash")
        recipe_id = recipe["id"]

        await async_client.delete(f"/recipes/{recipe_id}")
        await async_client.post(f"/recipes/{recipe_id}/restore")

        deleted_resp = await async_client.get("/recipes/deleted")
        ids = [r["id"] for r in deleted_resp.json()]
        assert recipe_id not in ids

    async def test_restore_nonexistent_404(self, async_client: AsyncClient):
        resp = await async_client.post("/recipes/999999/restore")
        assert resp.status_code == 404


# ── DELETE /recipes/{id}/permanent ──────────────────────────────────────────

class TestPermanentDeleteRecipe:

    async def test_permanent_delete_success(
        self, async_client: AsyncClient, auth_headers: dict, base_ingredients
    ):
        recipe = await _create_recipe(async_client, auth_headers, title="ByeBye")
        recipe_id = recipe["id"]

        resp = await async_client.delete(f"/recipes/{recipe_id}/permanent")
        assert resp.status_code == 200
        assert resp.json()["message"] == "Permanently deleted"

    async def test_permanent_delete_removes_from_all_lists(
        self, async_client: AsyncClient, auth_headers: dict, base_ingredients
    ):
        recipe = await _create_recipe(async_client, auth_headers, title="Gone")
        recipe_id = recipe["id"]

        await async_client.delete(f"/recipes/{recipe_id}/permanent")

        list_resp = await async_client.get("/recipes")
        assert recipe_id not in [r["id"] for r in list_resp.json()]

        deleted_resp = await async_client.get("/recipes/deleted")
        assert recipe_id not in [r["id"] for r in deleted_resp.json()]

    async def test_permanent_delete_nonexistent_404(self, async_client: AsyncClient):
        resp = await async_client.delete("/recipes/999999/permanent")
        assert resp.status_code == 404


# ── PUT /recipes/{id}  (update) ─────────────────────────────────────────────

class TestUpdateRecipe:

    async def test_update_title_and_summary(
        self, async_client: AsyncClient, auth_headers: dict, base_ingredients
    ):
        recipe = await _create_recipe(async_client, auth_headers, title="Original")
        recipe_id = recipe["id"]

        update_data = {
            "title": "Updated Title",
            "summary": "Updated summary",
            "prep_time": "5 minutes",
            "cook_time": "15 minutes",
            "total_time": "20 minutes",
            "servings": 4,
            "difficulty": "Hard",
            "tags_json": json.dumps(["updated"]),
            "ingredients_json": json.dumps([
                {"ingredient_name": "egg", "quantity": 3, "unit": "pcs"}
            ]),
            "steps_json": json.dumps(["New step 1", "New step 2"]),
        }

        resp = await async_client.put(
            f"/recipes/{recipe_id}", data=update_data, headers=auth_headers
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["title"] == "Updated Title"
        assert data["summary"] == "Updated summary"
        assert data["servings"] == 4

    async def test_update_nonexistent_recipe_404(
        self, async_client: AsyncClient, auth_headers: dict
    ):
        update_data = {
            "title": "Ghost",
            "summary": "Does not exist",
            "tags_json": "[]",
            "ingredients_json": "[]",
            "steps_json": "[]",
        }
        resp = await async_client.put(
            "/recipes/999999", data=update_data, headers=auth_headers
        )
        assert resp.status_code == 404

    async def test_update_replaces_tags(
        self, async_client: AsyncClient, auth_headers: dict, base_ingredients
    ):
        recipe = await _create_recipe(
            async_client, auth_headers, title="TagSwap", tags=["old"]
        )
        recipe_id = recipe["id"]

        update_data = {
            "title": "TagSwap",
            "summary": "Updated",
            "tags_json": json.dumps(["new-tag-a", "new-tag-b"]),
            "ingredients_json": json.dumps([
                {"ingredient_name": "egg", "quantity": 1, "unit": "pcs"}
            ]),
            "steps_json": json.dumps(["Step"]),
        }

        resp = await async_client.put(
            f"/recipes/{recipe_id}", data=update_data, headers=auth_headers
        )
        assert resp.status_code == 200
        tags = resp.json()["tags"]
        assert "old" not in tags
        assert "new-tag-a" in tags
        assert "new-tag-b" in tags

    async def test_update_replaces_ingredients(
        self, async_client: AsyncClient, auth_headers: dict, base_ingredients
    ):
        recipe = await _create_recipe(async_client, auth_headers, title="IngSwap")
        recipe_id = recipe["id"]

        update_data = {
            "title": "IngSwap",
            "summary": "Updated ingredients",
            "tags_json": "[]",
            "ingredients_json": json.dumps([
                {"ingredient_name": "milk", "quantity": 2, "unit": "cup"}
            ]),
            "steps_json": json.dumps(["Pour"]),
        }

        resp = await async_client.put(
            f"/recipes/{recipe_id}", data=update_data, headers=auth_headers
        )
        assert resp.status_code == 200
        ingredients = resp.json()["ingredients"]
        assert "milk" in ingredients
        assert "egg" not in ingredients


# ── GET /recipes/deleted ────────────────────────────────────────────────────

class TestDeletedRecipesList:

    async def test_deleted_list_empty_initially(self, async_client: AsyncClient):
        resp = await async_client.get("/recipes/deleted")
        assert resp.status_code == 200
        assert isinstance(resp.json(), list)

    async def test_deleted_list_has_recipe_structure(
        self, async_client: AsyncClient, auth_headers: dict, base_ingredients
    ):
        recipe = await _create_recipe(async_client, auth_headers, title="StructCheck")
        await async_client.delete(f"/recipes/{recipe['id']}")

        resp = await async_client.get("/recipes/deleted")
        assert resp.status_code == 200
        recipes = resp.json()
        assert len(recipes) > 0

        r = recipes[0]
        for field in ["id", "title", "summary", "ingredients", "steps", "nutrition"]:
            assert field in r, f"Missing field: {field}"
