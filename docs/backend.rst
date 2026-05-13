Backend
=======

The SimplyServe backend is implemented using FastAPI. It provides authentication, user profile management, recipe management, deleted recipe recovery, avatar upload, ingredient search, nutrition calculation, and database access.

The backend acts as the central API layer between the Flutter frontend and the database. It receives requests from the frontend, validates the data, performs database operations through SQLAlchemy models, and returns structured responses to the app.

Backend Responsibilities
------------------------

The backend is responsible for:

* Registering users.
* Hashing passwords before storage.
* Authenticating users through login.
* Creating JWT bearer tokens.
* Validating protected routes.
* Managing user profile data.
* Handling profile avatar uploads.
* Managing recipe creation, reading, updating, and deletion.
* Supporting soft delete, recipe restore, and permanent deletion.
* Searching ingredients.
* Parsing ingredient input.
* Normalising ingredient units.
* Calculating recipe nutrition information.
* Persisting structured data through SQLAlchemy models.
* Returning API responses in a format the Flutter frontend can use.

Backend Structure
-----------------

The backend is organised around FastAPI route functions, helper functions, database models, schemas, and authentication utilities.

The main backend files include:

``main.py``
~~~~~~~~~~~

Contains the FastAPI application, API endpoints, recipe logic, ingredient handling, soft-delete behaviour, profile endpoints, avatar upload handling, and backend helper functions.

``models.py``
~~~~~~~~~~~~~

Defines the SQLAlchemy database models used by the backend. These models represent tables such as users, recipes, ingredients, recipe ingredients, and tags.

``schemas.py``
~~~~~~~~~~~~~~

Defines Pydantic schemas used for request and response validation. These schemas control the structure of data sent to and returned from the API.

``auth.py``
~~~~~~~~~~~

Contains authentication utilities, including password hashing, password verification, JWT creation, and current-user validation.

``database.py``
~~~~~~~~~~~~~~~

Configures the database connection and provides database sessions to API routes.

Authentication Flow
-------------------

The authentication flow uses JWT bearer tokens.

1. The user registers through ``POST /register``.
2. The backend checks whether the submitted email is already registered.
3. The backend hashes the password using bcrypt.
4. The new user is stored in the database.
5. The user logs in through ``POST /token``.
6. The backend verifies the submitted email and password.
7. If the credentials are valid, the backend creates a JWT access token.
8. The frontend stores the token locally.
9. Protected requests include ``Authorization: Bearer <token>``.
10. The backend validates the token before returning protected data.

This means users cannot access protected profile or account-specific functionality unless they have a valid token.

Authentication Endpoints
------------------------

``POST /register``
~~~~~~~~~~~~~~~~~~

Registers a new user.

This endpoint receives user registration data, checks whether the email already exists, hashes the password, creates a new user record, and returns the created user.

Main behaviours:

* Accepts a new email, name, and password.
* Rejects duplicate email addresses.
* Stores the password as a hash instead of plain text.
* Creates a new user in the database.

Related frontend feature:

* Registration / account creation.

``POST /token``
~~~~~~~~~~~~~~~

Authenticates an existing user and returns a JWT bearer token.

This endpoint receives login credentials using the OAuth2 password form flow. It verifies the submitted password against the stored hashed password. If authentication succeeds, it returns an access token.

Main behaviours:

* Accepts email and password credentials.
* Verifies the password securely.
* Returns a JWT access token.
* Rejects incorrect email or password combinations.

Related frontend feature:

* LoginPage / AuthService.

User Profile Endpoints
----------------------

``GET /users/me``
~~~~~~~~~~~~~~~~~

Returns the currently authenticated user's profile.

This endpoint depends on JWT validation. If the token is valid, the backend returns the user record linked to that token.

Main behaviours:

* Requires a valid bearer token.
* Returns the authenticated user's email, name, and profile data.
* Rejects missing or invalid tokens.

Related frontend feature:

* ProfilePage.
* Authenticated session validation.

``PATCH /users/me``
~~~~~~~~~~~~~~~~~~~

Partially updates the authenticated user's profile.

This endpoint allows limited profile updates without replacing the full user object. It is useful for smaller profile changes.

Main behaviours:

* Requires authentication.
* Updates submitted profile fields.
* Keeps unchanged fields as they are.
* Saves the updated user record to the database.

Related frontend feature:

* Profile editing.

``PUT /users/me``
~~~~~~~~~~~~~~~~~

Updates the authenticated user's name.

This endpoint is used when the frontend submits a new profile name. The backend trims the submitted name and rejects empty values.

Main behaviours:

* Requires authentication.
* Validates that the name is not empty.
* Updates the user's name.
* Returns the updated user profile.

Related frontend feature:

* Profile name update.

``POST /users/me/avatar``
~~~~~~~~~~~~~~~~~~~~~~~~~

Uploads or updates the authenticated user's profile avatar.

This endpoint accepts an uploaded image file, validates the file type, saves the file in the uploads directory, and stores the image URL against the user profile.

Main behaviours:

* Requires authentication.
* Accepts supported image types such as JPEG, PNG, WebP, and GIF.
* Rejects unsupported image types.
* Saves the uploaded file with a unique filename.
* Updates the user's ``profile_image_url``.

Related frontend feature:

* Profile image upload.

Recipe Endpoints
----------------

``GET /recipes``
~~~~~~~~~~~~~~~~

Returns the available recipe catalogue.

This endpoint retrieves recipes that are not soft-deleted. It also gathers linked tags, ingredients, quantities, units, steps, and calculated nutrition information so the frontend can display complete recipe cards and recipe details.

Main behaviours:

* Returns non-deleted recipes.
* Excludes recipes where ``is_deleted`` is true.
* Includes recipe tags.
* Includes recipe ingredients and units.
* Calculates per-serving nutrition values.
* Returns data in the frontend ``Recipe`` schema format.

Related frontend features:

* RecipesView.
* RecipePage.
* SpinWheelView.
* Shopping-list generation.

``POST /recipes``
~~~~~~~~~~~~~~~~~

Creates a new recipe.

This endpoint receives multipart form data from the frontend. It can accept text fields, tags, ingredients, steps, serving count, preparation information, and an optional image upload.

Main behaviours:

* Creates a new recipe record.
* Saves an uploaded recipe image if provided.
* Parses submitted tags.
* Creates missing tags where needed.
* Parses submitted ingredients.
* Finds or creates ingredient records.
* Links ingredients to the recipe with quantity and unit.
* Calculates total and per-serving nutrition information.
* Returns the created recipe in the frontend response format.

Related frontend feature:

* RecipeFormView in create mode.

``PUT /recipes/{recipe_id}``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Updates an existing recipe.

This endpoint finds the existing recipe by ID, updates its details, replaces its tags and ingredient links, recalculates nutrition values, and returns the updated recipe.

Main behaviours:

* Validates that the recipe exists.
* Updates title, summary, times, servings, image, and steps.
* Replaces old recipe tags with the submitted tags.
* Replaces old recipe ingredients with the submitted ingredient list.
* Recalculates nutrition values after editing.
* Returns the updated recipe.

Related frontend feature:

* RecipeFormView in edit mode.

``DELETE /recipes/{recipe_id}``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Soft-deletes a recipe.

This endpoint does not immediately remove the recipe from the database. Instead, it sets the recipe's ``is_deleted`` field to true. The recipe disappears from the normal catalogue but remains available in the deleted recipes list.

Main behaviours:

* Validates that the recipe exists.
* Sets ``is_deleted`` to true.
* Keeps the recipe available for restoration.
* Returns a success message.

Related frontend features:

* RecipePage.
* RecipesView.
* DeletedRecipesView.

Deleted Recipe Endpoints
------------------------

``GET /recipes/deleted``
~~~~~~~~~~~~~~~~~~~~~~~~

Returns soft-deleted recipes.

This endpoint retrieves recipes where ``is_deleted`` is true. It returns the same type of recipe information as the normal recipe list, including tags, ingredients, steps, and nutrition information.

Main behaviours:

* Returns only deleted recipes.
* Includes tags and ingredients.
* Includes calculated nutrition values.
* Supports the deleted recipes recovery screen.

Related frontend feature:

* DeletedRecipesView.

``POST /recipes/{recipe_id}/restore``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Restores a soft-deleted recipe.

This endpoint finds a recipe by ID and sets ``is_deleted`` back to false. The recipe then becomes visible again in the main catalogue.

Main behaviours:

* Validates that the recipe exists.
* Marks the recipe as not deleted.
* Makes the recipe available in the normal recipe list again.
* Returns a restore success message.

Related frontend feature:

* DeletedRecipesView restore action.

``DELETE /recipes/{recipe_id}/permanent``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Permanently deletes a recipe.

This endpoint removes the recipe from the database. Unlike soft delete, this action is not intended to be reversible.

Main behaviours:

* Validates that the recipe exists.
* Deletes the recipe record from the database.
* Commits the database change.
* Returns a permanent deletion success message.

Related frontend feature:

* DeletedRecipesView permanent delete action.

Ingredient Endpoint
-------------------

``GET /ingredients``
~~~~~~~~~~~~~~~~~~~~

Searches the ingredient catalogue.

This endpoint supports ingredient search when users create or edit recipes. It accepts a query string and optional parameters such as limit and base-only filtering.

Main behaviours:

* Accepts a search query.
* Trims the query text.
* Limits the number of results.
* Optionally filters to base ingredients.
* Returns matching ingredients ordered by relevance and name.

Related frontend feature:

* RecipeFormView ingredient search.

Database Models
---------------

User
~~~~

Stores account information for registered users.

Main fields include:

* Email address.
* Display name.
* Hashed password.
* Profile image URL.

The user model supports authentication, profile display, and profile updates.

Recipe
~~~~~~

Stores recipe information.

Main fields include:

* Recipe name.
* Summary.
* Preparation time.
* Cooking time.
* Serving count.
* Instructions.
* Image URL.
* Soft-delete status.
* Nutrition values.

The recipe model supports recipe browsing, recipe creation, recipe editing, deletion, restoration, and nutrition display.

Ingredient
~~~~~~~~~~

Stores ingredient information.

Main fields include:

* Ingredient name.
* Normalised name.
* Base ingredient flag.
* Average calories.
* Average protein.
* Average carbohydrates.
* Average fats.
* Average cost where available.

The ingredient model supports ingredient search and recipe nutrition calculations.

RecipeIngredient
~~~~~~~~~~~~~~~~

Stores the relationship between recipes and ingredients.

Main fields include:

* Recipe ID.
* Ingredient ID.
* Quantity.
* Unit.

This model allows each recipe to have structured ingredient data rather than only plain text ingredients.

Tag
~~~

Stores recipe tags.

Tags support recipe organisation and filtering. Examples include meal type, dietary labels, cuisine labels, and budget-friendly labels.

RecipeTag
~~~~~~~~~

Stores the many-to-many relationship between recipes and tags.

This allows one recipe to have multiple tags and one tag to be linked to multiple recipes.

ShoppingList
~~~~~~~~~~~~

Defined for future or partial shopping-list persistence. In the current implementation, the main shopping-list behaviour is handled by the Flutter ``ShoppingListService``.

Core Backend Helper Functions
-----------------------------

``create_access_token``
~~~~~~~~~~~~~~~~~~~~~~~

Purpose:
Creates a signed JWT access token for an authenticated user.

Input:
User identity data and optional expiry information.

Output:
JWT bearer token.

Used by:
``POST /token``.

``get_current_user``
~~~~~~~~~~~~~~~~~~~~

Purpose:
Validates the JWT token and retrieves the currently authenticated user.

Input:
Authorization bearer token.

Output:
Authenticated user object.

Used by:
Protected user and recipe endpoints.

``_normalize_unit``
~~~~~~~~~~~~~~~~~~~

Purpose:
Normalises ingredient units so that equivalent units are stored consistently.

Expanded behaviour:
The function converts different forms of the same unit into a standard value. For example, ``grams`` and ``gram`` are converted to ``g``. If a unit is not recognised, the function falls back to ``pcs``.

Input:
Raw unit string entered by the user.

Output:
Normalised unit value.

Used by:
Recipe creation, recipe editing, and ingredient display.

``_parse_ingredient_text``
~~~~~~~~~~~~~~~~~~~~~~~~~~

Purpose:
Parses plain ingredient text into structured information.

Expanded behaviour:
The function attempts to extract quantity, unit, and ingredient name from text such as ``2 cups rice`` or ``1/2 tsp salt``. If the text cannot be fully parsed, it falls back to a default quantity and unit.

Input:
Ingredient string.

Output:
Dictionary containing ingredient name, quantity, and unit.

Used by:
Recipe ingredient seeding and ingredient payload processing.

``_parse_ingredient_payload``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Purpose:
Validates and parses submitted ingredient JSON.

Expanded behaviour:
The function accepts submitted ingredient data from the frontend. It supports ingredient entries as either strings or objects. It validates that quantities are numeric and greater than zero, removes duplicates, normalises units, and returns a clean ingredient list.

Input:
JSON string containing submitted ingredients.

Output:
List of parsed ingredient dictionaries.

Used by:
``POST /recipes`` and ``PUT /recipes/{recipe_id}``.

``_find_or_create_ingredient``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Purpose:
Finds an existing ingredient or creates a new ingredient record.

Expanded behaviour:
The function searches the database using the normalised ingredient name. If the ingredient already exists, it returns the existing record. If not, it creates a new non-base ingredient.

Input:
Database session and ingredient name.

Output:
Ingredient database record.

Used by:
Recipe creation and recipe editing.

``_seed_base_ingredients_catalog``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Purpose:
Loads base ingredient data into the database.

Expanded behaviour:
The function reads the ``base_ingredients.json`` file and inserts missing base ingredients into the database. It avoids duplicate insertion by checking whether a normalised ingredient already exists.

Input:
Database session.

Output:
No direct response; inserts ingredient records where needed.

Used by:
Application startup.

``_normalize_existing_ingredient_data``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Purpose:
Normalises ingredient units already stored in the database.

Expanded behaviour:
The function checks existing recipe ingredient rows and updates old or inconsistent unit values to the standard unit format.

Input:
Database session.

Output:
No direct response; updates database rows where needed.

Used by:
Application startup.

``_ensure_ingredient_table_columns``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Purpose:
Ensures required database columns exist.

Expanded behaviour:
The function performs lightweight migration-style checks by attempting to add missing columns for users, recipes, recipe ingredients, and ingredients. This supports development environments where the database schema may have changed over time.

Input:
No direct input.

Output:
No direct response; updates database schema where needed.

Used by:
Application startup.

``_calculate_recipe_nutrition_totals``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Purpose:
Calculates total nutrition values for a recipe.

Expanded behaviour:
The function joins recipe ingredients with ingredient nutrition data and multiplies nutrition values by ingredient quantity. It returns total calories, protein, carbohydrates, and fats before serving-size division.

Input:
Database session and recipe ID.

Output:
Dictionary containing total calories, protein, carbohydrates, and fats.

Used by:
Recipe listing, recipe creation, recipe update, and deleted recipe listing.

``_build_nutrition_info``
~~~~~~~~~~~~~~~~~~~~~~~~~

Purpose:
Converts total nutrition values into per-serving nutrition information.

Expanded behaviour:
The function divides total nutrition values by the number of servings and formats the output for the frontend. It ensures serving count cannot cause division by zero by using at least one serving.

Input:
Nutrition totals and serving count.

Output:
Formatted nutrition dictionary containing calories, protein, carbohydrates, and fats.

Used by:
Recipe listing, recipe creation, recipe update, and nutrition display.

Application Startup
-------------------

The backend performs setup work when the FastAPI app starts.

Startup tasks include:

* Creating database tables.
* Ensuring required columns exist.
* Loading the base ingredient catalogue.
* Linking predefined recipe ingredients.
* Normalising legacy ingredient unit data.

This startup process helps the app run consistently even when the database has changed during development.

Soft Delete Logic
-----------------

Recipes are not immediately removed from the database. The delete endpoint sets an ``is_deleted`` flag. Soft-deleted recipes are hidden from the main recipe catalogue but remain available in the Deleted Recipes screen.

This supports:

* Accidental deletion recovery.
* Restore behaviour.
* A safer recipe-management workflow.
* Permanent deletion only when the user confirms removal.

Backend Testing
---------------

Backend tests are written using ``pytest``. API tests cover authentication, user profile endpoints, recipe CRUD, deleted recipe recovery, avatar upload, ingredient search, validation errors, and helper functions.

Backend coverage is generated using ``pytest-cov``. The coverage evidence is documented in the Testing page and the test execution commands are documented in the Development Guide.