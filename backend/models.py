from sqlalchemy import Column, Integer, String, Boolean, Float
from database import Base

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True)
    hashed_password = Column(String)
    is_active = Column(Boolean, default=True)

class Ingredients(Base):
    __tablename__ = "ingredients"

    id = Column(Integer, primary_key=True, index=True)
    ingredient_name = Column(String, index=True)
    avg_calories = Column(Integer)
    avg_protein = Column(Integer)
    avg_carbs = Column(Integer)
    avg_fat = Column(Integer)
    avg_cost = Column(Float)

class RecipeComplexity(Base):
    __tablename__ = "recipe_complexity"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)
    time_passed = Column(Integer, index=True)

class Preference(Base):
    __tablename__ = "preference"

    preference_id = Column(Integer, primary_key=True, index=True)
    preference_name = Column(String)
    like = Column(Integer)
