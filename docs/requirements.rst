Requirements
============

This page summarises the implemented system requirements for SimplyServe in Coursework Iteration 2.

Functional Requirements
-----------------------

SR-1: Smart Meal Suggestions
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The system provides smart, non-duplicate meal suggestions through an interactive spinning wheel.

Implemented units:

* ``SpinWheelView``
* ``SpinningWheelWidget``
* ``AllergenFilterService``
* ``RerollAvoidanceService``

The user can spin the wheel to receive a random meal recommendation. The system applies meal-type filtering, removes recipes containing selected allergens, and prevents the same recipe from being suggested twice in the same day.

SR-2: Dietary Filters and Allergen Settings
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The system allows users to configure dietary restrictions through the Settings view.

Implemented units:

* ``SettingsView``
* ``AllergyService``
* ``AllergenFilterService``

Thirteen allergen categories are supported, including gluten, dairy, eggs, peanuts, tree nuts, fish, shellfish, soy, sesame, mustard, celery, sulphites, and lupin. Each allergen category is mapped to synonym keywords to improve detection.

SR-3: Calorie Coach
~~~~~~~~~~~~~~~~~~~

The system includes a Calorie Coach feature that calculates personalised calorie and macro targets.

Implemented units:

* ``CalorieCoachView``
* BMR and TDEE calculation logic
* Macro target calculation logic

The feature collects age, height, weight, gender, activity level, and fitness goal. It then calculates a daily calorie target and macro split.

SR-4: Recipe Management
~~~~~~~~~~~~~~~~~~~~~~~

The system supports full recipe management.

Implemented units:

* ``RecipesView``
* ``RecipePage``
* ``RecipeFormView``
* ``DeletedRecipesView``
* ``RecipeService``

Users can create, view, edit, search, soft-delete, restore, and permanently delete recipes. Recipe data includes title, summary, ingredients, quantities, units, steps, servings, tags, custom tags, and private notes.

SR-5: Shopping List
~~~~~~~~~~~~~~~~~~~

The system generates and manages shopping lists.

Implemented units:

* ``ShoppingListView``
* ``ShoppingListService``
* Add-to-shopping-list modal

Users can add recipe ingredients to a shopping list, add custom items, check off items, clear the list, and merge duplicate ingredients case-insensitively.

SR-6: Meal Calendar
~~~~~~~~~~~~~~~~~~~

The system provides a Meal Calendar for planning and logging meals.

Implemented units:

* ``MealCalendarView``
* ``MealPlanService``
* ``MealLogService``

Users can plan meals for future dates, log meals for past dates, set serving counts, and remove entries by setting servings to zero.

SR-7: Budget Awareness
~~~~~~~~~~~~~~~~~~~~~~

The system supports limited budget awareness through a ``Budget Friendly`` recipe tag.

Implemented units:

* Budget Friendly tag
* ``RecipesView`` tag filter

Full cost tracking and price-range filtering were descoped. The implemented version allows recipes to be tagged and filtered as budget friendly.

SR-8: Authentication and User Management
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The system supports registration, login, profile retrieval, profile update, avatar upload, and session persistence.

Implemented units:

* ``AuthService``
* ``POST /register``
* ``POST /token``
* ``GET /users/me``
* ``PUT /users/me``
* ``PATCH /users/me``
* ``POST /users/me/avatar``

Authentication uses JWT bearer tokens. Tokens are stored in ``SharedPreferences`` on the Flutter client and validated by the FastAPI backend.

Non-Functional Requirements
---------------------------

NFR-1: Usability and Offline Access
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The application provides a clear Flutter user interface and supports limited offline access using local fallback data and ``SharedPreferences``.

NFR-2: Security and Data Protection
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The system protects user data through hashed passwords, JWT authentication, protected API routes, and separation between user preference data and shared recipe data.

NFR-3: Performance and Responsiveness
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The application aims to keep common actions responsive. Image loading uses Flutter placeholders and the recipe catalogue has local fallback behaviour when the API is unavailable.

NFR-4: Persistence
~~~~~~~~~~~~~~~~~~

Server-side data is stored in PostgreSQL through SQLAlchemy models. Client-side preferences are stored using ``SharedPreferences``.