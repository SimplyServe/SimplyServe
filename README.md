# Full Stack Auth App

A simple full-stack application with **FastAPI** (Backend) and **Flutter** (Frontend).

## Prerequisites
- Python 3.11+
- Poetry
- Flutter SDK (3.10+)

## 1. Backend Setup (FastAPI)

Navigate to the backend directory:
```bash
cd backend
```

Install dependencies and run migrations:
```bash
poetry install
```

Start the server:
```bash
poetry run uvicorn main:app --reload
```
- API Documentation: http://127.0.0.1:8000/docs

## 2. App Setup (Flutter)

Navigate to the app directory:
```bash
cd app
```

Install dependencies:
```bash
flutter pub get
```

Run the application:
```bash
flutter run
```

## Troubleshooting

- **Windows Symlinks:** If `flutter pub get` or `flutter run` fails with symlink errors, enable **Developer Mode** in Windows Settings > Privacy & security > For developers.
- **Android Emulator:** Ensure you use `10.0.2.2:8000` to connect to localhost from the emulator (already configured in `lib/services/auth_service.dart`).
