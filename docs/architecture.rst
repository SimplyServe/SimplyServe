Architecture
============

Project Structure
-----------------

- ``app/``: Flutter application code.
- ``backend/``: FastAPI backend service.
- ``uploads/``: User-uploaded media.

High-Level Flow
---------------

1. Flutter client sends authenticated API requests.
2. FastAPI backend validates tokens and handles business logic.
3. Backend returns JSON responses consumed by frontend services.
