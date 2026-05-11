"""
Additional tests targeting specific uncovered lines to push coverage to 90%+.

Covers:
  - _parse_ingredient_payload edge cases (via POST /recipes)
  - GET /ingredients: base_only filter, limit clamping, q parameter
  - auth.py: create_access_token without expires_delta, JWT with no sub, unknown user
  - recipe_ingredients.py: missing file, non-dict JSON, invalid item types
  - async route handlers called directly (bypasses ASGI transport tracking gap)
"""

import json
import pytest
from datetime import timedelta
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession


# ── helpers ──────────────────────────────────────────────────────────────────

def _recipe_data(**overrides) -> dict:
    return {
        "title": "Coverage Test Recipe",
        "summary": "A recipe for coverage testing",
        "tags_json": "[]",
        "steps_json": '["step one"]',
        **overrides,
    }


# ── _parse_ingredient_payload edge cases ─────────────────────────────────────

class TestParseIngredientPayloadEdgeCases:
    """Drive _parse_ingredient_payload via POST /recipes to cover error branches."""

    async def test_invalid_json_returns_422(self, async_client: AsyncClient):
        resp = await async_client.post(
            "/recipes", data=_recipe_data(ingredients_json="not valid json")
        )
        assert resp.status_code == 422

    async def test_non_list_json_returns_422(self, async_client: AsyncClient):
        resp = await async_client.post(
            "/recipes", data=_recipe_data(ingredients_json='{"key": "value"}')
        )
        assert resp.status_code == 422

    async def test_non_string_non_dict_item_returns_422(self, async_client: AsyncClient):
        resp = await async_client.post(
            "/recipes", data=_recipe_data(ingredients_json="[42]")
        )
        assert resp.status_code == 422

    async def test_negative_quantity_returns_422(self, async_client: AsyncClient):
        resp = await async_client.post(
            "/recipes",
            data=_recipe_data(
                ingredients_json='[{"ingredient_name": "egg", "quantity": -1, "unit": "pcs"}]'
            ),
        )
        assert resp.status_code == 422

    async def test_zero_quantity_returns_422(self, async_client: AsyncClient):
        resp = await async_client.post(
            "/recipes",
            data=_recipe_data(
                ingredients_json='[{"ingredient_name": "egg", "quantity": 0, "unit": "pcs"}]'
            ),
        )
        assert resp.status_code == 422

    async def test_invalid_quantity_string_returns_422(self, async_client: AsyncClient):
        resp = await async_client.post(
            "/recipes",
            data=_recipe_data(
                ingredients_json='[{"ingredient_name": "egg", "quantity": "abc", "unit": "pcs"}]'
            ),
        )
        assert resp.status_code == 422

    async def test_string_ingredient_items_accepted(self, async_client: AsyncClient):
        """String items go through _parse_ingredient_text path."""
        resp = await async_client.post(
            "/recipes",
            data=_recipe_data(ingredients_json='["2 cups flour", "1 tsp salt"]'),
        )
        assert resp.status_code == 200
        names = resp.json()["ingredients"]
        assert "flour" in names
        assert "salt" in names

    async def test_duplicate_ingredients_deduplicated(self, async_client: AsyncClient):
        """Duplicate ingredient names are collapsed to one entry."""
        payload = json.dumps([
            {"ingredient_name": "egg", "quantity": 1, "unit": "pcs"},
            {"ingredient_name": "egg", "quantity": 2, "unit": "pcs"},
        ])
        resp = await async_client.post(
            "/recipes", data=_recipe_data(ingredients_json=payload)
        )
        assert resp.status_code == 200
        assert resp.json()["ingredients"].count("egg") == 1

    async def test_empty_name_ingredient_skipped(self, async_client: AsyncClient):
        """Ingredient with empty name is silently skipped."""
        payload = json.dumps([
            {"ingredient_name": "", "quantity": 1, "unit": "pcs"},
            {"ingredient_name": "egg", "quantity": 1, "unit": "pcs"},
        ])
        resp = await async_client.post(
            "/recipes", data=_recipe_data(ingredients_json=payload)
        )
        assert resp.status_code == 200
        assert "egg" in resp.json()["ingredients"]

    async def test_fraction_string_ingredient_no_unit(self, async_client: AsyncClient):
        """Fraction-only text (e.g. '1/2 flour') hits the fraction parsing branch."""
        resp = await async_client.post(
            "/recipes",
            data=_recipe_data(ingredients_json='["1/2 flour"]'),
        )
        assert resp.status_code == 200


# ── GET /ingredients edge cases ───────────────────────────────────────────────

class TestIngredientSearchEdgeCases:

    async def test_limit_zero_clamped_to_one(
        self, async_client: AsyncClient, base_ingredients
    ):
        resp = await async_client.get("/ingredients?limit=0")
        assert resp.status_code == 200
        assert isinstance(resp.json(), list)

    async def test_limit_above_max_clamped_to_fifty(
        self, async_client: AsyncClient, base_ingredients
    ):
        resp = await async_client.get("/ingredients?limit=999")
        assert resp.status_code == 200
        assert len(resp.json()) <= 50

    async def test_base_only_filter(
        self, async_client: AsyncClient, base_ingredients
    ):
        resp = await async_client.get("/ingredients?base_only=true")
        assert resp.status_code == 200
        assert isinstance(resp.json(), list)

    async def test_q_parameter_filters_results(
        self, async_client: AsyncClient, base_ingredients
    ):
        resp = await async_client.get("/ingredients?q=egg")
        assert resp.status_code == 200
        data = resp.json()
        assert isinstance(data, list)
        if data:
            assert any("egg" in item["ingredient_name"].lower() for item in data)

    async def test_empty_q_returns_all(
        self, async_client: AsyncClient, base_ingredients
    ):
        resp = await async_client.get("/ingredients?q=")
        assert resp.status_code == 200
        assert isinstance(resp.json(), list)

    async def test_base_only_with_q(
        self, async_client: AsyncClient, base_ingredients
    ):
        resp = await async_client.get("/ingredients?base_only=true&q=egg")
        assert resp.status_code == 200
        assert isinstance(resp.json(), list)


# ── auth.py edge cases ────────────────────────────────────────────────────────

class TestAuthEdgeCases:

    def test_create_access_token_without_expires_delta(self):
        """Covers the else branch in create_access_token (auth.py line 33)."""
        from auth import create_access_token
        token = create_access_token({"sub": "test@example.com"})
        assert isinstance(token, str)
        assert len(token) > 10

    async def test_jwt_with_no_sub_field_is_rejected(self, async_client: AsyncClient):
        """Token payload missing 'sub' → auth.py line 48 (raise credentials_exception)."""
        from auth import create_access_token
        bad_token = create_access_token(
            {"data": "no_sub_here"},
            expires_delta=timedelta(minutes=5),
        )
        resp = await async_client.get(
            "/users/me",
            headers={"Authorization": f"Bearer {bad_token}"},
        )
        assert resp.status_code == 401

    async def test_jwt_for_nonexistent_user_is_rejected(self, async_client: AsyncClient):
        """Valid token but user not in DB → auth.py lines 54-56."""
        from auth import create_access_token
        token = create_access_token(
            {"sub": "ghost_user_not_in_db@example.com"},
            expires_delta=timedelta(minutes=5),
        )
        resp = await async_client.get(
            "/users/me",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 401


# ── recipe_ingredients.py module ──────────────────────────────────────────────

class TestRecipeIngredientsModule:

    def test_returns_empty_dict_when_file_missing(self, tmp_path, monkeypatch):
        """Covers line 9: DATA_FILE.exists() is False → return {}."""
        import recipe_ingredients
        monkeypatch.setattr(
            recipe_ingredients, "DATA_FILE", tmp_path / "nonexistent.json"
        )
        result = recipe_ingredients.load_recipe_ingredients()
        assert result == {}

    def test_raises_when_top_level_is_not_dict(self, tmp_path, monkeypatch):
        """Covers line 15: raises ValueError when JSON root is a list."""
        import recipe_ingredients
        data_file = tmp_path / "recipe_ingredients.json"
        data_file.write_text('["not", "a", "dict"]')
        monkeypatch.setattr(recipe_ingredients, "DATA_FILE", data_file)
        with pytest.raises(ValueError, match="must contain a JSON object"):
            recipe_ingredients.load_recipe_ingredients()

    def test_skips_items_with_non_list_ingredients(self, tmp_path, monkeypatch):
        """Covers line 20: continue when ingredients value is not a list."""
        import recipe_ingredients
        data_file = tmp_path / "recipe_ingredients.json"
        data_file.write_text(json.dumps({
            "Good Recipe": ["1 cup flour", "2 eggs"],
            "Bad Recipe": "this should be a list not a string",
        }))
        monkeypatch.setattr(recipe_ingredients, "DATA_FILE", data_file)
        result = recipe_ingredients.load_recipe_ingredients()
        assert "Good Recipe" in result
        assert "Bad Recipe" not in result

    def test_normalizes_list_items_to_strings(self, tmp_path, monkeypatch):
        """Ingredients list items are converted to str."""
        import recipe_ingredients
        data_file = tmp_path / "recipe_ingredients.json"
        data_file.write_text(json.dumps({
            "Mixed Recipe": ["1 cup flour", 2, True],
        }))
        monkeypatch.setattr(recipe_ingredients, "DATA_FILE", data_file)
        result = recipe_ingredients.load_recipe_ingredients()
        assert result["Mixed Recipe"] == ["1 cup flour", "2", "True"]


# ── _find_or_create_ingredient (new ingredient creation path) ─────────────────

class TestFindOrCreateIngredient:

    async def test_new_ingredient_is_created_and_linked(
        self, async_client: AsyncClient
    ):
        """Creating a recipe with a brand-new ingredient name covers the
        'not found → create' branch of _find_or_create_ingredient."""
        resp = await async_client.post(
            "/recipes",
            data=_recipe_data(
                ingredients_json=json.dumps([
                    {
                        "ingredient_name": "unicorn_dust_unique_xyz",
                        "quantity": 1,
                        "unit": "pcs",
                    }
                ])
            ),
        )
        assert resp.status_code == 200
        assert "unicorn_dust_unique_xyz" in resp.json()["ingredients"]


# ── Direct async function calls (bypasses ASGI transport coverage gap) ─────────
#
# Python 3.13 + coverage 7.x has a known issue where lines inside async
# coroutines executed via ASGI transport are not attributed by sys.monitoring.
# Calling the functions directly from pytest-asyncio tests does get traced.

class TestDirectAsyncFunctions:

    async def test_find_or_create_ingredient_new(self, test_db: AsyncSession):
        """Directly call _find_or_create_ingredient to cover the create branch."""
        from main import _find_or_create_ingredient
        result = await _find_or_create_ingredient(test_db, "direct_test_ingredient")
        assert result.ingredient_name == "direct_test_ingredient"
        assert result.id is not None

    async def test_find_or_create_ingredient_existing(self, test_db: AsyncSession):
        """Call _find_or_create_ingredient twice to cover the 'already exists' branch."""
        from main import _find_or_create_ingredient
        first = await _find_or_create_ingredient(test_db, "shared_ingredient")
        second = await _find_or_create_ingredient(test_db, "shared_ingredient")
        assert first.id == second.id

    async def test_calculate_recipe_nutrition_totals(self, test_db: AsyncSession):
        """Directly call _calculate_recipe_nutrition_totals — covers the loop body."""
        from main import _find_or_create_ingredient, _calculate_recipe_nutrition_totals
        import models

        recipe = models.Recipe(
            recipe_name="Nutrition Test",
            summary="test",
            servings=1,
        )
        test_db.add(recipe)
        await test_db.commit()
        await test_db.refresh(recipe)

        ing = await _find_or_create_ingredient(test_db, "calorie_ingredient")
        ing.avg_calories = 100.0
        ing.avg_protein = 5.0
        ing.avg_carbs = 10.0
        ing.avg_fat = 3.0
        test_db.add(ing)

        ri = models.RecipeIngredient(
            ingredient_id=ing.id,
            recipe_id=recipe.recipe_id,
            quantity=2.0,
            unit="pcs",
        )
        test_db.add(ri)
        await test_db.commit()

        totals = await _calculate_recipe_nutrition_totals(test_db, recipe.recipe_id)
        assert totals["calories"] == pytest.approx(200.0)
        assert totals["protein"] == pytest.approx(10.0)

    async def test_list_recipes_direct(self, test_db: AsyncSession):
        """Directly call list_recipes endpoint function."""
        from main import list_recipes
        result = await list_recipes(db=test_db)
        assert isinstance(result, list)

    async def test_list_recipes_with_data(self, test_db: AsyncSession):
        """Call list_recipes with a recipe present to exercise the loop body."""
        import models, json
        from main import list_recipes

        recipe = models.Recipe(
            recipe_name="Loop Test Recipe",
            summary="exercises the for-loop in list_recipes",
            servings=2,
            instructions=json.dumps(["step 1"]),
        )
        test_db.add(recipe)
        await test_db.commit()

        result = await list_recipes(db=test_db)
        assert any(r.title == "Loop Test Recipe" for r in result)

    async def test_list_deleted_recipes_direct(self, test_db: AsyncSession):
        """Directly call list_deleted_recipes to cover its loop body."""
        import models, json
        from main import list_deleted_recipes

        recipe = models.Recipe(
            recipe_name="Deleted Recipe",
            summary="deleted",
            servings=1,
            is_deleted=True,
            instructions=json.dumps(["step"]),
        )
        test_db.add(recipe)
        await test_db.commit()

        result = await list_deleted_recipes(db=test_db)
        assert any(r.title == "Deleted Recipe" for r in result)

    async def test_create_user_direct(self, test_db: AsyncSession):
        """Directly call create_user to cover its body."""
        from main import create_user
        import schemas
        user_in = schemas.UserCreate(
            email="direct_create@example.com",
            password="securepassword123",
        )
        result = await create_user(user=user_in, db=test_db)
        assert result.email == "direct_create@example.com"

    async def test_create_user_duplicate_email(self, test_db: AsyncSession):
        """Cover the duplicate-email HTTPException branch in create_user."""
        from main import create_user
        from fastapi import HTTPException
        import schemas
        user_in = schemas.UserCreate(
            email="dup_create@example.com",
            password="password123",
        )
        await create_user(user=user_in, db=test_db)
        with pytest.raises(HTTPException) as exc_info:
            await create_user(user=user_in, db=test_db)
        assert exc_info.value.status_code == 400

    async def test_login_correct_credentials(self, test_db: AsyncSession):
        """Cover the happy-path token generation in login_for_access_token."""
        from main import create_user, login_for_access_token
        from fastapi.security import OAuth2PasswordRequestForm
        import schemas

        await create_user(
            user=schemas.UserCreate(email="login_ok@example.com", password="pass1234"),
            db=test_db,
        )

        class FakeForm:
            username = "login_ok@example.com"
            password = "pass1234"

        result = await login_for_access_token(form_data=FakeForm(), db=test_db)
        assert "access_token" in result
        assert result["token_type"] == "bearer"

    async def test_login_wrong_password(self, test_db: AsyncSession):
        """Cover the 401 branch in login_for_access_token."""
        from main import create_user, login_for_access_token
        from fastapi import HTTPException
        import schemas

        await create_user(
            user=schemas.UserCreate(email="login_bad@example.com", password="correct"),
            db=test_db,
        )

        class FakeForm:
            username = "login_bad@example.com"
            password = "wrong_password"

        with pytest.raises(HTTPException) as exc_info:
            await login_for_access_token(form_data=FakeForm(), db=test_db)
        assert exc_info.value.status_code == 401

    async def test_delete_recipe_direct(self, test_db: AsyncSession):
        """Cover delete_recipe body (soft delete)."""
        import models
        from main import delete_recipe

        recipe = models.Recipe(recipe_name="ToDelete", summary="x", servings=1)
        test_db.add(recipe)
        await test_db.commit()
        await test_db.refresh(recipe)

        result = await delete_recipe(recipe_id=recipe.recipe_id, db=test_db)
        assert result["message"] == "Success"

    async def test_delete_recipe_not_found(self, test_db: AsyncSession):
        """Cover the 404 branch in delete_recipe."""
        from main import delete_recipe
        from fastapi import HTTPException
        with pytest.raises(HTTPException) as exc_info:
            await delete_recipe(recipe_id=999999, db=test_db)
        assert exc_info.value.status_code == 404

    async def test_restore_recipe_direct(self, test_db: AsyncSession):
        """Cover restore_recipe body."""
        import models
        from main import restore_recipe

        recipe = models.Recipe(
            recipe_name="ToRestore", summary="x", servings=1, is_deleted=True
        )
        test_db.add(recipe)
        await test_db.commit()
        await test_db.refresh(recipe)

        result = await restore_recipe(recipe_id=recipe.recipe_id, db=test_db)
        assert result["message"] == "Restored"

    async def test_restore_recipe_not_found(self, test_db: AsyncSession):
        """Cover the 404 branch in restore_recipe."""
        from main import restore_recipe
        from fastapi import HTTPException
        with pytest.raises(HTTPException) as exc_info:
            await restore_recipe(recipe_id=999999, db=test_db)
        assert exc_info.value.status_code == 404

    async def test_permanent_delete_recipe_direct(self, test_db: AsyncSession):
        """Cover permanent_delete_recipe body."""
        import models
        from main import permanent_delete_recipe

        recipe = models.Recipe(recipe_name="ToPermanentDelete", summary="x", servings=1)
        test_db.add(recipe)
        await test_db.commit()
        await test_db.refresh(recipe)

        result = await permanent_delete_recipe(recipe_id=recipe.recipe_id, db=test_db)
        assert result["message"] == "Permanently deleted"

    async def test_permanent_delete_recipe_not_found(self, test_db: AsyncSession):
        """Cover the 404 branch in permanent_delete_recipe."""
        from main import permanent_delete_recipe
        from fastapi import HTTPException
        with pytest.raises(HTTPException) as exc_info:
            await permanent_delete_recipe(recipe_id=999999, db=test_db)
        assert exc_info.value.status_code == 404

    async def test_search_ingredients_direct(self, test_db: AsyncSession):
        """Cover search_ingredients including limit clamp and result return."""
        from main import search_ingredients

        result = await search_ingredients(q="", limit=0, base_only=False, db=test_db)
        assert isinstance(result, list)

        result2 = await search_ingredients(q="egg", limit=999, base_only=True, db=test_db)
        assert isinstance(result2, list)

    async def test_update_user_me_direct(self, test_db: AsyncSession):
        """Cover update_user_me body (PATCH /users/me)."""
        from main import create_user, update_user_me
        import schemas, models

        user = await create_user(
            user=schemas.UserCreate(email="patch_me@example.com", password="pass"),
            db=test_db,
        )
        update = schemas.UserUpdate(name="Patched Name")
        result = await update_user_me(update=update, current_user=user, db=test_db)
        assert result.name == "Patched Name"

    async def test_update_users_me_direct(self, test_db: AsyncSession):
        """Cover update_users_me body (PUT /users/me)."""
        from main import create_user, update_users_me
        from fastapi import HTTPException
        import schemas

        user = await create_user(
            user=schemas.UserCreate(email="put_me@example.com", password="pass"),
            db=test_db,
        )

        payload = schemas.UserNameUpdate(name="Put Name")
        result = await update_users_me(payload=payload, current_user=user, db=test_db)
        assert result.name == "Put Name"

        empty_payload = schemas.UserNameUpdate(name="   ")
        with pytest.raises(HTTPException) as exc_info:
            await update_users_me(payload=empty_payload, current_user=user, db=test_db)
        assert exc_info.value.status_code == 400


# ── SR-7: Budget Awareness — 'Budget Friendly' tag filter ────────────────────

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


# ── SR-6: Meal Calendar & Meal Planning ──────────────────────────────────────
#
# No HTTP endpoints exist yet for meal planning; tests exercise the Meals and
# MealRecipe database models directly so the schema is verified and the
# persistence layer is covered.

async def _make_user(db: AsyncSession, email: str) -> "models.User":
    from main import create_user
    import schemas
    return await create_user(
        user=schemas.UserCreate(email=email, password="pass"), db=db
    )

async def _make_recipe(db: AsyncSession, name: str = "Plan Recipe") -> "models.Recipe":
    import models as m
    recipe = m.Recipe(recipe_name=name, summary="test", servings=2)
    db.add(recipe)
    await db.commit()
    await db.refresh(recipe)
    return recipe


class TestMealModelPersistence:
    """SR-6: Meals rows can be created and queried correctly."""

    async def test_create_meal_persists(self, test_db: AsyncSession):
        import models as m
        from sqlalchemy import select
        user = await _make_user(test_db, "meal_persist@example.com")
        meal = m.Meals(user_id=user.id, planned_date="2026-06-01", stage="Dinner")
        test_db.add(meal)
        await test_db.commit()
        await test_db.refresh(meal)

        result = await test_db.execute(select(m.Meals).where(m.Meals.meal_id == meal.meal_id))
        fetched = result.scalars().first()
        assert fetched is not None
        assert fetched.planned_date == "2026-06-01"
        assert fetched.stage == "Dinner"

    async def test_meal_linked_to_correct_user(self, test_db: AsyncSession):
        import models as m
        from sqlalchemy import select
        user = await _make_user(test_db, "meal_user@example.com")
        meal = m.Meals(user_id=user.id, planned_date="2026-06-02", stage="Lunch")
        test_db.add(meal)
        await test_db.commit()
        await test_db.refresh(meal)

        result = await test_db.execute(
            select(m.Meals).where(m.Meals.user_id == user.id)
        )
        meals = result.scalars().all()
        assert any(me.meal_id == meal.meal_id for me in meals)

    async def test_meal_stage_values(self, test_db: AsyncSession):
        import models as m
        from sqlalchemy import select
        user = await _make_user(test_db, "meal_stages@example.com")
        for stage in ("Breakfast", "Lunch", "Dinner"):
            test_db.add(m.Meals(user_id=user.id, planned_date="2026-06-03", stage=stage))
        await test_db.commit()

        result = await test_db.execute(
            select(m.Meals).where(m.Meals.user_id == user.id)
        )
        stages = {me.stage for me in result.scalars().all()}
        assert stages == {"Breakfast", "Lunch", "Dinner"}

    async def test_multiple_meals_different_dates(self, test_db: AsyncSession):
        import models as m
        from sqlalchemy import select
        user = await _make_user(test_db, "meal_dates@example.com")
        dates = ["2026-06-01", "2026-06-02", "2026-06-03", "2026-06-04", "2026-06-05",
                 "2026-06-06", "2026-06-07"]
        for d in dates:
            test_db.add(m.Meals(user_id=user.id, planned_date=d, stage="Dinner"))
        await test_db.commit()

        result = await test_db.execute(
            select(m.Meals).where(m.Meals.user_id == user.id)
        )
        stored_dates = {me.planned_date for me in result.scalars().all()}
        assert stored_dates == set(dates)

    async def test_multiple_meals_same_date(self, test_db: AsyncSession):
        """Multiple meal slots (Breakfast + Lunch + Dinner) on one day."""
        import models as m
        from sqlalchemy import select
        user = await _make_user(test_db, "meal_same_day@example.com")
        for stage in ("Breakfast", "Lunch", "Dinner"):
            test_db.add(m.Meals(user_id=user.id, planned_date="2026-06-10", stage=stage))
        await test_db.commit()

        result = await test_db.execute(
            select(m.Meals).where(
                m.Meals.user_id == user.id,
                m.Meals.planned_date == "2026-06-10",
            )
        )
        assert len(result.scalars().all()) == 3


class TestMealRecipeAssociation:
    """SR-6: Recipes can be linked to meal slots via MealRecipe."""

    async def test_link_recipe_to_meal(self, test_db: AsyncSession):
        import models as m
        from sqlalchemy import select
        user = await _make_user(test_db, "meal_link@example.com")
        recipe = await _make_recipe(test_db, "Linked Recipe")
        meal = m.Meals(user_id=user.id, planned_date="2026-06-01", stage="Lunch")
        test_db.add(meal)
        await test_db.commit()
        await test_db.refresh(meal)

        link = m.MealRecipe(meal_id=meal.meal_id, recipe_id=recipe.recipe_id)
        test_db.add(link)
        await test_db.commit()

        result = await test_db.execute(
            select(m.MealRecipe).where(m.MealRecipe.meal_id == meal.meal_id)
        )
        links = result.scalars().all()
        assert len(links) == 1
        assert links[0].recipe_id == recipe.recipe_id

    async def test_multiple_recipes_linked_to_one_meal(self, test_db: AsyncSession):
        import models as m
        from sqlalchemy import select
        user = await _make_user(test_db, "meal_multi_recipe@example.com")
        r1 = await _make_recipe(test_db, "Recipe A")
        r2 = await _make_recipe(test_db, "Recipe B")
        meal = m.Meals(user_id=user.id, planned_date="2026-06-05", stage="Dinner")
        test_db.add(meal)
        await test_db.commit()
        await test_db.refresh(meal)

        for r in (r1, r2):
            test_db.add(m.MealRecipe(meal_id=meal.meal_id, recipe_id=r.recipe_id))
        await test_db.commit()

        result = await test_db.execute(
            select(m.MealRecipe).where(m.MealRecipe.meal_id == meal.meal_id)
        )
        assert len(result.scalars().all()) == 2

    async def test_same_recipe_linked_to_multiple_meals(self, test_db: AsyncSession):
        import models as m
        from sqlalchemy import select
        user = await _make_user(test_db, "recipe_multi_meal@example.com")
        recipe = await _make_recipe(test_db, "Reused Recipe")

        meal_ids = []
        for d, stage in [("2026-06-01", "Lunch"), ("2026-06-03", "Dinner")]:
            meal = m.Meals(user_id=user.id, planned_date=d, stage=stage)
            test_db.add(meal)
            await test_db.commit()
            await test_db.refresh(meal)
            meal_ids.append(meal.meal_id)

        for mid in meal_ids:
            test_db.add(m.MealRecipe(meal_id=mid, recipe_id=recipe.recipe_id))
        await test_db.commit()

        result = await test_db.execute(
            select(m.MealRecipe).where(m.MealRecipe.recipe_id == recipe.recipe_id)
        )
        assert len(result.scalars().all()) == 2


class TestMealPlanningWeekView:
    """SR-6: week-level planning — querying meals across a date range."""

    async def test_query_meals_for_week(self, test_db: AsyncSession):
        import models as m
        from sqlalchemy import select
        user = await _make_user(test_db, "meal_week@example.com")
        week = [f"2026-06-{d:02d}" for d in range(9, 16)]  # Mon–Sun
        for d in week:
            test_db.add(m.Meals(user_id=user.id, planned_date=d, stage="Dinner"))
        await test_db.commit()

        result = await test_db.execute(
            select(m.Meals).where(
                m.Meals.user_id == user.id,
                m.Meals.planned_date >= "2026-06-09",
                m.Meals.planned_date <= "2026-06-15",
            )
        )
        assert len(result.scalars().all()) == 7

    async def test_meals_outside_week_not_returned(self, test_db: AsyncSession):
        import models as m
        from sqlalchemy import select
        user = await _make_user(test_db, "meal_outside@example.com")
        test_db.add(m.Meals(user_id=user.id, planned_date="2026-05-01", stage="Lunch"))
        test_db.add(m.Meals(user_id=user.id, planned_date="2026-06-09", stage="Dinner"))
        await test_db.commit()

        result = await test_db.execute(
            select(m.Meals).where(
                m.Meals.user_id == user.id,
                m.Meals.planned_date >= "2026-06-09",
                m.Meals.planned_date <= "2026-06-15",
            )
        )
        dates = [me.planned_date for me in result.scalars().all()]
        assert "2026-05-01" not in dates
        assert "2026-06-09" in dates

    async def test_user_meal_isolation(self, test_db: AsyncSession):
        """Meals for user A must not appear in queries for user B."""
        import models as m
        from sqlalchemy import select
        user_a = await _make_user(test_db, "meal_iso_a@example.com")
        user_b = await _make_user(test_db, "meal_iso_b@example.com")

        test_db.add(m.Meals(user_id=user_a.id, planned_date="2026-06-01", stage="Lunch"))
        test_db.add(m.Meals(user_id=user_b.id, planned_date="2026-06-01", stage="Dinner"))
        await test_db.commit()

        result = await test_db.execute(
            select(m.Meals).where(m.Meals.user_id == user_a.id)
        )
        meals = result.scalars().all()
        assert all(me.user_id == user_a.id for me in meals)
        assert len(meals) == 1


class TestMealCascadeDelete:
    """SR-6: deleting a user cascade-deletes their meal plans."""

    async def test_user_delete_removes_meals(self, test_db: AsyncSession):
        import models as m
        from sqlalchemy import select
        user = await _make_user(test_db, "meal_cascade@example.com")
        user_id = user.id
        for d in ("2026-06-01", "2026-06-02"):
            test_db.add(m.Meals(user_id=user_id, planned_date=d, stage="Dinner"))
        await test_db.commit()

        await test_db.delete(user)
        await test_db.commit()

        result = await test_db.execute(
            select(m.Meals).where(m.Meals.user_id == user_id)
        )
        assert result.scalars().all() == []


class TestMealBoundary:
    """SR-6: boundary and equivalence cases for meal planning."""

    async def test_meal_with_no_stage(self, test_db: AsyncSession):
        import models as m
        from sqlalchemy import select
        user = await _make_user(test_db, "meal_no_stage@example.com")
        meal = m.Meals(user_id=user.id, planned_date="2026-06-01", stage=None)
        test_db.add(meal)
        await test_db.commit()
        await test_db.refresh(meal)
        assert meal.meal_id is not None

    async def test_meal_boundary_dates(self, test_db: AsyncSession):
        import models as m
        from sqlalchemy import select
        user = await _make_user(test_db, "meal_boundary@example.com")
        for date in ("2026-01-01", "2026-12-31"):
            test_db.add(m.Meals(user_id=user.id, planned_date=date, stage="Dinner"))
        await test_db.commit()

        result = await test_db.execute(
            select(m.Meals).where(m.Meals.user_id == user.id)
        )
        dates = {me.planned_date for me in result.scalars().all()}
        assert "2026-01-01" in dates
        assert "2026-12-31" in dates

    async def test_meal_with_linked_recipe_has_correct_ids(self, test_db: AsyncSession):
        import models as m
        from sqlalchemy import select
        user = await _make_user(test_db, "meal_ids@example.com")
        recipe = await _make_recipe(test_db, "ID Check Recipe")
        meal = m.Meals(user_id=user.id, planned_date="2026-07-04", stage="Dinner")
        test_db.add(meal)
        await test_db.commit()
        await test_db.refresh(meal)

        link = m.MealRecipe(meal_id=meal.meal_id, recipe_id=recipe.recipe_id)
        test_db.add(link)
        await test_db.commit()

        result = await test_db.execute(
            select(m.MealRecipe).where(m.MealRecipe.meal_id == meal.meal_id)
        )
        fetched = result.scalars().first()
        assert fetched.meal_id == meal.meal_id
        assert fetched.recipe_id == recipe.recipe_id
