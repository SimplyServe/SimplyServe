User Requirements
=================

This section documents the user requirements gathered during the design phase, how each was implemented in SimplyServe, and any changes made during development.

Implemented Requirements
------------------------

.. list-table::
   :header-rows: 1
   :widths: 5 40 30 25

   * - ID
     - Requirement
     - Implementation
     - Notes
   * - 1
     - Users need help deciding what to cook, especially when tired, stressed, or short on time.
     - Meal Spinner (home screen widget that randomly selects a recipe).
     -
   * - 3 & 5
     - Users want to filter suggestions by dietary preferences (e.g. vegetarian, high protein) and search or filter recipes by metadata such as cuisine, cost, prep time, and complexity.
     - Advanced Search in the Recipes page.
     - Requirements 3 and 5 were merged into a single advanced search feature.
   * - 4
     - Users want to exclude disliked ingredients and personalise recipe choices.
     - Allergy / ingredient exclusion settings in Account Settings.
     -
   * - 6
     - Users want options to tag or categorise recipes to match personal preferences.
     - Create Recipe flow in the Recipes page allows custom tags and categories.
     -
   * - 7
     - Users want to save recipes and keep personal notes to replicate meals accurately.
     - Favourite Recipes section in the Recipes page.
     -
   * - 8
     - Users want access to a variety of meal types (quick, healthy, cultural, meat-based, vegetarian, complex recipes).
     - Recipes page with diverse pre-loaded recipe catalogue.
     -
   * - 9
     - Users want automatic or easily editable shopping lists linked to recipes they choose.
     - Shopping List page, generated from selected recipes.
     -
   * - 13
     - Users want nutritional information such as calories, macros, and protein content.
     - Nutritional breakdown displayed on each recipe detail page.
     -
   * - 14
     - Some users want meal suggestions tailored to fitness or high-protein goals.
     - Calorie Coach screen provides goal-based meal output.
     -
   * - 15
     - Users want a simple, uncluttered, easy-to-navigate interface.
     - Applied app-wide through consistent layout and navigation design.
     -
   * - 16
     - Users want the app to feel quick and responsive with minimal delays.
     - App-wide performance optimisation and smooth animations.
     -
   * - 17
     - Users want access to core features even without reliable internet.
     - Offline support applied across core app features.
     -

Changed Requirements
--------------------

.. list-table::
   :header-rows: 1
   :widths: 5 40 55

   * - ID
     - Original Requirement
     - Change
   * - 2
     - Users want smart meal suggestions that avoid repetition and match their preferences, and adapt to what ingredients they have.
     - Smart meal suggestion is partially implemented via the Calorie Coach, which provides goal-based recommendations. However, ingredient-aware suggestions (adapting to what the user currently has at home) were **not implemented** due to scope constraints.
