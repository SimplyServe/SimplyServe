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

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  
    allow_credentials=True,
    allow_methods=["*"],  
    allow_headers=["*"],  
)

RECIPE_INGREDIENTS = {
    "Tuscan Salmon": [
        "2 salmon fillets",
        "1 cup heavy cream",
        "1 cup fresh spinach",
        "1/2 cup sun-dried tomatoes",
        "4 garlic cloves, minced",
        "1 tbsp olive oil",
        "1 tsp Italian seasoning",
        "Salt and pepper to taste",
        "Grated Parmesan cheese, to serve",
    ],
    "Carbonara": [
        "400g spaghetti",
        "200g pancetta or guanciale",
        "4 large eggs",
        "100g Pecorino Romano, grated",
        "50g Parmesan, grated",
        "2 garlic cloves",
        "2 tbsp olive oil",
        "Black pepper to taste",
        "Salt for pasta water",
    ],
    "Chicken Tacos": [
        "500g chicken breast, sliced",
        "8 small flour tortillas",
        "1 tsp cumin",
        "1 tsp smoked paprika",
        "1/2 tsp chilli powder",
        "2 limes, juiced",
        "1 cup fresh salsa",
        "1/2 cup sour cream",
        "1 avocado, sliced",
        "Fresh coriander, to serve",
    ],
}

VALID_UNITS = {unit.value for unit in schemas.UnitEnum}
BASE_INGREDIENTS_FILE = Path(__file__).resolve().parent / "data" / "base_ingredients.json"

UNIT_ALIASES = {
    "tsp": "tsp",
    "teaspoon": "tsp",
    "teaspoons": "tsp",
    "tbsp": "tbsp",
    "tablespoon": "tbsp",
    "tablespoons": "tbsp",
    "cup": "cup",
    "cups": "cup",
    "ml": "ml",
    "milliliter": "ml",
    "milliliters": "ml",
    "millilitre": "ml",
    "millilitres": "ml",
    "l": "l",
    "liter": "l",
    "liters": "l",
    "litre": "l",
    "litres": "l",
    "g": "g",
    "gram": "g",
    "grams": "g",
    "kg": "kg",
    "kilogram": "kg",
    "kilograms": "kg",
    "oz": "oz",
    "ounce": "oz",
    "ounces": "oz",
    "lb": "lb",
    "lbs": "lb",
    "pound": "lb",
    "pounds": "lb",
    "pcs": "pcs",
    "pc": "pcs",
    "piece": "pcs",
    "pieces": "pcs",
    "ea": "pcs",
}

_LEADING_AMOUNT_PATTERN = re.compile(
    r"^\s*(?P<qty>\d+\s+\d+/\d+|\d+/\d+|\d+(?:\.\d+)?)\s*(?P<unit>[A-Za-z]+)?\s+(?P<name>.+)$"
)


def _normalize_ingredient_name(name: str) -> str:
    return " ".join(name.strip().lower().split())


def _parse_quantity(value: str) -> float:
    cleaned = value.strip()
    if " " in cleaned and "/" in cleaned:
        whole, fraction = cleaned.split(" ", 1)
        return float(int(whole) + Fraction(fraction))
    if "/" in cleaned:
        return float(Fraction(cleaned))
    return float(cleaned)


def _normalize_unit(value: Optional[str]) -> str:
    unit = (value or "pcs").strip().lower()
    canonical = UNIT_ALIASES.get(unit)
    if canonical is None:
        raise HTTPException(
            status_code=422,
            detail=f"Invalid unit '{unit}'. Allowed values: {', '.join(sorted(VALID_UNITS))}",
        )
    return canonical


def _parse_ingredient_text(raw: str) -> dict:
    text = raw.strip()
    if not text:
        return {"ingredient_name": "", "quantity": 1.0, "unit": "pcs", "parsed_prefix": False}

    match = _LEADING_AMOUNT_PATTERN.match(text)
    if not match:
        return {
            "ingredient_name": text,
            "quantity": 1.0,
            "unit": "pcs",
            "parsed_prefix": False,
        }

    quantity = _parse_quantity(match.group("qty"))
    unit_token = (match.group("unit") or "").lower()
    name_tail = match.group("name").strip()
    canonical_unit = UNIT_ALIASES.get(unit_token)

    if canonical_unit:
        ingredient_name = name_tail
        unit = canonical_unit
    else:
        ingredient_name = f"{unit_token} {name_tail}".strip() if unit_token else name_tail
        unit = "pcs"

    return {
        "ingredient_name": ingredient_name,
        "quantity": quantity,
        "unit": unit,
        "parsed_prefix": True,
    }


async def _find_or_create_ingredient(db: AsyncSession, ingredient_name: str) -> models.Ingredients:
    normalized_name = _normalize_ingredient_name(ingredient_name)
    res = await db.execute(
        select(models.Ingredients).where(models.Ingredients.normalized_name == normalized_name)
    )
    ingredient = res.scalars().first()
    if ingredient:
        if ingredient.ingredient_name != ingredient_name:
            ingredient.ingredient_name = ingredient_name
            await db.commit()
        return ingredient

    ingredient = models.Ingredients(
        ingredient_name=ingredient_name,
        normalized_name=normalized_name,
        is_base=False,
    )
    db.add(ingredient)
    await db.commit()
    await db.refresh(ingredient)
    return ingredient


async def _ensure_ingredient_table_columns() -> None:
    async with engine.begin() as conn:
        table_info = await conn.execute(text("PRAGMA table_info(ingredients)"))
        columns = {row[1] for row in table_info.fetchall()}

        if "normalized_name" not in columns:
            await conn.execute(text("ALTER TABLE ingredients ADD COLUMN normalized_name VARCHAR"))
        if "is_base" not in columns:
            await conn.execute(text("ALTER TABLE ingredients ADD COLUMN is_base BOOLEAN NOT NULL DEFAULT 0"))


async def _seed_base_ingredients_catalog(db: AsyncSession) -> None:
    if not BASE_INGREDIENTS_FILE.exists():
        return

    raw_content = BASE_INGREDIENTS_FILE.read_text(encoding="utf-8").strip()
    if not raw_content:
        return

    try:
        payload = json.loads(raw_content)
    except json.JSONDecodeError as exc:
        raise RuntimeError("Invalid JSON in base ingredients catalog") from exc

    if not isinstance(payload, list):
        raise RuntimeError("Base ingredients catalog must be a JSON array")

    for item in payload:
        if not isinstance(item, dict):
            continue

        ingredient_name = str(item.get("ingredient_name") or item.get("name") or "").strip()
        if not ingredient_name:
            continue

        avg_calories = item.get("avg_calories")
        avg_protein = item.get("avg_protein")
        avg_carbs = item.get("avg_carbs")
        avg_fat = item.get("avg_fat")
        avg_cost = item.get("avg_cost")

        if avg_calories is not None:
            avg_calories = int(avg_calories)
        if avg_protein is not None:
            avg_protein = int(avg_protein)
        if avg_carbs is not None:
            avg_carbs = int(avg_carbs)
        if avg_fat is not None:
            avg_fat = int(avg_fat)
        if avg_cost is not None:
            avg_cost = float(avg_cost)

        normalized_name = _normalize_ingredient_name(ingredient_name)
        res = await db.execute(
            select(models.Ingredients).where(models.Ingredients.normalized_name == normalized_name)
        )
        ingredient = res.scalars().first()

        if ingredient:
            ingredient.ingredient_name = ingredient_name
            ingredient.is_base = True
            ingredient.avg_calories = avg_calories
            ingredient.avg_protein = avg_protein
            ingredient.avg_carbs = avg_carbs
            ingredient.avg_fat = avg_fat
            ingredient.avg_cost = avg_cost
        else:
            ingredient = models.Ingredients(
                ingredient_name=ingredient_name,
                normalized_name=normalized_name,
                is_base=True,
                avg_calories=avg_calories,
                avg_protein=avg_protein,
                avg_carbs=avg_carbs,
                avg_fat=avg_fat,
                avg_cost=avg_cost,
            )
            db.add(ingredient)

    await db.commit()


async def _normalize_existing_ingredient_data(db: AsyncSession) -> None:
    ingredients_res = await db.execute(select(models.Ingredients))
    for ingredient in ingredients_res.scalars().all():
        ingredient.normalized_name = _normalize_ingredient_name(ingredient.ingredient_name or "")
        if ingredient.is_base is None:
            ingredient.is_base = False

    rows_res = await db.execute(
        select(models.RecipeIngredient, models.Ingredients)
        .join(models.Ingredients, models.Ingredients.id == models.RecipeIngredient.ingredient_id)
    )
    rows = rows_res.all()

    for recipe_ingredient, ingredient in rows:
        parsed = _parse_ingredient_text(ingredient.ingredient_name or "")
        if not parsed["parsed_prefix"]:
            continue

        target_name = parsed["ingredient_name"]
        if not target_name:
            continue

        target_ingredient = await _find_or_create_ingredient(db, target_name)

        if target_ingredient.id != recipe_ingredient.ingredient_id:
            dup_res = await db.execute(
                select(models.RecipeIngredient).where(
                    models.RecipeIngredient.recipe_id == recipe_ingredient.recipe_id,
                    models.RecipeIngredient.ingredient_id == target_ingredient.id,
                )
            )
            duplicate = dup_res.scalars().first()
            if duplicate:
                duplicate_unit = (duplicate.unit or "pcs").lower()
                if (duplicate.quantity is None or float(duplicate.quantity) == 1.0) and duplicate_unit in {
                    "pcs",
                    "ea",
                    "piece",
                    "pieces",
                }:
                    duplicate.quantity = parsed["quantity"]
                    duplicate.unit = parsed["unit"]
                await db.delete(recipe_ingredient)
                continue

            recipe_ingredient.ingredient_id = target_ingredient.id

        recipe_ingredient.quantity = parsed["quantity"]
        recipe_ingredient.unit = parsed["unit"]

    all_ingredients_res = await db.execute(select(models.Ingredients))
    all_ingredients = all_ingredients_res.scalars().all()
    for ingredient in all_ingredients:
        parsed = _parse_ingredient_text(ingredient.ingredient_name or "")
        if not parsed["parsed_prefix"]:
            continue

        has_recipe_ref_res = await db.execute(
            select(models.RecipeIngredient).where(models.RecipeIngredient.ingredient_id == ingredient.id)
        )
        has_shopping_ref_res = await db.execute(
            select(models.ShoppingListIngredient).where(
                models.ShoppingListIngredient.ingredient_id == ingredient.id
            )
        )
        has_pantry_ref_res = await db.execute(
            select(models.UserPantry).where(models.UserPantry.ingredient_id == ingredient.id)
        )

        if (
            has_recipe_ref_res.scalars().first() is None
            and has_shopping_ref_res.scalars().first() is None
            and has_pantry_ref_res.scalars().first() is None
        ):
            await db.delete(ingredient)

    await db.commit()

@app.on_event("startup")
async def startup():
    async with engine.begin() as conn:
        await conn.run_sync(models.Base.metadata.create_all)

    await _ensure_ingredient_table_columns()

    async with database.AsyncSessionLocal() as db:
        await _seed_base_ingredients_catalog(db)

        for recipe_name, ing_list in RECIPE_INGREDIENTS.items():
            res = await db.execute(select(models.Recipe).where(models.Recipe.recipe_name == recipe_name))
            recipe = res.scalars().first()
            if not recipe:
                continue

            existing = await db.execute(
                select(models.RecipeIngredient).where(models.RecipeIngredient.recipe_id == recipe.recipe_id)
            )
            if existing.scalars().first():
                continue

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

        # Correct legacy rows where amount/unit were embedded in ingredient_name.
        await _normalize_existing_ingredient_data(db)


def _parse_ingredient_payload(ingredients_json: str) -> list[dict]:
    try:
        payload = json.loads(ingredients_json)
    except json.JSONDecodeError as exc:
        raise HTTPException(status_code=422, detail="ingredients_json must be valid JSON") from exc

    if not isinstance(payload, list):
        raise HTTPException(status_code=422, detail="ingredients_json must be a JSON array")

    parsed: list[dict] = []
    seen: set[str] = set()
    for item in payload:
        name: Optional[str] = None
        quantity: float = 1.0
        unit: str = "pcs"

        if isinstance(item, str):
            parsed_item = _parse_ingredient_text(item)
            name = parsed_item["ingredient_name"]
            quantity = parsed_item["quantity"]
            unit = parsed_item["unit"]
        elif isinstance(item, dict):
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
            continue
        if quantity <= 0:
            raise HTTPException(status_code=422, detail=f"Quantity must be greater than 0 for ingredient '{name}'")

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

async def seed_user_data(user_id: int, db: AsyncSession):

    res = await db.execute(select(models.Recipe))
    recipes = res.scalars().all()
    if not recipes:
        r1 = models.Recipe(
            recipe_name="Tuscan Salmon", 
            summary="Delicious creamy salmon with spinach and sun-dried tomatoes.", 
            instructions=json.dumps(["Season salmon.", "Pan fry for 5 mins.", "Make cream sauce."]), 
            prep_time=10, 
            cook_time=20, 
            servings=2, 
            image_url="https://images.unsplash.com/photo-1467003909585-2f8a72700288?w=800"
        )
        r2 = models.Recipe(
            recipe_name="Carbonara", 
            summary="Classic Italian pasta dish with eggs, cheese, pancetta and pepper.", 
            instructions=json.dumps(["Boil pasta.", "Fry pancetta.", "Mix eggs and cheese.", "Combine."]), 
            prep_time=10, 
            cook_time=15, 
            servings=4, 
            image_url="https://images.unsplash.com/photo-1612874742237-6526221588e3?w=800"
        )
        r3 = models.Recipe(
            recipe_name="Chicken Tacos", 
            summary="Spicy, zesty chicken tacos with fresh salsa.", 
            instructions=json.dumps(["Marinate chicken.", "Grill chicken.", "Assemble tacos."]), 
            prep_time=20, 
            cook_time=15, 
            servings=3, 
            image_url="https://images.unsplash.com/photo-1565299585323-38d6b0865b47?w=800"
        )
        db.add_all([r1, r2, r3])
        await db.commit()
        await db.refresh(r1)
        await db.refresh(r2)
        await db.refresh(r3)
        recipes = [r1, r2, r3]

    for r in recipes[:3]:

        rid = r.recipe_id
        rname = r.recipe_name

        existing_res = await db.execute(select(models.SavedRecipe).where(
            models.SavedRecipe.user_id == user_id, 
            models.SavedRecipe.recipe_id == rid
        ))
        if not existing_res.scalars().first():
            sr = models.SavedRecipe(
                user_id=user_id,
                recipe_id=rid,
                recipe_name=rname,
                user_notes="Recommended by SimplyServe"
            )
            db.add(sr)

    sl = models.ShoppingList(user_id=user_id, created_at=datetime.now().isoformat())
    db.add(sl)

    await db.commit()

@app.post("/register", response_model=schemas.User)
async def create_user(user: schemas.UserCreate, db: AsyncSession = Depends(database.get_db)):
    result = await db.execute(select(models.User).where(models.User.email == user.email))
    db_user = result.scalars().first()
    if db_user:
        raise HTTPException(status_code=400, detail="Email already registered")

    hashed_password = auth.get_password_hash(user.password)
    new_user = models.User(email=user.email, hashed_password=hashed_password)
    db.add(new_user)
    await db.commit()
    await db.refresh(new_user)

    await seed_user_data(new_user.id, db)

    return new_user

@app.post("/token", response_model=schemas.Token)
async def login_for_access_token(form_data: OAuth2PasswordRequestForm = Depends(), db: AsyncSession = Depends(database.get_db)):
    result = await db.execute(select(models.User).where(models.User.email == form_data.username))
    user = result.scalars().first()
    if not user or not auth.verify_password(form_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    access_token_expires = timedelta(minutes=auth.ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = auth.create_access_token(
        data={"sub": user.email}, expires_delta=access_token_expires
    )
    return {"access_token": access_token, "token_type": "bearer"}

@app.get("/users/me", response_model=schemas.User)
async def read_users_me(current_user: models.User = Depends(auth.get_current_user)):
    return current_user

from fastapi import File, UploadFile, Form
import os
import uuid

UPLOAD_DIR = "uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)

@app.get("/recipes", response_model=list[schemas.Recipe])
async def list_recipes(db: AsyncSession = Depends(database.get_db)):
    result = await db.execute(select(models.Recipe))
    recipes = result.scalars().all()

    recipe_responses = []
    for r in recipes:

        tag_result = await db.execute(
            select(models.Tag.tag_name).join(models.RecipeTag).where(models.RecipeTag.recipe_id == r.recipe_id)
        )
        tags = tag_result.scalars().all()

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
        ingredients = [ri["ingredient_name"] for ri in recipe_ingredients]

        recipe_dict = {
            "title": r.recipe_name or "",
            "summary": r.summary or "",
            "image_url": r.image_url,
            "prep_time": str(r.prep_time) if r.prep_time else "",
            "cook_time": str(r.cook_time) if r.cook_time else "",
            "total_time": "", 
            "servings": r.servings or 1,
            "difficulty": "Medium", 
            "tags": tags,
            "ingredients": ingredients,
            "recipe_ingredients": recipe_ingredients,
            "steps": json.loads(r.instructions) if r.instructions else [],
            "nutrition": schemas.NutritionInfo(
                calories=r.calories or 0,
                protein=f"{r.protien or 0}g",
                carbs=f"{r.carbs or 0}g",
                fats=f"{r.fat or 0}g"
            ) if r.calories else None,
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
    trimmed_query = q.strip()
    if limit < 1:
        limit = 1
    if limit > 50:
        limit = 50

    stmt = select(models.Ingredients)
    if base_only:
        stmt = stmt.where(models.Ingredients.is_base == True)
    if trimmed_query:
        stmt = stmt.where(models.Ingredients.ingredient_name.ilike(f"%{trimmed_query}%"))

    stmt = stmt.order_by(models.Ingredients.is_base.desc(), models.Ingredients.ingredient_name.asc())
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
    image_url = None
    if image:
        ext = image.filename.split(".")[-1]
        filename = f"{uuid.uuid4()}.{ext}"
        filepath = os.path.join(UPLOAD_DIR, filename)
        with open(filepath, "wb") as buffer:
            buffer.write(await image.read())

        image_url = f"http://localhost:8000/uploads/{filename}"

    new_recipe = models.Recipe(
        recipe_name=title,
        summary=summary,
        prep_time=int(prep_time.split()[0]) if prep_time and prep_time.split()[0].isdigit() else 0,
        cook_time=int(cook_time.split()[0]) if cook_time and cook_time.split()[0].isdigit() else 0,
        servings=servings,
        image_url=image_url,
        instructions=steps_json  
    )
    db.add(new_recipe)
    await db.commit()
    await db.refresh(new_recipe)

    tags = list(set(json.loads(tags_json)))
    for tag_name in tags:

        res = await db.execute(select(models.Tag).where(models.Tag.tag_name == tag_name))
        tag = res.scalars().first()
        if not tag:
            tag = models.Tag(tag_name=tag_name)
            db.add(tag)
            await db.commit()
            await db.refresh(tag)

        rt = models.RecipeTag(tag_id=tag.id, recipe_id=new_recipe.recipe_id)
        db.add(rt)

    parsed_ingredients = _parse_ingredient_payload(ingredients_json)
    for ingredient in parsed_ingredients:
        ing_name = ingredient["ingredient_name"]
        ing = await _find_or_create_ingredient(db, ing_name)

        ri = models.RecipeIngredient(
            ingredient_id=ing.id,
            recipe_id=new_recipe.recipe_id,
            quantity=ingredient["quantity"],
            unit=ingredient["unit"],
        )
        db.add(ri)

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
        "nutrition": None,
        "id": new_recipe.recipe_id,
    }

@app.delete("/recipes/{recipe_id}")
async def delete_recipe(recipe_id: int, db: AsyncSession = Depends(database.get_db)):
    res = await db.execute(select(models.Recipe).where(models.Recipe.recipe_id == recipe_id))
    recipe = res.scalars().first()
    if not recipe:
        raise HTTPException(status_code=404, detail="Recipe not found")

    await db.execute(models.RecipeTag.__table__.delete().where(models.RecipeTag.recipe_id == recipe_id))
    await db.execute(models.RecipeIngredient.__table__.delete().where(models.RecipeIngredient.recipe_id == recipe_id))

    await db.delete(recipe)
    await db.commit()
    return {"message": "Success"}

from fastapi.staticfiles import StaticFiles
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")
