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

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

def _normalize_unit(unit: str) -> str:
    unit = (unit or "").strip().lower()
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
    # If still not a valid UnitEnum value, fall back to pcs
    valid = {"tsp", "tbsp", "cup", "ml", "l", "g", "kg", "oz", "lb", "pcs"}
    return normalized if normalized in valid else "pcs"


def _parse_ingredient_text(raw: str) -> dict:
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

    match = re.match(r'^([\d\s/]+)\s+([a-zA-Z]+)\s+(.+)$', raw)
    if match:
        qty_str, unit_str, name = match.groups()
        try:
            quantity = float(Fraction(qty_str.strip()))
        except (ValueError, ZeroDivisionError):
            quantity = 1.0
        if unit_str.lower() in known_units:
            unit = _normalize_unit(unit_str)
            ingredient_name = name.split(",")[0].strip()
        else:
            ingredient_name = (unit_str + " " + name).split(",")[0].strip()
    else:
        match2 = re.match(r'^([\d/]+)\s+(.+)$', raw)
        if match2:
            qty_str, name = match2.groups()
            try:
                quantity = float(Fraction(qty_str.strip()))
            except (ValueError, ZeroDivisionError):
                quantity = 1.0
            ingredient_name = name.split(",")[0].strip()
        else:
            ingredient_name = raw.split(",")[0].strip()

    return {"ingredient_name": ingredient_name, "quantity": quantity, "unit": unit}


async def _find_or_create_ingredient(db: AsyncSession, name: str) -> models.Ingredients:
    normalized = name.strip().lower()
    res = await db.execute(
        select(models.Ingredients).where(models.Ingredients.normalized_name == normalized)
    )
    ing = res.scalars().first()
    if not ing:
        ing = models.Ingredients(
            ingredient_name=name.strip(),
            normalized_name=normalized,
            is_base=False,
        )
        db.add(ing)
        await db.flush()
    return ing


async def _seed_base_ingredients_catalog(db: AsyncSession):
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
    valid = {"tsp", "tbsp", "cup", "ml", "l", "g", "kg", "oz", "lb", "pcs"}
    result = await db.execute(select(models.RecipeIngredient))
    rows = result.scalars().all()
    for row in rows:
        normalized = _normalize_unit(row.unit or "")
        if normalized != row.unit:
            row.unit = normalized
    await db.commit()


async def _ensure_ingredient_table_columns():
    async with engine.begin() as conn:
        try:
            await conn.execute(text(
                "ALTER TABLE recipe ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0"
            ))
        except Exception:
            pass
        for col, col_type in [("quantity", "REAL"), ("unit", "TEXT")]:
            try:
                await conn.execute(text(f"ALTER TABLE recipe_ingredient ADD COLUMN {col} {col_type}"))
            except Exception:
                pass
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
        # Backfill normalized_name for any existing rows that have it null
        await conn.execute(text(
            "UPDATE ingredients SET normalized_name = LOWER(ingredient_name) WHERE normalized_name IS NULL"
        ))


async def _calculate_recipe_nutrition_totals(db: AsyncSession, recipe_id: int) -> dict:
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
        qty = qty or 1.0
        if cal: totals["calories"] += cal * qty
        if prot: totals["protein"] += prot * qty
        if carbs: totals["carbs"] += carbs * qty
        if fat: totals["fats"] += fat * qty
    return totals


def _build_nutrition_info(totals: dict, servings: int) -> dict:
    s = max(servings, 1)
    return {
        "calories": int(round(totals["calories"] / s)),
        "protein": f"{int(round(totals['protein'] / s))}g",
        "carbs": f"{int(round(totals['carbs'] / s))}g",
        "fats": f"{int(round(totals['fats'] / s))}g",
    }


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

    # await seed_user_data(new_user.id, db)

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
    result = await db.execute(
        select(models.Recipe).where(models.Recipe.is_deleted != True)
    )
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
            "total_time": "", 
            "servings": r.servings or 1,
            "difficulty": "Medium", 
            "tags": tags,
            "ingredients": ingredients,
            "recipe_ingredients": recipe_ingredients,
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

    totals = await _calculate_recipe_nutrition_totals(db, new_recipe.recipe_id)
    new_recipe.calories = int(round(totals["calories"]))
    new_recipe.protien = int(round(totals["protein"]))
    new_recipe.carbs = int(round(totals["carbs"]))
    new_recipe.fat = int(round(totals["fats"]))
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
    recipe_res = await db.execute(
        select(models.Recipe).where(models.Recipe.recipe_id == recipe_id)
    )
    recipe = recipe_res.scalars().first()
    if not recipe:
        raise HTTPException(status_code=404, detail="Recipe not found")

    image_url = recipe.image_url
    if image:
        ext = image.filename.split(".")[-1]
        filename = f"{uuid.uuid4()}.{ext}"
        filepath = os.path.join(UPLOAD_DIR, filename)
        with open(filepath, "wb") as buffer:
            buffer.write(await image.read())
        image_url = f"http://localhost:8000/uploads/{filename}"

    recipe.recipe_name = title
    recipe.summary = summary
    recipe.prep_time = int(prep_time.split()[0]) if prep_time and prep_time.split()[0].isdigit() else 0
    recipe.cook_time = int(cook_time.split()[0]) if cook_time and cook_time.split()[0].isdigit() else 0
    recipe.servings = servings
    recipe.image_url = image_url
    recipe.instructions = steps_json

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

    totals = await _calculate_recipe_nutrition_totals(db, recipe_id)
    recipe.calories = int(round(totals["calories"]))
    recipe.protien = int(round(totals["protein"]))
    recipe.carbs = int(round(totals["carbs"]))
    recipe.fat = int(round(totals["fats"]))
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
    res = await db.execute(select(models.Recipe).where(models.Recipe.recipe_id == recipe_id))
    recipe = res.scalars().first()
    if not recipe:
        raise HTTPException(status_code=404, detail="Recipe not found")
    recipe.is_deleted = True
    await db.commit()
    return {"message": "Success"}


@app.get("/recipes/deleted", response_model=list[schemas.Recipe])
async def list_deleted_recipes(db: AsyncSession = Depends(database.get_db)):
    result = await db.execute(
        select(models.Recipe).where(models.Recipe.is_deleted == True)
    )
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
    res = await db.execute(select(models.Recipe).where(models.Recipe.recipe_id == recipe_id))
    recipe = res.scalars().first()
    if not recipe:
        raise HTTPException(status_code=404, detail="Recipe not found")
    recipe.is_deleted = False
    await db.commit()
    return {"message": "Restored"}

from fastapi.staticfiles import StaticFiles
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")
