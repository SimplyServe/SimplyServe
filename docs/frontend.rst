Frontend
========

The frontend is implemented in Flutter and is responsible for the user interface, navigation, form validation, local state management, and communication with the FastAPI backend.

Main Views
----------

LoginPage
~~~~~~~~~

Displays the login form and allows users to authenticate using email and password. It communicates with ``AuthService`` and stores JWT tokens in ``SharedPreferences``.

DashboardView
~~~~~~~~~~~~~

Provides the main landing page after login and gives users access to the main SimplyServe features.

RecipesView
~~~~~~~~~~~

Displays the recipe catalogue. Users can search recipes, filter recipes by tags, apply allergen filtering, open recipe details, and add ingredients to the shopping list.

RecipePage
~~~~~~~~~~

Displays the details of a selected recipe, including summary, ingredients, steps, tags, and nutrition information.

RecipeFormView
~~~~~~~~~~~~~~

Allows users to create or edit recipes. It supports title, summary, ingredients, units, quantities, steps, tags, custom tags, private notes, servings, and image upload.

DeletedRecipesView
~~~~~~~~~~~~~~~~~~

Shows soft-deleted recipes and allows users to restore or permanently delete them.

SpinWheelView
~~~~~~~~~~~~~

Displays the smart meal spinner. It applies allergen filtering, meal-type filtering, and reroll avoidance before showing a recommendation.

SpinningWheelWidget
~~~~~~~~~~~~~~~~~~~

Provides the spinning wheel animation and selected recipe result.

CalorieCoachView
~~~~~~~~~~~~~~~~

Collects biometric and goal information from the user. It calculates calorie targets and macro targets based on BMR and TDEE.

NutritionalDashboardView
~~~~~~~~~~~~~~~~~~~~~~~~

Displays daily nutrition totals and progress indicators for calories, protein, carbohydrates, and fats.

ShoppingListView
~~~~~~~~~~~~~~~~

Displays the shopping list. Users can add custom items, check off items, remove items, and clear the list.

MealCalendarView
~~~~~~~~~~~~~~~~

Allows users to plan future meals and log past meals. Serving counts are used to calculate nutritional totals.

SettingsView
~~~~~~~~~~~~

Allows users to manage preferences, including allergen settings. The Allergies tab lets users add and remove allergen categories.

Frontend Services
-----------------

AuthService
~~~~~~~~~~~

Handles login, logout, token storage, and retrieval of authentication state.

RecipeService
~~~~~~~~~~~~~

Handles communication with backend recipe endpoints.

AllergyService
~~~~~~~~~~~~~~

Stores and retrieves the user's selected allergens.

AllergenFilterService
~~~~~~~~~~~~~~~~~~~~~

Checks recipe ingredients against allergen categories and synonym keywords.

ShoppingListService
~~~~~~~~~~~~~~~~~~~

Manages shopping list items, quantity updates, deduplication, and item removal.

MealPlanService
~~~~~~~~~~~~~~~

Stores future planned meals by date.

MealLogService
~~~~~~~~~~~~~~

Stores logged meals and calculates daily nutrition totals.

RerollAvoidanceService
~~~~~~~~~~~~~~~~~~~~~~

Tracks recipes already shown during the current day and prevents repeated suggestions.

CustomTagService
~~~~~~~~~~~~~~~~

Stores and manages user-defined recipe tags.

PrivateNotesService
~~~~~~~~~~~~~~~~~~~

Stores local private notes linked to recipes.