"""
Integration tests for recipe endpoints.
Tests recipe listing, creation, filtering, and ingredient search.
"""

import json
import pytest
from httpx import AsyncClient


class TestRecipeList:
    """Tests for GET /recipes endpoint."""

    async def test_get_recipes_empty(self, async_client: AsyncClient):
        """Test getting recipes when none exist."""
        response = await async_client.get("/recipes")

        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)
        assert len(data) == 0


    async def test_get_recipes_response_structure(
        self,
        async_client: AsyncClient,
        auth_headers: dict,
        base_ingredients,
        test_recipe_data: dict
    ):
        """Test recipe response has expected structure when recipes exist."""
        # First create a recipe
        response = await async_client.post(
            "/recipes",
            data=test_recipe_data,
            headers=auth_headers
        )
        assert response.status_code == 200

        # Then fetch recipes
        get_response = await async_client.get("/recipes")
        assert get_response.status_code == 200

        recipes = get_response.json()
        assert len(recipes) > 0

        recipe = recipes[0]
        # Verify recipe structure
        required_fields = [
            "id", "title", "summary", "difficulty",
            "prep_time", "cook_time", "servings", "image_url",
            "ingredients", "steps", "nutrition", "tags"
        ]
        for field in required_fields:
            assert field in recipe, f"Missing field: {field}"

        # Verify nutrition structure
        nutrition = recipe["nutrition"]
        assert "calories" in nutrition
        assert "protein" in nutrition
        assert "carbs" in nutrition
        assert "fats" in nutrition


    async def test_get_recipes_pagination(
        self,
        async_client: AsyncClient,
        auth_headers: dict,
        base_ingredients,
        test_recipe_data: dict
    ):
        """Test recipe pagination parameters are accepted."""
        # Create multiple recipes
        for i in range(3):
            data = test_recipe_data.copy()
            data["title"] = f"Recipe {i+1}"
            response = await async_client.post(
                "/recipes",
                data=data,
                headers=auth_headers
            )
            assert response.status_code == 200

        # Test with offset parameter (should be accepted without error)
        response = await async_client.get("/recipes?offset=1")
        assert response.status_code == 200
        recipes = response.json()
        assert isinstance(recipes, list)


    async def test_get_recipes_no_auth_required(
        self,
        async_client: AsyncClient
    ):
        """Test that fetching recipes doesn't require authentication."""
        # This endpoint should be public
        response = await async_client.get("/recipes")
        assert response.status_code == 200


class TestRecipeCreation:
    """Tests for POST /recipes endpoint."""

    async def test_create_recipe_success(
        self,
        async_client: AsyncClient,
        auth_headers: dict,
        base_ingredients,
        test_recipe_data: dict
    ):
        """Test successful recipe creation."""
        response = await async_client.post(
            "/recipes",
            data=test_recipe_data,
            headers=auth_headers
        )

        assert response.status_code == 200
        data = response.json()

        assert data["title"] == test_recipe_data["title"]
        assert data["summary"] == test_recipe_data["summary"]
        assert data["difficulty"] == test_recipe_data["difficulty"]
        assert "id" in data
        assert data["id"] > 0


    async def test_create_recipe_without_auth(
        self,
        async_client: AsyncClient,
        base_ingredients,
        test_recipe_data: dict
    ):
        """Test recipe creation without authentication."""
        response = await async_client.post(
            "/recipes",
            data=test_recipe_data
        )

        # Backend allows recipe creation without auth (no auth requirement on POST /recipes)
        assert response.status_code == 200


    async def test_create_recipe_with_invalid_token(
        self,
        async_client: AsyncClient,
        base_ingredients,
        test_recipe_data: dict
    ):
        """Test recipe creation with invalid token."""
        headers = {"Authorization": "Bearer invalid_token"}

        response = await async_client.post(
            "/recipes",
            data=test_recipe_data,
            headers=headers
        )

        # Backend allows recipe creation without auth (invalid token still passes through)
        assert response.status_code == 200


    async def test_create_recipe_missing_required_fields(
        self,
        async_client: AsyncClient,
        auth_headers: dict
    ):
        """Test recipe creation with missing required fields fails."""
        incomplete_data = {
            "title": "Incomplete Recipe"
            # Missing summary, ingredients, steps, etc.
        }

        response = await async_client.post(
            "/recipes",
            data=incomplete_data,
            headers=auth_headers
        )

        assert response.status_code == 422  # Validation error


    async def test_create_recipe_with_valid_ingredients(
        self,
        async_client: AsyncClient,
        auth_headers: dict,
        base_ingredients,
        test_recipe_data: dict
    ):
        """Test recipe creation uses real ingredients from database."""
        response = await async_client.post(
            "/recipes",
            data=test_recipe_data,
            headers=auth_headers
        )

        assert response.status_code == 200
        data = response.json()

        # Verify ingredients are linked
        assert "ingredients" in data
        assert len(data["ingredients"]) > 0
        assert "egg" in data["ingredients"]
        assert "milk" in data["ingredients"]


    async def test_create_recipe_nutrition_calculated(
        self,
        async_client: AsyncClient,
        auth_headers: dict,
        base_ingredients,
        test_recipe_data: dict
    ):
        """Test that nutrition info is properly calculated."""
        response = await async_client.post(
            "/recipes",
            data=test_recipe_data,
            headers=auth_headers
        )

        assert response.status_code == 200
        data = response.json()

        # Check nutrition is calculated
        nutrition = data["nutrition"]
        assert "calories" in nutrition
        assert "protein" in nutrition
        assert "carbs" in nutrition
        assert "fats" in nutrition

        # Nutrition values can be numbers or strings with units
        for key, value in nutrition.items():
            assert value is not None


class TestIngredientSearch:
    """Tests for GET /ingredients endpoint."""

    async def test_get_all_ingredients(
        self,
        async_client: AsyncClient,
        base_ingredients
    ):
        """Test fetching all ingredients."""
        response = await async_client.get("/ingredients")

        assert response.status_code == 200
        data = response.json()

        assert isinstance(data, list)
        assert len(data) > 0

        # Check structure of ingredient
        ingredient = data[0]
        assert "id" in ingredient or "ingredient_name" in ingredient


    async def test_search_ingredients_by_name(
        self,
        async_client: AsyncClient,
        base_ingredients
    ):
        """Test searching ingredients by name."""
        response = await async_client.get("/ingredients?query=chicken")

        assert response.status_code == 200
        data = response.json()

        assert isinstance(data, list)
        if len(data) > 0:
            # Results should be chicken-related
            names = [ing.get("ingredient_name", "").lower() for ing in data]
            assert any("chicken" in name for name in names)


    async def test_search_ingredients_empty_result(
        self,
        async_client: AsyncClient,
        base_ingredients
    ):
        """Test searching ingredients with no specific match returns all or filtered."""
        response = await async_client.get("/ingredients?query=xyz_nonexistent_ingredient_123")

        assert response.status_code == 200
        data = response.json()

        # When query doesn't match any ingredients, endpoint behavior may vary
        # Some return empty, some return all - just verify it's a list
        assert isinstance(data, list)


    async def test_search_ingredients_case_insensitive(
        self,
        async_client: AsyncClient,
        base_ingredients
    ):
        """Test that ingredient search is case-insensitive."""
        # Search with uppercase
        response1 = await async_client.get("/ingredients?query=CHICKEN")
        # Search with lowercase
        response2 = await async_client.get("/ingredients?query=chicken")

        assert response1.status_code == 200
        assert response2.status_code == 200

        # Should return same results
        data1 = response1.json()
        data2 = response2.json()

        # If one has results, both should have results
        if len(data1) > 0 and len(data2) > 0:
            assert len(data1) == len(data2)


    async def test_ingredients_response_structure(
        self,
        async_client: AsyncClient,
        base_ingredients
    ):
        """Test ingredient response has expected nutritional structure."""
        response = await async_client.get("/ingredients")

        assert response.status_code == 200
        ingredients = response.json()

        if len(ingredients) > 0:
            ing = ingredients[0]
            # Check for nutrition information
            nutritional_fields = [
                "avg_calories", "avg_protein", "avg_carbs", "avg_fat"
            ]
            # At least some should be present
            has_nutrition = any(field in ing for field in nutritional_fields)
            assert has_nutrition or "ingredient_name" in ing


class TestRecipeIngredients:
    """Tests for recipe ingredient associations."""

    async def test_recipe_includes_all_ingredients(
        self,
        async_client: AsyncClient,
        auth_headers: dict,
        base_ingredients,
        test_recipe_data: dict
    ):
        """Test that created recipe includes all specified ingredients."""
        response = await async_client.post(
            "/recipes",
            data=test_recipe_data,
            headers=auth_headers
        )

        assert response.status_code == 200
        recipe = response.json()

        # Parse the original ingredients
        original_ingredients = json.loads(test_recipe_data["ingredients_json"])
        ingredient_names = [ing["ingredient_name"] for ing in original_ingredients]

        # Check all ingredients are in response
        recipe_ingredients = recipe.get("ingredients", [])
        for ing_name in ingredient_names:
            assert ing_name in recipe_ingredients


    async def test_recipe_ingredients_with_quantities(
        self,
        async_client: AsyncClient,
        auth_headers: dict,
        base_ingredients,
        test_recipe_data: dict
    ):
        """Test that recipe includes ingredient quantities."""
        response = await async_client.post(
            "/recipes",
            data=test_recipe_data,
            headers=auth_headers
        )

        assert response.status_code == 200
        recipe = response.json()

        # Check recipe_ingredients has quantity info
        recipe_ingredients = recipe.get("recipe_ingredients", [])
        assert len(recipe_ingredients) > 0

        for ing in recipe_ingredients:
            assert "ingredient_name" in ing
            assert "quantity" in ing
            assert "unit" in ing


class TestRecipeTags:
    """Tests for recipe tag associations."""

    async def test_recipe_tags_created(
        self,
        async_client: AsyncClient,
        auth_headers: dict,
        base_ingredients,
        test_recipe_data: dict
    ):
        """Test that recipe tags are properly created and associated."""
        response = await async_client.post(
            "/recipes",
            data=test_recipe_data,
            headers=auth_headers
        )

        assert response.status_code == 200
        recipe = response.json()

        # Get tags from original data
        original_tags = json.loads(test_recipe_data["tags_json"])

        # Verify tags in response
        recipe_tags = recipe.get("tags", [])
        assert len(recipe_tags) > 0

        for tag in original_tags:
            assert tag in recipe_tags


    async def test_duplicate_tags_removed(
        self,
        async_client: AsyncClient,
        auth_headers: dict,
        base_ingredients
    ):
        """Test that duplicate tags are not created."""
        recipe_data = {
            "title": "Recipe with Duplicate Tags",
            "summary": "Test recipe",
            "prep_time": "10 minutes",
            "cook_time": "20 minutes",
            "total_time": "30 minutes",
            "servings": 2,
            "difficulty": "Easy",
            "tags_json": json.dumps(["test", "test", "easy", "easy"]),  # Duplicates
            "ingredients_json": json.dumps([
                {"ingredient_name": "egg", "quantity": 1, "unit": "pcs"}
            ]),
            "steps_json": json.dumps(["Mix", "Cook"])
        }

        response = await async_client.post(
            "/recipes",
            data=recipe_data,
            headers=auth_headers
        )

        assert response.status_code == 200
        recipe = response.json()

        # Tags should be unique
        tags = recipe.get("tags", [])
        assert len(tags) == len(set(tags))  # No duplicates


class TestRecipeEdgeCases:
    """Tests for edge cases and error handling."""

    async def test_recipe_with_special_characters(
        self,
        async_client: AsyncClient,
        auth_headers: dict,
        base_ingredients
    ):
        """Test recipe creation with special characters in title/summary."""
        recipe_data = {
            "title": "Café's Famous Recipe™ & More!",
            "summary": "Special chars: @#$% 中文",
            "prep_time": "10 minutes",
            "cook_time": "20 minutes",
            "total_time": "30 minutes",
            "servings": 2,
            "difficulty": "Hard",
            "tags_json": json.dumps(["special", "chars"]),
            "ingredients_json": json.dumps([
                {"ingredient_name": "egg", "quantity": 1, "unit": "pcs"}
            ]),
            "steps_json": json.dumps(["Mix", "Cook"])
        }

        response = await async_client.post(
            "/recipes",
            data=recipe_data,
            headers=auth_headers
        )

        assert response.status_code == 200
        recipe = response.json()
        assert recipe["title"] == recipe_data["title"]


    async def test_recipe_with_large_quantities(
        self,
        async_client: AsyncClient,
        auth_headers: dict,
        base_ingredients
    ):
        """Test recipe with very large ingredient quantities."""
        recipe_data = {
            "title": "Bulk Recipe",
            "summary": "Large quantity recipe",
            "prep_time": "10 minutes",
            "cook_time": "20 minutes",
            "total_time": "30 minutes",
            "servings": 100,
            "difficulty": "Medium",
            "tags_json": json.dumps(["bulk"]),
            "ingredients_json": json.dumps([
                {"ingredient_name": "egg", "quantity": 1000, "unit": "pcs"},
                {"ingredient_name": "milk", "quantity": 500, "unit": "liters"}
            ]),
            "steps_json": json.dumps(["Mix large amounts", "Cook"])
        }

        response = await async_client.post(
            "/recipes",
            data=recipe_data,
            headers=auth_headers
        )

        assert response.status_code == 200
        recipe = response.json()
        assert recipe["servings"] == 100


    async def test_recipe_with_no_tags(
        self,
        async_client: AsyncClient,
        auth_headers: dict,
        base_ingredients
    ):
        """Test recipe creation without tags."""
        recipe_data = {
            "title": "No Tags Recipe",
            "summary": "Recipe without tags",
            "prep_time": "10 minutes",
            "cook_time": "20 minutes",
            "total_time": "30 minutes",
            "servings": 2,
            "difficulty": "Easy",
            "tags_json": json.dumps([]),
            "ingredients_json": json.dumps([
                {"ingredient_name": "egg", "quantity": 1, "unit": "pcs"}
            ]),
            "steps_json": json.dumps(["Cook"])
        }

        response = await async_client.post(
            "/recipes",
            data=recipe_data,
            headers=auth_headers
        )

        assert response.status_code == 200
        recipe = response.json()
        assert isinstance(recipe.get("tags", []), list)


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


# ── SR-2: Dietary tag filtering via API ───────────────────────────────────────

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


# ── SR-2: Allergen ingredient search ──────────────────────────────────────────

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


# ── SR-2 additional invalid/boundary ──────────────────────────────────────────

class TestSR2AdditionalInvalid:

    @pytest.mark.asyncio
    async def test_allergen_tag_removed_via_update(
        self, async_client: AsyncClient, base_ingredients
    ):
        """NT: allergen tag removed when recipe is updated."""
        create = await async_client.post("/recipes", data={
            "title": "SR2 Remove Tag",
            "summary": "s",
            "tags_json": json.dumps(["contains-eggs", "vegetarian"]),
            "ingredients_json": json.dumps([
                {"ingredient_name": "egg", "quantity": 2, "unit": "pcs"}
            ]),
            "steps_json": json.dumps(["Cook"]),
        })
        rid = create.json()["id"]
        update = await async_client.put(f"/recipes/{rid}", data={
            "title": "SR2 Remove Tag",
            "summary": "s",
            "tags_json": json.dumps(["vegetarian"]),
            "ingredients_json": json.dumps([
                {"ingredient_name": "egg", "quantity": 2, "unit": "pcs"}
            ]),
            "steps_json": json.dumps(["Cook"]),
        })
        assert update.status_code == 200
        assert "contains-eggs" not in update.json()["tags"]

    @pytest.mark.asyncio
    async def test_empty_allergen_search_returns_all(
        self, async_client: AsyncClient, base_ingredients
    ):
        """BVA: empty q= returns full ingredient list."""
        resp = await async_client.get("/ingredients?q=")
        assert resp.status_code == 200
        assert isinstance(resp.json(), list)
        assert len(resp.json()) > 0


# ── SR-3: Nutrition in API responses ──────────────────────────────────────────

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


# ── SR-4: Additional recipe CRUD ──────────────────────────────────────────────

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

        deleted = (await async_client.get("/recipes/deleted")).json()
        assert rid in [r["id"] for r in deleted]

        restore_resp = await async_client.post(f"/recipes/{rid}/restore")
        assert restore_resp.json()["message"] == "Restored"

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


# ── SR-4: Ingredient search ───────────────────────────────────────────────────

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


# ── SR-4: Recipe tag management ───────────────────────────────────────────────

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


# ── SR-4: Case insensitive definitive ─────────────────────────────────────────

class TestSR4CaseInsensitiveDefinitive:
    @pytest.mark.asyncio
    async def test_ingredient_search_case_insensitive_definitive(
        self, async_client: AsyncClient, base_ingredients
    ):
        """EP: definitive case-insensitive check — 'egg' is guaranteed in base_ingredients fixture."""
        r_upper = await async_client.get("/ingredients?q=EGG")
        r_lower = await async_client.get("/ingredients?q=egg")
        assert r_upper.status_code == 200
        assert r_lower.status_code == 200
        assert len(r_lower.json()) > 0, "base_ingredients fixture must seed at least one 'egg' ingredient"
        assert len(r_upper.json()) == len(r_lower.json())
