API Reference
=============

This page documents the main FastAPI endpoints used by the SimplyServe application. The API supports authentication, user profile management, recipe management, deleted recipe recovery, avatar upload, and ingredient search.

Authentication Endpoints
------------------------

POST /register
~~~~~~~~~~~~~~

Purpose
^^^^^^^

Creates a new user account.

Authentication Required?
^^^^^^^^^^^^^^^^^^^^^^^^

No. This endpoint is public because new users must be able to register before logging in.

Input / Body
^^^^^^^^^^^^

Example request body:

.. code-block:: json

   {
     "email": "user@example.com",
     "password": "Password123",
     "display_name": "Test User"
   }

Success Behaviour
^^^^^^^^^^^^^^^^^

The backend creates a new user record, hashes the password using bcrypt, and stores the user in the database.

Expected success response:

.. code-block:: json

   {
     "message": "User registered successfully"
   }

Error Cases
^^^^^^^^^^^

* ``400`` if the email address is already registered.
* ``422`` if required fields are missing.
* ``422`` if the email format is invalid.
* ``422`` if the password field is empty or invalid.

Frontend Feature That Uses It
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Used by the registration screen during account creation.


POST /token
~~~~~~~~~~~

Purpose
^^^^^^^

Authenticates an existing user and returns a JWT bearer token.

Authentication Required?
^^^^^^^^^^^^^^^^^^^^^^^^

No. This endpoint is public because it is used to obtain the access token.

Input / Body
^^^^^^^^^^^^

This endpoint uses the OAuth2 password flow and expects form data rather than JSON.

Example form fields:

.. code-block:: text

   username=user@example.com
   password=Password123

Success Behaviour
^^^^^^^^^^^^^^^^^

If the credentials are correct, the backend returns a JWT access token.

Expected success response:

.. code-block:: json

   {
     "access_token": "jwt_token_here",
     "token_type": "bearer"
   }

Error Cases
^^^^^^^^^^^

* ``401`` if the email does not exist.
* ``401`` if the password is incorrect.
* ``422`` if required form fields are missing.

Frontend Feature That Uses It
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Used by ``LoginPage`` and ``AuthService``. The returned token is stored in ``SharedPreferences`` and attached to protected API requests using the ``Authorization: Bearer`` header.


User Profile Endpoints
----------------------

GET /users/me
~~~~~~~~~~~~~

Purpose
^^^^^^^

Returns the profile details of the currently authenticated user.

Authentication Required?
^^^^^^^^^^^^^^^^^^^^^^^^

Yes. A valid JWT bearer token is required.

Input / Body
^^^^^^^^^^^^

No request body is required.

The request must include:

.. code-block:: text

   Authorization: Bearer <access_token>

Success Behaviour
^^^^^^^^^^^^^^^^^

Returns the authenticated user's profile information.

Example response:

.. code-block:: json

   {
     "id": 1,
     "email": "user@example.com",
     "display_name": "Test User"
   }

Error Cases
^^^^^^^^^^^

* ``401`` if no token is provided.
* ``401`` if the token is invalid.
* ``401`` if the token is malformed.
* ``401`` if the token has expired.
* ``401`` if the ``Bearer`` prefix is missing.

Frontend Feature That Uses It
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Used by ``AuthService`` and the user profile/settings area to retrieve the current logged-in user's details.


PUT /users/me
~~~~~~~~~~~~~

Purpose
^^^^^^^

Updates the authenticated user's profile details.

Authentication Required?
^^^^^^^^^^^^^^^^^^^^^^^^

Yes. A valid JWT bearer token is required.

Input / Body
^^^^^^^^^^^^

Example request body:

.. code-block:: json

   {
     "display_name": "Updated Name"
   }

Success Behaviour
^^^^^^^^^^^^^^^^^

Updates the user's profile and returns the updated profile details.

Example response:

.. code-block:: json

   {
     "id": 1,
     "email": "user@example.com",
     "display_name": "Updated Name"
   }

Error Cases
^^^^^^^^^^^

* ``401`` if the token is missing or invalid.
* ``400`` if the submitted display name is empty.
* ``422`` if the request body is malformed.

Frontend Feature That Uses It
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Used by the profile editing feature where users update their display name or account details.


PATCH /users/me
~~~~~~~~~~~~~~~

Purpose
^^^^^^^

Partially updates the authenticated user's profile.

Authentication Required?
^^^^^^^^^^^^^^^^^^^^^^^^

Yes. A valid JWT bearer token is required.

Input / Body
^^^^^^^^^^^^

Example request body:

.. code-block:: json

   {
     "display_name": "New Display Name"
   }

Success Behaviour
^^^^^^^^^^^^^^^^^

Updates only the submitted profile fields while leaving other user fields unchanged.

Error Cases
^^^^^^^^^^^

* ``401`` if the token is missing, invalid, or expired.
* ``400`` if an empty display name is submitted.
* ``422`` if the request body is invalid.

Frontend Feature That Uses It
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Used by the user profile/settings feature for partial profile updates.


POST /users/me/avatar
~~~~~~~~~~~~~~~~~~~~~

Purpose
^^^^^^^

Uploads or updates the authenticated user's profile avatar.

Authentication Required?
^^^^^^^^^^^^^^^^^^^^^^^^

Yes. A valid JWT bearer token is required.

Input / Body
^^^^^^^^^^^^

The request uses multipart form data.

Example form data:

.. code-block:: text

   file: avatar.png

Success Behaviour
^^^^^^^^^^^^^^^^^

Stores the uploaded avatar and associates it with the authenticated user.

Expected behaviour:

* Accepts supported image file types such as ``.jpg``, ``.jpeg``, and ``.png``.
* Updates the user's avatar reference.

Error Cases
^^^^^^^^^^^

* ``401`` if the token is missing or invalid.
* ``400`` if the file type is unsupported.
* ``422`` if no file is uploaded.
* ``400`` if the uploaded file is empty or invalid.

Frontend Feature That Uses It
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Used by the profile/avatar upload feature in the frontend.


Recipe Endpoints
----------------

GET /recipes
~~~~~~~~~~~~

Purpose
^^^^^^^

Returns the available recipe catalogue.

Authentication Required?
^^^^^^^^^^^^^^^^^^^^^^^^

This depends on the implementation. If the route is protected, a valid JWT bearer token is required. If public catalogue browsing is allowed, no token is required.

Input / Body
^^^^^^^^^^^^

No request body is required.

Success Behaviour
^^^^^^^^^^^^^^^^^

Returns a list of non-deleted recipes.

Example response:

.. code-block:: json

   [
     {
       "id": 1,
       "title": "Chicken Pasta",
       "summary": "A simple high-protein meal.",
       "servings": 2,
       "tags": ["Dinner", "High Protein"],
       "is_deleted": false
     }
   ]

Error Cases
^^^^^^^^^^^

* ``401`` if authentication is required and the token is missing or invalid.
* ``500`` if the recipe catalogue cannot be retrieved.
* Empty list returned if no recipes are available.

Frontend Feature That Uses It
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Used by ``RecipesView``, ``RecipePage``, ``SpinWheelView``, ``CalorieCoachView``, and shopping-list generation features.


POST /recipes
~~~~~~~~~~~~~

Purpose
^^^^^^^

Creates a new recipe.

Authentication Required?
^^^^^^^^^^^^^^^^^^^^^^^^

Yes. A valid JWT bearer token is required if recipe creation is restricted to logged-in users.

Input / Body
^^^^^^^^^^^^

Example request body:

.. code-block:: json

   {
     "title": "Chicken Pasta",
     "summary": "A simple high-protein meal.",
     "servings": 2,
     "ingredients": [
       {
         "name": "Chicken breast",
         "quantity": 200,
         "unit": "g"
       },
       {
         "name": "Pasta",
         "quantity": 150,
         "unit": "g"
       }
     ],
     "steps": [
       "Cook the pasta.",
       "Cook the chicken.",
       "Combine and serve."
     ],
     "tags": ["Dinner", "High Protein"]
   }

Success Behaviour
^^^^^^^^^^^^^^^^^

Creates a new recipe record, links the recipe to ingredients and tags, calculates nutrition information where possible, and returns the created recipe.

Error Cases
^^^^^^^^^^^

* ``401`` if the user is not authenticated.
* ``422`` if required fields are missing.
* ``422`` if the request body is malformed.
* ``400`` if the recipe title is empty.
* ``400`` if the ingredient list is invalid.
* ``400`` if servings are zero or negative, depending on validation rules.

Frontend Feature That Uses It
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Used by ``RecipeFormView`` when users create a new recipe.


PUT /recipes/{id}
~~~~~~~~~~~~~~~~~

Purpose
^^^^^^^

Updates an existing recipe.

Authentication Required?
^^^^^^^^^^^^^^^^^^^^^^^^

Yes. A valid JWT bearer token is required if recipe editing is restricted to logged-in users.

Input / Body
^^^^^^^^^^^^

Path parameter:

.. code-block:: text

   id: recipe ID

Example request body:

.. code-block:: json

   {
     "title": "Updated Chicken Pasta",
     "summary": "Updated recipe summary.",
     "servings": 3,
     "tags": ["Dinner", "High Protein", "Budget Friendly"]
   }

Success Behaviour
^^^^^^^^^^^^^^^^^

Updates the selected recipe and returns the updated recipe details.

Error Cases
^^^^^^^^^^^

* ``401`` if the user is not authenticated.
* ``404`` if the recipe ID does not exist.
* ``422`` if the request body is malformed.
* ``400`` if submitted recipe data is invalid.

Frontend Feature That Uses It
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Used by ``RecipeFormView`` when editing an existing recipe.


DELETE /recipes/{id}
~~~~~~~~~~~~~~~~~~~~

Purpose
^^^^^^^

Soft-deletes a recipe.

Authentication Required?
^^^^^^^^^^^^^^^^^^^^^^^^

Yes. A valid JWT bearer token is required if recipe deletion is restricted to logged-in users.

Input / Body
^^^^^^^^^^^^

Path parameter:

.. code-block:: text

   id: recipe ID

No request body is required.

Success Behaviour
^^^^^^^^^^^^^^^^^

The backend sets the recipe's ``is_deleted`` field to ``true``. The recipe is hidden from the main catalogue but remains available in the deleted recipes list.

Expected success response:

.. code-block:: json

   {
     "message": "Recipe deleted successfully"
   }

Error Cases
^^^^^^^^^^^

* ``401`` if the user is not authenticated.
* ``404`` if the recipe ID does not exist.
* ``400`` if the recipe is already deleted, depending on implementation.

Frontend Feature That Uses It
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Used by ``RecipePage`` or ``RecipesView`` when the user deletes a recipe. The deleted recipe can later be restored from ``DeletedRecipesView``.


GET /recipes/deleted
~~~~~~~~~~~~~~~~~~~~

Purpose
^^^^^^^

Returns all soft-deleted recipes.

Authentication Required?
^^^^^^^^^^^^^^^^^^^^^^^^

Yes. A valid JWT bearer token is required if deleted recipes are user-specific or protected.

Input / Body
^^^^^^^^^^^^

No request body is required.

Success Behaviour
^^^^^^^^^^^^^^^^^

Returns a list of recipes where ``is_deleted`` is ``true``.

Example response:

.. code-block:: json

   [
     {
       "id": 4,
       "title": "Deleted Recipe",
       "is_deleted": true
     }
   ]

Error Cases
^^^^^^^^^^^

* ``401`` if the user is not authenticated.
* Empty list returned if there are no deleted recipes.

Frontend Feature That Uses It
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Used by ``DeletedRecipesView`` to display recipes that can be restored or permanently deleted.


POST /recipes/{id}/restore
~~~~~~~~~~~~~~~~~~~~~~~~~~~

Purpose
^^^^^^^

Restores a soft-deleted recipe.

Authentication Required?
^^^^^^^^^^^^^^^^^^^^^^^^

Yes. A valid JWT bearer token is required if recipe restoration is protected.

Input / Body
^^^^^^^^^^^^

Path parameter:

.. code-block:: text

   id: recipe ID

No request body is required.

Success Behaviour
^^^^^^^^^^^^^^^^^

The backend sets ``is_deleted`` back to ``false`` and returns the restored recipe or a success message.

Expected success response:

.. code-block:: json

   {
     "message": "Recipe restored successfully"
   }

Error Cases
^^^^^^^^^^^

* ``401`` if the user is not authenticated.
* ``404`` if the recipe ID does not exist.
* ``400`` if the recipe is not currently deleted, depending on implementation.

Frontend Feature That Uses It
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Used by ``DeletedRecipesView`` when the user restores a soft-deleted recipe.


DELETE /recipes/{id}/permanent
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Purpose
^^^^^^^

Permanently deletes a recipe from the database.

Authentication Required?
^^^^^^^^^^^^^^^^^^^^^^^^

Yes. A valid JWT bearer token is required if permanent deletion is protected.

Input / Body
^^^^^^^^^^^^

Path parameter:

.. code-block:: text

   id: recipe ID

No request body is required.

Success Behaviour
^^^^^^^^^^^^^^^^^

The backend permanently removes the recipe record and related associations from the database.

Expected success response:

.. code-block:: json

   {
     "message": "Recipe permanently deleted"
   }

Error Cases
^^^^^^^^^^^

* ``401`` if the user is not authenticated.
* ``404`` if the recipe ID does not exist.
* ``400`` if the recipe cannot be permanently deleted due to database constraints.

Frontend Feature That Uses It
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Used by ``DeletedRecipesView`` when the user chooses to permanently remove a recipe.


Ingredient Endpoints
--------------------

GET /ingredients?q=
~~~~~~~~~~~~~~~~~~~

Purpose
^^^^^^^

Searches the ingredient database using a query string.

Authentication Required?
^^^^^^^^^^^^^^^^^^^^^^^^

This depends on the implementation. If ingredient search is protected, a valid JWT bearer token is required. If ingredient search is public, no token is required.

Input / Query Parameters
^^^^^^^^^^^^^^^^^^^^^^^^

Query parameter:

.. code-block:: text

   q: ingredient search term

Example request:

.. code-block:: text

   GET /ingredients?q=chicken

Success Behaviour
^^^^^^^^^^^^^^^^^

Returns matching ingredients from the database.

Example response:

.. code-block:: json

   [
     {
       "id": 1,
       "name": "Chicken breast",
       "avg_calories": 165,
       "avg_protein": 31,
       "avg_carbs": 0,
       "avg_fat": 3.6
     }
   ]

Error Cases
^^^^^^^^^^^

* Empty list returned if no ingredients match the query.
* ``422`` if the query parameter is invalid.
* ``401`` if authentication is required and the token is missing or invalid.

Frontend Feature That Uses It
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Used by ``RecipeFormView`` when users search for ingredients while creating or editing recipes.


API Error Handling
------------------

Common Error Responses
~~~~~~~~~~~~~~~~~~~~~~

The API may return the following common HTTP responses:

* ``400 Bad Request``: The request was understood but contains invalid data.
* ``401 Unauthorized``: Authentication is missing, invalid, malformed, or expired.
* ``404 Not Found``: The requested resource does not exist.
* ``422 Unprocessable Entity``: Required fields are missing or the request format is invalid.
* ``500 Internal Server Error``: An unexpected backend error occurred.

Authentication Header Format
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Protected endpoints require the following header:

.. code-block:: text

   Authorization: Bearer <access_token>

The frontend stores the JWT token in ``SharedPreferences`` and attaches it to protected requests through ``AuthService`` or the relevant API service class.