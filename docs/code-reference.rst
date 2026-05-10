Code Reference
==============

This page summarises the main methods, services, and helper functions documented in the SimplyServe codebase.

Backend Functions
-----------------

.. list-table::
   :header-rows: 1
   :widths: 25 45 30

   * - Function / Endpoint
     - Responsibility
     - Related Feature
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
     - Converts ingredient input into structured data.
     - Recipe creation / editing
   * - ``_build_nutrition_info``
     - Calculates recipe nutrition from ingredients and servings.
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