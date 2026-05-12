"""
recipe_ingredients.py — Seed data loader for recipe ingredient lists.

This module reads `data/recipe_ingredients.json` once at import time and
exposes the result as the module-level constant `RECIPE_INGREDIENTS`.

`RECIPE_INGREDIENTS` is consumed during the FastAPI `startup` event in
main.py to associate ingredient strings with seeded recipe records. For each
recipe name found in the JSON object, the startup routine:

  1. Looks up the matching Recipe row by `recipe_name`.
  2. Skips the recipe if it already has ingredient rows (idempotent).
  3. Calls `_parse_ingredient_text()` on each ingredient string to extract
     the name, quantity, and unit.
  4. Calls `_find_or_create_ingredient()` to obtain or insert an Ingredients
     row.
  5. Inserts a RecipeIngredient join row with the parsed quantity and unit.

Data format (data/recipe_ingredients.json)
------------------------------------------
The JSON file must be a top-level object whose keys are exact recipe names
and whose values are arrays of free-text ingredient strings:

    {
        "Spaghetti Bolognese": [
            "200 g beef mince",
            "1 cup tomato sauce",
            "2 cloves garlic"
        ],
        ...
    }

Ingredient strings are parsed by `_parse_ingredient_text()` in main.py, which
handles fractions (e.g. "1/2 cup"), named units, and falls back gracefully
when no quantity or unit is present.

If the file does not exist (e.g. in a fresh checkout without data assets),
`load_recipe_ingredients()` returns an empty dict so startup continues safely
without raising an exception.
"""

import json
from pathlib import Path

# Absolute path to the ingredient seed file, resolved relative to this module
# so it works regardless of the working directory from which uvicorn is started.
DATA_FILE = Path(__file__).resolve().parent / "data" / "recipe_ingredients.json"


def load_recipe_ingredients() -> dict[str, list[str]]:
    """Load and validate the recipe ingredients seed data from disk.

    Reads `data/recipe_ingredients.json` and returns a normalised mapping of
    recipe name → list of ingredient strings. Entries with non-string keys or
    non-list values are silently skipped to avoid crashing on malformed data.

    Returns:
        A dict mapping recipe name strings to lists of ingredient text strings.
        Returns an empty dict if the data file does not exist.

    Raises:
        ValueError: If the top-level JSON value is not an object (dict).
            This guards against accidentally pointing the loader at an array-
            formatted file and producing nonsensical startup behaviour.
    """
    # Return early if the seed file is absent — startup should not fail
    # in environments where the data/ directory is not present.
    if not DATA_FILE.exists():
        return {}

    with DATA_FILE.open("r", encoding="utf-8") as f:
        data = json.load(f)

    # The top-level value must be a JSON object so we can iterate key→list.
    if not isinstance(data, dict):
        raise ValueError("recipe_ingredients.json must contain a JSON object at the top level")

    # Validate and normalise each entry: skip malformed ones, coerce ingredient
    # items to strings in case numeric values were accidentally included.
    normalized: dict[str, list[str]] = {}
    for recipe_name, ingredients in data.items():
        if not isinstance(recipe_name, str) or not isinstance(ingredients, list):
            continue
        # Coerce each list element to str — guards against accidental ints/floats.
        normalized[recipe_name] = [str(item) for item in ingredients]

    return normalized


# Module-level constant: loaded once at import time and reused by the startup
# event in main.py. This avoids re-reading the file on every request and keeps
# the startup logic free of file I/O boilerplate.
RECIPE_INGREDIENTS = load_recipe_ingredients()
