Architecture
============

SimplyServe uses a layered client-server architecture. The frontend is implemented in Flutter, the backend is implemented with FastAPI, and structured data is stored through SQLAlchemy models.

Architecture Diagram
--------------------

.. code-block:: text

   +--------------------------------------------------+
   |                  Flutter Frontend                |
   |--------------------------------------------------|
   | Views: LoginPage, DashboardView, RecipesView,    |
   | RecipeFormView, SpinWheelView, MealCalendarView  |
   | ShoppingListView, SettingsView                   |
   +---------------------------+----------------------+
                               |
                               v
   +--------------------------------------------------+
   |              Flutter Service Layer               |
   |--------------------------------------------------|
   | AuthService, RecipeService, AllergyService,      |
   | AllergenFilterService, ShoppingListService,      |
   | MealPlanService, MealLogService,                 |
   | RerollAvoidanceService                           |
   +---------------------------+----------------------+
                |                              |
                v                              v
   +--------------------------+       +----------------------+
   | SharedPreferences        |       | HTTP API Requests    |
   | Local session/preferences|       | to FastAPI backend   |
   +--------------------------+       +----------+-----------+
                                                 |
                                                 v
   +--------------------------------------------------+
   |                 FastAPI Backend                  |
   |--------------------------------------------------|
   | Authentication, Users, Recipes, Ingredients,     |
   | Deleted Recipes, Avatar Upload                   |
   +---------------------------+----------------------+
                               |
                               v
   +--------------------------------------------------+
   |                 SQLAlchemy Models                |
   |--------------------------------------------------|
   | User, Recipe, Ingredient, RecipeIngredient, Tag  |
   +---------------------------+----------------------+
                               |
                               v
   +--------------------------------------------------+
   |                    Database                      |
   +--------------------------------------------------+

Frontend Layer
--------------

The frontend layer contains the Flutter views and widgets that users interact with. It handles navigation, form input, validation, display logic, and local UI state.

Service Layer
-------------

The service layer separates business logic from UI code. For example, ``AllergenFilterService`` handles allergy filtering, ``ShoppingListService`` handles list aggregation, and ``RerollAvoidanceService`` prevents repeated meal suggestions.

Backend Layer
-------------

The backend layer exposes FastAPI endpoints for authentication, user profiles, recipes, ingredients, deleted recipes, and avatar uploads.

Persistence Layer
-----------------

Two persistence mechanisms are used:

* ``SharedPreferences`` stores local user preferences, session tokens, allergy selections, and other device-level data.
* The backend database stores shared structured data such as users, recipes, ingredients, and tags.

Architectural Changes from CW1
------------------------------

The main architectural change from CW1 was the removal of Firebase authentication. Authentication was moved to a custom FastAPI JWT implementation. This made the system easier to test locally and reduced reliance on external cloud services.

The suggestion logic was also separated into smaller services. The spinner UI handles display and interaction, while allergen filtering and reroll avoidance are handled by dedicated services. This reduces coupling and makes the feature easier to test.

Budget tracking was descoped, so no cost-calculation API or cost-tracking UI was implemented. Instead, budget awareness is represented by a ``Budget Friendly`` recipe tag.