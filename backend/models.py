"""
models.py — SQLAlchemy ORM table definitions for SimplyServe.

Each class in this module maps to a table in the SQLite `main.db` database.
Tables are created automatically by `Base.metadata.create_all()` during the
FastAPI `startup` event in main.py.

Table overview
--------------
  users                    : Registered user accounts with hashed passwords
                             and optional profile images.
  ingredients              : Ingredient catalogue including base nutritional
                             data per 100 g / per unit.
  recipe                   : Recipe records with metadata, nutrition totals,
                             cooking times, and a soft-delete flag.
  recipe_ingredient        : Many-to-many join between recipes and ingredients,
                             storing per-recipe quantity and unit.
  tags / recipe_tag        : Tag catalogue and its join table linking tags to
                             recipes.
  saved_recipes            : User favourites — links a user to a recipe_id
                             with optional personal notes.
  shopping_list /
  shopping_list_ingredient : Per-user shopping lists and their checked items.
  meals / meal_recipe      : Meal plan entries linked to recipes for the
                             calendar view.
  preference /
  user_preference          : Dietary preference options and per-user selections
                             (future feature).
  user_pantry              : Ingredient stock tracked per user (future feature).
  recipe_complexity        : Complexity/difficulty bands (future feature).
  recipe_feedback          : User ratings and like/dislike signals (future
                             feature).

Soft-delete convention
----------------------
`Recipe.is_deleted = True` hides a recipe from the main catalogue while
preserving it so it can be restored via /recipes/{id}/restore. Recipes with
`is_deleted = True` appear only on the Deleted Recipes screen.

Nutrition typo
--------------
`Recipe.protien` contains a historical spelling error. The column name is kept
as-is to avoid a breaking schema migration; all Python code references it as
`recipe.protien`.
"""

from sqlalchemy import Column, Integer, String, Boolean, Float, ForeignKey
from sqlalchemy.orm import relationship
from database import Base


# ── User ──────────────────────────────────────────────────────────────────────

class User(Base):
    """Registered user account.

    Relationships:
        shopping_lists : One-to-many → ShoppingList (cascade delete).
        meals          : One-to-many → Meals (cascade delete).
        saved_recipes  : One-to-many → SavedRecipe (cascade delete).
    """
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True)
    # Display name set during registration or updated via /users/me.
    name = Column(String, nullable=True)
    # bcrypt hash of the user's password — never stored as plain text.
    hashed_password = Column(String)
    is_active = Column(Boolean, default=True)
    # Duplicate `name` column preserved from a schema migration; SQLAlchemy
    # will use the last definition, so this is effectively the same column.
    name = Column(String, nullable=True)
    # Relative URL path to the uploaded avatar image, e.g. "/uploads/avatar_1_abc.jpg".
    profile_image_url = Column(String, nullable=True)

    shopping_lists = relationship("ShoppingList", back_populates="user", cascade="all, delete-orphan")
    meals = relationship("Meals", back_populates="user", cascade="all, delete-orphan")
    saved_recipes = relationship("SavedRecipe", back_populates="user", cascade="all, delete-orphan")


# ── Ingredients ───────────────────────────────────────────────────────────────

class Ingredients(Base):
    """Ingredient catalogue entry with optional per-100-g nutrition data.

    Base ingredients (`is_base=True`) are seeded from data/base_ingredients.json
    at startup and carry verified nutrition values. Non-base ingredients are
    created on-the-fly when a recipe references an unrecognised ingredient name.

    `normalized_name` is the lowercase version of `ingredient_name` and is used
    for case-insensitive duplicate detection during recipe creation.
    """
    __tablename__ = "ingredients"

    id = Column(Integer, primary_key=True, index=True)
    ingredient_name = Column(String, index=True)
    # Lowercase version of ingredient_name used for fast duplicate checks.
    normalized_name = Column(String, index=True)
    # True for catalogue ingredients loaded from base_ingredients.json.
    is_base = Column(Boolean, default=False, nullable=False)
    # Per-unit nutritional values. NULL for non-base ingredients that have no
    # data — nutrition totals for such recipes will be 0 for missing fields.
    avg_calories = Column(Integer)
    avg_protein = Column(Integer)
    avg_carbs = Column(Integer)
    avg_fat = Column(Integer)
    # Estimated cost per unit (not currently surfaced in the UI).
    avg_cost = Column(Float)


# ── RecipeComplexity ──────────────────────────────────────────────────────────

class RecipeComplexity(Base):
    """Difficulty band for recipes (future feature — not currently assigned).

    Intended to hold named difficulty tiers (e.g. Easy/Medium/Hard) with a
    time threshold so recipes can be auto-classified by cook time.
    """
    __tablename__ = "recipe_complexity"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)
    time_passed = Column(Integer, index=True)


# ── Preference ────────────────────────────────────────────────────────────────

class Preference(Base):
    """Dietary preference option (future feature).

    Represents a single preference option such as "Vegetarian" or "Gluten-free"
    that can be linked to users via UserPreference.
    """
    __tablename__ = "preference"

    preference_id = Column(Integer, primary_key=True, index=True)
    preference_name = Column(String)
    # 1 = liked preference, 0 = disliked / avoided.
    like = Column(Integer)


# ── ShoppingList ──────────────────────────────────────────────────────────────

class ShoppingList(Base):
    """A shopping list owned by a user, created from a meal plan or recipe.

    Shopping list items are stored in ShoppingListIngredient rows linked to
    this record via `shopping_list_id`.
    """
    __tablename__ = "shopping_list"

    shopping_list_id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), index=True)
    created_at = Column(String)

    user = relationship("User", back_populates="shopping_lists")


# ── Meals ─────────────────────────────────────────────────────────────────────

class Meals(Base):
    """A meal plan entry for a specific user and date.

    The `stage` column holds the meal type label (e.g. "Breakfast", "Lunch",
    "Dinner") shown in the calendar view. Recipes are linked via MealRecipe.
    """
    __tablename__ = "meals"

    meal_id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), index=True)
    # ISO 8601 date string (e.g. "2025-03-15") for calendar lookup.
    planned_date = Column(String)
    stage = Column(String, index=True)

    user = relationship("User", back_populates="meals")


# ── Recipe ────────────────────────────────────────────────────────────────────

class Recipe(Base):
    """Core recipe record.

    Soft-delete: set `is_deleted = True` to hide from the catalogue without
    destroying data. The recipe can be restored via `POST /recipes/{id}/restore`.

    Nutrition fields (`calories`, `protien`, `carbs`, `fat`) store the total
    nutrient values across all ingredients and are recalculated whenever the
    recipe is created or updated. Per-serving values are derived at query time
    by dividing by `servings`.

    Note: `protien` is a legacy spelling error retained to avoid a destructive
    schema migration.
    """
    __tablename__ = "recipe"

    recipe_id = Column(Integer, primary_key=True, index=True)
    # Optional link to a difficulty band — not currently populated by the API.
    complexity_id = Column(Integer, ForeignKey("recipe_complexity.id"))
    recipe_name = Column(String)
    cuisine = Column(String)
    # Preparation time in minutes.
    prep_time = Column(Integer)
    cost_estimate = Column(Integer)
    # Total nutrition across all ingredients (not per-serving).
    calories = Column(Integer)
    protien = Column(Integer)   # intentional legacy typo — do not rename
    carbs = Column(Integer)
    fat = Column(Integer)

    summary = Column(String)
    # Absolute URL path to the uploaded recipe image, e.g. "http://localhost:8000/uploads/abc.jpg".
    image_url = Column(String)
    # Cooking time in minutes.
    cook_time = Column(Integer)
    servings = Column(Integer)
    # JSON array of instruction step strings, serialised as text.
    instructions = Column(String)
    # Soft-delete flag: True = hidden from /recipes, visible on /recipes/deleted.
    is_deleted = Column(Boolean, default=False, nullable=False)


# ── SavedRecipe ───────────────────────────────────────────────────────────────

class SavedRecipe(Base):
    """A user's saved (favourited) recipe.

    Built-in catalogue recipes have no backend `id` on the Flutter side; the
    Flutter app handles favouriting built-ins locally. This table is used for
    user-created recipes that the owner wants to bookmark with notes.
    """
    __tablename__ = "saved_recipes"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), index=True)
    recipe_id = Column(Integer, ForeignKey("recipe.recipe_id"), index=True)
    recipe_name = Column(String)
    # Optional free-text notes the user added alongside the saved recipe.
    user_notes = Column(String)

    user = relationship("User", back_populates="saved_recipes")


# ── recipe_feedback ───────────────────────────────────────────────────────────

class recipe_feedback(Base):
    """User rating and like/dislike signal for a recipe (future feature).

    Intended for a recommendation engine that surfaces popular recipes.
    `rating` is an integer score; `liked` is a boolean flag (0/1).
    """
    __tablename__ = "recipe_feedback"

    feedback_id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), index=True)
    recipe_id = Column(Integer, ForeignKey("recipe.recipe_id"), index=True)
    # Integer star rating (e.g. 1–5).
    rating = Column(Integer)
    # 1 = liked, 0 = disliked.
    liked = Column(Integer)
    created_at = Column(String)


# ── ShoppingListIngredient ────────────────────────────────────────────────────

class ShoppingListIngredient(Base):
    """A single ingredient line-item on a shopping list.

    The composite primary key (`shopping_list_id`, `ingredient_id`) enforces
    that each ingredient appears at most once per list. `checked` is a boolean
    flag (stored as integer) toggled when the user ticks an item while shopping.
    """
    __tablename__ = "shopping_list_ingredient"

    shopping_list_id = Column(Integer, ForeignKey('shopping_list.shopping_list_id'), primary_key=True)
    ingredient_id = Column(Integer, ForeignKey('ingredients.id'), primary_key=True)
    quantity = Column(Integer)
    # 0 = unchecked, 1 = checked off in the shopping list UI.
    checked = Column(Integer)
    unit = Column(String)


# ── UserPantry ────────────────────────────────────────────────────────────────

class UserPantry(Base):
    """Ingredient stock tracked in a user's virtual pantry (future feature).

    Intended to let the app suggest recipes based on what the user already has
    at home and to automatically deduct used quantities after cooking.
    """
    __tablename__ = "user_pantry"

    ingredient_id = Column(Integer, ForeignKey('ingredients.id'), primary_key=True)
    user_id = Column(Integer, ForeignKey('users.id'), primary_key=True)
    quantity = Column(Integer)
    unit = Column(Integer)
    updated_at = Column(String)


# ── UserPreference ────────────────────────────────────────────────────────────

class UserPreference(Base):
    """Many-to-many join between users and dietary preferences (future feature)."""
    __tablename__ = "user_preference"

    user_id = Column(Integer, ForeignKey('users.id'), primary_key=True)
    preference_id = Column(Integer, ForeignKey('preference.preference_id'), primary_key=True)


# ── RecipeTag ─────────────────────────────────────────────────────────────────

class RecipeTag(Base):
    """Many-to-many join linking recipes to tags.

    Tags are global (shared across users) — see Tag. This table records which
    tags have been applied to which recipes.
    """
    __tablename__ = "recipe_tag"

    tag_id = Column(Integer, ForeignKey('tags.id'), primary_key=True)
    recipe_id = Column(Integer, ForeignKey('recipe.recipe_id'), primary_key=True)


# ── MealRecipe ────────────────────────────────────────────────────────────────

class MealRecipe(Base):
    """Many-to-many join linking a meal plan entry to one or more recipes."""
    __tablename__ = "meal_recipe"

    meal_id = Column(Integer, ForeignKey('meals.meal_id'), primary_key=True)
    recipe_id = Column(Integer, ForeignKey('recipe.recipe_id'), primary_key=True)


# ── RecipeIngredient ──────────────────────────────────────────────────────────

class RecipeIngredient(Base):
    """An ingredient used in a specific recipe with its quantity and unit.

    `quantity` is a floating-point amount so fractional values (e.g. 0.5 cup)
    are stored exactly. `unit` is normalised via `_normalize_unit()` at write
    time so all stored values belong to the UnitEnum set in schemas.py.
    """
    __tablename__ = "recipe_ingredient"

    # Composite primary key: each ingredient appears at most once per recipe.
    recipe_id = Column(Integer, ForeignKey('recipe.recipe_id'), primary_key=True)
    ingredient_id = Column(Integer, ForeignKey('ingredients.id'), primary_key=True)
    quantity = Column(Float)
    # Normalised unit string — one of: tsp, tbsp, cup, ml, l, g, kg, oz, lb, pcs.
    unit = Column(String)


# ── Tag ───────────────────────────────────────────────────────────────────────

class Tag(Base):
    """A recipe classification tag (e.g. "Vegan", "Quick", "High Protein").

    Tags are shared globally across all users (`user_id` is nullable and not
    currently enforced). `tag_name` is unique so the same label is never
    duplicated in the catalogue. The /recipes POST/PUT endpoints create missing
    tags on the fly before linking them via RecipeTag.
    """
    __tablename__ = "tags"

    id = Column(Integer, primary_key=True, index=True)
    # Optional owner — currently unused; tags are treated as global.
    user_id = Column(Integer, ForeignKey('users.id'))
    # Human-readable tag label, unique across the entire catalogue.
    tag_name = Column(String, unique=True)
