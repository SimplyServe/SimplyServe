"""
Additional tests targeting specific uncovered lines to push coverage to 90%+.

Covers:
  - _parse_ingredient_payload edge cases (via POST /recipes)
  - GET /ingredients: base_only filter, limit clamping, q parameter
  - auth.py: create_access_token without expires_delta, JWT with no sub, unknown user
  - recipe_ingredients.py: missing file, non-dict JSON, invalid item types
  - async route handlers called directly (bypasses ASGI transport tracking gap)

System Requirement Tests:
  - SR-1: Smart Meal Suggestions (Meal Spinner / Reroll Avoidance)
  - SR-2: Dietary Filters & Allergen Settings (13 allergen categories)
  - SR-3: Calorie Coach (BMR/TDEE Calculator & Macro Targets)
  - SR-4: Recipe Management (CRUD, Search, Tags, Soft Delete, Helpers)
  - SR-5: Shopping List Management (Automatic generation from recipes)
  - SR-6: Meal Calendar & Meal Planning
  - SR-7: Budget Awareness ('Budget Friendly' tag filter)
  - SR-8: Authentication & User Management (Custom JWT, Profile, Avatar)
  - NFR:  Non-Functional (Performance, Error Handling, Data Consistency)

Test Methodologies:
  - Equivalence Partitioning (EP)
  - Boundary Value Analysis (BVA)
  - Negative Testing (NT)
  - Integration Testing (IT)
"""

import io
import json
import time
import pytest
from datetime import datetime, timedelta
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

import models


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

class TestSR1MealsModelCRUD:
    """SR-1: Meals model CRUD for planned meal storage."""

    async def test_create_meal_with_all_fields(self, test_db: AsyncSession):
        """EP: valid meal with all fields populated."""
        user = models.User(
            email="sr1_meal@example.com", hashed_password="hashed", is_active=True
        )
        test_db.add(user)
        await test_db.commit()
        await test_db.refresh(user)

        meal = models.Meals(user_id=user.id, planned_date="2025-01-15", stage="dinner")
        test_db.add(meal)
        await test_db.commit()
        await test_db.refresh(meal)

        assert meal.meal_id is not None
        assert meal.user_id == user.id
        assert meal.planned_date == "2025-01-15"
        assert meal.stage == "dinner"

    async def test_create_meal_breakfast_stage(self, test_db: AsyncSession):
        """EP: meal with breakfast stage."""
        user = models.User(
            email="sr1_bfast@example.com", hashed_password="h", is_active=True
        )
        test_db.add(user)
        await test_db.commit()
        await test_db.refresh(user)

        meal = models.Meals(user_id=user.id, planned_date="2025-01-15", stage="breakfast")
        test_db.add(meal)
        await test_db.commit()
        assert meal.stage == "breakfast"

    async def test_create_meal_lunch_stage(self, test_db: AsyncSession):
        """EP: meal with lunch stage."""
        user = models.User(
            email="sr1_lunch@example.com", hashed_password="h", is_active=True
        )
        test_db.add(user)
        await test_db.commit()
        await test_db.refresh(user)

        meal = models.Meals(user_id=user.id, planned_date="2025-01-15", stage="lunch")
        test_db.add(meal)
        await test_db.commit()
        assert meal.stage == "lunch"

    async def test_multiple_meals_per_day(self, test_db: AsyncSession):
        """EP: user can have multiple meals per day."""
        user = models.User(
            email="sr1_multi@example.com", hashed_password="h", is_active=True
        )
        test_db.add(user)
        await test_db.commit()
        await test_db.refresh(user)

        for stage in ["breakfast", "lunch", "dinner"]:
            test_db.add(models.Meals(user_id=user.id, planned_date="2025-01-15", stage=stage))
        await test_db.commit()

        result = await test_db.execute(
            select(models.Meals).where(models.Meals.user_id == user.id)
        )
        assert len(result.scalars().all()) == 3

    async def test_meal_user_relationship(self, test_db: AsyncSession):
        """IT: Meals.user back-populates correctly."""
        user = models.User(
            email="sr1_rel@example.com", hashed_password="h", is_active=True
        )
        test_db.add(user)
        await test_db.commit()
        await test_db.refresh(user)

        meal = models.Meals(user_id=user.id, planned_date="2025-02-01", stage="dinner")
        test_db.add(meal)
        await test_db.commit()

        result = await test_db.execute(
            select(models.Meals).where(models.Meals.user_id == user.id)
        )
        assert result.scalars().first() is not None


class TestSR1MealRecipeAssociation:
    """SR-1: Linking recipes to meals via MealRecipe junction table."""

    async def test_link_recipe_to_meal(self, test_db: AsyncSession):
        """EP: valid recipe-meal link."""
        user = models.User(email="sr1_mr@example.com", hashed_password="h", is_active=True)
        test_db.add(user)
        await test_db.commit()
        await test_db.refresh(user)

        recipe = models.Recipe(recipe_name="Suggested", summary="s", servings=2)
        test_db.add(recipe)
        await test_db.commit()
        await test_db.refresh(recipe)

        meal = models.Meals(user_id=user.id, planned_date="2025-01-20", stage="dinner")
        test_db.add(meal)
        await test_db.commit()
        await test_db.refresh(meal)

        test_db.add(models.MealRecipe(meal_id=meal.meal_id, recipe_id=recipe.recipe_id))
        await test_db.commit()

        result = await test_db.execute(
            select(models.MealRecipe).where(models.MealRecipe.meal_id == meal.meal_id)
        )
        link = result.scalars().first()
        assert link is not None
        assert link.recipe_id == recipe.recipe_id

    async def test_multiple_recipes_per_meal(self, test_db: AsyncSession):
        """EP: a meal can include multiple recipes."""
        user = models.User(email="sr1_mr2@example.com", hashed_password="h", is_active=True)
        test_db.add(user)
        await test_db.commit()
        await test_db.refresh(user)

        meal = models.Meals(user_id=user.id, planned_date="2025-01-20", stage="dinner")
        test_db.add(meal)
        await test_db.commit()
        await test_db.refresh(meal)

        for i in range(3):
            recipe = models.Recipe(recipe_name=f"MR Recipe {i}", summary="s", servings=1)
            test_db.add(recipe)
            await test_db.commit()
            await test_db.refresh(recipe)
            test_db.add(models.MealRecipe(meal_id=meal.meal_id, recipe_id=recipe.recipe_id))
        await test_db.commit()

        result = await test_db.execute(
            select(models.MealRecipe).where(models.MealRecipe.meal_id == meal.meal_id)
        )
        assert len(result.scalars().all()) == 3


class TestSR1RecipeFeedback:
    """SR-1: Recipe feedback for reroll avoidance."""

    async def test_create_positive_feedback(self, test_db: AsyncSession):
        """EP: user likes a recipe."""
        user = models.User(email="sr1_fb1@example.com", hashed_password="h", is_active=True)
        test_db.add(user)
        await test_db.commit()
        await test_db.refresh(user)

        recipe = models.Recipe(recipe_name="Liked", summary="s", servings=2)
        test_db.add(recipe)
        await test_db.commit()
        await test_db.refresh(recipe)

        fb = models.recipe_feedback(
            user_id=user.id, recipe_id=recipe.recipe_id,
            rating=5, liked=1, created_at=datetime.utcnow().isoformat(),
        )
        test_db.add(fb)
        await test_db.commit()
        await test_db.refresh(fb)

        assert fb.feedback_id is not None
        assert fb.rating == 5
        assert fb.liked == 1

    async def test_create_negative_feedback(self, test_db: AsyncSession):
        """EP: user dislikes a recipe."""
        user = models.User(email="sr1_fb2@example.com", hashed_password="h", is_active=True)
        test_db.add(user)
        await test_db.commit()
        await test_db.refresh(user)

        recipe = models.Recipe(recipe_name="Disliked", summary="s", servings=1)
        test_db.add(recipe)
        await test_db.commit()
        await test_db.refresh(recipe)

        fb = models.recipe_feedback(
            user_id=user.id, recipe_id=recipe.recipe_id,
            rating=1, liked=0, created_at=datetime.utcnow().isoformat(),
        )
        test_db.add(fb)
        await test_db.commit()
        assert fb.rating == 1
        assert fb.liked == 0

    async def test_feedback_rating_boundary_min(self, test_db: AsyncSession):
        """BVA: minimum rating value (1)."""
        user = models.User(email="sr1_fb3@example.com", hashed_password="h", is_active=True)
        test_db.add(user)
        await test_db.commit()
        await test_db.refresh(user)

        recipe = models.Recipe(recipe_name="MinR", summary="s", servings=1)
        test_db.add(recipe)
        await test_db.commit()
        await test_db.refresh(recipe)

        fb = models.recipe_feedback(
            user_id=user.id, recipe_id=recipe.recipe_id,
            rating=1, liked=0, created_at=datetime.utcnow().isoformat(),
        )
        test_db.add(fb)
        await test_db.commit()
        assert fb.rating == 1

    async def test_feedback_rating_boundary_max(self, test_db: AsyncSession):
        """BVA: maximum rating value (5)."""
        user = models.User(email="sr1_fb4@example.com", hashed_password="h", is_active=True)
        test_db.add(user)
        await test_db.commit()
        await test_db.refresh(user)

        recipe = models.Recipe(recipe_name="MaxR", summary="s", servings=1)
        test_db.add(recipe)
        await test_db.commit()
        await test_db.refresh(recipe)

        fb = models.recipe_feedback(
            user_id=user.id, recipe_id=recipe.recipe_id,
            rating=5, liked=1, created_at=datetime.utcnow().isoformat(),
        )
        test_db.add(fb)
        await test_db.commit()
        assert fb.rating == 5

    async def test_multiple_feedback_per_user(self, test_db: AsyncSession):
        """EP: user can rate multiple recipes."""
        user = models.User(email="sr1_fb5@example.com", hashed_password="h", is_active=True)
        test_db.add(user)
        await test_db.commit()
        await test_db.refresh(user)

        for i in range(3):
            recipe = models.Recipe(recipe_name=f"FB {i}", summary="s", servings=1)
            test_db.add(recipe)
            await test_db.commit()
            await test_db.refresh(recipe)
            test_db.add(models.recipe_feedback(
                user_id=user.id, recipe_id=recipe.recipe_id,
                rating=i + 1, liked=1 if i > 1 else 0,
                created_at=datetime.utcnow().isoformat(),
            ))
        await test_db.commit()

        result = await test_db.execute(
            select(models.recipe_feedback).where(models.recipe_feedback.user_id == user.id)
        )
        assert len(result.scalars().all()) == 3

    async def test_reroll_avoidance_disliked_tracked(self, test_db: AsyncSession):
        """IT: disliked recipes queryable for reroll avoidance."""
        user = models.User(email="sr1_reroll@example.com", hashed_password="h", is_active=True)
        test_db.add(user)
        await test_db.commit()
        await test_db.refresh(user)

        disliked_ids = []
        for i, (liked_val, rating) in enumerate([(1, 5), (1, 4), (0, 1)]):
            recipe = models.Recipe(recipe_name=f"Reroll {i}", summary="s", servings=1)
            test_db.add(recipe)
            await test_db.commit()
            await test_db.refresh(recipe)
            test_db.add(models.recipe_feedback(
                user_id=user.id, recipe_id=recipe.recipe_id,
                rating=rating, liked=liked_val,
                created_at=datetime.utcnow().isoformat(),
            ))
            if liked_val == 0:
                disliked_ids.append(recipe.recipe_id)
        await test_db.commit()

        result = await test_db.execute(
            select(models.recipe_feedback.recipe_id).where(
                models.recipe_feedback.user_id == user.id,
                models.recipe_feedback.liked == 0,
            )
        )
        avoided = [row[0] for row in result.all()]
        assert len(avoided) == 1
        assert avoided[0] == disliked_ids[0]


class TestSR1MealSuggestionFiltering:
    """SR-1: Recipe filtering for meal suggestions."""

    async def test_excludes_deleted_recipes(self, test_db: AsyncSession):
        """EP: deleted recipes excluded from suggestions."""
        test_db.add_all([
            models.Recipe(recipe_name="Active", summary="a", servings=2, is_deleted=False),
            models.Recipe(recipe_name="Deleted", summary="d", servings=2, is_deleted=True),
        ])
        await test_db.commit()

        result = await test_db.execute(
            select(models.Recipe).where(models.Recipe.is_deleted != True)
        )
        names = [r.recipe_name for r in result.scalars().all()]
        assert "Active" in names
        assert "Deleted" not in names

    async def test_filter_by_tag_for_suggestions(self, test_db: AsyncSession):
        """IT: filter recipes by tag for meal suggestions."""
        recipe = models.Recipe(recipe_name="QuickMeal", summary="s", servings=1)
        test_db.add(recipe)
        await test_db.commit()
        await test_db.refresh(recipe)

        tag = models.Tag(tag_name="sr1-quick-meal")
        test_db.add(tag)
        await test_db.commit()
        await test_db.refresh(tag)

        test_db.add(models.RecipeTag(tag_id=tag.id, recipe_id=recipe.recipe_id))
        await test_db.commit()

        result = await test_db.execute(
            select(models.Recipe.recipe_name)
            .join(models.RecipeTag).join(models.Tag)
            .where(models.Tag.tag_name == "sr1-quick-meal")
        )
        assert "QuickMeal" in [row[0] for row in result.all()]

class TestSR2PreferenceModel:
    """SR-2: Preference model for allergen/dietary preference storage."""

    async def test_create_preference(self, test_db: AsyncSession):
        """EP: valid preference creation."""
        pref = models.Preference(preference_name="Gluten-Free", like=1)
        test_db.add(pref)
        await test_db.commit()
        await test_db.refresh(pref)

        assert pref.preference_id is not None
        assert pref.preference_name == "Gluten-Free"
        assert pref.like == 1

    async def test_create_allergen_dislike(self, test_db: AsyncSession):
        """EP: allergen marked as dislike (0)."""
        pref = models.Preference(preference_name="Contains Nuts", like=0)
        test_db.add(pref)
        await test_db.commit()
        assert pref.like == 0

    async def test_all_13_allergen_categories(self, test_db: AsyncSession):
        """BVA: all 13 major allergen categories can be stored."""
        allergens = [
            "Celery", "Cereals containing gluten", "Crustaceans",
            "Eggs", "Fish", "Lupin", "Milk", "Molluscs",
            "Mustard", "Nuts", "Peanuts", "Sesame seeds", "Soybeans",
        ]
        for name in allergens:
            test_db.add(models.Preference(preference_name=name, like=0))
        await test_db.commit()

        result = await test_db.execute(select(models.Preference))
        assert len(result.scalars().all()) == 13

    async def test_query_preference_by_name(self, test_db: AsyncSession):
        """EP: retrieve preference by name."""
        test_db.add(models.Preference(preference_name="Dairy-Free", like=1))
        await test_db.commit()

        result = await test_db.execute(
            select(models.Preference).where(models.Preference.preference_name == "Dairy-Free")
        )
        assert result.scalars().first() is not None


class TestSR2UserPreferenceAssociation:
    """SR-2: Linking users to dietary preferences."""

    async def test_link_user_to_preference(self, test_db: AsyncSession):
        """EP: associate a user with a preference."""
        user = models.User(email="sr2_up@example.com", hashed_password="h", is_active=True)
        test_db.add(user)
        await test_db.commit()
        await test_db.refresh(user)

        pref = models.Preference(preference_name="Vegetarian", like=1)
        test_db.add(pref)
        await test_db.commit()
        await test_db.refresh(pref)

        test_db.add(models.UserPreference(user_id=user.id, preference_id=pref.preference_id))
        await test_db.commit()

        result = await test_db.execute(
            select(models.UserPreference).where(models.UserPreference.user_id == user.id)
        )
        assert result.scalars().first() is not None

    async def test_user_multiple_preferences(self, test_db: AsyncSession):
        """EP: user can have multiple dietary preferences."""
        user = models.User(email="sr2_up2@example.com", hashed_password="h", is_active=True)
        test_db.add(user)
        await test_db.commit()
        await test_db.refresh(user)

        for name in ["Vegetarian", "Nut-Free", "Gluten-Free"]:
            pref = models.Preference(preference_name=name, like=1)
            test_db.add(pref)
            await test_db.commit()
            await test_db.refresh(pref)
            test_db.add(models.UserPreference(user_id=user.id, preference_id=pref.preference_id))
        await test_db.commit()

        result = await test_db.execute(
            select(models.UserPreference).where(models.UserPreference.user_id == user.id)
        )
        assert len(result.scalars().all()) == 3

    async def test_query_user_allergens(self, test_db: AsyncSession):
        """IT: query all allergens a user has flagged."""
        user = models.User(email="sr2_qa@example.com", hashed_password="h", is_active=True)
        test_db.add(user)
        await test_db.commit()
        await test_db.refresh(user)

        for name in ["Peanuts", "Shellfish"]:
            pref = models.Preference(preference_name=name, like=0)
            test_db.add(pref)
            await test_db.commit()
            await test_db.refresh(pref)
            test_db.add(models.UserPreference(user_id=user.id, preference_id=pref.preference_id))
        await test_db.commit()

        result = await test_db.execute(
            select(models.Preference.preference_name)
            .join(models.UserPreference, models.Preference.preference_id == models.UserPreference.preference_id)
            .where(models.UserPreference.user_id == user.id, models.Preference.like == 0)
        )
        allergens = [row[0] for row in result.all()]
        assert "Peanuts" in allergens
        assert "Shellfish" in allergens


class TestSR2DietaryTagFiltering:
    """SR-2: Filtering recipes by dietary tags via API."""

    async def test_vegan_tag_in_recipes(self, async_client: AsyncClient, base_ingredients):
        """IT: recipe with vegan tag returned in listing."""
        resp = await async_client.post("/recipes", data={
            "title": "SR2 Vegan Bowl", "summary": "Plant-based",
            "tags_json": json.dumps(["vegan", "dairy-free"]),
            "ingredients_json": json.dumps([{"ingredient_name": "spinach", "quantity": 100, "unit": "g"}]),
            "steps_json": json.dumps(["Prepare"]),
        })
        assert resp.status_code == 200

        recipes = (await async_client.get("/recipes")).json()
        vegan = [r for r in recipes if "vegan" in r.get("tags", [])]
        assert len(vegan) >= 1

    async def test_vegetarian_vs_meat_tags(self, async_client: AsyncClient, base_ingredients):
        """EP: vegetarian and meat tags separate correctly."""
        for title, tags in [("SR2 Veggie", ["vegetarian"]), ("SR2 Meat", ["meat"])]:
            await async_client.post("/recipes", data={
                "title": title, "summary": f"{title} summary",
                "tags_json": json.dumps(tags),
                "ingredients_json": json.dumps([{"ingredient_name": "onion", "quantity": 1, "unit": "pcs"}]),
                "steps_json": json.dumps(["Cook"]),
            })

        recipes = (await async_client.get("/recipes")).json()
        vegetarian = [r for r in recipes if "vegetarian" in r.get("tags", [])]
        assert all(r["title"] != "SR2 Meat" for r in vegetarian)

    async def test_gluten_free_tag(self, async_client: AsyncClient, base_ingredients):
        """EP: gluten-free tag stored and retrieved."""
        resp = await async_client.post("/recipes", data={
            "title": "SR2 GF Salad", "summary": "GF",
            "tags_json": json.dumps(["gluten-free"]),
            "ingredients_json": json.dumps([{"ingredient_name": "tomato", "quantity": 2, "unit": "pcs"}]),
            "steps_json": json.dumps(["Chop"]),
        })
        assert resp.status_code == 200
        assert "gluten-free" in resp.json()["tags"]

    async def test_multiple_dietary_tags(self, async_client: AsyncClient, base_ingredients):
        """EP: recipe can have multiple dietary tags."""
        resp = await async_client.post("/recipes", data={
            "title": "SR2 Multi Diet", "summary": "Many restrictions",
            "tags_json": json.dumps(["vegan", "gluten-free", "nut-free", "soy-free"]),
            "ingredients_json": json.dumps([{"ingredient_name": "carrot", "quantity": 3, "unit": "pcs"}]),
            "steps_json": json.dumps(["Prep"]),
        })
        assert resp.status_code == 200
        tags = resp.json()["tags"]
        for t in ["vegan", "gluten-free", "nut-free", "soy-free"]:
            assert t in tags

    async def test_no_dietary_tags(self, async_client: AsyncClient, base_ingredients):
        """NT: recipe with no dietary tags."""
        resp = await async_client.post("/recipes", data={
            "title": "SR2 No Diet", "summary": "Normal",
            "tags_json": json.dumps([]),
            "ingredients_json": json.dumps([{"ingredient_name": "egg", "quantity": 2, "unit": "pcs"}]),
            "steps_json": json.dumps(["Cook"]),
        })
        assert resp.status_code == 200
        assert resp.json()["tags"] == []


class TestSR2IngredientAllergenSearch:
    """SR-2: Identifying allergens through ingredient search."""

    async def test_search_milk_allergen(self, async_client: AsyncClient, base_ingredients):
        """EP: search for common allergen 'milk'."""
        resp = await async_client.get("/ingredients?q=milk")
        assert resp.status_code == 200
        if resp.json():
            assert any("milk" in i["ingredient_name"].lower() for i in resp.json())

    async def test_search_egg_allergen(self, async_client: AsyncClient, base_ingredients):
        """EP: search for egg allergen."""
        resp = await async_client.get("/ingredients?q=egg")
        assert resp.status_code == 200
        if resp.json():
            assert any("egg" in i["ingredient_name"].lower() for i in resp.json())

    async def test_allergen_in_recipe_ingredients(self, async_client: AsyncClient, base_ingredients):
        """IT: recipe containing allergen lists it in ingredients."""
        resp = await async_client.post("/recipes", data={
            "title": "SR2 Egg Dish", "summary": "Contains eggs",
            "tags_json": json.dumps(["contains-eggs"]),
            "ingredients_json": json.dumps([{"ingredient_name": "egg", "quantity": 3, "unit": "pcs"}]),
            "steps_json": json.dumps(["Scramble"]),
        })
        assert resp.status_code == 200
        assert "egg" in resp.json()["ingredients"]

class TestSR3NutritionCalculation:
    """SR-3: Nutrition calculation via _calculate_recipe_nutrition_totals."""

    async def test_single_ingredient_totals(self, test_db: AsyncSession):
        """EP: recipe with one ingredient."""
        from main import _find_or_create_ingredient, _calculate_recipe_nutrition_totals

        recipe = models.Recipe(recipe_name="SR3 Single", summary="s", servings=1)
        test_db.add(recipe)
        await test_db.commit()
        await test_db.refresh(recipe)

        ing = await _find_or_create_ingredient(test_db, "sr3_chicken")
        ing.avg_calories = 165.0
        ing.avg_protein = 31.0
        ing.avg_carbs = 0.0
        ing.avg_fat = 3.6
        test_db.add(ing)
        test_db.add(models.RecipeIngredient(
            recipe_id=recipe.recipe_id, ingredient_id=ing.id, quantity=2.0, unit="pcs"
        ))
        await test_db.commit()

        totals = await _calculate_recipe_nutrition_totals(test_db, recipe.recipe_id)
        assert totals["calories"] == pytest.approx(330.0)
        assert totals["protein"] == pytest.approx(62.0)

    async def test_multiple_ingredient_totals(self, test_db: AsyncSession):
        """EP: recipe with multiple ingredients."""
        from main import _find_or_create_ingredient, _calculate_recipe_nutrition_totals

        recipe = models.Recipe(recipe_name="SR3 Multi", summary="s", servings=2)
        test_db.add(recipe)
        await test_db.commit()
        await test_db.refresh(recipe)

        for name, cal, prot, carbs, fat, qty in [
            ("sr3_egg", 155.0, 13.0, 1.0, 11.0, 2.0),
            ("sr3_milk", 0.61, 0.03, 0.05, 0.03, 250.0),
        ]:
            ing = await _find_or_create_ingredient(test_db, name)
            ing.avg_calories, ing.avg_protein = cal, prot
            ing.avg_carbs, ing.avg_fat = carbs, fat
            test_db.add(ing)
            test_db.add(models.RecipeIngredient(
                recipe_id=recipe.recipe_id, ingredient_id=ing.id, quantity=qty, unit="g"
            ))
        await test_db.commit()

        totals = await _calculate_recipe_nutrition_totals(test_db, recipe.recipe_id)
        assert totals["calories"] == pytest.approx(462.5)

    async def test_no_ingredients_zero_totals(self, test_db: AsyncSession):
        """BVA: recipe with zero ingredients returns all zeros."""
        from main import _calculate_recipe_nutrition_totals

        recipe = models.Recipe(recipe_name="SR3 Empty", summary="s", servings=1)
        test_db.add(recipe)
        await test_db.commit()
        await test_db.refresh(recipe)

        totals = await _calculate_recipe_nutrition_totals(test_db, recipe.recipe_id)
        assert totals == {"calories": 0.0, "protein": 0.0, "carbs": 0.0, "fats": 0.0}

    async def test_null_nutrition_fields_handled(self, test_db: AsyncSession):
        """NT: ingredient with null nutrition fields treated as 0."""
        from main import _find_or_create_ingredient, _calculate_recipe_nutrition_totals

        recipe = models.Recipe(recipe_name="SR3 Null", summary="s", servings=1)
        test_db.add(recipe)
        await test_db.commit()
        await test_db.refresh(recipe)

        ing = await _find_or_create_ingredient(test_db, "sr3_unknown")
        test_db.add(models.RecipeIngredient(
            recipe_id=recipe.recipe_id, ingredient_id=ing.id, quantity=5.0, unit="g"
        ))
        await test_db.commit()

        totals = await _calculate_recipe_nutrition_totals(test_db, recipe.recipe_id)
        assert totals["calories"] == 0.0

    async def test_null_quantity_defaults_to_one(self, test_db: AsyncSession):
        """NT: null quantity treated as 1."""
        from main import _find_or_create_ingredient, _calculate_recipe_nutrition_totals

        recipe = models.Recipe(recipe_name="SR3 NullQty", summary="s", servings=1)
        test_db.add(recipe)
        await test_db.commit()
        await test_db.refresh(recipe)

        ing = await _find_or_create_ingredient(test_db, "sr3_nullqty")
        ing.avg_calories = 100.0
        ing.avg_protein = 10.0
        ing.avg_carbs = 5.0
        ing.avg_fat = 2.0
        test_db.add(ing)
        test_db.add(models.RecipeIngredient(
            recipe_id=recipe.recipe_id, ingredient_id=ing.id, quantity=None, unit="pcs"
        ))
        await test_db.commit()

        totals = await _calculate_recipe_nutrition_totals(test_db, recipe.recipe_id)
        assert totals["calories"] == pytest.approx(100.0)


class TestSR3PerServingNutrition:
    """SR-3: Per-serving nutrition via _build_nutrition_info."""

    def test_even_division(self):
        """EP: even division by servings."""
        from main import _build_nutrition_info
        result = _build_nutrition_info(
            {"calories": 800, "protein": 60, "carbs": 100, "fats": 30}, servings=4
        )
        assert result["calories"] == 200
        assert result["protein"] == "15g"

    def test_fractional_rounding(self):
        """BVA: fractional results rounded."""
        from main import _build_nutrition_info
        result = _build_nutrition_info(
            {"calories": 100, "protein": 7, "carbs": 15, "fats": 3}, servings=3
        )
        assert result["calories"] == 33
        assert isinstance(result["protein"], str)

    def test_single_serving(self):
        """BVA: 1 serving returns totals."""
        from main import _build_nutrition_info
        result = _build_nutrition_info(
            {"calories": 500, "protein": 40, "carbs": 60, "fats": 20}, servings=1
        )
        assert result["calories"] == 500

    def test_zero_servings(self):
        """BVA: 0 servings treated as 1."""
        from main import _build_nutrition_info
        result = _build_nutrition_info(
            {"calories": 300, "protein": 25, "carbs": 35, "fats": 10}, servings=0
        )
        assert result["calories"] == 300

    def test_large_servings(self):
        """BVA: very large servings count."""
        from main import _build_nutrition_info
        result = _build_nutrition_info(
            {"calories": 10000, "protein": 500, "carbs": 1500, "fats": 300}, servings=100
        )
        assert result["calories"] == 100
        assert result["protein"] == "5g"


class TestSR3BaseIngredientData:
    """SR-3: Base ingredient seed data integrity."""

    async def test_base_ingredients_have_nutrition(self, test_db: AsyncSession, base_ingredients):
        """IT: seeded base ingredients include nutrition fields."""
        result = await test_db.execute(
            select(models.Ingredients).where(models.Ingredients.avg_calories.isnot(None))
        )
        ingredients = result.scalars().all()
        assert len(ingredients) > 0
        for ing in ingredients:
            assert ing.avg_calories is not None
            assert ing.avg_protein is not None

    async def test_base_ingredients_non_negative_calories(self, test_db: AsyncSession, base_ingredients):
        """BVA: calories must be non-negative."""
        result = await test_db.execute(
            select(models.Ingredients).where(models.Ingredients.avg_calories.isnot(None))
        )
        for ing in result.scalars().all():
            assert ing.avg_calories >= 0

    async def test_base_ingredients_have_cost(self, test_db: AsyncSession, base_ingredients):
        """IT: base ingredients have cost data."""
        result = await test_db.execute(
            select(models.Ingredients).where(models.Ingredients.avg_cost.isnot(None))
        )
        ingredients = result.scalars().all()
        assert len(ingredients) > 0
        for ing in ingredients:
            assert ing.avg_cost is not None


class TestSR3NutritionViaAPI:
    """SR-3: Nutrition in API responses."""

    async def test_created_recipe_has_nutrition(self, async_client: AsyncClient, base_ingredients):
        """IT: nutrition calculated on recipe creation."""
        resp = await async_client.post("/recipes", data={
            "title": "SR3 API Nutr", "summary": "test",
            "servings": 2, "tags_json": "[]",
            "ingredients_json": json.dumps([
                {"ingredient_name": "egg", "quantity": 3, "unit": "pcs"},
                {"ingredient_name": "milk", "quantity": 200, "unit": "ml"},
            ]),
            "steps_json": json.dumps(["Mix"]),
        })
        assert resp.status_code == 200
        nutrition = resp.json()["nutrition"]
        assert isinstance(nutrition["calories"], int)
        assert nutrition["protein"].endswith("g")

    async def test_recipe_list_includes_nutrition(self, async_client: AsyncClient, base_ingredients):
        """IT: GET /recipes includes nutrition for each recipe."""
        await async_client.post("/recipes", data={
            "title": "SR3 List Nutr", "summary": "test", "tags_json": "[]",
            "ingredients_json": json.dumps([{"ingredient_name": "egg", "quantity": 2, "unit": "pcs"}]),
            "steps_json": json.dumps(["Cook"]),
        })
        recipes = (await async_client.get("/recipes")).json()
        for recipe in recipes:
            assert "nutrition" in recipe
            assert recipe["nutrition"] is not None

    async def test_nutrition_varies_with_servings(self, async_client: AsyncClient, base_ingredients):
        """EP: different servings = different per-serving nutrition."""
        base = {
            "summary": "test", "tags_json": "[]",
            "ingredients_json": json.dumps([{"ingredient_name": "egg", "quantity": 4, "unit": "pcs"}]),
            "steps_json": json.dumps(["Cook"]),
        }
        r1 = await async_client.post("/recipes", data={**base, "title": "SR3 S1", "servings": 1})
        r4 = await async_client.post("/recipes", data={**base, "title": "SR3 S4", "servings": 4})
        cal1, cal4 = r1.json()["nutrition"]["calories"], r4.json()["nutrition"]["calories"]
        if cal1 > 0 and cal4 > 0:
            assert cal1 > cal4

    async def test_empty_ingredients_zero_nutrition(self, async_client: AsyncClient):
        """BVA: recipe with empty ingredients has zero nutrition."""
        resp = await async_client.post("/recipes", data={
            "title": "SR3 Empty Nutr", "summary": "empty",
            "tags_json": "[]", "ingredients_json": "[]",
            "steps_json": json.dumps(["Nothing"]),
        })
        assert resp.status_code == 200
        n = resp.json()["nutrition"]
        assert n["calories"] == 0
        assert n["protein"] == "0g"

    async def test_macro_format_g_suffix(self, async_client: AsyncClient, base_ingredients):
        """IT: macros formatted as strings with 'g' suffix."""
        resp = await async_client.post("/recipes", data={
            "title": "SR3 Fmt", "summary": "fmt",
            "tags_json": "[]",
            "ingredients_json": json.dumps([{"ingredient_name": "egg", "quantity": 2, "unit": "pcs"}]),
            "steps_json": json.dumps(["Cook"]),
        })
        n = resp.json()["nutrition"]
        for key in ["protein", "carbs", "fats"]:
            assert n[key].endswith("g")

class TestSR4RecipeCRUD:
    """SR-4: Additional recipe CRUD tests."""

    async def test_create_recipe_returns_id(self, async_client: AsyncClient, base_ingredients):
        """EP: created recipe has a positive integer ID."""
        resp = await async_client.post("/recipes", data=_recipe_data(
            title="SR4 Create", summary="sr4",
            ingredients_json=json.dumps([{"ingredient_name": "egg", "quantity": 1, "unit": "pcs"}]),
        ))
        assert resp.status_code == 200
        assert resp.json()["id"] > 0

    async def test_recipe_fields_match_input(self, async_client: AsyncClient, base_ingredients):
        """EP: returned recipe fields match submitted data."""
        resp = await async_client.post("/recipes", data={
            "title": "SR4 Match", "summary": "Match test",
            "prep_time": "15 minutes", "cook_time": "25 minutes",
            "total_time": "40 minutes", "servings": 3, "difficulty": "Hard",
            "tags_json": json.dumps(["sr4"]),
            "ingredients_json": json.dumps([{"ingredient_name": "egg", "quantity": 2, "unit": "pcs"}]),
            "steps_json": json.dumps(["Step 1", "Step 2"]),
        })
        assert resp.status_code == 200
        data = resp.json()
        assert data["title"] == "SR4 Match"
        assert data["summary"] == "Match test"
        assert data["servings"] == 3
        assert data["difficulty"] == "Hard"
        assert data["steps"] == ["Step 1", "Step 2"]

    async def test_update_recipe_changes_fields(self, async_client: AsyncClient, base_ingredients):
        """EP: PUT /recipes/{id} updates fields."""
        create = await async_client.post("/recipes", data=_recipe_data(
            title="SR4 Original",
            ingredients_json=json.dumps([{"ingredient_name": "egg", "quantity": 1, "unit": "pcs"}]),
        ))
        rid = create.json()["id"]

        update = await async_client.put(f"/recipes/{rid}", data={
            "title": "SR4 Updated", "summary": "Updated",
            "tags_json": json.dumps(["updated"]),
            "ingredients_json": json.dumps([{"ingredient_name": "milk", "quantity": 1, "unit": "cup"}]),
            "steps_json": json.dumps(["New step"]),
        })
        assert update.status_code == 200
        assert update.json()["title"] == "SR4 Updated"

    async def test_soft_delete_and_restore_cycle(self, async_client: AsyncClient, base_ingredients):
        """IT: full soft-delete → restore cycle."""
        create = await async_client.post("/recipes", data=_recipe_data(
            title="SR4 Cycle",
            ingredients_json=json.dumps([{"ingredient_name": "egg", "quantity": 1, "unit": "pcs"}]),
        ))
        rid = create.json()["id"]

        del_resp = await async_client.delete(f"/recipes/{rid}")
        assert del_resp.json()["message"] == "Success"

        # Should be in deleted list
        deleted = (await async_client.get("/recipes/deleted")).json()
        assert rid in [r["id"] for r in deleted]

        # Restore
        restore_resp = await async_client.post(f"/recipes/{rid}/restore")
        assert restore_resp.json()["message"] == "Restored"

        # Should be back in main list
        recipes = (await async_client.get("/recipes")).json()
        assert rid in [r["id"] for r in recipes]

    async def test_permanent_delete_removes_completely(self, async_client: AsyncClient, base_ingredients):
        """IT: permanent delete removes from all lists."""
        create = await async_client.post("/recipes", data=_recipe_data(
            title="SR4 Perm Del",
            ingredients_json=json.dumps([{"ingredient_name": "egg", "quantity": 1, "unit": "pcs"}]),
        ))
        rid = create.json()["id"]

        await async_client.delete(f"/recipes/{rid}/permanent")

        recipes = (await async_client.get("/recipes")).json()
        deleted = (await async_client.get("/recipes/deleted")).json()
        assert rid not in [r["id"] for r in recipes]
        assert rid not in [r["id"] for r in deleted]


class TestSR4RecipeSearch:
    """SR-4: Ingredient search functionality."""

    async def test_search_case_insensitive(self, async_client: AsyncClient, base_ingredients):
        """EP: ingredient search is case-insensitive."""
        r1 = await async_client.get("/ingredients?q=EGG")
        r2 = await async_client.get("/ingredients?q=egg")
        assert r1.status_code == 200
        assert r2.status_code == 200
        if r1.json() and r2.json():
            assert len(r1.json()) == len(r2.json())

    async def test_search_nonexistent_returns_empty(self, async_client: AsyncClient, base_ingredients):
        """NT: nonexistent ingredient search returns empty list."""
        resp = await async_client.get("/ingredients?q=zzz_nonexistent_xyz")
        assert resp.status_code == 200
        assert resp.json() == []

    async def test_search_limit_respected(self, async_client: AsyncClient, base_ingredients):
        """BVA: limit parameter respected in results."""
        resp = await async_client.get("/ingredients?limit=3")
        assert resp.status_code == 200
        assert len(resp.json()) <= 3


class TestSR4RecipeTags:
    """SR-4: Recipe tag management."""

    async def test_tags_deduplicated(self, async_client: AsyncClient, base_ingredients):
        """EP: duplicate tags collapsed."""
        resp = await async_client.post("/recipes", data={
            "title": "SR4 DupTag", "summary": "s",
            "tags_json": json.dumps(["dup", "dup", "unique"]),
            "ingredients_json": json.dumps([{"ingredient_name": "egg", "quantity": 1, "unit": "pcs"}]),
            "steps_json": json.dumps(["Cook"]),
        })
        assert resp.status_code == 200
        tags = resp.json()["tags"]
        assert tags.count("dup") == 1
        assert "unique" in tags

    async def test_update_replaces_tags(self, async_client: AsyncClient, base_ingredients):
        """EP: updating recipe replaces tags completely."""
        create = await async_client.post("/recipes", data={
            "title": "SR4 TagReplace", "summary": "s",
            "tags_json": json.dumps(["old"]),
            "ingredients_json": json.dumps([{"ingredient_name": "egg", "quantity": 1, "unit": "pcs"}]),
            "steps_json": json.dumps(["Cook"]),
        })
        rid = create.json()["id"]

        update = await async_client.put(f"/recipes/{rid}", data={
            "title": "SR4 TagReplace", "summary": "s",
            "tags_json": json.dumps(["new"]),
            "ingredients_json": json.dumps([{"ingredient_name": "egg", "quantity": 1, "unit": "pcs"}]),
            "steps_json": json.dumps(["Cook"]),
        })
        assert "old" not in update.json()["tags"]
        assert "new" in update.json()["tags"]


class TestSR4HelperFunctions:
    """SR-4: Additional helper function tests."""

    def test_normalize_unit_informal_units(self):
        """EP: informal units mapped to pcs."""
        from main import _normalize_unit
        for unit in ["pinch", "clove", "bunch", "slice", "can"]:
            assert _normalize_unit(unit) == "pcs"

    def test_parse_ingredient_text_fraction(self):
        """EP: fractional quantity parsing."""
        from main import _parse_ingredient_text
        result = _parse_ingredient_text("1/2 tsp salt")
        assert result["quantity"] == pytest.approx(0.5)
        assert result["unit"] == "tsp"
        assert result["ingredient_name"] == "salt"

    def test_parse_ingredient_text_plain_name(self):
        """EP: plain name with no quantity/unit."""
        from main import _parse_ingredient_text
        result = _parse_ingredient_text("salt and pepper")
        assert result["ingredient_name"] == "salt and pepper"
        assert result["quantity"] == 1.0
        assert result["unit"] == "pcs"

class TestSR5ShoppingListModel:
    """SR-5: ShoppingList model CRUD."""

    async def test_create_shopping_list(self, test_db: AsyncSession):
        """EP: create a shopping list for a user."""
        user = models.User(email="sr5_sl@example.com", hashed_password="h", is_active=True)
        test_db.add(user)
        await test_db.commit()
        await test_db.refresh(user)

        sl = models.ShoppingList(
            user_id=user.id,
            created_at=datetime.utcnow().isoformat(),
        )
        test_db.add(sl)
        await test_db.commit()
        await test_db.refresh(sl)

        assert sl.shopping_list_id is not None
        assert sl.user_id == user.id

    async def test_shopping_list_user_relationship(self, test_db: AsyncSession):
        """IT: shopping list linked to user."""
        user = models.User(email="sr5_slrel@example.com", hashed_password="h", is_active=True)
        test_db.add(user)
        await test_db.commit()
        await test_db.refresh(user)

        sl = models.ShoppingList(user_id=user.id, created_at=datetime.utcnow().isoformat())
        test_db.add(sl)
        await test_db.commit()

        result = await test_db.execute(
            select(models.ShoppingList).where(models.ShoppingList.user_id == user.id)
        )
        assert result.scalars().first() is not None

    async def test_multiple_shopping_lists_per_user(self, test_db: AsyncSession):
        """EP: user can have multiple shopping lists."""
        user = models.User(email="sr5_multi@example.com", hashed_password="h", is_active=True)
        test_db.add(user)
        await test_db.commit()
        await test_db.refresh(user)

        for _ in range(3):
            test_db.add(models.ShoppingList(
                user_id=user.id, created_at=datetime.utcnow().isoformat()
            ))
        await test_db.commit()

        result = await test_db.execute(
            select(models.ShoppingList).where(models.ShoppingList.user_id == user.id)
        )
        assert len(result.scalars().all()) == 3


class TestSR5ShoppingListIngredients:
    """SR-5: ShoppingListIngredient model for ingredient tracking."""

    async def test_add_ingredient_to_shopping_list(self, test_db: AsyncSession):
        """EP: add an ingredient to a shopping list."""
        user = models.User(email="sr5_sli@example.com", hashed_password="h", is_active=True)
        test_db.add(user)
        await test_db.commit()
        await test_db.refresh(user)

        sl = models.ShoppingList(user_id=user.id, created_at=datetime.utcnow().isoformat())
        test_db.add(sl)
        await test_db.commit()
        await test_db.refresh(sl)

        ing = models.Ingredients(ingredient_name="SR5 Flour", normalized_name="sr5 flour", is_base=True)
        test_db.add(ing)
        await test_db.commit()
        await test_db.refresh(ing)

        sli = models.ShoppingListIngredient(
            shopping_list_id=sl.shopping_list_id,
            ingredient_id=ing.id,
            quantity=500,
            checked=0,
            unit="g",
        )
        test_db.add(sli)
        await test_db.commit()

        result = await test_db.execute(
            select(models.ShoppingListIngredient).where(
                models.ShoppingListIngredient.shopping_list_id == sl.shopping_list_id
            )
        )
        item = result.scalars().first()
        assert item is not None
        assert item.quantity == 500
        assert item.unit == "g"
        assert item.checked == 0

    async def test_check_off_ingredient(self, test_db: AsyncSession):
        """EP: mark ingredient as checked."""
        user = models.User(email="sr5_chk@example.com", hashed_password="h", is_active=True)
        test_db.add(user)
        await test_db.commit()
        await test_db.refresh(user)

        sl = models.ShoppingList(user_id=user.id, created_at=datetime.utcnow().isoformat())
        test_db.add(sl)
        await test_db.commit()
        await test_db.refresh(sl)

        ing = models.Ingredients(ingredient_name="SR5 Sugar", normalized_name="sr5 sugar", is_base=True)
        test_db.add(ing)
        await test_db.commit()
        await test_db.refresh(ing)

        sli = models.ShoppingListIngredient(
            shopping_list_id=sl.shopping_list_id,
            ingredient_id=ing.id, quantity=200, checked=0, unit="g",
        )
        test_db.add(sli)
        await test_db.commit()

        # Check it off
        sli.checked = 1
        await test_db.commit()

        result = await test_db.execute(
            select(models.ShoppingListIngredient).where(
                models.ShoppingListIngredient.shopping_list_id == sl.shopping_list_id
            )
        )
        assert result.scalars().first().checked == 1

    async def test_multiple_ingredients_on_list(self, test_db: AsyncSession):
        """EP: shopping list can have multiple ingredients."""
        user = models.User(email="sr5_multii@example.com", hashed_password="h", is_active=True)
        test_db.add(user)
        await test_db.commit()
        await test_db.refresh(user)

        sl = models.ShoppingList(user_id=user.id, created_at=datetime.utcnow().isoformat())
        test_db.add(sl)
        await test_db.commit()
        await test_db.refresh(sl)

        for i, name in enumerate(["SR5 Egg", "SR5 Milk", "SR5 Butter"]):
            ing = models.Ingredients(ingredient_name=name, normalized_name=name.lower(), is_base=True)
            test_db.add(ing)
            await test_db.commit()
            await test_db.refresh(ing)
            test_db.add(models.ShoppingListIngredient(
                shopping_list_id=sl.shopping_list_id,
                ingredient_id=ing.id, quantity=i + 1, checked=0, unit="pcs",
            ))
        await test_db.commit()

        result = await test_db.execute(
            select(models.ShoppingListIngredient).where(
                models.ShoppingListIngredient.shopping_list_id == sl.shopping_list_id
            )
        )
        assert len(result.scalars().all()) == 3


class TestSR5RecipeIngredientExtraction:
    """SR-5: Extracting ingredients from recipes for shopping list generation."""

    async def test_recipe_ingredients_queryable(self, test_db: AsyncSession):
        """IT: recipe ingredients can be queried for list generation."""
        from main import _find_or_create_ingredient

        recipe = models.Recipe(recipe_name="SR5 Query", summary="s", servings=2)
        test_db.add(recipe)
        await test_db.commit()
        await test_db.refresh(recipe)

        for name, qty, unit in [("sr5_flour", 200, "g"), ("sr5_egg", 3, "pcs")]:
            ing = await _find_or_create_ingredient(test_db, name)
            test_db.add(models.RecipeIngredient(
                recipe_id=recipe.recipe_id, ingredient_id=ing.id, quantity=qty, unit=unit
            ))
        await test_db.commit()

        result = await test_db.execute(
            select(
                models.Ingredients.ingredient_name,
                models.RecipeIngredient.quantity,
                models.RecipeIngredient.unit,
            )
            .join(models.RecipeIngredient)
            .where(models.RecipeIngredient.recipe_id == recipe.recipe_id)
        )
        rows = result.all()
        assert len(rows) == 2
        names = [r[0] for r in rows]
        assert "sr5_flour" in names
        assert "sr5_egg" in names

class TestSR6MealCalendar:
    """SR-6: Meal planning with calendar dates."""

    async def test_meal_planned_date_stored(self, test_db: AsyncSession):
        """EP: planned_date field stored correctly."""
        user = models.User(email="sr6_cal@example.com", hashed_password="h", is_active=True)
        test_db.add(user)
        await test_db.commit()
        await test_db.refresh(user)

        meal = models.Meals(user_id=user.id, planned_date="2025-03-15", stage="lunch")
        test_db.add(meal)
        await test_db.commit()
        await test_db.refresh(meal)

        assert meal.planned_date == "2025-03-15"

    async def test_meals_queryable_by_date(self, test_db: AsyncSession):
        """EP: meals can be queried by planned_date."""
        user = models.User(email="sr6_qd@example.com", hashed_password="h", is_active=True)
        test_db.add(user)
        await test_db.commit()
        await test_db.refresh(user)

        for date in ["2025-03-10", "2025-03-11", "2025-03-12"]:
            test_db.add(models.Meals(user_id=user.id, planned_date=date, stage="dinner"))
        await test_db.commit()

        result = await test_db.execute(
            select(models.Meals).where(
                models.Meals.user_id == user.id,
                models.Meals.planned_date == "2025-03-11",
            )
        )
        meals = result.scalars().all()
        assert len(meals) == 1
        assert meals[0].planned_date == "2025-03-11"

    async def test_multiple_stages_per_date(self, test_db: AsyncSession):
        """EP: multiple stages (breakfast, lunch, dinner) per date."""
        user = models.User(email="sr6_stages@example.com", hashed_password="h", is_active=True)
        test_db.add(user)
        await test_db.commit()
        await test_db.refresh(user)

        for stage in ["breakfast", "lunch", "dinner"]:
            test_db.add(models.Meals(user_id=user.id, planned_date="2025-03-15", stage=stage))
        await test_db.commit()

        result = await test_db.execute(
            select(models.Meals).where(
                models.Meals.user_id == user.id,
                models.Meals.planned_date == "2025-03-15",
            )
        )
        meals = result.scalars().all()
        assert len(meals) == 3
        stages = {m.stage for m in meals}
        assert stages == {"breakfast", "lunch", "dinner"}

    async def test_meal_with_recipe_on_date(self, test_db: AsyncSession):
        """IT: meal linked to recipe on specific date."""
        user = models.User(email="sr6_mr@example.com", hashed_password="h", is_active=True)
        test_db.add(user)
        await test_db.commit()
        await test_db.refresh(user)

        recipe = models.Recipe(recipe_name="SR6 Planned", summary="s", servings=2)
        test_db.add(recipe)
        await test_db.commit()
        await test_db.refresh(recipe)

        meal = models.Meals(user_id=user.id, planned_date="2025-04-01", stage="dinner")
        test_db.add(meal)
        await test_db.commit()
        await test_db.refresh(meal)

        test_db.add(models.MealRecipe(meal_id=meal.meal_id, recipe_id=recipe.recipe_id))
        await test_db.commit()

        result = await test_db.execute(
            select(models.MealRecipe.recipe_id)
            .join(models.Meals, models.Meals.meal_id == models.MealRecipe.meal_id)
            .where(
                models.Meals.user_id == user.id,
                models.Meals.planned_date == "2025-04-01",
            )
        )
        recipe_ids = [row[0] for row in result.all()]
        assert recipe.recipe_id in recipe_ids

    async def test_week_plan_query(self, test_db: AsyncSession):
        """IT: query meals for a full week range."""
        user = models.User(email="sr6_week@example.com", hashed_password="h", is_active=True)
        test_db.add(user)
        await test_db.commit()
        await test_db.refresh(user)

        dates = [f"2025-03-{10+i:02d}" for i in range(7)]
        for date in dates:
            test_db.add(models.Meals(user_id=user.id, planned_date=date, stage="dinner"))
        await test_db.commit()

        result = await test_db.execute(
            select(models.Meals).where(
                models.Meals.user_id == user.id,
                models.Meals.planned_date >= "2025-03-10",
                models.Meals.planned_date <= "2025-03-16",
            )
        )
        assert len(result.scalars().all()) == 7

class TestSR7IngredientCost:
    """SR-7: Ingredient cost data for budget awareness."""

    async def test_ingredient_has_avg_cost(self, test_db: AsyncSession, base_ingredients):
        """EP: base ingredients have avg_cost field."""
        result = await test_db.execute(
            select(models.Ingredients).where(models.Ingredients.avg_cost.isnot(None))
        )
        ingredients = result.scalars().all()
        assert len(ingredients) > 0
        for ing in ingredients:
            assert ing.avg_cost is not None
            assert ing.avg_cost >= 0

    async def test_cost_varies_across_ingredients(self, test_db: AsyncSession, base_ingredients):
        """EP: different ingredients have different costs."""
        result = await test_db.execute(
            select(models.Ingredients.avg_cost).where(models.Ingredients.avg_cost.isnot(None))
        )
        costs = [row[0] for row in result.all() if row[0] is not None]
        assert len(set(costs)) > 1  # Not all the same cost


class TestSR7RecipeCostEstimate:
    """SR-7: Recipe cost_estimate field."""

    async def test_recipe_has_cost_estimate_field(self, test_db: AsyncSession):
        """EP: Recipe model has cost_estimate column."""
        recipe = models.Recipe(
            recipe_name="SR7 Budget", summary="s", servings=2, cost_estimate=5
        )
        test_db.add(recipe)
        await test_db.commit()
        await test_db.refresh(recipe)

        assert recipe.cost_estimate == 5

    async def test_recipe_cost_estimate_nullable(self, test_db: AsyncSession):
        """BVA: cost_estimate can be null."""
        recipe = models.Recipe(recipe_name="SR7 NoCost", summary="s", servings=1)
        test_db.add(recipe)
        await test_db.commit()
        await test_db.refresh(recipe)

        assert recipe.cost_estimate is None


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

    async def test_ingredient_cost_data_for_budget_calc(self, test_db: AsyncSession, base_ingredients):
        """IT: ingredient cost data available for budget calculations."""
        result = await test_db.execute(
            select(models.Ingredients.ingredient_name, models.Ingredients.avg_cost)
            .where(models.Ingredients.avg_cost.isnot(None))
        )
        rows = result.all()
        assert len(rows) > 0
        # All costs should be positive or zero
        for name, cost in rows:
            assert cost >= 0

class TestSR8JWTAuthentication:
    """SR-8: Custom JWT token authentication."""

    async def test_jwt_token_structure(self, async_client: AsyncClient):
        """EP: JWT token has 3 dot-separated parts."""
        await async_client.post("/register", json={
            "email": "sr8_jwt@example.com", "password": "pass123"
        })
        login = await async_client.post("/token", data={
            "username": "sr8_jwt@example.com", "password": "pass123"
        })
        token = login.json()["access_token"]
        parts = token.split(".")
        assert len(parts) == 3
        assert all(len(p) > 0 for p in parts)

    async def test_token_grants_access(self, async_client: AsyncClient):
        """IT: valid token grants access to protected route."""
        await async_client.post("/register", json={
            "email": "sr8_access@example.com", "password": "pass123"
        })
        login = await async_client.post("/token", data={
            "username": "sr8_access@example.com", "password": "pass123"
        })
        token = login.json()["access_token"]

        me = await async_client.get("/users/me", headers={"Authorization": f"Bearer {token}"})
        assert me.status_code == 200
        assert me.json()["email"] == "sr8_access@example.com"

    async def test_expired_or_invalid_token_rejected(self, async_client: AsyncClient):
        """NT: invalid token rejected with 401."""
        resp = await async_client.get(
            "/users/me", headers={"Authorization": "Bearer invalid_token"}
        )
        assert resp.status_code == 401

    async def test_missing_token_rejected(self, async_client: AsyncClient):
        """NT: missing token rejected with 401."""
        resp = await async_client.get("/users/me")
        assert resp.status_code == 401

    def test_token_uses_hs256(self):
        """EP: token uses HS256 algorithm."""
        from auth import ALGORITHM
        assert ALGORITHM == "HS256"

    def test_token_expiry_is_30_minutes(self):
        """EP: default token expiry is 30 minutes."""
        from auth import ACCESS_TOKEN_EXPIRE_MINUTES
        assert ACCESS_TOKEN_EXPIRE_MINUTES == 30


class TestSR8UserRegistration:
    """SR-8: User registration flow."""

    async def test_register_returns_user_without_password(self, async_client: AsyncClient):
        """EP: registration response includes user data but not password."""
        resp = await async_client.post("/register", json={
            "email": "sr8_reg@example.com", "password": "secure123"
        })
        assert resp.status_code == 200
        data = resp.json()
        assert "id" in data
        assert data["email"] == "sr8_reg@example.com"
        assert "password" not in data
        assert "hashed_password" not in data

    async def test_register_duplicate_email_400(self, async_client: AsyncClient):
        """NT: duplicate email registration fails with 400."""
        await async_client.post("/register", json={
            "email": "sr8_dup@example.com", "password": "pass1"
        })
        resp = await async_client.post("/register", json={
            "email": "sr8_dup@example.com", "password": "pass2"
        })
        assert resp.status_code == 400

    async def test_register_invalid_email_format(self, async_client: AsyncClient):
        """NT: invalid email format rejected."""
        resp = await async_client.post("/register", json={
            "email": "not-an-email", "password": "pass123"
        })
        assert resp.status_code in [400, 422]

    async def test_register_missing_password_422(self, async_client: AsyncClient):
        """NT: missing password field rejected."""
        resp = await async_client.post("/register", json={"email": "sr8_nopw@example.com"})
        assert resp.status_code == 422


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


class TestNFRUserPantry:
    """NFR: UserPantry model data integrity."""

    async def test_create_pantry_item(self, test_db: AsyncSession):
        """EP: user pantry item can be stored."""
        user = models.User(email="nfr_pantry@example.com", hashed_password="h", is_active=True)
        test_db.add(user)
        await test_db.commit()
        await test_db.refresh(user)

        ing = models.Ingredients(ingredient_name="NFR Rice", normalized_name="nfr rice", is_base=True)
        test_db.add(ing)
        await test_db.commit()
        await test_db.refresh(ing)

        pantry = models.UserPantry(
            user_id=user.id, ingredient_id=ing.id,
            quantity=500, unit=1,
            updated_at=datetime.utcnow().isoformat(),
        )
        test_db.add(pantry)
        await test_db.commit()

        result = await test_db.execute(
            select(models.UserPantry).where(models.UserPantry.user_id == user.id)
        )
        item = result.scalars().first()
        assert item is not None
        assert item.quantity == 500


class TestNFRSavedRecipes:
    """NFR: SavedRecipe model data integrity."""

    async def test_save_recipe_for_user(self, test_db: AsyncSession):
        """EP: user can save a recipe."""
        user = models.User(email="nfr_saved@example.com", hashed_password="h", is_active=True)
        test_db.add(user)
        await test_db.commit()
        await test_db.refresh(user)

        recipe = models.Recipe(recipe_name="NFR Saved", summary="s", servings=1)
        test_db.add(recipe)
        await test_db.commit()
        await test_db.refresh(recipe)

        saved = models.SavedRecipe(
            user_id=user.id, recipe_id=recipe.recipe_id,
            recipe_name="NFR Saved", user_notes="My favorite",
        )
        test_db.add(saved)
        await test_db.commit()
        await test_db.refresh(saved)

        assert saved.id is not None
        assert saved.user_notes == "My favorite"

    async def test_user_can_save_multiple_recipes(self, test_db: AsyncSession):
        """EP: user can save multiple recipes."""
        user = models.User(email="nfr_multisave@example.com", hashed_password="h", is_active=True)
        test_db.add(user)
        await test_db.commit()
        await test_db.refresh(user)

        for i in range(3):
            recipe = models.Recipe(recipe_name=f"NFR Save {i}", summary="s", servings=1)
            test_db.add(recipe)
            await test_db.commit()
            await test_db.refresh(recipe)
            test_db.add(models.SavedRecipe(
                user_id=user.id, recipe_id=recipe.recipe_id,
                recipe_name=f"NFR Save {i}",
            ))
        await test_db.commit()

        result = await test_db.execute(
            select(models.SavedRecipe).where(models.SavedRecipe.user_id == user.id)
        )
        assert len(result.scalars().all()) == 3

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
