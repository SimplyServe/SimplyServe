from pydantic import BaseModel, EmailStr
from typing import Optional

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
    steps: list[str] = []
    nutrition: Optional[NutritionInfo] = None

class RecipeCreate(RecipeBase):
    pass

class Recipe(RecipeBase):
    id: int

    class Config:
        from_attributes = True
