Testing
=======

The SimplyServe test strategy combines requirement-based testing, equivalence partitioning, boundary value analysis, positive testing, negative testing, widget testing, service testing, integration testing, and backend API testing.

Testing Methodology
-------------------

The test plan was produced by decomposing each system requirement into implemented units of code. Each unit was then tested using valid, invalid, boundary, and error-state input partitions.

The test plan includes:

* Test ID.
* System requirement.
* Unit of code.
* Test type.
* Methodology.
* Test data.
* Expected output.
* Valid or invalid classification.
* Evidence reference.

Test Types
----------

Flutter Unit Tests
~~~~~~~~~~~~~~~~~~

Used to test service-layer logic in isolation, including calorie calculations, shopping-list logic, allergen filtering, and authentication state.

Flutter Widget Tests
~~~~~~~~~~~~~~~~~~~~

Used to test UI rendering and interaction for pages such as LoginPage, DashboardView, RecipesView, ShoppingListView, SettingsView, MealCalendarView, CalorieCoachView, and SpinWheelView.

Flutter Integration Tests
~~~~~~~~~~~~~~~~~~~~~~~~~

Used to test full user flows such as app launch, login, navigation, and user interaction across multiple screens.

Backend API Tests
~~~~~~~~~~~~~~~~~

Used to test FastAPI endpoints, authentication flows, recipe CRUD, deleted recipe recovery, profile updates, avatar upload, and helper functions.

Coverage Evidence
-----------------

Frontend coverage can be generated with:

.. code-block:: bash

   cd app
   flutter test --coverage

Backend coverage can be generated with:

.. code-block:: bash

   cd backend
   pytest --cov=backend --cov-report=html tests/

Traceability
------------

Each automated test is mapped back to a requirement and unit of code. This ensures the tests do not only check isolated behaviours but also provide coverage evidence for the implemented system requirements.