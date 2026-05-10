Development Guide
=================

This page explains how to set up, run, test, and document the SimplyServe project.

Repository
----------

The project is stored in GitHub and uses version control to manage implementation, documentation, and testing changes.

Recommended workflow:

* Create a branch for each feature or documentation change.
* Commit changes with clear commit messages.
* Open pull requests for review.
* Use GitHub Actions where available to run tests automatically.

Frontend Setup
--------------

The frontend is implemented in Flutter.

Typical setup steps:

.. code-block:: bash

   flutter pub get
   flutter run

Frontend tests can be run using:

.. code-block:: bash

   flutter test

Coverage can be generated using:

.. code-block:: bash

   flutter test --coverage

Backend Setup
-------------

The backend is implemented using FastAPI.

Typical setup steps:

.. code-block:: bash

   pip install -r requirements.txt

Run the backend using:

.. code-block:: bash

   uvicorn main:app --reload

Backend Testing
---------------

Backend tests are implemented using pytest.

Run the backend tests using:

.. code-block:: bash

   pytest

Generate a backend coverage report using:

.. code-block:: bash

   pytest --cov=backend --cov-report=html tests/

Testing Strategy
----------------

The test strategy uses:

* Requirement-based testing.
* Equivalence partitioning.
* Boundary value analysis.
* Positive and negative testing.
* Flutter unit tests.
* Flutter widget tests.
* Flutter integration tests.
* Python pytest backend API tests.

The test plan maps each test case to a system requirement, unit of code, test type, methodology, test data, expected result, and evidence.

ReadTheDocs Documentation
-------------------------

The documentation is built using Sphinx and ReadTheDocs.

The main documentation files are:

* ``index.rst``
* ``requirements.rst``
* ``architecture.rst``
* ``frontend.rst``
* ``backend.rst``
* ``api.rst``
* ``development.rst``

The ReadTheDocs configuration file is:

.. code-block:: text

   .readthedocs.yaml

The Sphinx configuration file is:

.. code-block:: text

   docs/conf.py

To build the documentation locally:

.. code-block:: bash

   sphinx-build -b html docs docs/_build/html

Documentation Purpose
---------------------

The documentation provides a maintainable reference for the implemented system. It explains the system requirements, frontend components, backend API, architecture, development process, and testing approach.