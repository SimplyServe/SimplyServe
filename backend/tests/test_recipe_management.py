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


# ── SR-7: Budget Friendly tag ─────────────────────────────────────────────────

BUDGET_TAG = "Budget Friendly"


def _budget_recipe(**overrides) -> dict:
    return {
        "title": overrides.get("title", "Budget Friendly Recipe"),
        "summary": overrides.get("summary", "A cheap and cheerful recipe"),
        "prep_time": "5 minutes",
        "cook_time": "15 minutes",
        "total_time": "20 minutes",
        "servings": overrides.get("servings", 2),
        "difficulty": "Easy",
        "tags_json": json.dumps(overrides.get("tags", [BUDGET_TAG])),
        "ingredients_json": json.dumps(
            overrides.get("ingredients", [
                {"ingredient_name": "egg", "quantity": 1, "unit": "pcs"}
            ])
        ),
        "steps_json": json.dumps(overrides.get("steps", ["Cook and serve"])),
    }


class TestSR7BudgetFriendlyTag:
    """SR-7: Budget Friendly tag filtering."""

    async def test_budget_friendly_tag_created(self, async_client: AsyncClient, base_ingredients):
        """EP: recipe with 'Budget Friendly' tag can be created."""
        resp = await async_client.post("/recipes", data={
            "title": "SR7 Budget Recipe", "summary": "Cheap eats",
            "tags_json": json.dumps(["Budget Friendly"]),
            "ingredients_json": json.dumps([
                {"ingredient_name": "potato", "quantity": 3, "unit": "pcs"},
                {"ingredient_name": "onion", "quantity": 1, "unit": "pcs"},
            ]),
            "steps_json": json.dumps(["Chop", "Fry"]),
        })
        assert resp.status_code == 200
        assert "Budget Friendly" in resp.json()["tags"]

    async def test_filter_budget_friendly_recipes(self, async_client: AsyncClient, base_ingredients):
        """IT: filter for budget-friendly recipes from listing."""
        await async_client.post("/recipes", data={
            "title": "SR7 Cheap", "summary": "Cheap",
            "tags_json": json.dumps(["Budget Friendly"]),
            "ingredients_json": json.dumps([{"ingredient_name": "potato", "quantity": 2, "unit": "pcs"}]),
            "steps_json": json.dumps(["Cook"]),
        })
        await async_client.post("/recipes", data={
            "title": "SR7 Expensive", "summary": "Pricey",
            "tags_json": json.dumps(["premium"]),
            "ingredients_json": json.dumps([{"ingredient_name": "egg", "quantity": 1, "unit": "pcs"}]),
            "steps_json": json.dumps(["Cook"]),
        })

        recipes = (await async_client.get("/recipes")).json()
        budget = [r for r in recipes if "Budget Friendly" in r.get("tags", [])]
        assert len(budget) >= 1
        assert all("Budget Friendly" in r["tags"] for r in budget)

    async def test_ingredient_cost_data_for_budget_calc(self, test_db, base_ingredients):
        """IT: ingredient cost data available for budget calculations."""
        from sqlalchemy.future import select
        import models
        result = await test_db.execute(
            select(models.Ingredients.ingredient_name, models.Ingredients.avg_cost)
            .where(models.Ingredients.avg_cost.isnot(None))
        )
        rows = result.all()
        assert len(rows) > 0
        for name, cost in rows:
            assert cost >= 0


class TestBudgetFriendlyTagCreation:
    """SR-7: recipes can be tagged 'Budget Friendly' and the tag is returned."""

    async def test_budget_friendly_tag_present_in_response(
        self, async_client: AsyncClient, base_ingredients
    ):
        resp = await async_client.post("/recipes", data=_budget_recipe())
        assert resp.status_code == 200
        assert BUDGET_TAG in resp.json()["tags"]

    async def test_budget_friendly_tag_alongside_other_tags(
        self, async_client: AsyncClient, base_ingredients
    ):
        resp = await async_client.post(
            "/recipes",
            data=_budget_recipe(tags=[BUDGET_TAG, "Quick", "Easy"]),
        )
        assert resp.status_code == 200
        tags = resp.json()["tags"]
        assert BUDGET_TAG in tags
        assert "Quick" in tags
        assert "Easy" in tags

    async def test_budget_friendly_tag_case_preserved(
        self, async_client: AsyncClient, base_ingredients
    ):
        """Tag name casing must be stored exactly as supplied."""
        resp = await async_client.post("/recipes", data=_budget_recipe())
        assert resp.status_code == 200
        assert BUDGET_TAG in resp.json()["tags"]
        assert "budget friendly" not in resp.json()["tags"]
        assert "BUDGET FRIENDLY" not in resp.json()["tags"]

    async def test_non_budget_recipe_does_not_have_tag(
        self, async_client: AsyncClient, base_ingredients
    ):
        resp = await async_client.post(
            "/recipes",
            data=_budget_recipe(tags=["Fancy", "Expensive"]),
        )
        assert resp.status_code == 200
        assert BUDGET_TAG not in resp.json()["tags"]


class TestBudgetFriendlyTagFiltering:
    """SR-7: the tag data returned by GET /recipes supports client-side filtering."""

    async def test_budget_recipe_visible_in_recipe_list(
        self, async_client: AsyncClient, base_ingredients
    ):
        create_resp = await async_client.post("/recipes", data=_budget_recipe())
        recipe_id = create_resp.json()["id"]

        list_resp = await async_client.get("/recipes")
        assert list_resp.status_code == 200
        ids = [r["id"] for r in list_resp.json()]
        assert recipe_id in ids

    async def test_budget_tag_present_on_recipe_in_list(
        self, async_client: AsyncClient, base_ingredients
    ):
        create_resp = await async_client.post("/recipes", data=_budget_recipe())
        recipe_id = create_resp.json()["id"]

        list_resp = await async_client.get("/recipes")
        recipe = next(r for r in list_resp.json() if r["id"] == recipe_id)
        assert BUDGET_TAG in recipe["tags"]

    async def test_only_budget_recipes_have_tag(
        self, async_client: AsyncClient, base_ingredients
    ):
        """Mixed catalogue: only the budget recipe carries the tag."""
        await async_client.post("/recipes", data=_budget_recipe(title="Budget One"))
        await async_client.post(
            "/recipes", data=_budget_recipe(title="Fancy One", tags=["Fancy"])
        )

        list_resp = await async_client.get("/recipes")
        recipes = list_resp.json()

        budget = [r for r in recipes if BUDGET_TAG in r["tags"]]
        non_budget = [r for r in recipes if BUDGET_TAG not in r["tags"]]

        assert len(budget) >= 1
        assert all(BUDGET_TAG in r["tags"] for r in budget)
        assert all(BUDGET_TAG not in r["tags"] for r in non_budget)

    async def test_multiple_budget_recipes_all_tagged(
        self, async_client: AsyncClient, base_ingredients
    ):
        for i in range(3):
            await async_client.post(
                "/recipes", data=_budget_recipe(title=f"Budget Recipe {i}")
            )

        list_resp = await async_client.get("/recipes")
        budget_recipes = [r for r in list_resp.json() if BUDGET_TAG in r["tags"]]
        assert len(budget_recipes) >= 3


class TestBudgetFriendlyTagUpdate:
    """SR-7: the 'Budget Friendly' tag can be added or removed via recipe update."""

    async def _create(self, client, tags):
        resp = await client.post("/recipes", data=_budget_recipe(tags=tags))
        assert resp.status_code == 200
        return resp.json()["id"]

    async def _update(self, client, recipe_id, tags, headers):
        data = {
            "title": "Updated Recipe",
            "summary": "Updated",
            "tags_json": json.dumps(tags),
            "ingredients_json": json.dumps([
                {"ingredient_name": "egg", "quantity": 1, "unit": "pcs"}
            ]),
            "steps_json": json.dumps(["Cook"]),
        }
        return await client.put(f"/recipes/{recipe_id}", data=data, headers=headers)

    async def test_add_budget_tag_via_update(
        self, async_client: AsyncClient, auth_headers: dict, base_ingredients
    ):
        recipe_id = await self._create(async_client, ["Fancy"])
        resp = await self._update(async_client, recipe_id, [BUDGET_TAG], auth_headers)
        assert resp.status_code == 200
        assert BUDGET_TAG in resp.json()["tags"]

    async def test_remove_budget_tag_via_update(
        self, async_client: AsyncClient, auth_headers: dict, base_ingredients
    ):
        recipe_id = await self._create(async_client, [BUDGET_TAG])
        resp = await self._update(async_client, recipe_id, ["Fancy"], auth_headers)
        assert resp.status_code == 200
        assert BUDGET_TAG not in resp.json()["tags"]

    async def test_budget_tag_survives_update_when_included(
        self, async_client: AsyncClient, auth_headers: dict, base_ingredients
    ):
        recipe_id = await self._create(async_client, [BUDGET_TAG, "Quick"])
        resp = await self._update(
            async_client, recipe_id, [BUDGET_TAG, "Healthy"], auth_headers
        )
        assert resp.status_code == 200
        assert BUDGET_TAG in resp.json()["tags"]

    async def test_budget_tag_hidden_after_soft_delete(
        self, async_client: AsyncClient, base_ingredients
    ):
        """Soft-deleted budget recipes must not appear in the active list."""
        create_resp = await async_client.post("/recipes", data=_budget_recipe())
        recipe_id = create_resp.json()["id"]

        await async_client.delete(f"/recipes/{recipe_id}")

        list_resp = await async_client.get("/recipes")
        ids = [r["id"] for r in list_resp.json()]
        assert recipe_id not in ids

    async def test_budget_tag_visible_after_restore(
        self, async_client: AsyncClient, base_ingredients
    ):
        """Restoring a soft-deleted budget recipe brings the tag back to the list."""
        create_resp = await async_client.post("/recipes", data=_budget_recipe())
        recipe_id = create_resp.json()["id"]

        await async_client.delete(f"/recipes/{recipe_id}")
        await async_client.post(f"/recipes/{recipe_id}/restore")

        list_resp = await async_client.get("/recipes")
        recipe = next((r for r in list_resp.json() if r["id"] == recipe_id), None)
        assert recipe is not None
        assert BUDGET_TAG in recipe["tags"]


class TestBudgetFriendlyBoundary:
    """SR-7: boundary and equivalence cases for the Budget Friendly tag."""

    async def test_budget_tag_with_minimum_servings(
        self, async_client: AsyncClient, base_ingredients
    ):
        resp = await async_client.post(
            "/recipes", data=_budget_recipe(servings=1)
        )
        assert resp.status_code == 200
        assert BUDGET_TAG in resp.json()["tags"]

    async def test_budget_tag_with_maximum_servings(
        self, async_client: AsyncClient, base_ingredients
    ):
        resp = await async_client.post(
            "/recipes", data=_budget_recipe(servings=100)
        )
        assert resp.status_code == 200
        assert BUDGET_TAG in resp.json()["tags"]

    async def test_budget_tag_deduplicated_when_sent_twice(
        self, async_client: AsyncClient, base_ingredients
    ):
        resp = await async_client.post(
            "/recipes",
            data=_budget_recipe(tags=[BUDGET_TAG, BUDGET_TAG]),
        )
        assert resp.status_code == 200
        tags = resp.json()["tags"]
        assert tags.count(BUDGET_TAG) == 1

    async def test_budget_tag_only_recipe_has_no_other_tags(
        self, async_client: AsyncClient, base_ingredients
    ):
        resp = await async_client.post(
            "/recipes", data=_budget_recipe(tags=[BUDGET_TAG])
        )
        assert resp.status_code == 200
        assert resp.json()["tags"] == [BUDGET_TAG]
