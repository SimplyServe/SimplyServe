"""
Direct async function call tests.

Python 3.13 + coverage 7.x has a known issue where lines inside async
coroutines executed via ASGI transport are not attributed by sys.monitoring.
Calling the functions directly from pytest-asyncio tests does get traced.
"""

import json
import pytest
from sqlalchemy.ext.asyncio import AsyncSession

import models


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
        import schemas

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
