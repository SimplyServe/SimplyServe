API Reference
=============

This page documents the main FastAPI endpoints used by the SimplyServe application.

Authentication Endpoints
------------------------

POST /register
~~~~~~~~~~~~~~

Registers a new user account.

Request data:

* Email
* Password
* Optional display name

Expected behaviour:

* Creates a new user.
* Hashes the password using bcrypt.
* Rejects duplicate emails.
* Rejects invalid or missing fields.

POST /token
~~~~~~~~~~~

Authenticates a user and returns a JWT access token.

Request data:

* Email / username
* Password

Expected behaviour:

* Returns a bearer token for valid credentials.
* Returns ``401`` for incorrect credentials.

User Endpoints
--------------

GET /users/me
~~~~~~~~~~~~~

Returns the currently authenticated user's profile.

Authentication:

* Requires a valid JWT bearer token.

Expected behaviour:

* Returns user profile details when the token is valid.
* Returns ``401`` when the token is missing, invalid, malformed, or expired.

PUT /users/me
~~~~~~~~~~~~~

Updates the authenticated user's profile.

Authentication:

* Requires a valid JWT bearer token.

PATCH /users/me
~~~~~~~~~~~~~~~

Partially updates the authenticated user's profile.

Authentication:

* Requires a valid JWT bearer token.

POST /users/me/avatar
~~~~~~~~~~~~~~~~~~~~~

Uploads or updates the authenticated user's avatar image.

Authentication:

* Requires a valid JWT bearer token.

Expected behaviour:

* Accepts supported image formats such as JPEG and PNG.
* Rejects unsupported file types.

Recipe Endpoints
----------------

GET /recipes
~~~~~~~~~~~~

Returns the available recipe catalogue.

Expected behaviour:

* Returns non-deleted recipes.
* Supports recipe display in the frontend catalogue.

POST /recipes
~~~~~~~~~~~~~

Creates a new recipe.

Expected behaviour:

* Stores recipe title, summary, ingredients, steps, tags, servings, and nutrition information.
* Rejects missing required fields.

PUT /recipes/{id}
~~~~~~~~~~~~~~~~~

Updates an existing recipe.

Expected behaviour:

* Updates the selected recipe if it exists.
* Returns ``404`` if the recipe does not exist.

DELETE /recipes/{id}
~~~~~~~~~~~~~~~~~~~~

Soft-deletes a recipe.

Expected behaviour:

* Sets the recipe's ``is_deleted`` field to ``True``.
* Removes the recipe from the main recipe catalogue.
* Keeps the recipe available for restoration.

GET /recipes/deleted
~~~~~~~~~~~~~~~~~~~~

Returns soft-deleted recipes.

Expected behaviour:

* Used by ``DeletedRecipesView``.
* Displays recipes that can be restored or permanently deleted.

POST /recipes/{id}/restore
~~~~~~~~~~~~~~~~~~~~~~~~~~~

Restores a soft-deleted recipe.

Expected behaviour:

* Sets ``is_deleted`` back to ``False``.
* Returns ``404`` if the recipe does not exist.

DELETE /recipes/{id}/permanent
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Permanently deletes a recipe.

Expected behaviour:

* Removes the recipe record completely.
* Returns ``404`` if the recipe does not exist.

Ingredient Endpoints
--------------------

GET /ingredients?q=
~~~~~~~~~~~~~~~~~~~

Searches the ingredients table using a query string.

Expected behaviour:

* Returns matching ingredients.
* Supports ingredient search in ``RecipeFormView``.