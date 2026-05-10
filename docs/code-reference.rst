Code Reference
==============

This page summarises the main methods, services, endpoints, and helper functions documented in the SimplyServe codebase. It is intended to support maintainability by explaining the purpose of the main backend functions and frontend services/components.

Backend Functions and Endpoints
-------------------------------

.. list-table::
   :header-rows: 1
   :widths: 25 45 30

   * - Function / Endpoint
     - Responsibility
     - Related Feature
   * - ``POST /register``
     - Creates a new user account and stores the password securely.
     - Registration
   * - ``POST /token``
     - Authenticates a user and returns a JWT bearer token.
     - Login / authentication
   * - ``GET /users/me``
     - Retrieves the authenticated user's profile.
     - Profile
   * - ``PATCH /users/me``
     - Partially updates the authenticated user's profile.
     - Profile editing
   * - ``PUT /users/me``
     - Updates the authenticated user's name.
     - Profile editing
   * - ``POST /users/me/avatar``
     - Uploads and stores a user avatar image.
     - Profile image upload
   * - ``GET /recipes``
     - Returns the available non-deleted recipe catalogue.
     - Recipe browsing
   * - ``POST /recipes``
     - Creates a new recipe with ingredients, tags, image, and nutrition data.
     - Recipe creation
   * - ``PUT /recipes/{recipe_id}``
     - Updates an existing recipe.
     - Recipe editing
   * - ``DELETE /recipes/{recipe_id}``
     - Soft-deletes a recipe by marking it as deleted.
     - Recipe deletion
   * - ``GET /recipes/deleted``
     - Returns soft-deleted recipes.
     - Deleted recipes
   * - ``POST /recipes/{recipe_id}/restore``
     - Restores a soft-deleted recipe.
     - Recipe recovery
   * - ``DELETE /recipes/{recipe_id}/permanent``
     - Permanently deletes a recipe from the database.
     - Permanent deletion
   * - ``GET /ingredients``
     - Searches the ingredient catalogue.
     - Recipe form ingredient search
   * - ``create_access_token``
     - Creates a JWT token for authenticated users.
     - Login / authentication
   * - ``get_current_user``
     - Validates a bearer token and retrieves the active user.
     - Protected routes
   * - ``_normalize_unit``
     - Standardises ingredient units.
     - Recipe creation / editing
   * - ``_parse_ingredient_text``
     - Converts ingredient input into structured ingredient data.
     - Recipe creation / editing
   * - ``_parse_ingredient_payload``
     - Validates and parses submitted ingredient JSON.
     - Recipe creation / editing
   * - ``_find_or_create_ingredient``
     - Retrieves an existing ingredient or creates a new one.
     - Ingredient management
   * - ``_calculate_recipe_nutrition_totals``
     - Calculates total nutrition values from recipe ingredients.
     - Recipe nutrition
   * - ``_build_nutrition_info``
     - Converts total nutrition values into per-serving nutrition information.
     - Nutrition dashboard / recipes

Frontend Services
-----------------

.. list-table::
   :header-rows: 1
   :widths: 25 45 30

   * - Service
     - Responsibility
     - Related Screens
   * - ``AuthService``
     - Handles login, logout, token storage, and session persistence.
     - LoginPage, ProfilePage
   * - ``RecipeService``
     - Handles recipe API calls.
     - RecipesView, RecipePage, RecipeFormView
   * - ``AllergyService``
     - Stores and retrieves selected allergy categories.
     - SettingsView, RecipesView
   * - ``AllergenFilterService``
     - Filters recipes using selected allergens and synonym keywords.
     - RecipesView, SettingsView, SpinWheelView
   * - ``ShoppingListService``
     - Manages shopping-list items, quantities, and deduplication.
     - ShoppingListView
   * - ``MealPlanService``
     - Stores planned meals by date.
     - MealCalendarView
   * - ``MealLogService``
     - Stores logged meals and calculates nutrition totals.
     - MealCalendarView, NutritionalDashboardView
   * - ``RerollAvoidanceService``
     - Prevents duplicate meal suggestions during the same day.
     - SpinWheelView
   * - ``CustomTagService``
     - Manages user-created recipe tags.
     - RecipeFormView, RecipesView
   * - ``PrivateNotesService``
     - Stores private notes linked to recipes.
     - RecipePage, RecipeFormView

Frontend Views and Components
-----------------------------

.. list-table::
   :header-rows: 1
   :widths: 25 45 30

   * - View / Component
     - Responsibility
     - Related Feature
   * - ``LoginPage``
     - Displays the login form and starts the authentication flow.
     - Authentication
   * - ``DashboardView``
     - Provides the main landing page and daily nutrition summary.
     - Dashboard
   * - ``RecipesView``
     - Displays recipes, search, filters, and recipe cards.
     - Recipe browsing
   * - ``RecipePage``
     - Displays full details for a selected recipe.
     - Recipe details
   * - ``RecipeFormView``
     - Allows users to create and edit recipes.
     - Recipe management
   * - ``DeletedRecipesView``
     - Displays deleted recipes and supports restore/permanent delete actions.
     - Deleted recipes
   * - ``SpinWheelView``
     - Provides the random meal suggestion interface.
     - Smart meal suggestions
   * - ``SpinningWheelWidget``
     - Displays the animated spinning wheel component.
     - Meal spinner
   * - ``CalorieCoachView``
     - Collects user information and calculates calorie/macronutrient targets.
     - Calorie coach
   * - ``NutritionalDashboardView``
     - Displays daily nutrition totals and progress indicators.
     - Nutrition tracking
   * - ``MealCalendarView``
     - Supports planning future meals and logging eaten meals.
     - Meal planning
   * - ``ShoppingListView``
     - Displays and manages recipe-generated shopping list items.
     - Shopping list
   * - ``SettingsView``
     - Manages user preferences and allergy settings.
     - Settings
   * - ``ProfilePage``
     - Displays and updates user profile information.
     - Profile