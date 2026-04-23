from sqlalchemy import Column, Integer, String, Boolean, Float, ForeignKey
from sqlalchemy.orm import relationship
from database import Base

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True)
    name = Column(String, nullable=True)
    hashed_password = Column(String)
    is_active = Column(Boolean, default=True)
    name = Column(String, nullable=True)
    profile_image_url = Column(String, nullable=True)

    shopping_lists = relationship("ShoppingList", back_populates="user", cascade="all, delete-orphan")
    meals = relationship("Meals", back_populates="user", cascade="all, delete-orphan")
    saved_recipes = relationship("SavedRecipe", back_populates="user", cascade="all, delete-orphan")

class Ingredients(Base):
    __tablename__ = "ingredients"

    id = Column(Integer, primary_key=True, index=True)
    ingredient_name = Column(String, index=True)
    normalized_name = Column(String, index=True)
    is_base = Column(Boolean, default=False, nullable=False)
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

class ShoppingList(Base):
    __tablename__ = "shopping_list"

    shopping_list_id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), index=True)
    created_at = Column(String)

    user = relationship("User", back_populates="shopping_lists")

class Meals(Base):
    __tablename__ = "meals"

    meal_id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), index=True)
    planned_date = Column(String)
    stage = Column(String, index=True)

    user = relationship("User", back_populates="meals")

class Recipe(Base):
    __tablename__ = "recipe"
    recipe_id = Column(Integer, primary_key=True, index=True)
    complexity_id = Column(Integer, ForeignKey("recipe_complexity.id"))
    recipe_name = Column(String)
    cuisine = Column(String)
    prep_time = Column(Integer)
    cost_estimate = Column(Integer)
    calories = Column(Integer)
    protien = Column(Integer)
    carbs = Column(Integer)
    fat = Column(Integer)

    summary = Column(String)
    image_url = Column(String)
    cook_time = Column(Integer)
    servings = Column(Integer)
    instructions = Column(String)
    is_deleted = Column(Boolean, default=False, nullable=False)

class SavedRecipe(Base):
    __tablename__ = "saved_recipes"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), index=True)
    recipe_id = Column(Integer, ForeignKey("recipe.recipe_id"), index=True)
    recipe_name = Column(String)
    user_notes = Column(String)

    user = relationship("User", back_populates="saved_recipes")

class recipe_feedback(Base):
    __tablename__ = "recipe_feedback"
    feedback_id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), index=True)
    recipe_id = Column(Integer, ForeignKey("recipe.recipe_id"), index=True)
    rating = Column(Integer)
    liked = Column(Integer)
    created_at = Column(String)

class ShoppingListIngredient(Base):
    __tablename__ = "shopping_list_ingredient"

    shopping_list_id = Column(Integer, ForeignKey('shopping_list.shopping_list_id'), primary_key=True)
    ingredient_id = Column(Integer, ForeignKey('ingredients.id'), primary_key=True)
    quantity = Column(Integer)
    checked = Column(Integer)
    unit = Column(String)

class UserPantry(Base):
    __tablename__ = "user_pantry"

    ingredient_id = Column(Integer, ForeignKey('ingredients.id'), primary_key=True)
    user_id = Column(Integer, ForeignKey('users.id'), primary_key=True)
    quantity = Column(Integer)
    unit = Column(Integer)
    updated_at = Column(String)

class UserPreference(Base):
    __tablename__ = "user_preference"

    user_id = Column(Integer, ForeignKey('users.id'), primary_key=True)
    preference_id = Column(Integer, ForeignKey('preference.preference_id'), primary_key=True)

class RecipeTag(Base):
    __tablename__ = "recipe_tag"

    tag_id = Column(Integer, ForeignKey('tags.id'), primary_key=True)
    recipe_id = Column(Integer, ForeignKey('recipe.recipe_id'), primary_key=True)

class MealRecipe(Base):
    __tablename__ = "meal_recipe"

    meal_id = Column(Integer, ForeignKey('meals.meal_id'), primary_key=True)
    recipe_id = Column(Integer, ForeignKey('recipe.recipe_id'), primary_key=True)

class RecipeIngredient(Base):
    __tablename__ = "recipe_ingredient"

    recipe_id = Column(Integer, ForeignKey('recipe.recipe_id'), primary_key=True)
    ingredient_id = Column(Integer, ForeignKey('ingredients.id'), primary_key=True)
    quantity = Column(Float)
    unit = Column(String)

class Tag(Base):
    __tablename__ = "tags"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey('users.id'))
    tag_name = Column(String, unique=True)
    