Frontend
========

The SimplyServe frontend is implemented in Flutter. It is responsible for the user interface, navigation, local state handling, user input validation, and communication with the FastAPI backend.

The frontend is the part of the system that users directly interact with. It allows users to log in, browse recipes, manage recipes, use the meal spinner, plan meals, log meals, manage allergies, generate shopping lists, and view nutrition-related information.

Frontend Structure
------------------

The frontend is organised around three main areas:

* ``Views``: full screens/pages that the user interacts with.
* ``Widgets``: reusable interface elements used inside views.
* ``Services``: classes that handle data access, local storage, backend communication, and frontend business logic.

Views are responsible for displaying information and collecting user actions. Services keep the view code cleaner by handling operations such as authentication, recipe retrieval, allergy filtering, shopping-list persistence, and meal logging.

Main Views and Components
-------------------------

LoginPage
~~~~~~~~~

Purpose:
Allows users to access their SimplyServe account using their email and password.

Expanded behaviour:
The login page displays input fields for the user's email and password. When the user submits the form, the page sends the credentials to the authentication service. If the backend accepts the credentials, the frontend receives a JWT access token and stores it locally so the user remains authenticated during the session.

The page also handles invalid login attempts by showing an error message when the backend rejects the credentials. This prevents the user from entering the main application without a valid account.

Main responsibility:
Collects login credentials, communicates with ``AuthService``, stores the authenticated session, and routes the user into the application after successful login.

Related backend endpoint:
``POST /token``

Related service:
``AuthService``


DashboardView
~~~~~~~~~~~~~

Purpose:
Acts as the main home screen after login.

Expanded behaviour:
The dashboard gives users a quick overview of their daily nutrition and provides navigation to the main parts of the app. It displays calorie and macronutrient summary information based on the meals that the user has logged.

The dashboard also acts as a central access point. From this screen, users can move to recipes, the meal spinner, the meal calendar, the shopping list, settings, and other major features without needing to search through the app.

Main responsibility:
Displays high-level daily information and provides quick navigation to the main SimplyServe features.

Related services:
``MealLogService`` and navigation-related frontend logic.


RecipesView
~~~~~~~~~~~

Purpose:
Displays the recipe catalogue and allows users to search, filter, and access recipes.

Expanded behaviour:
The recipes view is one of the core frontend screens. It displays recipe cards containing recipe titles, images, tags, preparation information, and summary details. Users can search for recipes by name and apply filters such as cuisine, tags, difficulty, duration, or meal type depending on the available recipe metadata.

The view also integrates allergy filtering. Recipes that contain ingredients matching the user's selected allergies can be hidden or excluded from the displayed results. This allows the recipe catalogue to adapt to user dietary restrictions.

Users can open a recipe card to view the full recipe details, add recipe ingredients to the shopping list, or access recipe-management actions such as editing or deleting where available.

Main responsibility:
Displays available recipes, supports search and filtering, applies allergy-based hiding, and provides entry points into recipe details and shopping-list integration.

Related services:
``RecipeService``, ``AllergenFilterService``, ``ShoppingListService``

Related backend endpoint:
``GET /recipes``


RecipePage
~~~~~~~~~~

Purpose:
Shows the full details of a selected recipe.

Expanded behaviour:
The recipe page displays the detailed information for one selected recipe. This includes the recipe title, image, summary, ingredients, ingredient quantities, preparation steps, serving count, tags, and nutritional values.

The page allows the user to understand exactly what is required to prepare the meal. It can also provide actions such as adding ingredients to the shopping list, marking the recipe as a favourite, editing the recipe, or deleting the recipe.

This page connects the browsing experience to practical meal preparation by turning a recipe card into a full set of instructions and ingredients.

Main responsibility:
Displays full recipe content and gives users actions for using, saving, editing, deleting, or adding the recipe to the shopping list.

Related services:
``RecipeService``, ``ShoppingListService``, ``FavouritesService``, ``PrivateNotesService``


RecipeFormView
~~~~~~~~~~~~~~

Purpose:
Allows users to create new recipes or edit existing recipes.

Expanded behaviour:
The recipe form view provides a structured form for entering recipe information. Users can add a recipe title, summary, serving count, preparation time, cooking time, ingredients, quantities, units, steps, tags, and an image.

When editing an existing recipe, the form is pre-filled with the current recipe details. This allows users to update recipe information without recreating the recipe from scratch.

The form also supports ingredient entry and tag selection. This helps ensure that recipes can later be searched, filtered, displayed correctly, and used for nutrition and shopping-list features.

Main responsibility:
Collects recipe data, validates required fields, allows ingredient and step entry, supports image upload, and sends create/update requests to the backend.

Related backend endpoints:
``POST /recipes`` and ``PUT /recipes/{id}``

Related service:
``RecipeService``


DeletedRecipesView
~~~~~~~~~~~~~~~~~~

Purpose:
Displays recipes that have been soft-deleted.

Expanded behaviour:
The deleted recipes view gives users a recovery area for recipes that were removed from the main catalogue but not permanently deleted. This supports safer recipe management because accidental deletions can be reversed.

Users can restore a deleted recipe, which makes it visible again in the normal recipe catalogue. They can also permanently delete a recipe if they are sure it should be removed completely.

This feature supports the soft-delete design used by the backend, where recipes are first marked as deleted rather than immediately removed from the database.

Main responsibility:
Displays soft-deleted recipes and provides restore/permanent delete actions.

Related backend endpoints:
``GET /recipes/deleted``, ``POST /recipes/{id}/restore``, and ``DELETE /recipes/{id}/permanent``

Related service:
``RecipeService``


SpinWheelView
~~~~~~~~~~~~~

Purpose:
Provides the smart meal suggestion feature.

Expanded behaviour:
The spin wheel view helps users choose a meal when they are unsure what to eat. It retrieves the available recipe list and applies filtering before a recipe is selected.

The view can filter recipes by meal type, such as breakfast, lunch, dinner, or snack. It can also remove recipes that contain selected allergens. This means the suggestion is not just random; it is filtered according to the user's preferences and safety settings.

The feature also works with reroll avoidance, so the same recipe is not repeatedly suggested during the same day where that logic is enabled.

Main responsibility:
Prepares a safe and relevant list of recipes for the spinner by applying meal-type filters, allergy filters, and reroll-avoidance rules.

Related services:
``RecipeService``, ``AllergenFilterService``, ``RerollAvoidanceService``


SpinningWheelWidget
~~~~~~~~~~~~~~~~~~~

Purpose:
Displays the visual spinning-wheel interface.

Expanded behaviour:
The spinning wheel widget is the animated component used by the meal spinner. It receives a list of recipes and visually spins before selecting one result.

This widget improves the user experience by making meal selection more interactive than a normal list or button. After the spin finishes, it displays the selected recipe so the user can decide whether to view or prepare it.

Main responsibility:
Animates recipe selection and returns a selected meal suggestion.

Related feature:
Smart Meal Suggestions / Meal Spinner


CalorieCoachView
~~~~~~~~~~~~~~~~

Purpose:
Calculates personalised calorie and macronutrient targets.

Expanded behaviour:
The Calorie Coach collects user information such as age, height, weight, gender, activity level, and goal. The user's goal may involve maintaining weight, gaining weight, or losing weight.

Based on this information, the view calculates estimated daily calorie needs and macronutrient targets. This gives the user a clearer idea of how many calories, protein, carbohydrates, and fats they may need each day.

The feature supports personalised nutrition planning by connecting user biometric information to meal-planning decisions. It can also support recipe recommendations or filtering where recipes are matched against dietary or nutrition goals.

Main responsibility:
Collects user fitness/nutrition inputs, calculates calorie and macro targets, and presents personalised nutrition guidance.

Related functionality:
BMR calculation, TDEE calculation, goal-based calorie adjustment, macro target display.


NutritionalDashboardView
~~~~~~~~~~~~~~~~~~~~~~~~

Purpose:
Displays daily nutrition progress.

Expanded behaviour:
The nutritional dashboard shows how much the user has consumed based on logged meals. It presents values such as calories, protein, carbohydrates, and fats.

This allows users to compare their daily intake against their target values. Progress indicators make it easier to see whether the user is under, near, or over their daily goals.

The dashboard depends on meal logging, because meals added to the log contribute to the daily totals.

Main responsibility:
Summarises logged meal data and displays daily nutrition totals and progress.

Related service:
``MealLogService``


ShoppingListView
~~~~~~~~~~~~~~~~

Purpose:
Displays and manages the user's shopping list.

Expanded behaviour:
The shopping list view gathers ingredients that the user adds from recipes. When ingredients from multiple recipes overlap, the shopping-list logic can merge duplicates and update quantities instead of creating unnecessary repeated entries.

Users can also manage the list by adjusting quantities, removing items, clearing the list, or marking items as complete depending on the available UI behaviour.

This feature turns recipe browsing into practical shopping preparation by helping users know what ingredients they need to buy.

Main responsibility:
Displays shopping-list items, supports ingredient aggregation, allows item management, and keeps the list usable for meal preparation.

Related service:
``ShoppingListService``


MealCalendarView
~~~~~~~~~~~~~~~~

Purpose:
Allows users to plan future meals and log meals that have been eaten.

Expanded behaviour:
The meal calendar provides a date-based interface for meal planning. Users can assign recipes to specific dates and set serving counts. This helps organise meals ahead of time.

The view also supports meal logging. When a meal is logged, it can contribute to the nutritional dashboard and daily nutrition totals.

The calendar separates planning behaviour from logging behaviour, allowing users to distinguish between meals they intend to eat and meals they have actually eaten.

Main responsibility:
Supports date-based meal planning, meal logging, serving-count management, and interaction with nutrition tracking.

Related services:
``MealPlanService`` and ``MealLogService``


SettingsView
~~~~~~~~~~~~

Purpose:
Allows users to manage app preferences and allergy settings.

Expanded behaviour:
The settings view stores user preferences that affect how the rest of the app behaves. The most important setting is allergy management.

Users can select allergy categories such as dairy, gluten, peanuts, shellfish, or other supported allergens. These selected allergies are stored locally and used by recipe browsing and meal suggestions to hide unsafe recipes.

The settings view may also show which recipes are hidden because of the selected allergies. This helps users understand why certain recipes are not appearing in the catalogue or spinner.

Main responsibility:
Allows users to manage allergy preferences and stores those preferences for use by recipe filtering and meal suggestions.

Related services:
``AllergyService`` and ``AllergenFilterService``


ProfilePage
~~~~~~~~~~~

Purpose:
Displays authenticated user profile information.

Expanded behaviour:
The profile page shows information linked to the signed-in user, such as their email address and display name. Where supported, it allows the user to update their name or profile image.

The profile page depends on authentication because it uses the stored JWT token to retrieve or update the current user's details.

Main responsibility:
Displays and updates user account information for the authenticated user.

Related backend endpoints:
``GET /users/me``, ``PUT /users/me``, ``PATCH /users/me``, and ``POST /users/me/avatar``

Related services:
``AuthService`` and ``ProfileService``


Frontend Services
-----------------

AuthService
~~~~~~~~~~~

Purpose:
Handles authentication and session persistence.

Expanded behaviour:
``AuthService`` sends login or registration requests to the backend and manages the JWT token returned after a successful login. It stores the token locally so the user can remain signed in between app actions.

It also supports logout by clearing the stored token. Other services can rely on the stored token when making authenticated backend requests.

Main responsibility:
Handles login, logout, registration, token storage, and authentication state.


RecipeService
~~~~~~~~~~~~~

Purpose:
Handles communication with the backend recipe API.

Expanded behaviour:
``RecipeService`` is responsible for retrieving recipes, creating recipes, updating recipes, deleting recipes, restoring deleted recipes, and permanently deleting recipes.

This keeps recipe-related API logic separate from the UI. Views such as ``RecipesView``, ``RecipePage``, ``RecipeFormView``, and ``DeletedRecipesView`` can call this service instead of directly handling HTTP requests.

Main responsibility:
Provides frontend access to recipe API operations.


AllergyService
~~~~~~~~~~~~~~

Purpose:
Stores and retrieves selected allergy categories.

Expanded behaviour:
``AllergyService`` keeps track of the user's selected allergens using local persistence. This means allergy settings remain available after the user leaves the screen or restarts the app.

The selected allergies are then used by filtering services to decide which recipes should be hidden.

Main responsibility:
Persists user allergy preferences and provides them to other frontend features.


AllergenFilterService
~~~~~~~~~~~~~~~~~~~~~

Purpose:
Filters recipes based on selected allergens.

Expanded behaviour:
``AllergenFilterService`` checks recipe ingredients against allergen categories and synonym keywords. For example, if the user selects a dairy allergy, the service can identify ingredients that relate to dairy and exclude those recipes.

This service is used by recipe browsing, settings previews, and meal suggestions. Separating this logic into its own service keeps allergy filtering consistent across the app.

Main responsibility:
Detects allergen matches and removes unsafe recipes from displayed or suggested results.


ShoppingListService
~~~~~~~~~~~~~~~~~~~

Purpose:
Manages shopping-list data and behaviour.

Expanded behaviour:
``ShoppingListService`` stores shopping-list items and handles logic such as adding recipe ingredients, merging duplicate ingredients, updating quantities, removing items, and clearing the list.

This service prevents the UI from needing to manage all shopping-list calculations directly.

Main responsibility:
Maintains the shopping list and applies aggregation/deduplication logic.


MealPlanService
~~~~~~~~~~~~~~~

Purpose:
Stores planned meals by date.

Expanded behaviour:
``MealPlanService`` records which recipes the user plans to eat on future dates. This supports meal preparation and helps the user organise their week.

The service stores planned meals separately from logged meals, so the app can distinguish between intended meals and meals actually eaten.

Main responsibility:
Manages future meal planning data.


MealLogService
~~~~~~~~~~~~~~

Purpose:
Stores logged meals and calculates daily nutrition totals.

Expanded behaviour:
``MealLogService`` records meals that the user has eaten. It uses serving counts and recipe nutrition data to calculate daily totals for calories, protein, carbohydrates, and fats.

These totals are then used by the dashboard and nutritional dashboard to show progress.

Main responsibility:
Tracks eaten meals and calculates nutrition summaries.


RerollAvoidanceService
~~~~~~~~~~~~~~~~~~~~~~

Purpose:
Prevents repeated meal suggestions.

Expanded behaviour:
``RerollAvoidanceService`` tracks which recipes have already been suggested by the meal spinner during the same day. This reduces repeated suggestions and makes the spinner feel more useful.

The stored suggestions can reset by date, allowing recipes to become available again on another day.

Main responsibility:
Tracks previously suggested meals and prevents unnecessary repetition.


CustomTagService
~~~~~~~~~~~~~~~~

Purpose:
Manages user-defined recipe tags.

Expanded behaviour:
``CustomTagService`` allows users to create and manage their own recipe tags. Custom tags help users organise recipes in a way that matches their personal habits, such as ``Quick``, ``Gym``, ``Cheap``, or ``Family``.

These tags can then support filtering and recipe organisation.

Main responsibility:
Stores and manages user-created tags.


PrivateNotesService
~~~~~~~~~~~~~~~~~~~

Purpose:
Stores private notes linked to recipes.

Expanded behaviour:
``PrivateNotesService`` allows users to attach personal notes to recipes. These notes may include cooking adjustments, substitutions, reminders, or personal comments.

The notes are private to the user and are stored locally.

Main responsibility:
Stores personal recipe notes for later reference.


Frontend Validation
-------------------

Frontend behaviour is validated through the test plan, manual functional testing, and the final video demonstration. The formal automated coverage evidence submitted for the coursework focuses on the backend because the backend provides the clearest measurable coverage evidence through pytest and pytest-cov.