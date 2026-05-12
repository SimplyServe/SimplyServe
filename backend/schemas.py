"""
schemas.py — Pydantic request/response schemas for SimplyServe.

Pydantic models in this module serve two purposes:
  1. Request validation  : FastAPI automatically parses and validates incoming
                           JSON bodies against these schemas, returning a 422
                           Unprocessable Entity response if validation fails.
  2. Response serialisation : Route handlers return ORM objects or dicts; FastAPI
                           uses the `response_model` schema to serialise them,
                           strip extra fields, and coerce types.

Schema hierarchy
----------------

  Authentication
  ├── Token           : Returned by POST /token — contains the JWT string.
  └── TokenData       : Internal helper — decoded claims extracted from a JWT.

  Users
  ├── UserBase        : Shared base with `email` field.
  ├── UserCreate      : Registration payload — adds `password` and optional `name`.
  ├── UserLogin       : Login payload (currently superseded by OAuth2 form).
  ├── UserUpdate      : PATCH /users/me — all fields optional.
  ├── UserNameUpdate  : PUT /users/me — replaces the display name only.
  └── User            : Full user response — adds `id`, `is_active`, `profile_image_url`.
                        `from_attributes = True` enables ORM → Pydantic conversion.

  Recipes
  ├── NutritionInfo        : Per-serving macro breakdown returned with every recipe.
  ├── RecipeIngredientItem : Structured ingredient with quantity and validated unit.
  ├── IngredientSearchResult : Minimal ingredient shape for the search endpoint.
  ├── RecipeBase           : Shared recipe fields (title, times, tags, steps, …).
  ├── RecipeCreate         : Recipe creation payload (inherits RecipeBase).
  └── Recipe               : Full recipe response — adds `id`.
                             `from_attributes = True` enables ORM → Pydantic conversion.

UnitEnum
--------
The UnitEnum enforces that all ingredient unit values stored in the database
and returned to clients belong to a fixed, known set. The `_normalize_unit()`
helper in main.py converts free-text unit strings to UnitEnum members before
writing to the database.
"""

from pydantic import BaseModel, EmailStr, Field
from typing import Optional
from enum import Enum


# ── Unit enumeration ──────────────────────────────────────────────────────────

class UnitEnum(str, Enum):
    """Valid measurement units for recipe ingredients.

    Inheriting from `str` means the enum values serialise as plain strings in
    JSON responses rather than `{"value": "tsp"}` objects.
    """
    tsp  = "tsp"   # teaspoon
    tbsp = "tbsp"  # tablespoon
    cup  = "cup"
    ml   = "ml"    # millilitre
    l    = "l"     # litre
    g    = "g"     # gram
    kg   = "kg"    # kilogram
    oz   = "oz"    # ounce
    lb   = "lb"    # pound
    pcs  = "pcs"   # pieces / count (also used as a catch-all fallback)


# ── Authentication schemas ────────────────────────────────────────────────────

class Token(BaseModel):
    """OAuth2 bearer token response returned by POST /token.

    The Flutter client stores `access_token` and prepends
    `Authorization: Bearer <access_token>` to all subsequent requests.
    """
    access_token: str
    # Always "bearer" — the OAuth2 token type identifier.
    token_type: str


class TokenData(BaseModel):
    """Internal schema for decoded JWT claims.

    Used only inside `auth.get_current_user` to hold the validated email
    extracted from the token's `sub` claim before the database lookup.
    """
    email: Optional[str] = None


# ── User schemas ──────────────────────────────────────────────────────────────

class UserBase(BaseModel):
    """Base user schema — shared by request and response models."""
    email: EmailStr  # Validated as a properly formatted email address.


class UserCreate(UserBase):
    """Payload for POST /register.

    The `password` field is accepted here but never returned in any response —
    only the bcrypt hash is stored in the database.
    """
    password: str
    name: Optional[str] = None


class UserLogin(UserBase):
    """Login payload schema.

    Note: The `/token` endpoint uses `OAuth2PasswordRequestForm` directly
    (which reads `username`/`password` form fields), so this schema is not
    currently wired to a route. Kept for potential future use.
    """
    password: str


class UserUpdate(BaseModel):
    """Payload for PATCH /users/me — partial update.

    All fields are optional so the client can update only the fields it sends.
    """
    name: Optional[str] = None


class User(UserBase):
    """Full user response schema returned by /users/me and /register.

    `from_attributes = True` (formerly `orm_mode = True` in Pydantic v1)
    allows FastAPI to convert a SQLAlchemy User ORM object directly into
    this schema without an explicit `.dict()` call.
    """
    id: int
    name: Optional[str] = None
    is_active: bool
    # Duplicate `name` field from the ORM definition — Pydantic uses the last
    # declaration, which is identical, so there is no conflict in practice.
    name: Optional[str] = None
    # Relative URL to the uploaded profile image, or None if no avatar uploaded.
    profile_image_url: Optional[str] = None

    class Config:
        from_attributes = True  # Enable ORM object → Pydantic model conversion.


class UserNameUpdate(BaseModel):
    """Payload for PUT /users/me — full name replacement.

    Unlike UserUpdate (PATCH), this schema requires `name` to be present.
    The endpoint validates that the value is non-empty after stripping.
    """
    name: str


# ── Nutrition schema ──────────────────────────────────────────────────────────

class NutritionInfo(BaseModel):
    """Per-serving nutrition breakdown returned as part of every recipe response.

    `calories` is an integer value. Macro fields (`protein`, `carbs`, `fats`)
    are returned as gram strings (e.g. "32g") to match the Flutter model's
    expected format and allow easy UI display without client-side conversion.
    """
    calories: int
    protein: str   # e.g. "32g"
    carbs: str     # e.g. "45g"
    fats: str      # e.g. "12g"


# ── Recipe ingredient schema ──────────────────────────────────────────────────

class RecipeIngredientItem(BaseModel):
    """A single ingredient entry with a validated quantity and unit.

    This schema is embedded inside `RecipeBase.recipe_ingredients` and drives
    the structured ingredient display in the Flutter recipe detail view. The
    `unit` field is constrained to UnitEnum values so invalid units are
    rejected at the schema layer.
    """
    ingredient_name: str
    # Must be a positive float — validated by _parse_ingredient_payload in main.py.
    quantity: float
    # Constrained to the UnitEnum set; `_normalize_unit()` coerces raw text first.
    unit: UnitEnum


class IngredientSearchResult(BaseModel):
    """Minimal ingredient shape returned by GET /ingredients.

    Used by the Flutter recipe form to populate the ingredient search
    autocomplete. `is_base` lets the UI show a badge for catalogue ingredients
    that have verified nutrition data.
    """
    id: int
    ingredient_name: str
    # True for base catalogue ingredients with known nutrition values.
    is_base: bool = False

    class Config:
        from_attributes = True  # Enable ORM Ingredients → this schema.


# ── Recipe schemas ────────────────────────────────────────────────────────────

class RecipeBase(BaseModel):
    """Shared recipe fields used by both creation payloads and response models.

    Time fields (`prep_time`, `cook_time`, `total_time`) are strings to
    accommodate labels like "30 mins" supplied by the frontend. The backend
    extracts the leading integer for storage and returns the raw string in
    responses.

    `recipe_ingredients` contains the structured ingredient list used by
    the Flutter recipe detail and shopping list features. `ingredients` is a
    flat list of ingredient name strings for simpler display contexts.
    """
    title: str
    summary: str
    image_url: Optional[str] = None
    prep_time: str
    cook_time: str
    total_time: str
    servings: int
    difficulty: str
    tags: list[str] = []
    # Flat list of ingredient name strings — convenience field for simple display.
    ingredients: list[str] = []
    # Structured ingredient list with quantity and unit — used for shopping lists.
    recipe_ingredients: list[RecipeIngredientItem] = []
    steps: list[str] = []
    # Per-serving nutrition calculated from ingredient data; None if unavailable.
    nutrition: Optional[NutritionInfo] = None


class RecipeCreate(RecipeBase):
    """Payload schema for recipe creation.

    Currently identical to RecipeBase. The POST /recipes endpoint uses
    multipart form data rather than a JSON body, so this schema is used only
    for documentation and type hints — not for direct request parsing.
    """
    pass


class Recipe(RecipeBase):
    """Full recipe response schema including the database-assigned ID.

    The `id` field maps to `recipe_id` in the ORM model. FastAPI serialises
    ORM Recipe objects into this schema for all recipe list and detail endpoints.

    `from_attributes = True` enables the ORM → Pydantic conversion without an
    explicit `.dict()` call inside the route handler.
    """
    id: int  # Backend-assigned recipe ID (recipe_id in the ORM model).

    class Config:
        from_attributes = True  # Enable ORM Recipe → this schema.
