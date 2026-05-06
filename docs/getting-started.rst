Getting Started
===============

This section will explain how to run the project locally.

Prerequisites
-------------

- Flutter SDK
- Python 3.11+
- Poetry (for backend dependency management)

Local Setup
-----------

Backend
~~~~~~~

1. Navigate to the ``backend/`` directory::

    cd backend

2. Activate the Poetry virtual environment::

    poetry env activate

3. Install dependencies::

    poetry install

4. Start the FastAPI server::

    uvicorn main:app --reload

   The API will be available at ``http://127.0.0.1:8000``.

Frontend
~~~~~~~~

1. Navigate to the ``app/`` directory::

    cd app

2. Install Flutter dependencies::

    flutter pub get

3. Run the Flutter app::

    flutter run

   Select your target device when prompted (e.g. Chrome, an Android emulator, or a connected device).
