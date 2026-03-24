import json
from pathlib import Path

DATA_FILE = Path(__file__).resolve().parent / "data" / "recipe_ingredients.json"


def load_recipe_ingredients() -> dict[str, list[str]]:
    if not DATA_FILE.exists():
        return {}

    with DATA_FILE.open("r", encoding="utf-8") as f:
        data = json.load(f)

    if not isinstance(data, dict):
        raise ValueError("recipe_ingredients.json must contain a JSON object at the top level")

    normalized: dict[str, list[str]] = {}
    for recipe_name, ingredients in data.items():
        if not isinstance(recipe_name, str) or not isinstance(ingredients, list):
            continue
        normalized[recipe_name] = [str(item) for item in ingredients]

    return normalized


RECIPE_INGREDIENTS = load_recipe_ingredients()
