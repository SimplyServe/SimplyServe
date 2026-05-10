Backend
=======

The SimplyServe backend is implemented using FastAPI. It provides authentication, user profile management, recipe management, deleted recipe recovery, avatar upload, ingredient search, and database access.

Backend Responsibilities
------------------------

The backend is responsible for:

* Registering users.
* Hashing passwords.
* Authenticating users.
* Creating JWT bearer tokens.
* Validating protected routes.
* Managing user profile data.
* Managing recipe CRUD operations.
* Supporting soft delete, restore, and permanent delete.
* Searching ingredients.
* Calculating nutrition information.
* Persisting structured data through SQLAlchemy models.

Authentication Flow
-------------------

The authentication flow uses JWT bearer tokens.

1. The user registers through ``POST /register``.
2. The backend hashes the password using bcrypt.
3. The user logs in through ``POST /token``.
4. The backend verifies the credentials.
5. The backend returns a JWT access token.
6. The frontend stores the token.
7. Protected requests include ``Authorization: Bearer <token>``.
8. The backend validates the token before returning protected data.

Database Models
---------------

User
~~~~

Stores user account information, including email, hashed password, display name, and profile-related fields.

Recipe
~~~~~~

Stores recipe title, summary, servings, instructions, image reference, soft-delete status, tags, and nutrition values.

Ingredient
~~~~~~~~~~

Stores ingredient names and nutritional values such as calories, protein, carbohydrates, and fats.

RecipeIngredient
~~~~~~~~~~~~~~~~

Stores the relationship between recipes and ingredients, including quantity and unit.

Tag
~~~

Stores recipe tags, including meal type, dietary tags, cuisine tags, and budget-friendly labels.

ShoppingList
~~~~~~~~~~~~

Defined for future or partial shopping-list persistence. The current frontend shopping-list behaviour is mainly handled by ``ShoppingListService``.

Core Backend Functions
----------------------

create_access_token
~~~~~~~~~~~~~~~~~~~

Purpose:
Creates a signed JWT access token for an authenticated user.

Input:
User identity and expiry information.

Output:
JWT bearer token.

Used by:
``POST /token``.

get_current_user
~~~~~~~~~~~~~~~~

Purpose:
Validates the JWT token and retrieves the currently authenticated user.

Input:
Authorization bearer token.

Output:
Authenticated user object.

Used by:
Protected user and recipe endpoints.

_normalize_unit
~~~~~~~~~~~~~~~

Purpose:
Normalises ingredient units so that equivalent units are stored consistently.

Input:
Raw unit string entered by the user.

Output:
Normalised unit value.

Used by:
Recipe creation and ingredient processing.

_parse_ingredient_text
~~~~~~~~~~~~~~~~~~~~~~

Purpose:
Parses ingredient text into structured information.

Input:
Ingredient string.

Output:
Ingredient name, quantity, and unit where possible.

Used by:
Recipe creation and recipe editing.

_build_nutrition_info
~~~~~~~~~~~~~~~~~~~~~

Purpose:
Calculates recipe nutrition values from ingredient nutrition data and serving counts.

Input:
Recipe ingredients, quantities, and serving count.

Output:
Nutrition summary containing calories, protein, carbohydrates, and fats.

Used by:
Recipe creation, recipe update, and nutritional display.

Soft Delete Logic
-----------------

Recipes are not immediately removed from the database. The delete endpoint sets an ``is_deleted`` flag. Soft-deleted recipes are hidden from the main recipe catalogue but remain available in the Deleted Recipes screen.

This supports:

* Accidental deletion recovery.
* Restore behaviour.
* Permanent deletion only when the user confirms removal.

Backend Testing
---------------

Backend tests are written using ``pytest``. API tests cover authentication, user profile endpoints, recipe CRUD, deleted recipe recovery, avatar upload, ingredient search, and helper functions.