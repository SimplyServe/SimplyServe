Development Guide
=================

This page documents the development workflow used for SimplyServe, including branching, pull requests, testing, documentation builds, and deployment validation.

Version Control Workflow
------------------------

The project uses GitHub for version control. Development work is completed through branches and pull requests rather than direct uncontrolled commits to ``main``.

Workflow:

1. A team member creates a feature branch from ``main``.
2. The change is implemented locally.
3. The branch is pushed to GitHub.
4. A pull request is opened.
5. Another team member reviews the pull request.
6. The pull request is approved and merged into ``main``.
7. ReadTheDocs is rebuilt from the latest ``main`` commit.

This workflow was used for implementation changes, documentation updates, and test-plan improvements.

Pull Request Review
-------------------

Pull requests were used to review changes before merging. This reduced the risk of overwriting files, merging incomplete documentation, or submitting pages with broken formatting.

Examples of reviewed changes include:

* Refactoring the documentation structure.
* Expanding the API reference page.
* Updating the frontend and backend documentation.
* Fixing ReadTheDocs build configuration.
* Correcting ``.rst`` formatting and headings.

GitHub Actions
--------------

GitHub Actions is used to validate that the documentation can build successfully before submission.

The documentation workflow is stored at:

.. code-block:: text

   .github/workflows/docs-build.yml

The workflow checks out the repository, installs the documentation requirements, and runs:

.. code-block:: bash

   sphinx-build -b html docs docs/_build/html

This confirms that the ReadTheDocs source files can be built successfully.

ReadTheDocs Build
-----------------

The public documentation is hosted on ReadTheDocs. The build configuration is stored in:

.. code-block:: text

   .readthedocs.yaml

The Sphinx configuration is stored in:

.. code-block:: text

   docs/conf.py

The ReadTheDocs project builds from the ``main`` branch of the GitHub repository.

Manual Rebuild
--------------

Because the webhook connection may not always trigger automatically, the project can be rebuilt manually:

1. Open the ReadTheDocs project.
2. Go to ``Builds``.
3. Click ``Rebuild`` for the latest version.
4. Check that the build uses the newest GitHub commit.
5. Confirm that the build status is successful.

Testing and Validation
----------------------

Backend automated tests are run using ``pytest``. These tests validate API endpoints, authentication, database behaviour, helper functions, and error handling.

Backend tests can be run with:

.. code-block:: bash

   cd backend
   poetry run pytest tests/

Backend coverage can be generated with:

.. code-block:: bash

   cd backend
   poetry run pytest tests/ --cov=. --cov-report=term-missing --cov-report=html:htmlcov --html=pytest-report.html --self-contained-html

Frontend behaviour is validated through the test plan, manual functional testing, and the final video demonstration. The automated coverage evidence submitted for this coursework focuses on the backend because the backend tests provide the clearest measurable coverage evidence.

Documentation build:

.. code-block:: bash

   sphinx-build -b html docs docs/_build/html

Validation Before Submission
----------------------------

Before submission, the team checks that:

* The ReadTheDocs build succeeds.
* The live documentation reflects the latest GitHub commit.
* The API page documents implemented endpoints.
* The frontend page documents implemented Flutter views, widgets, and services.
* The backend page documents authentication, models, helper functions, and API logic.
* The architecture page explains the implemented system structure.
* No placeholder text remains.