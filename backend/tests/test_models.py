"""
Model-level tests for database models and direct data operations.

Covers:
  - SR-1: Meals, MealRecipe, recipe_feedback models
  - SR-2: Preference, UserPreference models
  - SR-3: Nutrition calculation via direct function calls
  - SR-5: ShoppingList, ShoppingListIngredient models
  - SR-6: Meal calendar and planning
  - SR-7: Ingredient cost and recipe cost_estimate
  - NFR:  UserPantry, SavedRecipe model integrity
"""

import json
import pytest
from datetime import datetime
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

import models


# ── helpers ──────────────────────────────────────────────────────────────────

async def _make_user(db: AsyncSession, email: str) -> "models.User":
    from main import create_user
    import schemas
    return await create_user(
        user=schemas.UserCreate(email=email, password="pass"), db=db
    )


async def _make_recipe(db: AsyncSession, name: str = "Plan Recipe") -> "models.Recipe":
    recipe = models.Recipe(recipe_name=name, summary="test", servings=2)
    db.add(recipe)
    await db.commit()
    await db.refresh(recipe)
    return recipe


# ── SR-1: Meals model CRUD ───────────────────────────────────────────────────

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


# ── SR-1: Meal-recipe association ─────────────────────────────────────────────

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


# ── SR-1: Recipe feedback ────────────────────────────────────────────────────

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


# ── SR-1: Meal suggestion filtering ──────────────────────────────────────────

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


# ── SR-1: Additional invalid/boundary ─────────────────────────────────────────

class TestSR1AdditionalInvalid:
    @pytest.mark.asyncio
    async def test_disliked_feedback_tracked_for_reroll(self, test_db: AsyncSession):
        """NT: disliked (liked=0) recipe feedback stored and queryable."""
        user = models.User(email="sr1_add1@example.com", hashed_password="h", is_active=True)
        test_db.add(user); await test_db.commit(); await test_db.refresh(user)
        recipe = models.Recipe(recipe_name="SR1 Dislike", summary="s", servings=1)
        test_db.add(recipe); await test_db.commit(); await test_db.refresh(recipe)
        fb = models.recipe_feedback(
            user_id=user.id, recipe_id=recipe.recipe_id,
            rating=1, liked=0, created_at=datetime.utcnow().isoformat()
        )
        test_db.add(fb); await test_db.commit()
        result = await test_db.execute(
            select(models.recipe_feedback).where(
                models.recipe_feedback.user_id == user.id,
                models.recipe_feedback.liked == 0
            )
        )
        assert len(result.scalars().all()) == 1

    @pytest.mark.asyncio
    async def test_no_meals_for_new_user(self, test_db: AsyncSession):
        """NT: new user with no meals returns empty suggestion pool."""
        user = models.User(email="sr1_add2@example.com", hashed_password="h", is_active=True)
        test_db.add(user); await test_db.commit(); await test_db.refresh(user)
        result = await test_db.execute(
            select(models.Meals).where(models.Meals.user_id == user.id)
        )
        assert result.scalars().all() == []

    @pytest.mark.asyncio
    async def test_all_deleted_recipes_empty_pool(self, test_db: AsyncSession):
        """NT: all recipes soft-deleted → suggestion pool empty."""
        for name in ["Del1", "Del2", "Del3"]:
            test_db.add(models.Recipe(recipe_name=name, summary="s", servings=1, is_deleted=True))
        await test_db.commit()
        result = await test_db.execute(
            select(models.Recipe).where(models.Recipe.is_deleted != True)
        )
        assert result.scalars().all() == []


# ── SR-2: Preference model ───────────────────────────────────────────────────

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


# ── SR-2: User preference association ─────────────────────────────────────────

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


# ── SR-2: Additional invalid/boundary (model-level) ──────────────────────────

class TestSR2AdditionalInvalidModel:
    @pytest.mark.asyncio
    async def test_duplicate_preference_link_handled(self, test_db: AsyncSession):
        """NT: linking same preference to same user twice handled gracefully."""
        user = models.User(email="sr2_add1@example.com", hashed_password="h", is_active=True)
        test_db.add(user); await test_db.commit(); await test_db.refresh(user)
        pref = models.Preference(preference_name="NutFreeDup", like=1)
        test_db.add(pref); await test_db.commit(); await test_db.refresh(pref)
        test_db.add(models.UserPreference(user_id=user.id, preference_id=pref.preference_id))
        await test_db.commit()
        test_db.add(models.UserPreference(user_id=user.id, preference_id=pref.preference_id))
        try:
            await test_db.commit()
        except Exception:
            await test_db.rollback()
        result = await test_db.execute(
            select(models.UserPreference).where(models.UserPreference.user_id == user.id)
        )
        assert len(result.scalars().all()) >= 1  # no unhandled crash


# ── SR-3: Nutrition calculation ───────────────────────────────────────────────

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


# ── SR-3: Base ingredient data ────────────────────────────────────────────────

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


# ── SR-5: Shopping list model ─────────────────────────────────────────────────

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


# ── SR-5: Shopping list ingredients ───────────────────────────────────────────

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


# ── SR-5: Recipe ingredient extraction ────────────────────────────────────────

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


# ── SR-5: Invalid/boundary ────────────────────────────────────────────────────

class TestSR5InvalidBoundary:
    @pytest.mark.asyncio
    async def test_zero_quantity_boundary(self, test_db: AsyncSession):
        """BVA: zero quantity accepted at model level."""
        user = models.User(email="sr5_inv1@example.com", hashed_password="h", is_active=True)
        test_db.add(user); await test_db.commit(); await test_db.refresh(user)
        sl = models.ShoppingList(user_id=user.id, created_at=datetime.utcnow().isoformat())
        test_db.add(sl); await test_db.commit(); await test_db.refresh(sl)
        ing = models.Ingredients(ingredient_name="SR5 Zero", normalized_name="sr5 zero", is_base=True)
        test_db.add(ing); await test_db.commit(); await test_db.refresh(ing)
        sli = models.ShoppingListIngredient(
            shopping_list_id=sl.shopping_list_id,
            ingredient_id=ing.id, quantity=0, checked=0, unit="g"
        )
        test_db.add(sli); await test_db.commit()
        result = await test_db.execute(
            select(models.ShoppingListIngredient).where(
                models.ShoppingListIngredient.shopping_list_id == sl.shopping_list_id
            )
        )
        assert result.scalars().first().quantity == 0

    @pytest.mark.asyncio
    async def test_negative_quantity(self, test_db: AsyncSession):
        """NT: negative quantity stored at model level (no HTTP validation layer)."""
        user = models.User(email="sr5_inv2@example.com", hashed_password="h", is_active=True)
        test_db.add(user); await test_db.commit(); await test_db.refresh(user)
        sl = models.ShoppingList(user_id=user.id, created_at=datetime.utcnow().isoformat())
        test_db.add(sl); await test_db.commit(); await test_db.refresh(sl)
        ing = models.Ingredients(ingredient_name="SR5 Neg", normalized_name="sr5 neg", is_base=True)
        test_db.add(ing); await test_db.commit(); await test_db.refresh(ing)
        sli = models.ShoppingListIngredient(
            shopping_list_id=sl.shopping_list_id,
            ingredient_id=ing.id, quantity=-1, checked=0, unit="g"
        )
        test_db.add(sli); await test_db.commit()
        result = await test_db.execute(
            select(models.ShoppingListIngredient).where(
                models.ShoppingListIngredient.shopping_list_id == sl.shopping_list_id
            )
        )
        assert result.scalars().first().quantity == -1

    @pytest.mark.asyncio
    async def test_user_with_no_list_returns_empty(self, test_db: AsyncSession):
        """NT: querying shopping lists for a user who has none."""
        user = models.User(email="sr5_inv3@example.com", hashed_password="h", is_active=True)
        test_db.add(user); await test_db.commit(); await test_db.refresh(user)
        result = await test_db.execute(
            select(models.ShoppingList).where(models.ShoppingList.user_id == user.id)
        )
        assert result.scalars().all() == []

    @pytest.mark.asyncio
    async def test_empty_shopping_list_has_no_ingredients(self, test_db: AsyncSession):
        """BVA: newly created list with no ingredients added returns empty."""
        user = models.User(email="sr5_inv4@example.com", hashed_password="h", is_active=True)
        test_db.add(user); await test_db.commit(); await test_db.refresh(user)
        sl = models.ShoppingList(user_id=user.id, created_at=datetime.utcnow().isoformat())
        test_db.add(sl); await test_db.commit(); await test_db.refresh(sl)
        result = await test_db.execute(
            select(models.ShoppingListIngredient).where(
                models.ShoppingListIngredient.shopping_list_id == sl.shopping_list_id
            )
        )
        assert result.scalars().all() == []

    @pytest.mark.asyncio
    async def test_duplicate_ingredient_creates_two_rows(self, test_db: AsyncSession):
        """NT: same ingredient added twice creates two separate rows (not auto-merged)."""
        user = models.User(email="sr5_inv5@example.com", hashed_password="h", is_active=True)
        test_db.add(user); await test_db.commit(); await test_db.refresh(user)
        sl = models.ShoppingList(user_id=user.id, created_at=datetime.utcnow().isoformat())
        test_db.add(sl); await test_db.commit(); await test_db.refresh(sl)
        ing = models.Ingredients(ingredient_name="SR5 Dup", normalized_name="sr5 dup", is_base=True)
        test_db.add(ing); await test_db.commit(); await test_db.refresh(ing)
        for qty in [100, 200]:
            test_db.add(models.ShoppingListIngredient(
                shopping_list_id=sl.shopping_list_id,
                ingredient_id=ing.id, quantity=qty, checked=0, unit="g"
            ))
        await test_db.commit()
        result = await test_db.execute(
            select(models.ShoppingListIngredient).where(
                models.ShoppingListIngredient.shopping_list_id == sl.shopping_list_id
            )
        )
        assert len(result.scalars().all()) == 2


# ── SR-6: Meal calendar ──────────────────────────────────────────────────────

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


# ── SR-6: Additional invalid/boundary ─────────────────────────────────────────

class TestSR6AdditionalInvalid:
    @pytest.mark.asyncio
    async def test_query_date_with_no_meals_returns_empty(self, test_db: AsyncSession):
        """NT: querying a date with no planned meals returns empty."""
        user = models.User(email="sr6_add1@example.com", hashed_password="h", is_active=True)
        test_db.add(user); await test_db.commit(); await test_db.refresh(user)
        result = await test_db.execute(
            select(models.Meals).where(
                models.Meals.user_id == user.id,
                models.Meals.planned_date == "2026-01-15"
            )
        )
        assert result.scalars().all() == []

    @pytest.mark.asyncio
    async def test_far_future_date_accepted(self, test_db: AsyncSession):
        """BVA: far-future date (2030-12-31) accepted at model level."""
        user = models.User(email="sr6_add2@example.com", hashed_password="h", is_active=True)
        test_db.add(user); await test_db.commit(); await test_db.refresh(user)
        meal = models.Meals(user_id=user.id, planned_date="2030-12-31", stage="dinner")
        test_db.add(meal); await test_db.commit(); await test_db.refresh(meal)
        assert meal.meal_id is not None
        assert meal.planned_date == "2030-12-31"

    @pytest.mark.asyncio
    async def test_week_range_no_meals_returns_empty(self, test_db: AsyncSession):
        """NT: date range with no meals in that window returns empty."""
        user = models.User(email="sr6_add3@example.com", hashed_password="h", is_active=True)
        test_db.add(user); await test_db.commit(); await test_db.refresh(user)
        test_db.add(models.Meals(user_id=user.id, planned_date="2025-01-01", stage="lunch"))
        await test_db.commit()
        result = await test_db.execute(
            select(models.Meals).where(
                models.Meals.user_id == user.id,
                models.Meals.planned_date >= "2026-06-01",
                models.Meals.planned_date <= "2026-06-07"
            )
        )
        assert result.scalars().all() == []


# ── SR-7: Ingredient cost ────────────────────────────────────────────────────

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
        assert len(set(costs)) > 1


# ── SR-7: Recipe cost estimate ────────────────────────────────────────────────

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


# ── SR-6: Meal model persistence (additional) ────────────────────────────────

class TestMealModelPersistence:
    """SR-6: Meals rows can be created and queried correctly."""

    async def test_create_meal_persists(self, test_db: AsyncSession):
        user = await _make_user(test_db, "meal_persist@example.com")
        meal = models.Meals(user_id=user.id, planned_date="2026-06-01", stage="Dinner")
        test_db.add(meal)
        await test_db.commit()
        await test_db.refresh(meal)

        result = await test_db.execute(select(models.Meals).where(models.Meals.meal_id == meal.meal_id))
        fetched = result.scalars().first()
        assert fetched is not None
        assert fetched.planned_date == "2026-06-01"
        assert fetched.stage == "Dinner"

    async def test_meal_linked_to_correct_user(self, test_db: AsyncSession):
        user = await _make_user(test_db, "meal_user@example.com")
        meal = models.Meals(user_id=user.id, planned_date="2026-06-02", stage="Lunch")
        test_db.add(meal)
        await test_db.commit()
        await test_db.refresh(meal)

        result = await test_db.execute(
            select(models.Meals).where(models.Meals.user_id == user.id)
        )
        meals = result.scalars().all()
        assert any(me.meal_id == meal.meal_id for me in meals)

    async def test_meal_stage_values(self, test_db: AsyncSession):
        user = await _make_user(test_db, "meal_stages@example.com")
        for stage in ("Breakfast", "Lunch", "Dinner"):
            test_db.add(models.Meals(user_id=user.id, planned_date="2026-06-03", stage=stage))
        await test_db.commit()

        result = await test_db.execute(
            select(models.Meals).where(models.Meals.user_id == user.id)
        )
        stages = {me.stage for me in result.scalars().all()}
        assert stages == {"Breakfast", "Lunch", "Dinner"}

    async def test_multiple_meals_different_dates(self, test_db: AsyncSession):
        user = await _make_user(test_db, "meal_dates@example.com")
        dates = ["2026-06-01", "2026-06-02", "2026-06-03", "2026-06-04", "2026-06-05",
                 "2026-06-06", "2026-06-07"]
        for d in dates:
            test_db.add(models.Meals(user_id=user.id, planned_date=d, stage="Dinner"))
        await test_db.commit()

        result = await test_db.execute(
            select(models.Meals).where(models.Meals.user_id == user.id)
        )
        stored_dates = {me.planned_date for me in result.scalars().all()}
        assert stored_dates == set(dates)

    async def test_multiple_meals_same_date(self, test_db: AsyncSession):
        """Multiple meal slots (Breakfast + Lunch + Dinner) on one day."""
        user = await _make_user(test_db, "meal_same_day@example.com")
        for stage in ("Breakfast", "Lunch", "Dinner"):
            test_db.add(models.Meals(user_id=user.id, planned_date="2026-06-10", stage=stage))
        await test_db.commit()

        result = await test_db.execute(
            select(models.Meals).where(
                models.Meals.user_id == user.id,
                models.Meals.planned_date == "2026-06-10",
            )
        )
        assert len(result.scalars().all()) == 3


# ── SR-6: Meal-recipe association (additional) ───────────────────────────────

class TestMealRecipeAssociation:
    """SR-6: Recipes can be linked to meal slots via MealRecipe."""

    async def test_link_recipe_to_meal(self, test_db: AsyncSession):
        user = await _make_user(test_db, "meal_link@example.com")
        recipe = await _make_recipe(test_db, "Linked Recipe")
        meal = models.Meals(user_id=user.id, planned_date="2026-06-01", stage="Lunch")
        test_db.add(meal)
        await test_db.commit()
        await test_db.refresh(meal)

        link = models.MealRecipe(meal_id=meal.meal_id, recipe_id=recipe.recipe_id)
        test_db.add(link)
        await test_db.commit()

        result = await test_db.execute(
            select(models.MealRecipe).where(models.MealRecipe.meal_id == meal.meal_id)
        )
        links = result.scalars().all()
        assert len(links) == 1
        assert links[0].recipe_id == recipe.recipe_id

    async def test_multiple_recipes_linked_to_one_meal(self, test_db: AsyncSession):
        user = await _make_user(test_db, "meal_multi_recipe@example.com")
        r1 = await _make_recipe(test_db, "Recipe A")
        r2 = await _make_recipe(test_db, "Recipe B")
        meal = models.Meals(user_id=user.id, planned_date="2026-06-05", stage="Dinner")
        test_db.add(meal)
        await test_db.commit()
        await test_db.refresh(meal)

        for r in (r1, r2):
            test_db.add(models.MealRecipe(meal_id=meal.meal_id, recipe_id=r.recipe_id))
        await test_db.commit()

        result = await test_db.execute(
            select(models.MealRecipe).where(models.MealRecipe.meal_id == meal.meal_id)
        )
        assert len(result.scalars().all()) == 2

    async def test_same_recipe_linked_to_multiple_meals(self, test_db: AsyncSession):
        user = await _make_user(test_db, "recipe_multi_meal@example.com")
        recipe = await _make_recipe(test_db, "Reused Recipe")

        meal_ids = []
        for d, stage in [("2026-06-01", "Lunch"), ("2026-06-03", "Dinner")]:
            meal = models.Meals(user_id=user.id, planned_date=d, stage=stage)
            test_db.add(meal)
            await test_db.commit()
            await test_db.refresh(meal)
            meal_ids.append(meal.meal_id)

        for mid in meal_ids:
            test_db.add(models.MealRecipe(meal_id=mid, recipe_id=recipe.recipe_id))
        await test_db.commit()

        result = await test_db.execute(
            select(models.MealRecipe).where(models.MealRecipe.recipe_id == recipe.recipe_id)
        )
        assert len(result.scalars().all()) == 2


# ── SR-6: Week view ──────────────────────────────────────────────────────────

class TestMealPlanningWeekView:
    """SR-6: week-level planning — querying meals across a date range."""

    async def test_query_meals_for_week(self, test_db: AsyncSession):
        user = await _make_user(test_db, "meal_week@example.com")
        week = [f"2026-06-{d:02d}" for d in range(9, 16)]
        for d in week:
            test_db.add(models.Meals(user_id=user.id, planned_date=d, stage="Dinner"))
        await test_db.commit()

        result = await test_db.execute(
            select(models.Meals).where(
                models.Meals.user_id == user.id,
                models.Meals.planned_date >= "2026-06-09",
                models.Meals.planned_date <= "2026-06-15",
            )
        )
        assert len(result.scalars().all()) == 7

    async def test_meals_outside_week_not_returned(self, test_db: AsyncSession):
        user = await _make_user(test_db, "meal_outside@example.com")
        test_db.add(models.Meals(user_id=user.id, planned_date="2026-05-01", stage="Lunch"))
        test_db.add(models.Meals(user_id=user.id, planned_date="2026-06-09", stage="Dinner"))
        await test_db.commit()

        result = await test_db.execute(
            select(models.Meals).where(
                models.Meals.user_id == user.id,
                models.Meals.planned_date >= "2026-06-09",
                models.Meals.planned_date <= "2026-06-15",
            )
        )
        dates = [me.planned_date for me in result.scalars().all()]
        assert "2026-05-01" not in dates
        assert "2026-06-09" in dates

    async def test_user_meal_isolation(self, test_db: AsyncSession):
        """Meals for user A must not appear in queries for user B."""
        user_a = await _make_user(test_db, "meal_iso_a@example.com")
        user_b = await _make_user(test_db, "meal_iso_b@example.com")

        test_db.add(models.Meals(user_id=user_a.id, planned_date="2026-06-01", stage="Lunch"))
        test_db.add(models.Meals(user_id=user_b.id, planned_date="2026-06-01", stage="Dinner"))
        await test_db.commit()

        result = await test_db.execute(
            select(models.Meals).where(models.Meals.user_id == user_a.id)
        )
        meals = result.scalars().all()
        assert all(me.user_id == user_a.id for me in meals)
        assert len(meals) == 1


# ── SR-6: Cascade delete ─────────────────────────────────────────────────────

class TestMealCascadeDelete:
    """SR-6: deleting a user cascade-deletes their meal plans."""

    async def test_user_delete_removes_meals(self, test_db: AsyncSession):
        user = await _make_user(test_db, "meal_cascade@example.com")
        user_id = user.id
        for d in ("2026-06-01", "2026-06-02"):
            test_db.add(models.Meals(user_id=user_id, planned_date=d, stage="Dinner"))
        await test_db.commit()

        await test_db.delete(user)
        await test_db.commit()

        result = await test_db.execute(
            select(models.Meals).where(models.Meals.user_id == user_id)
        )
        assert result.scalars().all() == []


# ── SR-6: Boundary ───────────────────────────────────────────────────────────

class TestMealBoundary:
    """SR-6: boundary and equivalence cases for meal planning."""

    async def test_meal_with_no_stage(self, test_db: AsyncSession):
        user = await _make_user(test_db, "meal_no_stage@example.com")
        meal = models.Meals(user_id=user.id, planned_date="2026-06-01", stage=None)
        test_db.add(meal)
        await test_db.commit()
        await test_db.refresh(meal)
        assert meal.meal_id is not None

    async def test_meal_boundary_dates(self, test_db: AsyncSession):
        user = await _make_user(test_db, "meal_boundary@example.com")
        for date in ("2026-01-01", "2026-12-31"):
            test_db.add(models.Meals(user_id=user.id, planned_date=date, stage="Dinner"))
        await test_db.commit()

        result = await test_db.execute(
            select(models.Meals).where(models.Meals.user_id == user.id)
        )
        dates = {me.planned_date for me in result.scalars().all()}
        assert "2026-01-01" in dates
        assert "2026-12-31" in dates

    async def test_meal_with_linked_recipe_has_correct_ids(self, test_db: AsyncSession):
        user = await _make_user(test_db, "meal_ids@example.com")
        recipe = await _make_recipe(test_db, "ID Check Recipe")
        meal = models.Meals(user_id=user.id, planned_date="2026-07-04", stage="Dinner")
        test_db.add(meal)
        await test_db.commit()
        await test_db.refresh(meal)

        link = models.MealRecipe(meal_id=meal.meal_id, recipe_id=recipe.recipe_id)
        test_db.add(link)
        await test_db.commit()

        result = await test_db.execute(
            select(models.MealRecipe).where(models.MealRecipe.meal_id == meal.meal_id)
        )
        fetched = result.scalars().first()
        assert fetched.meal_id == meal.meal_id
        assert fetched.recipe_id == recipe.recipe_id


# ── NFR: UserPantry model ────────────────────────────────────────────────────

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


# ── NFR: SavedRecipe model ───────────────────────────────────────────────────

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
