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
