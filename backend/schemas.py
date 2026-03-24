from pydantic import BaseModel, EmailStr
from typing import Optional
from enum import Enum


class UnitEnum(str, Enum):
    tsp = "tsp"
    tbsp = "tbsp"
    cup = "cup"
    ml = "ml"
    l = "l"
    g = "g"
    kg = "kg"
    oz = "oz"
    lb = "lb"
    pcs = "pcs"

class Token(BaseModel):
    access_token: str
    token_type: str

class TokenData(BaseModel):
    email: Optional[str] = None

class UserBase(BaseModel):
    email: EmailStr

class UserCreate(UserBase):
    password: str

class UserLogin(UserBase):
    password: str

class User(UserBase):
    id: int
    is_active: bool

    class Config:
        from_attributes = True

class NutritionInfo(BaseModel):
    calories: int
    protein: str
    carbs: str
    fats: str


class RecipeIngredientItem(BaseModel):
    ingredient_name: str
    quantity: float
    unit: UnitEnum


class IngredientSearchResult(BaseModel):
    id: int
    ingredient_name: str
    is_base: bool = False

    class Config:
        from_attributes = True

class RecipeBase(BaseModel):
    title: str
    summary: str
    image_url: Optional[str] = None
    prep_time: str
    cook_time: str
    total_time: str
    servings: int
    difficulty: str
    tags: list[str] = []
    ingredients: list[str] = []
    recipe_ingredients: list[RecipeIngredientItem] = []
    steps: list[str] = []
    nutrition: Optional[NutritionInfo] = None

class RecipeCreate(RecipeBase):
    pass

class Recipe(RecipeBase):
    id: int

    class Config:
        from_attributes = True
