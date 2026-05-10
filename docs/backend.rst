Backend
=======

The SimplyServe backend is implemented using FastAPI. It provides authentication, recipe management, ingredient search, deleted recipe management, user profile management, and database persistence.

Backend Responsibilities
------------------------

The backend is responsible for:

* Creating and authenticating users.
* Issuing JWT access tokens.
* Validating protected routes.
* Managing recipe CRUD operations.
* Managing soft-deleted recipes.
* Searching ingredients.
* Storing structured data in PostgreSQL.
* Calculating recipe nutrition from ingredient values.
* Handling user profile updates and avatar uploads.

Authentication
--------------

Authentication uses a custom JWT implementation.

The main authentication flow is:

1. A user registers through ``POST /register``.
2. The backend stores the user with a bcrypt-hashed password.
3. The user logs in through ``POST /token``.
4. The backend returns a JWT bearer token.
5. The Flutter frontend stores the token in ``SharedPreferences``.
6. Protected requests include the token in the ``Authorization`` header.
7. FastAPI validates the token before allowing access to protected endpoints.

Database Layer
--------------

The backend uses SQLAlchemy models with PostgreSQL.

Main data models include:

User
~~~~

Stores user account information, including email, hashed password, display name, and profile data.

Recipe
~~~~~~

Stores recipe details such as title, summary, steps, servings, image information, soft-delete status, and calculated nutrition values.

Ingredients
~~~~~~~~~~~

Stores ingredient data, including average calories, protein, carbohydrates, fats, and cost values.

RecipeIngredient
~~~~~~~~~~~~~~~~

Stores the relationship between recipes and ingredients, including quantity and unit information.

Tag
~~~

Stores recipe tags such as dietary tags, cuisine tags, meal-type tags, and budget-related tags.

ShoppingList and ShoppingListIngredient
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Defined in the database schema to support future server-side shopping list persistence. The current Iteration 2 shopping list is primarily handled client-side.

Backend Helper Functions
------------------------

_normalize_unit
~~~~~~~~~~~~~~~

Normalises ingredient units so that different user inputs can be handled consistently.

_parse_ingredient_text
~~~~~~~~~~~~~~~~~~~~~~

Parses ingredient text entered by the user and extracts structured ingredient information where possible.

_build_nutrition_info
~~~~~~~~~~~~~~~~~~~~~

Calculates nutrition information for a recipe using ingredient nutrition values and serving counts.

Soft Delete Logic
-----------------

Recipes are not immediately removed when deleted. Instead, the backend sets an ``is_deleted`` flag. Soft-deleted recipes are hidden from the main recipe list but can be restored from the Deleted Recipes view.

Permanent deletion is available when the user confirms that the recipe should be removed completely.