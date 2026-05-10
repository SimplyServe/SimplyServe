Frontend
========

The SimplyServe frontend is implemented in Flutter. It is responsible for the user interface, navigation, local state handling, user input validation, and communication with the FastAPI backend.

Frontend Structure
------------------

The frontend is organised around views, widgets, and service classes.

Views handle full screens, widgets handle reusable interface elements, and services handle data access or business logic.

Main Views and Components
-------------------------

LoginPage
~~~~~~~~~

Purpose:
Allows users to log in using their email and password.

Main responsibility:
Collects credentials, sends them to ``AuthService``, receives the JWT token, and stores the authenticated session.

Related functionality:
Uses ``POST /token`` through the authentication flow.

DashboardView
~~~~~~~~~~~~~

Purpose:
Provides the main landing page after login.

Main responsibility:
Displays daily calorie and macro summaries and gives quick navigation to recipes, meal spinner, calendar, and other app features.

RecipesView
~~~~~~~~~~~

Purpose:
Displays the recipe catalogue.

Main responsibility:
Allows users to browse recipes, search by name, apply advanced filters, apply allergy-based hiding, open recipe details, and add recipe ingredients to the shopping list.

Related services:
``RecipeService``, ``AllergenFilterService``, ``ShoppingListService``.

RecipePage
~~~~~~~~~~

Purpose:
Displays the full details of a selected recipe.

Main responsibility:
Shows recipe title, summary, ingredients, instructions, nutrition, tags, favourite status, edit option, delete option, and shopping-list integration.

RecipeFormView
~~~~~~~~~~~~~~

Purpose:
Allows users to create and edit recipes.

Main responsibility:
Collects recipe title, summary, servings, ingredients, quantities, units, steps, tags, and image uploads.

Related backend endpoints:
``POST /recipes`` and ``PUT /recipes/{id}``.

DeletedRecipesView
~~~~~~~~~~~~~~~~~~

Purpose:
Displays soft-deleted recipes.

Main responsibility:
Allows users to restore recipes or permanently delete them.

Related backend endpoints:
``GET /recipes/deleted``, ``POST /recipes/{id}/restore``, and ``DELETE /recipes/{id}/permanent``.

SpinWheelView
~~~~~~~~~~~~~

Purpose:
Provides a random meal suggestion interface.

Main responsibility:
Fetches the available recipes, applies allergen filtering and meal-type filtering, and passes the available recipe list to the spinning wheel widget.

SpinningWheelWidget
~~~~~~~~~~~~~~~~~~~

Purpose:
Displays the visual spinning wheel.

Main responsibility:
Animates the spin and returns a selected recipe recommendation.

Related services:
``RerollAvoidanceService`` and ``AllergenFilterService``.

CalorieCoachView
~~~~~~~~~~~~~~~~

Purpose:
Calculates personalised calorie and macro targets.

Main responsibility:
Collects age, height, weight, gender, activity level, and fitness goal, then calculates BMR, TDEE, calorie target, protein, fat, and carbohydrate targets.

NutritionalDashboardView
~~~~~~~~~~~~~~~~~~~~~~~~

Purpose:
Displays daily nutrition progress.

Main responsibility:
Shows calories, protein, carbohydrates, and fats based on logged meals.

Related service:
``MealLogService``.

ShoppingListView
~~~~~~~~~~~~~~~~

Purpose:
Displays and manages the shopping list.

Main responsibility:
Shows ingredients added from recipes, merges duplicate ingredients, lets users adjust quantities, remove items, and clear the list.

Related service:
``ShoppingListService``.

MealCalendarView
~~~~~~~~~~~~~~~~

Purpose:
Allows users to plan and log meals.

Main responsibility:
Supports assigning recipes to dates, setting serving counts, planning future meals, and logging meals eaten.

Related services:
``MealPlanService`` and ``MealLogService``.

SettingsView
~~~~~~~~~~~~

Purpose:
Allows users to manage preferences.

Main responsibility:
Stores allergy settings, shows recipes hidden by selected allergies, and allows users to remove or update allergy preferences.

ProfilePage
~~~~~~~~~~~

Purpose:
Displays authenticated user profile information.

Main responsibility:
Shows the signed-in user email and profile details.

Frontend Services
-----------------

AuthService
~~~~~~~~~~~

Handles registration, login, logout, token storage, and session persistence.

RecipeService
~~~~~~~~~~~~~

Handles API requests for recipe listing, recipe creation, recipe editing, recipe deletion, recipe restoration, and permanent deletion.

AllergyService
~~~~~~~~~~~~~~

Stores and retrieves the user's selected allergies using local persistence.

AllergenFilterService
~~~~~~~~~~~~~~~~~~~~~

Checks recipe ingredients against allergen categories and synonym keywords. It is used by recipe browsing, meal suggestions, and settings previews.

ShoppingListService
~~~~~~~~~~~~~~~~~~~

Manages shopping-list state, duplicate ingredient merging, quantity updates, item removal, and clear-list behaviour.

MealPlanService
~~~~~~~~~~~~~~~

Stores planned meals by date.

MealLogService
~~~~~~~~~~~~~~

Stores logged meals and calculates daily nutrition totals.

RerollAvoidanceService
~~~~~~~~~~~~~~~~~~~~~~

Tracks recipes already suggested during the same day and prevents repeated suggestions.

CustomTagService
~~~~~~~~~~~~~~~~

Manages user-defined recipe tags.

PrivateNotesService
~~~~~~~~~~~~~~~~~~~

Stores local private notes linked to recipes.

Frontend Testing
----------------

Frontend behaviour is tested through Flutter unit tests, widget tests, and integration tests. These cover service-layer logic, screen rendering, navigation, form behaviour, and end-to-end user flows.