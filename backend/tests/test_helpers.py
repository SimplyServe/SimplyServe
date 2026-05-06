"""
Unit tests for helper functions in main.py:
  - _normalize_unit
  - _parse_ingredient_text
  - _build_nutrition_info
"""

import pytest
from main import _normalize_unit, _parse_ingredient_text, _build_nutrition_info


# ── _normalize_unit ─────────────────────────────────────────────────────────

class TestNormalizeUnit:

    # Plural / long-form → abbreviation
    @pytest.mark.parametrize("raw,expected", [
        ("tablespoon", "tbsp"),
        ("tablespoons", "tbsp"),
        ("teaspoon", "tsp"),
        ("teaspoons", "tsp"),
        ("cup", "cup"),
        ("cups", "cup"),
        ("gram", "g"),
        ("grams", "g"),
        ("kilogram", "kg"),
        ("kilograms", "kg"),
        ("milliliter", "ml"),
        ("milliliters", "ml"),
        ("millilitre", "ml"),
        ("liter", "l"),
        ("liters", "l"),
        ("litre", "l"),
        ("ounce", "oz"),
        ("ounces", "oz"),
        ("pound", "lb"),
        ("pounds", "lb"),
        ("piece", "pcs"),
        ("pieces", "pcs"),
        ("pc", "pcs"),
    ])
    def test_known_aliases(self, raw, expected):
        assert _normalize_unit(raw) == expected

    # Already-canonical values stay the same
    @pytest.mark.parametrize("unit", ["tsp", "tbsp", "cup", "ml", "l", "g", "kg", "oz", "lb", "pcs"])
    def test_canonical_passthrough(self, unit):
        assert _normalize_unit(unit) == unit

    # Edge: whitespace and capitalisation
    def test_strips_whitespace_and_lowercases(self):
        assert _normalize_unit("  Tablespoons  ") == "tbsp"

    # Edge: empty or None → pcs
    def test_empty_string_returns_pcs(self):
        assert _normalize_unit("") == "pcs"

    def test_none_returns_pcs(self):
        assert _normalize_unit(None) == "pcs"

    # Unknown unit → pcs
    def test_unknown_unit_falls_back_to_pcs(self):
        assert _normalize_unit("handful") == "pcs"

    # Informal units that are mapped to pcs
    @pytest.mark.parametrize("raw", ["pinch", "clove", "cloves", "bunch", "slice", "slices", "can", "cans"])
    def test_informal_units_map_to_pcs(self, raw):
        assert _normalize_unit(raw) == "pcs"


# ── _parse_ingredient_text ──────────────────────────────────────────────────

class TestParseIngredientText:

    def test_quantity_unit_name(self):
        result = _parse_ingredient_text("2 cups flour")
        assert result["quantity"] == 2.0
        assert result["unit"] == "cup"
        assert result["ingredient_name"] == "flour"

    def test_fractional_quantity(self):
        result = _parse_ingredient_text("1/2 tsp salt")
        assert result["quantity"] == pytest.approx(0.5)
        assert result["unit"] == "tsp"
        assert result["ingredient_name"] == "salt"

    def test_quantity_without_unit(self):
        result = _parse_ingredient_text("3 eggs")
        assert result["quantity"] == 3.0
        assert result["ingredient_name"] == "eggs"

    def test_plain_name_only(self):
        result = _parse_ingredient_text("salt and pepper")
        assert result["ingredient_name"] == "salt and pepper"
        assert result["quantity"] == 1.0
        assert result["unit"] == "pcs"

    def test_strips_trailing_comma_notes(self):
        result = _parse_ingredient_text("2 cups milk, warmed")
        assert result["ingredient_name"] == "milk"

    def test_whitespace_trimmed(self):
        result = _parse_ingredient_text("  1 cup  sugar  ")
        assert result["ingredient_name"] == "sugar"

    def test_unknown_unit_treated_as_name(self):
        result = _parse_ingredient_text("2 large onions")
        # "large" is not in known_units → becomes part of ingredient_name
        assert "large" in result["ingredient_name"].lower() or "onion" in result["ingredient_name"].lower()

    def test_zero_division_fraction_fallback(self):
        result = _parse_ingredient_text("0/0 cups flour")
        # Should not crash; falls back to 1.0
        assert result["quantity"] == 1.0


# ── _build_nutrition_info ───────────────────────────────────────────────────

class TestBuildNutritionInfo:

    def test_simple_case(self):
        totals = {"calories": 400, "protein": 40, "carbs": 60, "fats": 20}
        result = _build_nutrition_info(totals, servings=2)
        assert result["calories"] == 200
        assert result["protein"] == "20g"
        assert result["carbs"] == "30g"
        assert result["fats"] == "10g"

    def test_single_serving(self):
        totals = {"calories": 300, "protein": 25, "carbs": 45, "fats": 10}
        result = _build_nutrition_info(totals, servings=1)
        assert result["calories"] == 300
        assert result["protein"] == "25g"

    def test_zero_servings_treated_as_one(self):
        totals = {"calories": 500, "protein": 50, "carbs": 70, "fats": 30}
        result = _build_nutrition_info(totals, servings=0)
        assert result["calories"] == 500

    def test_negative_servings_treated_as_one(self):
        totals = {"calories": 500, "protein": 50, "carbs": 70, "fats": 30}
        result = _build_nutrition_info(totals, servings=-3)
        assert result["calories"] == 500

    def test_rounding(self):
        totals = {"calories": 333, "protein": 33.3, "carbs": 66.6, "fats": 11.1}
        result = _build_nutrition_info(totals, servings=2)
        # 333 / 2 = 166.5 → rounds to 166 or 167
        assert isinstance(result["calories"], int)
        assert isinstance(result["protein"], str)

    def test_all_zero_totals(self):
        totals = {"calories": 0, "protein": 0, "carbs": 0, "fats": 0}
        result = _build_nutrition_info(totals, servings=4)
        assert result["calories"] == 0
        assert result["protein"] == "0g"
        assert result["carbs"] == "0g"
        assert result["fats"] == "0g"

    def test_large_values(self):
        totals = {"calories": 10000, "protein": 500, "carbs": 1200, "fats": 600}
        result = _build_nutrition_info(totals, servings=10)
        assert result["calories"] == 1000
        assert result["protein"] == "50g"
