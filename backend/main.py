from typing import Optional

from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from datetime import timedelta

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

@app.on_event("startup")
async def startup():
    async with engine.begin() as conn:
        await conn.run_sync(models.Base.metadata.create_all)

import json
from datetime import datetime

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

import json
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
            select(models.Ingredients.ingredient_name).join(models.RecipeIngredient).where(models.RecipeIngredient.recipe_id == r.recipe_id)
        )
        ingredients = ing_result.scalars().all()

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

    ingredients = list(set(json.loads(ingredients_json)))
    for ing_name in ingredients:
        res = await db.execute(select(models.Ingredients).where(models.Ingredients.ingredient_name == ing_name))
        ing = res.scalars().first()
        if not ing:
            ing = models.Ingredients(ingredient_name=ing_name)
            db.add(ing)
            await db.commit()
            await db.refresh(ing)

        ri = models.RecipeIngredient(ingredient_id=ing.id, recipe_id=new_recipe.recipe_id, quantity=1, unit="ea")
        db.add(ri)

    await db.commit()

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
        "ingredients": ingredients,
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
