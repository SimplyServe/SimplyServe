"""
main.py — FastAPI application entry point for SimplyServe.

This module wires together all routes, middleware, startup tasks, and helper
utilities for the SimplyServe REST API. It is the file uvicorn loads when the
server starts:

    uvicorn main:app --reload

Architecture overview
---------------------
  database.py      : Async SQLAlchemy engine + session factory (SQLite).
  models.py        : SQLAlchemy ORM table classes.
  schemas.py       : Pydantic request/response validation schemas.
  auth.py          : JWT token creation, bcrypt password hashing, current-user
                     dependency.
  recipe_ingredients.py : Seed data loader for built-in recipe ingredients.

Route summary
-------------
  POST   /register                   Register a new user.
  POST   /token                      Authenticate and receive a JWT.
  GET    /users/me                   Fetch the current user's profile.
  PATCH  /users/me                   Partially update the current user.
  PUT    /users/me                   Replace the current user's display name.
  POST   /users/me/avatar            Upload a profile avatar image.
  GET    /recipes                    List all non-deleted recipes.
  POST   /recipes                    Create a new user recipe.
  PUT    /recipes/{id}               Update an existing recipe.
  DELETE /recipes/{id}               Soft-delete a recipe.
  GET    /recipes/deleted            List soft-deleted recipes.
  POST   /recipes/{id}/restore       Restore a soft-deleted recipe.
  DELETE /recipes/{id}/permanent     Permanently erase a recipe.
  GET    /ingredients                Search the ingredient catalogue.
  GET    /uploads/{filename}         Serve uploaded image files (static mount).

Nutrition calculation
---------------------
Per-ingredient nutrition is stored per unit in the `ingredients` table (seeded
from data/base_ingredients.json). When a recipe is created or updated:
  1. `_calculate_recipe_nutrition_totals()` JOINs `recipe_ingredient` with
     `ingredients`, multiplies each ingredient's per-unit values by `quantity`,
     and sums the results.
  2. `_build_nutrition_info()` divides the totals by `servings` and formats
     them as per-serving strings for the response.

Soft-delete pattern
-------------------
User-created recipes are never truly deleted on the first DELETE call. Instead
`Recipe.is_deleted` is set to True. The recipe disappears from GET /recipes
but remains accessible via GET /recipes/deleted, from which it can be restored
(POST /recipes/{id}/restore) or permanently removed
(DELETE /recipes/{id}/permanent).

Image upload pattern
--------------------
Both recipe images and profile avatars are saved to the local `uploads/`
directory with a UUID-prefixed filename to avoid collisions. The directory is
mounted as a FastAPI StaticFiles route at `/uploads` so Flutter can load them
via a standard HTTP URL.

CORS policy
-----------
`allow_origins=["*"]` with `allow_credentials=False` is intentional for
local development — the Flutter app and backend run on different ports. In
production this should be locked to the specific frontend origin.
"""

from typing import Optional
from fractions import Fraction
import json
import re
from pathlib import Path

from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import text
from datetime import timedelta, datetime

import models, schemas, auth, database
from database import engine
from recipe_ingredients import RECIPE_INGREDIENTS

from fastapi import File, UploadFile, Form
import os
import uuid

# ── Application instance ──────────────────────────────────────────────────────

app = FastAPI()

# CORS middleware: allow any origin so the Flutter web/desktop client and the
# Swagger UI at /docs can reach the API without cross-origin blocks.
# `allow_credentials=False` is required when `allow_origins=["*"]`.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Unit normalisation helpers ────────────────────────────────────────────────

def _normalize_unit(unit: str) -> str:
    """Return a standardised ingredient unit.

    Maps common long-form and plural unit spellings to their canonical
    short-form counterparts so the database only ever stores UnitEnum values.
    Unknown units fall back to "pcs" (pieces) rather than raising an error,
    which keeps the ingredient pipeline robust against unexpected input.

    Args:
        unit: Raw unit text supplied by a recipe ingredient, such as
            "grams", "g", "tablespoons", or "tbsp".

    Returns:
        A normalised unit string belonging to the UnitEnum set:
        {tsp, tbsp, cup, ml, l, g, kg, oz, lb, pcs}.
    """
    unit = (unit or "").strip().lower()

    # Mapping from long-form / plural spellings → canonical short form.
    mapping = {
        "tablespoon": "tbsp", "tablespoons": "tbsp", "tbsps": "tbsp",
        "teaspoon": "tsp", "teaspoons": "tsp", "tsps": "tsp",
        "cup": "cup", "cups": "cup",
        "gram": "g", "grams": "g", "gr": "g",
        "kilogram": "kg", "kilograms": "kg",
        "milliliter": "ml", "milliliters": "ml", "millilitre": "ml",
        "liter": "l", "liters": "l", "litre": "l",
        "ounce": "oz", "ounces": "oz",
        "pound": "lb", "pounds": "lb",
        "piece": "pcs", "pieces": "pcs", "pc": "pcs",
        "pinch": "pcs", "clove": "pcs", "cloves": "pcs",
        "bunch": "pcs", "slice": "pcs", "slices": "pcs",
        "can": "pcs", "cans": "pcs",
    }
    normalized = mapping.get(unit, unit)

    # If still not a valid UnitEnum value after the mapping, fall back to "pcs"
    # so the RecipeIngredient row is always valid.
    valid = {"tsp", "tbsp", "cup", "ml", "l", "g", "kg", "oz", "lb", "pcs"}
    return normalized if normalized in valid else "pcs"


def _parse_ingredient_text(raw: str) -> dict:
    """Parse a free-text ingredient string into structured ingredient data.

    Uses two regex patterns tried in order:
      Pattern 1 — quantity + unit + name: `^(qty) (unit) (name)$`
        e.g. "200 g chicken breast" → qty=200.0, unit="g", name="chicken breast"
      Pattern 2 — quantity + name (no unit): `^(qty) (name)$`
        e.g. "3 eggs" → qty=3.0, unit="pcs", name="eggs"
      Fallback — name only:
        e.g. "salt" → qty=1.0, unit="pcs", name="salt"

    `Fraction` from the standard library handles slash-notation quantities
    such as "1/2" or "3 1/4" without needing a custom parser.

    Trailing comma-separated qualifiers (e.g. "chicken, boneless") are
    stripped to keep the ingredient name clean.

    Args:
        raw: Ingredient text such as "1 cup flour" or "200 g chicken".

    Returns:
        A dict with keys: `ingredient_name` (str), `quantity` (float),
        `unit` (normalised str).
    """
    raw = raw.strip()
    quantity = 1.0
    unit = "pcs"
    ingredient_name = raw

    known_units = {
        "cup", "cups", "tbsp", "tsp", "tablespoon", "tablespoons",
        "teaspoon", "teaspoons", "g", "kg", "ml", "l", "oz", "lb",
        "gram", "grams", "piece", "pieces", "pcs", "pinch", "clove",
        "cloves", "slice", "slices", "can", "bunch",
    }

    # Pattern 1: `<quantity> <unit> <name>` — the most common format.
    match = re.match(r'^([\d\s/]+)\s+([a-zA-Z]+)\s+(.+)$', raw)
    if match:
        qty_str, unit_str, name = match.groups()
        try:
            # Fraction handles "1/2", "3 1/4", "2" etc. uniformly.
            quantity = float(Fraction(qty_str.strip()))
        except (ValueError, ZeroDivisionError):
            quantity = 1.0

        if unit_str.lower() in known_units:
            unit = _normalize_unit(unit_str)
            # Strip comma-qualified sub-descriptions from the ingredient name.
            ingredient_name = name.split(",")[0].strip()
        else:
            # The second token is not a unit — treat it as part of the name.
            ingredient_name = (unit_str + " " + name).split(",")[0].strip()
    else:
        # Pattern 2: `<quantity> <name>` — no unit token.
        match2 = re.match(r'^([\d/]+)\s+(.+)$', raw)
        if match2:
            qty_str, name = match2.groups()
            try:
                quantity = float(Fraction(qty_str.strip()))
            except (ValueError, ZeroDivisionError):
                quantity = 1.0
            ingredient_name = name.split(",")[0].strip()
        else:
            # Fallback: the entire string is the ingredient name.
            ingredient_name = raw.split(",")[0].strip()

    return {"ingredient_name": ingredient_name, "quantity": quantity, "unit": unit}


# ── Database helpers ──────────────────────────────────────────────────────────

async def _find_or_create_ingredient(db: AsyncSession, name: str) -> models.Ingredients:
    """Find an ingredient by normalised name or create it if missing.

    Normalisation (lowercase, strip) prevents duplicate rows for the same
    ingredient with different capitalisation. `db.flush()` assigns a database
    ID to the new row without committing the transaction, so the ID can be
    used immediately in subsequent recipe_ingredient rows within the same
    transaction.

    Args:
        db: Active asynchronous database session.
        name: Ingredient name supplied by a recipe or seed data.

    Returns:
        The existing or newly-created Ingredients database record.
    """
    normalized = name.strip().lower()
    res = await db.execute(
        select(models.Ingredients).where(models.Ingredients.normalized_name == normalized)
    )
    ing = res.scalars().first()
    if not ing:
        ing = models.Ingredients(
            ingredient_name=name.strip(),
            normalized_name=normalized,
            # Non-base ingredients have no nutrition data; is_base=False marks
            # them as user-added so the search endpoint can distinguish them.
            is_base=False,
        )
        db.add(ing)
        # flush() sends the INSERT to the DB within the current transaction,
        # obtaining an auto-generated `id` without a full commit.
        await db.flush()
    return ing


async def _seed_base_ingredients_catalog(db: AsyncSession):
    """Seed the database with base ingredient nutrition records.

    Reads data/base_ingredients.json and inserts each ingredient only when a
    row with the same normalised name does not already exist. This makes the
    function safe to call on every application startup without creating
    duplicate rows.

    The JSON file should contain a list of objects with the keys:
        ingredient_name, avg_calories, avg_protein, avg_carbs, avg_fat,
        avg_cost.

    Args:
        db: Active asynchronous database session.
    """
    base_file = Path(__file__).resolve().parent / "data" / "base_ingredients.json"
    if not base_file.exists():
        return

    with base_file.open("r", encoding="utf-8") as f:
        data = json.load(f)

    for item in data:
        name = item.get("ingredient_name", "").strip()
        if not name:
            continue

        normalized = name.lower()
        res = await db.execute(
            select(models.Ingredients).where(models.Ingredients.normalized_name == normalized)
        )
        # Skip rows that already exist — idempotent on repeated startups.
        if res.scalars().first():
            continue

        db.add(models.Ingredients(
            ingredient_name=name,
            normalized_name=normalized,
            is_base=True,
            avg_calories=item.get("avg_calories"),
            avg_protein=item.get("avg_protein"),
            avg_carbs=item.get("avg_carbs"),
            avg_fat=item.get("avg_fat"),
            avg_cost=item.get("avg_cost"),
        ))
    await db.commit()


async def _normalize_existing_ingredient_data(db: AsyncSession):
    """Normalise units for existing recipe ingredient rows.

    Called during startup to fix legacy rows where units were stored in
    long-form (e.g. "grams") or non-canonical spellings. Rows whose unit is
    already valid are untouched. The commit at the end persists all changes
    in a single transaction.

    Args:
        db: Active asynchronous database session.
    """
    valid = {"tsp", "tbsp", "cup", "ml", "l", "g", "kg", "oz", "lb", "pcs"}
    result = await db.execute(select(models.RecipeIngredient))
    rows = result.scalars().all()

    for row in rows:
        normalized = _normalize_unit(row.unit or "")
        if normalized != row.unit:
            row.unit = normalized

    await db.commit()


async def _ensure_ingredient_table_columns():
    """Ensure database tables contain all columns required by the current app.

    Performs lightweight ALTER TABLE operations for columns that were added
    after the initial schema was created. Each ALTER is wrapped in a try/except
    so that existing columns are silently ignored — this keeps the function
    idempotent across repeated startups.

    Columns managed:
      users              : name, profile_image_url
      recipe             : is_deleted
      recipe_ingredient  : quantity, unit
      ingredients        : normalized_name, is_base, avg_calories, avg_protein,
                           avg_carbs, avg_fat, avg_cost

    After adding columns, a backfill UPDATE sets `normalized_name` for any
    ingredients rows that were inserted before the column existed.
    """
    async with engine.begin() as conn:
        # User profile columns added in a later sprint.
        for col, col_type in [("name", "TEXT"), ("profile_image_url", "TEXT")]:
            try:
                await conn.execute(text(f"ALTER TABLE users ADD COLUMN {col} {col_type}"))
            except Exception:
                pass  # Column already exists — safe to ignore.

        # Soft-delete flag for the recipe table.
        try:
            await conn.execute(text(
                "ALTER TABLE recipe ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0"
            ))
        except Exception:
            pass

        # Duplicate attempt for `name` — harmless because the outer try/except
        # catches the "duplicate column" error from SQLite.
        try:
            await conn.execute(text("ALTER TABLE users ADD COLUMN name TEXT"))
        except Exception:
            pass

        # Quantity and unit were added to recipe_ingredient after the initial schema.
        for col, col_type in [("quantity", "REAL"), ("unit", "TEXT")]:
            try:
                await conn.execute(text(f"ALTER TABLE recipe_ingredient ADD COLUMN {col} {col_type}"))
            except Exception:
                pass

        # Nutrition and metadata columns added to ingredients for the base catalogue.
        for col, col_type in [
            ("normalized_name", "TEXT"),
            ("is_base", "INTEGER DEFAULT 0"),
            ("avg_calories", "REAL"),
            ("avg_protein", "REAL"),
            ("avg_carbs", "REAL"),
            ("avg_fat", "REAL"),
            ("avg_cost", "REAL"),
        ]:
            try:
                await conn.execute(text(f"ALTER TABLE ingredients ADD COLUMN {col} {col_type}"))
            except Exception:
                pass

        # Backfill normalized_name for any existing rows that pre-date the column.
        await conn.execute(text(
            "UPDATE ingredients SET normalized_name = LOWER(ingredient_name) WHERE normalized_name IS NULL"
        ))


# ── Nutrition helpers ─────────────────────────────────────────────────────────

async def _calculate_recipe_nutrition_totals(db: AsyncSession, recipe_id: int) -> dict:
    """Calculate total nutrition values for a recipe by summing ingredient data.

    JOINs the `ingredients` table (which holds per-unit nutrition) with
    `recipe_ingredient` (which holds per-recipe quantity) and multiplies each
    nutrient value by the ingredient's quantity. Missing nutrition values are
    treated as zero so recipes with unknown ingredients do not raise errors.

    Args:
        db: Active asynchronous database session.
        recipe_id: Database ID of the recipe whose ingredients should be totalled.

    Returns:
        A dict with keys `calories`, `protein`, `carbs`, `fats` holding the
        total (not per-serving) float values across all ingredients.
    """
    result = await db.execute(
        select(
            models.Ingredients.avg_calories,
            models.Ingredients.avg_protein,
            models.Ingredients.avg_carbs,
            models.Ingredients.avg_fat,
            models.RecipeIngredient.quantity,
        )
        .join(models.RecipeIngredient, models.Ingredients.id == models.RecipeIngredient.ingredient_id)
        .where(models.RecipeIngredient.recipe_id == recipe_id)
    )

    totals = {"calories": 0.0, "protein": 0.0, "carbs": 0.0, "fats": 0.0}
    for cal, prot, carbs, fat, qty in result.all():
        qty = qty or 1.0  # Default to 1 unit if quantity is NULL.
        if cal:   totals["calories"] += cal * qty
        if prot:  totals["protein"]  += prot * qty
        if carbs: totals["carbs"]    += carbs * qty
        if fat:   totals["fats"]     += fat * qty

    return totals


def _build_nutrition_info(totals: dict, servings: int) -> dict:
    """Build per-serving nutrition information for API responses.

    Divides each total nutrient value by `servings` and formats the result
    as the `NutritionInfo` dict shape expected by the Flutter `RecipeModel`.
    Calories are returned as an integer; macros are returned as gram strings
    (e.g. "32g") so the Flutter UI can display them directly.

    Args:
        totals: Total recipe nutrition dict from `_calculate_recipe_nutrition_totals`.
        servings: Number of servings — clamped to a minimum of 1 to avoid
            division by zero.

    Returns:
        A dict matching the `NutritionInfo` schema:
        { calories: int, protein: str, carbs: str, fats: str }
    """
    s = max(servings, 1)  # Guard against zero or negative serving counts.
    return {
        "calories": int(round(totals["calories"] / s)),
        "protein":  f"{int(round(totals['protein'] / s))}g",
        "carbs":    f"{int(round(totals['carbs']   / s))}g",
        "fats":     f"{int(round(totals['fats']    / s))}g",
    }


# ── Startup event ─────────────────────────────────────────────────────────────

@app.on_event("startup")
async def startup():
    """Initialise the database and seed required ingredient data on app startup.

    Execution order:
      1. `Base.metadata.create_all` — create any tables that don't yet exist.
      2. `_ensure_ingredient_table_columns` — add newer columns via ALTER TABLE.
      3. `_seed_base_ingredients_catalog` — insert base ingredient nutrition data.
      4. For each recipe in RECIPE_INGREDIENTS:
           - Find the Recipe row by name.
           - Skip if it already has RecipeIngredient rows (idempotent).
           - Parse, find/create, and link each ingredient.
      5. `_normalize_existing_ingredient_data` — fix legacy unit strings.

    This function is called once when uvicorn starts and never again during
    the server's lifetime unless it is restarted.
    """
    # Step 1: Create tables from ORM definitions (safe to call on existing DBs).
    async with engine.begin() as conn:
        await conn.run_sync(models.Base.metadata.create_all)

    # Step 2: Add newer columns that may be missing from an existing database.
    await _ensure_ingredient_table_columns()

    async with database.AsyncSessionLocal() as db:
        # Step 3: Populate the base ingredient nutrition catalogue.
        await _seed_base_ingredients_catalog(db)

        # Step 4: Attach ingredient rows to seeded recipe records.
        for recipe_name, ing_list in RECIPE_INGREDIENTS.items():
            res = await db.execute(select(models.Recipe).where(models.Recipe.recipe_name == recipe_name))
            recipe = res.scalars().first()
            if not recipe:
                continue  # Recipe not yet seeded — skip gracefully.

            # Check for existing ingredient rows to avoid duplicating them.
            existing = await db.execute(
                select(models.RecipeIngredient).where(models.RecipeIngredient.recipe_id == recipe.recipe_id)
            )
            if existing.scalars().first():
                continue  # Already seeded — idempotent guard.

            for raw_ingredient in ing_list:
                parsed = _parse_ingredient_text(raw_ingredient)
                ing = await _find_or_create_ingredient(db, parsed["ingredient_name"])
                db.add(
                    models.RecipeIngredient(
                        ingredient_id=ing.id,
                        recipe_id=recipe.recipe_id,
                        quantity=parsed["quantity"],
                        unit=parsed["unit"],
                    )
                )

        await db.commit()

        # Step 5: Correct legacy rows where unit was stored as a long-form string.
        await _normalize_existing_ingredient_data(db)


# ── Ingredient payload parser ─────────────────────────────────────────────────

def _parse_ingredient_payload(ingredients_json: str) -> list[dict]:
    """Validate and parse the ingredients_json payload from recipe forms.

    The Flutter recipe form submits ingredients as a JSON-encoded string in a
    multipart form upload. Each element can be either:
      - A string  → passed to `_parse_ingredient_text()` for free-text parsing.
      - An object → fields `ingredient_name`/`name`, `quantity`, `unit` are
                    extracted and normalised directly.

    De-duplication: ingredients with the same lowercased name that appear more
    than once are silently dropped, keeping the list deterministic.

    Args:
        ingredients_json: JSON string submitted from the Flutter recipe form.

    Returns:
        A de-duplicated list of dicts with keys:
        { ingredient_name: str, quantity: float, unit: str (normalised) }

    Raises:
        HTTPException 422: If the JSON is invalid, not an array, contains a
            non-parseable quantity, or contains a non-positive quantity.
    """
    try:
        payload = json.loads(ingredients_json)
    except json.JSONDecodeError as exc:
        raise HTTPException(status_code=422, detail="ingredients_json must be valid JSON") from exc

    if not isinstance(payload, list):
        raise HTTPException(status_code=422, detail="ingredients_json must be a JSON array")

    parsed: list[dict] = []
    seen: set[str] = set()  # Tracks lowercased names to prevent duplicates.

    for item in payload:
        name: Optional[str] = None
        quantity: float = 1.0
        unit: str = "pcs"

        if isinstance(item, str):
            # Free-text ingredient string — delegate to the text parser.
            parsed_item = _parse_ingredient_text(item)
            name = parsed_item["ingredient_name"]
            quantity = parsed_item["quantity"]
            unit = parsed_item["unit"]
        elif isinstance(item, dict):
            # Structured object from the Flutter form's structured ingredient list.
            name = str(item.get("ingredient_name") or item.get("name") or "").strip()
            quantity_value = item.get("quantity", 1)
            try:
                quantity = float(quantity_value)
            except (TypeError, ValueError) as exc:
                raise HTTPException(status_code=422, detail=f"Invalid quantity for ingredient '{name}'") from exc
            unit = _normalize_unit(str(item.get("unit") or "pcs"))
        else:
            raise HTTPException(status_code=422, detail="Each ingredient must be a string or object")

        if not name:
            continue  # Skip blank names rather than failing.

        if quantity <= 0:
            raise HTTPException(status_code=422, detail=f"Quantity must be greater than 0 for ingredient '{name}'")

        # De-duplicate by normalised name — first occurrence wins.
        key = name.lower()
        if key in seen:
            continue
        seen.add(key)

        parsed.append({
            "ingredient_name": name,
            "quantity": quantity,
            "unit": unit,
        })

    return parsed


# ── User seeding placeholder ──────────────────────────────────────────────────

async def seed_user_data(user_id: int, db: AsyncSession):
    """Placeholder for adding default data for a newly registered user.

    Args:
        user_id: ID of the newly-created user.
        db: Active asynchronous database session.

    Currently unused — kept as an extension point for future onboarding flows
    such as pre-populating a shopping list or meal plan.
    """
    pass


# ── Authentication routes ─────────────────────────────────────────────────────

@app.post("/register", response_model=schemas.User)
async def create_user(user: schemas.UserCreate, db: AsyncSession = Depends(database.get_db)):
    """Register a new user account.

    Validates that the email is not already registered, hashes the password
    with bcrypt, and persists the new user record. Returns the created user
    (without the password) serialised via the `schemas.User` response model.

    Args:
        user: Registration payload — email, password, optional name.
        db: Active asynchronous database session.

    Returns:
        The newly-created user record (id, email, name, is_active, profile_image_url).

    Raises:
        HTTPException 400: If the email address is already registered.
    """
    result = await db.execute(select(models.User).where(models.User.email == user.email))
    db_user = result.scalars().first()
    if db_user:
        raise HTTPException(status_code=400, detail="Email already registered")

    # Hash the plain-text password before storage — never persisted as plain text.
    hashed_password = auth.get_password_hash(user.password)
    new_user = models.User(email=user.email, name=user.name, hashed_password=hashed_password)
    db.add(new_user)
    await db.commit()
    await db.refresh(new_user)

    # seed_user_data is available here if default data should be added on signup.
    # await seed_user_data(new_user.id, db)

    return new_user


@app.post("/token", response_model=schemas.Token)
async def login_for_access_token(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: AsyncSession = Depends(database.get_db),
):
    """Authenticate a user and return a JWT bearer token.

    Uses the OAuth2 password flow: credentials are submitted as a form body
    with `username` (mapped to email) and `password` fields. FastAPI's
    `OAuth2PasswordRequestForm` dependency handles decoding the form.

    On success, a JWT is minted with `auth.create_access_token()` signed using
    HS256 and valid for `ACCESS_TOKEN_EXPIRE_MINUTES` (30 minutes).

    Args:
        form_data: OAuth2 password-flow form — `username` = email, `password`.
        db: Active asynchronous database session.

    Returns:
        { access_token: str, token_type: "bearer" }

    Raises:
        HTTPException 401: If the email does not exist or password is incorrect.
    """
    result = await db.execute(select(models.User).where(models.User.email == form_data.username))
    user = result.scalars().first()

    # Verify both that the user exists and that the password hash matches.
    if not user or not auth.verify_password(form_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # Create a JWT with `sub` = user's email and a 30-minute expiry.
    access_token_expires = timedelta(minutes=auth.ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = auth.create_access_token(
        data={"sub": user.email}, expires_delta=access_token_expires
    )
    return {"access_token": access_token, "token_type": "bearer"}


# ── User profile routes ───────────────────────────────────────────────────────

@app.get("/users/me", response_model=schemas.User)
async def read_users_me(current_user: models.User = Depends(auth.get_current_user)):
    """Return the currently authenticated user's profile.

    The `auth.get_current_user` dependency validates the bearer token and
    loads the User ORM object, which FastAPI serialises via `schemas.User`.

    Args:
        current_user: User resolved from the JWT bearer token dependency.

    Returns:
        The authenticated user's profile (id, email, name, profile_image_url).
    """
    return current_user


@app.patch("/users/me", response_model=schemas.User)
async def update_user_me(
    update: schemas.UserUpdate,
    current_user: models.User = Depends(auth.get_current_user),
    db: AsyncSession = Depends(database.get_db),
):
    """Partially update the authenticated user's profile.

    Accepts a JSON body with optional fields. Only fields that are not None
    are applied, so sending `{"name": "Alice"}` only updates the name — no
    other fields are touched. Currently only `name` is supported.

    Args:
        update: Partial update payload — all fields optional.
        current_user: User resolved from the JWT bearer token dependency.
        db: Active asynchronous database session.

    Returns:
        The updated user record.
    """
    if update.name is not None:
        current_user.name = update.name.strip()
    db.add(current_user)
    await db.commit()
    await db.refresh(current_user)
    return current_user


@app.post("/users/me/avatar", response_model=schemas.User)
async def upload_avatar(
    image: UploadFile = File(...),
    current_user: models.User = Depends(auth.get_current_user),
    db: AsyncSession = Depends(database.get_db),
):
    """Upload and attach a profile avatar image for the authenticated user.

    The uploaded image is saved to the `uploads/` directory with a filename
    in the format `avatar_{user_id}_{uuid}.{ext}`, ensuring uniqueness and
    allowing the serving endpoint to distinguish avatars from recipe images.
    The relative URL `/uploads/{filename}` is persisted in `profile_image_url`.

    Supported MIME types: image/jpeg, image/png, image/webp, image/gif.

    Args:
        image: Uploaded image file submitted as multipart/form-data.
        current_user: User resolved from the JWT bearer token dependency.
        db: Active asynchronous database session.

    Returns:
        The updated user record including the new `profile_image_url`.

    Raises:
        HTTPException 400: If the uploaded content type is not supported.
    """
    allowed = {"image/jpeg", "image/png", "image/webp", "image/gif"}
    if image.content_type not in allowed:
        raise HTTPException(status_code=400, detail="Unsupported image type")

    # Preserve the file extension from the original filename.
    ext = image.filename.rsplit(".", 1)[-1] if "." in image.filename else "jpg"
    filename = f"avatar_{current_user.id}_{uuid.uuid4().hex}.{ext}"
    filepath = os.path.join(UPLOAD_DIR, filename)

    with open(filepath, "wb") as buffer:
        buffer.write(await image.read())

    # Store the relative URL — the /uploads static mount serves the actual file.
    current_user.profile_image_url = f"/uploads/{filename}"
    db.add(current_user)
    await db.commit()
    await db.refresh(current_user)
    return current_user


@app.put("/users/me", response_model=schemas.User)
async def update_users_me(
    payload: schemas.UserNameUpdate,
    current_user: models.User = Depends(auth.get_current_user),
    db: AsyncSession = Depends(database.get_db),
):
    """Replace the authenticated user's display name (PUT semantics).

    Unlike PATCH /users/me, this endpoint requires `name` to be present and
    non-empty. Used by the Flutter profile screen's rename flow.

    Args:
        payload: Request body containing the new display name.
        current_user: User resolved from the JWT bearer token dependency.
        db: Active asynchronous database session.

    Returns:
        The updated user record.

    Raises:
        HTTPException 400: If the submitted name is empty after stripping.
    """
    trimmed_name = payload.name.strip()
    if not trimmed_name:
        raise HTTPException(status_code=400, detail="Name cannot be empty")

    current_user.name = trimmed_name
    db.add(current_user)
    await db.commit()
    await db.refresh(current_user)
    return current_user


# ── Upload directory setup ────────────────────────────────────────────────────

# These imports are also at the top of the file; the duplicates here are
# harmless — Python caches module imports.
from fastapi import File, UploadFile, Form
import os
import uuid

# Directory where uploaded recipe images and profile avatars are stored.
# Created automatically if it does not exist.
UPLOAD_DIR = "uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)


# ── Recipe catalogue routes ───────────────────────────────────────────────────

@app.get("/recipes", response_model=list[schemas.Recipe])
async def list_recipes(db: AsyncSession = Depends(database.get_db)):
    """Return all non-deleted recipes for the recipe catalogue.

    Fetches every Recipe row where `is_deleted != True`, then for each recipe
    executes two additional queries to load its tags and ingredient rows.
    Nutrition totals are calculated via `_calculate_recipe_nutrition_totals()`
    and divided per serving by `_build_nutrition_info()`.

    No authentication is required — the catalogue is publicly readable.

    Args:
        db: Active asynchronous database session.

    Returns:
        A list of `schemas.Recipe` objects, each including tags, flat
        ingredient names, structured recipe_ingredients, steps, and
        per-serving nutrition.
    """
    result = await db.execute(
        select(models.Recipe).where(models.Recipe.is_deleted != True)
    )
    recipes = result.scalars().all()

    recipe_responses = []
    for r in recipes:
        # Load tags via the recipe_tag join table.
        tag_result = await db.execute(
            select(models.Tag.tag_name)
            .join(models.RecipeTag)
            .where(models.RecipeTag.recipe_id == r.recipe_id)
        )
        tags = tag_result.scalars().all()

        # Load structured ingredient rows (name + quantity + unit).
        ing_result = await db.execute(
            select(
                models.Ingredients.ingredient_name,
                models.RecipeIngredient.quantity,
                models.RecipeIngredient.unit,
            )
            .join(models.RecipeIngredient)
            .where(models.RecipeIngredient.recipe_id == r.recipe_id)
        )
        ingredient_rows = ing_result.all()

        # Build the structured list and normalise units in case legacy rows slipped through.
        recipe_ingredients = [
            {
                "ingredient_name": row[0],
                "quantity": float(row[1] or 1),
                "unit": _normalize_unit(row[2]),
            }
            for row in ingredient_rows
        ]
        # Flat name list for simpler display contexts (e.g. ingredient chips).
        ingredients = [ri["ingredient_name"] for ri in recipe_ingredients]

        # Calculate per-serving nutrition from ingredient data.
        nutrition = _build_nutrition_info(
            await _calculate_recipe_nutrition_totals(db, r.recipe_id),
            r.servings or 1,
        )

        recipe_dict = {
            "title": r.recipe_name or "",
            "summary": r.summary or "",
            "image_url": r.image_url,
            "prep_time": str(r.prep_time) if r.prep_time else "",
            "cook_time": str(r.cook_time) if r.cook_time else "",
            "total_time": "",   # Computed by the frontend from prep + cook.
            "servings": r.servings or 1,
            "difficulty": "Medium",  # Not yet stored per-recipe; defaulted here.
            "tags": tags,
            "ingredients": ingredients,
            "recipe_ingredients": recipe_ingredients,
            # Instructions are stored as a JSON string; parse back to a list.
            "steps": json.loads(r.instructions) if r.instructions else [],
            "nutrition": nutrition,
            "id": r.recipe_id,
        }
        recipe_responses.append(schemas.Recipe(**recipe_dict))

    return recipe_responses


@app.get("/ingredients", response_model=list[schemas.IngredientSearchResult])
async def search_ingredients(
    q: str = "",
    limit: int = 20,
    base_only: bool = False,
    db: AsyncSession = Depends(database.get_db),
):
    """Search ingredients by name for the recipe form autocomplete.

    Returns a list of matching ingredients ordered with base catalogue
    ingredients first (is_base=True), then alphabetically by name.

    Query parameters:
        q         : Partial name search (case-insensitive ILIKE pattern).
        limit     : Maximum results to return (clamped to 1–50).
        base_only : When true, restricts results to base catalogue ingredients
                    that have verified nutrition data.

    Args:
        q: Optional search text.
        limit: Maximum number of results to return, clamped between 1 and 50.
        base_only: When true, restricts results to base catalogue ingredients.
        db: Active asynchronous database session.

    Returns:
        Matching `schemas.IngredientSearchResult` objects ordered by base
        status then name.
    """
    trimmed_query = q.strip()

    # Clamp limit to a safe range — avoids both empty and excessively large results.
    if limit < 1:
        limit = 1
    if limit > 50:
        limit = 50

    stmt = select(models.Ingredients)

    if base_only:
        stmt = stmt.where(models.Ingredients.is_base == True)

    if trimmed_query:
        # ILIKE performs a case-insensitive substring match (%query%).
        stmt = stmt.where(models.Ingredients.ingredient_name.ilike(f"%{trimmed_query}%"))

    # Base catalogue ingredients appear first so they are prioritised in the
    # Flutter autocomplete list, then alphabetical within each group.
    stmt = stmt.order_by(
        models.Ingredients.is_base.desc(),
        models.Ingredients.ingredient_name.asc()
    )
    stmt = stmt.limit(limit)

    result = await db.execute(stmt)
    ingredients = result.scalars().all()
    return ingredients


@app.post("/recipes", response_model=schemas.Recipe)
async def create_recipe(
    db: AsyncSession = Depends(database.get_db),
    title: str = Form(...),
    summary: str = Form(...),
    prep_time: str = Form(""),
    cook_time: str = Form(""),
    total_time: str = Form(""),
    servings: int = Form(1),
    difficulty: str = Form(""),
    tags_json: str = Form("[]"),
    ingredients_json: str = Form("[]"),
    steps_json: str = Form("[]"),
    image: Optional[UploadFile] = File(None)
):
    """Create a new recipe submitted from the Flutter recipe form.

    Accepts a multipart/form-data body (required for image uploads). The
    creation pipeline is:
      1. Save the uploaded image to `uploads/` and build its URL (if present).
      2. Insert the Recipe row with metadata.
      3. Upsert and link Tag rows from `tags_json`.
      4. Parse, find/create, and link Ingredient rows from `ingredients_json`.
      5. Commit, then recalculate and store total nutrition on the Recipe row.
      6. Return the full recipe response with calculated per-serving nutrition.

    Tags are de-duplicated by converting the list to a set before processing.
    Ingredients are de-duplicated by `_parse_ingredient_payload()`.

    Args:
        db: Active asynchronous database session.
        title: Recipe title.
        summary: Short recipe description.
        prep_time: Preparation time text (e.g. "30 mins").
        cook_time: Cooking time text (e.g. "45 mins").
        total_time: Total time text (computed by frontend; not stored).
        servings: Number of servings for per-serving nutrition calculation.
        difficulty: Difficulty label (e.g. "Easy", "Medium", "Hard").
        tags_json: JSON array of tag name strings.
        ingredients_json: JSON array of ingredient strings or objects.
        steps_json: JSON array of instruction step strings.
        image: Optional uploaded recipe image (multipart file).

    Returns:
        The newly-created `schemas.Recipe` with all fields populated.
    """
    # ── Image upload ──────────────────────────────────────────────────────────
    image_url = None
    if image:
        ext = image.filename.split(".")[-1]
        filename = f"{uuid.uuid4()}.{ext}"
        filepath = os.path.join(UPLOAD_DIR, filename)
        with open(filepath, "wb") as buffer:
            buffer.write(await image.read())
        # Absolute URL used by Flutter to load the image via NetworkImage.
        image_url = f"http://localhost:8000/uploads/{filename}"

    # ── Recipe row ────────────────────────────────────────────────────────────
    # Extract the leading integer from time strings like "30 mins".
    new_recipe = models.Recipe(
        recipe_name=title,
        summary=summary,
        prep_time=int(prep_time.split()[0]) if prep_time and prep_time.split()[0].isdigit() else 0,
        cook_time=int(cook_time.split()[0]) if cook_time and cook_time.split()[0].isdigit() else 0,
        servings=servings,
        image_url=image_url,
        # Instructions are stored as a JSON string so the list structure is preserved.
        instructions=steps_json,
    )
    db.add(new_recipe)
    await db.commit()
    await db.refresh(new_recipe)

    # ── Tags ──────────────────────────────────────────────────────────────────
    # De-duplicate tag names via set conversion before inserting.
    tags = list(set(json.loads(tags_json)))
    for tag_name in tags:
        # Find existing tag or create a new one — tags are global (shared).
        res = await db.execute(select(models.Tag).where(models.Tag.tag_name == tag_name))
        tag = res.scalars().first()
        if not tag:
            tag = models.Tag(tag_name=tag_name)
            db.add(tag)
            await db.commit()
            await db.refresh(tag)

        # Link the tag to this recipe via the recipe_tag join table.
        rt = models.RecipeTag(tag_id=tag.id, recipe_id=new_recipe.recipe_id)
        db.add(rt)

    # ── Ingredients ───────────────────────────────────────────────────────────
    parsed_ingredients = _parse_ingredient_payload(ingredients_json)
    for ingredient in parsed_ingredients:
        ing_name = ingredient["ingredient_name"]
        # find_or_create_ingredient handles case-insensitive deduplication.
        ing = await _find_or_create_ingredient(db, ing_name)

        ri = models.RecipeIngredient(
            ingredient_id=ing.id,
            recipe_id=new_recipe.recipe_id,
            quantity=ingredient["quantity"],
            unit=ingredient["unit"],
        )
        db.add(ri)

    await db.commit()

    # ── Nutrition recalculation ───────────────────────────────────────────────
    # Calculate after all ingredient rows are committed so the JOIN returns data.
    totals = await _calculate_recipe_nutrition_totals(db, new_recipe.recipe_id)
    # Store total (not per-serving) nutrition on the Recipe row for reference.
    new_recipe.calories = int(round(totals["calories"]))
    new_recipe.protien  = int(round(totals["protein"]))  # legacy typo retained
    new_recipe.carbs    = int(round(totals["carbs"]))
    new_recipe.fat      = int(round(totals["fats"]))
    await db.commit()

    # ── Build response ────────────────────────────────────────────────────────
    recipe_ingredients = [
        {
            "ingredient_name": ingredient["ingredient_name"],
            "quantity": ingredient["quantity"],
            "unit": ingredient["unit"],
        }
        for ingredient in parsed_ingredients
    ]

    return {
        "title": title,
        "summary": summary,
        "image_url": image_url,
        "prep_time": prep_time,
        "cook_time": cook_time,
        "total_time": total_time,
        "servings": servings,
        "difficulty": difficulty,
        "tags": tags,
        "ingredients": [ingredient["ingredient_name"] for ingredient in parsed_ingredients],
        "recipe_ingredients": recipe_ingredients,
        "steps": json.loads(steps_json),
        "nutrition": _build_nutrition_info(totals, servings),
        "id": new_recipe.recipe_id,
    }


@app.put("/recipes/{recipe_id}", response_model=schemas.Recipe)
async def update_recipe(
    recipe_id: int,
    db: AsyncSession = Depends(database.get_db),
    title: str = Form(...),
    summary: str = Form(...),
    prep_time: str = Form(""),
    cook_time: str = Form(""),
    total_time: str = Form(""),
    servings: int = Form(1),
    difficulty: str = Form(""),
    tags_json: str = Form("[]"),
    ingredients_json: str = Form("[]"),
    steps_json: str = Form("[]"),
    image: Optional[UploadFile] = File(None),
):
    """Update an existing user-created recipe and recalculate its nutrition.

    The update strategy is a full replace of the recipe's tags and ingredients:
      1. Fetch the existing Recipe row (404 if not found).
      2. Optionally replace the image — keep the existing URL if no new image.
      3. Update all scalar fields on the Recipe row.
      4. DELETE all existing RecipeTag and RecipeIngredient rows for this recipe.
      5. Re-insert tags and ingredients from the submitted payload.
      6. Recalculate and persist total nutrition on the Recipe row.
      7. Return the updated recipe response.

    This replace-all approach avoids complex diff logic at the cost of slightly
    more database writes, which is acceptable for a single-recipe update.

    Args:
        recipe_id: ID of the recipe to update (path parameter).
        db: Active asynchronous database session.
        (remaining args) : Same form fields as `create_recipe`.

    Returns:
        The updated `schemas.Recipe`.

    Raises:
        HTTPException 404: If no recipe with `recipe_id` exists.
    """
    recipe_res = await db.execute(
        select(models.Recipe).where(models.Recipe.recipe_id == recipe_id)
    )
    recipe = recipe_res.scalars().first()
    if not recipe:
        raise HTTPException(status_code=404, detail="Recipe not found")

    # ── Image replacement ─────────────────────────────────────────────────────
    image_url = recipe.image_url  # Preserve the existing image URL by default.
    if image:
        ext = image.filename.split(".")[-1]
        filename = f"{uuid.uuid4()}.{ext}"
        filepath = os.path.join(UPLOAD_DIR, filename)
        with open(filepath, "wb") as buffer:
            buffer.write(await image.read())
        image_url = f"http://localhost:8000/uploads/{filename}"

    # ── Scalar field update ───────────────────────────────────────────────────
    recipe.recipe_name  = title
    recipe.summary      = summary
    recipe.prep_time    = int(prep_time.split()[0]) if prep_time and prep_time.split()[0].isdigit() else 0
    recipe.cook_time    = int(cook_time.split()[0]) if cook_time and cook_time.split()[0].isdigit() else 0
    recipe.servings     = servings
    recipe.image_url    = image_url
    recipe.instructions = steps_json

    # ── Replace tags and ingredients ──────────────────────────────────────────
    # Delete all existing join rows before re-inserting from the submitted payload.
    await db.execute(models.RecipeTag.__table__.delete().where(models.RecipeTag.recipe_id == recipe_id))
    await db.execute(
        models.RecipeIngredient.__table__.delete().where(models.RecipeIngredient.recipe_id == recipe_id)
    )

    tags = list(set(json.loads(tags_json)))
    for tag_name in tags:
        res = await db.execute(select(models.Tag).where(models.Tag.tag_name == tag_name))
        tag = res.scalars().first()
        if not tag:
            tag = models.Tag(tag_name=tag_name)
            db.add(tag)
            await db.commit()
            await db.refresh(tag)
        db.add(models.RecipeTag(tag_id=tag.id, recipe_id=recipe_id))

    parsed_ingredients = _parse_ingredient_payload(ingredients_json)
    for ingredient in parsed_ingredients:
        ing = await _find_or_create_ingredient(db, ingredient["ingredient_name"])
        db.add(
            models.RecipeIngredient(
                ingredient_id=ing.id,
                recipe_id=recipe_id,
                quantity=ingredient["quantity"],
                unit=ingredient["unit"],
            )
        )

    await db.commit()

    # ── Nutrition recalculation ───────────────────────────────────────────────
    totals = await _calculate_recipe_nutrition_totals(db, recipe_id)
    recipe.calories = int(round(totals["calories"]))
    recipe.protien  = int(round(totals["protein"]))  # legacy typo retained
    recipe.carbs    = int(round(totals["carbs"]))
    recipe.fat      = int(round(totals["fats"]))
    await db.commit()

    recipe_ingredients = [
        {
            "ingredient_name": ingredient["ingredient_name"],
            "quantity": ingredient["quantity"],
            "unit": ingredient["unit"],
        }
        for ingredient in parsed_ingredients
    ]

    return {
        "title": title,
        "summary": summary,
        "image_url": image_url,
        "prep_time": prep_time,
        "cook_time": cook_time,
        "total_time": total_time,
        "servings": servings,
        "difficulty": difficulty,
        "tags": tags,
        "ingredients": [ingredient["ingredient_name"] for ingredient in parsed_ingredients],
        "recipe_ingredients": recipe_ingredients,
        "steps": json.loads(steps_json),
        "nutrition": _build_nutrition_info(totals, servings),
        "id": recipe_id,
    }


@app.delete("/recipes/{recipe_id}")
async def delete_recipe(recipe_id: int, db: AsyncSession = Depends(database.get_db)):
    """Soft-delete a recipe by setting its `is_deleted` flag to True.

    The recipe is hidden from GET /recipes but remains in the database and
    appears on GET /recipes/deleted, where it can be restored or permanently
    removed. This prevents accidental data loss.

    Args:
        recipe_id: ID of the recipe to soft-delete (path parameter).
        db: Active asynchronous database session.

    Returns:
        { "message": "Success" }

    Raises:
        HTTPException 404: If the recipe ID does not exist.
    """
    res = await db.execute(select(models.Recipe).where(models.Recipe.recipe_id == recipe_id))
    recipe = res.scalars().first()
    if not recipe:
        raise HTTPException(status_code=404, detail="Recipe not found")

    # Soft-delete: mark as hidden rather than issuing a DELETE statement.
    recipe.is_deleted = True
    await db.commit()
    return {"message": "Success"}


@app.get("/recipes/deleted", response_model=list[schemas.Recipe])
async def list_deleted_recipes(db: AsyncSession = Depends(database.get_db)):
    """Return all recipes that have been soft-deleted.

    Used by the Flutter Deleted Recipes screen, which lets the user restore
    a recipe to the main catalogue or permanently erase it. The response
    shape is identical to GET /recipes so the same Flutter model is reused.

    Args:
        db: Active asynchronous database session.

    Returns:
        A list of soft-deleted `schemas.Recipe` objects with full nutrition
        and ingredient data.
    """
    result = await db.execute(
        select(models.Recipe).where(models.Recipe.is_deleted == True)
    )
    recipes = result.scalars().all()

    recipe_responses = []
    for r in recipes:
        # Load tags for the deleted recipe.
        tag_result = await db.execute(
            select(models.Tag.tag_name)
            .join(models.RecipeTag)
            .where(models.RecipeTag.recipe_id == r.recipe_id)
        )
        tags = tag_result.scalars().all()

        # Load structured ingredient rows.
        ing_result = await db.execute(
            select(
                models.Ingredients.ingredient_name,
                models.RecipeIngredient.quantity,
                models.RecipeIngredient.unit,
            )
            .join(models.RecipeIngredient)
            .where(models.RecipeIngredient.recipe_id == r.recipe_id)
        )
        ingredient_rows = ing_result.all()
        recipe_ingredients = [
            {
                "ingredient_name": row[0],
                "quantity": float(row[1] or 1),
                "unit": _normalize_unit(row[2]),
            }
            for row in ingredient_rows
        ]

        nutrition = _build_nutrition_info(
            await _calculate_recipe_nutrition_totals(db, r.recipe_id),
            r.servings or 1,
        )

        recipe_responses.append(schemas.Recipe(**{
            "title": r.recipe_name or "",
            "summary": r.summary or "",
            "image_url": r.image_url,
            "prep_time": str(r.prep_time) if r.prep_time else "",
            "cook_time": str(r.cook_time) if r.cook_time else "",
            "total_time": "",
            "servings": r.servings or 1,
            "difficulty": "Medium",
            "tags": tags,
            "ingredients": [ri["ingredient_name"] for ri in recipe_ingredients],
            "recipe_ingredients": recipe_ingredients,
            "steps": json.loads(r.instructions) if r.instructions else [],
            "nutrition": nutrition,
            "id": r.recipe_id,
        }))

    return recipe_responses


@app.post("/recipes/{recipe_id}/restore")
async def restore_recipe(recipe_id: int, db: AsyncSession = Depends(database.get_db)):
    """Restore a soft-deleted recipe to the main catalogue.

    Clears the `is_deleted` flag so the recipe reappears on GET /recipes and
    disappears from GET /recipes/deleted. No data is changed other than the flag.

    Args:
        recipe_id: ID of the recipe to restore (path parameter).
        db: Active asynchronous database session.

    Returns:
        { "message": "Restored" }

    Raises:
        HTTPException 404: If the recipe ID does not exist.
    """
    res = await db.execute(select(models.Recipe).where(models.Recipe.recipe_id == recipe_id))
    recipe = res.scalars().first()
    if not recipe:
        raise HTTPException(status_code=404, detail="Recipe not found")

    recipe.is_deleted = False
    await db.commit()
    return {"message": "Restored"}


@app.delete("/recipes/{recipe_id}/permanent")
async def permanent_delete_recipe(recipe_id: int, db: AsyncSession = Depends(database.get_db)):
    """Permanently delete a recipe and all related rows from the database.

    Cascades deletes to RecipeTag and RecipeIngredient rows via SQLite
    foreign-key constraints (if enabled) or by the ORM cascade settings.
    This action is irreversible — unlike the soft-delete, there is no restore.

    Args:
        recipe_id: ID of the recipe to permanently remove (path parameter).
        db: Active asynchronous database session.

    Returns:
        { "message": "Permanently deleted" }

    Raises:
        HTTPException 404: If the recipe ID does not exist.
    """
    res = await db.execute(select(models.Recipe).where(models.Recipe.recipe_id == recipe_id))
    recipe = res.scalars().first()
    if not recipe:
        raise HTTPException(status_code=404, detail="Recipe not found")

    # `db.delete()` issues a SQL DELETE statement and cascades to related rows.
    await db.delete(recipe)
    await db.commit()
    return {"message": "Permanently deleted"}


# ── Static file serving ───────────────────────────────────────────────────────

from fastapi.staticfiles import StaticFiles

# Mount the uploads directory as a static file route so Flutter can load
# recipe images and avatar images via `http://localhost:8000/uploads/<filename>`.
# This must be mounted AFTER all route definitions to avoid shadowing API routes.
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")
