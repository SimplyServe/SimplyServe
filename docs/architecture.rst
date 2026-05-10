Architecture
============

SimplyServe uses a layered client-server architecture. The frontend is implemented in Flutter, the backend is implemented using FastAPI, and structured server-side data is stored in PostgreSQL.

Architecture Overview
---------------------

.. code-block:: text

   Flutter Frontend
   ├── Views and Widgets
   │   ├── LoginPage
   │   ├── DashboardView
   │   ├── RecipesView
   │   ├── RecipeFormView
   │   ├── SpinWheelView
   │   ├── CalorieCoachView
   │   ├── NutritionalDashboardView
   │   ├── ShoppingListView
   │   ├── MealCalendarView
   │   └── SettingsView
   │
   ├── Application Services
   │   ├── AuthService
   │   ├── RecipeService
   │   ├── AllergyService
   │   ├── AllergenFilterService
   │   ├── ShoppingListService
   │   ├── MealPlanService
   │   ├── MealLogService
   │   ├── RerollAvoidanceService
   │   ├── CustomTagService
   │   └── PrivateNotesService
   │
   ├── Local Persistence
   │   └── SharedPreferences
   │
   └── HTTP API Calls
       ↓
   FastAPI Backend
   ├── Authentication Endpoints
   ├── Recipe Endpoints
   ├── Ingredient Endpoints
   ├── User Profile Endpoints
   ├── SQLAlchemy Models
   └── Helper Functions
       ↓
   PostgreSQL Database

Frontend Layer
--------------

The frontend layer contains the Flutter views, widgets, navigation, form validation, and user interaction logic. It is responsible for displaying recipes, collecting user input, showing the meal spinner, managing settings, and displaying meal planning and nutrition data.

Application Service Layer
-------------------------

The service layer contains client-side business logic. It separates the UI from data handling and feature-specific logic.

Examples include:

* ``AuthService`` for token storage and authentication state.
* ``AllergenFilterService`` for allergen detection.
* ``ShoppingListService`` for deduplication and shopping list state.
* ``MealLogService`` for logged meals and nutrition totals.
* ``RerollAvoidanceService`` for preventing repeated meal suggestions.

Backend API Layer
-----------------

The backend layer is implemented in FastAPI. It exposes REST API endpoints for authentication, users, recipes, ingredients, deleted recipes, and profile images.

Persistence Layer
-----------------

SimplyServe uses two persistence mechanisms:

* PostgreSQL for shared structured data such as users, recipes, ingredients, recipe ingredients, and tags.
* SharedPreferences for local user-specific preferences such as allergen choices, favourites, custom tags, private notes, calorie coach values, and session tokens.

Main Architectural Changes from CW1
-----------------------------------

The main change from CW1 is the removal of Firebase. Authentication was moved to a custom JWT-based FastAPI implementation. This reduced dependency on third-party cloud services and made local development and testing easier.

The smart suggestion logic was also split into clearer service responsibilities. The spinner interface handles user interaction, while allergen filtering and reroll avoidance are handled by separate services.

Budget tracking was descoped, which simplified the architecture because no cost-calculation endpoint or price-tracking frontend component was required.