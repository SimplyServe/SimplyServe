
# Please use feature branches to publish your work
each pull request needs approval from another team member, so when you create a pull request send a message in the group chat to alert other team members.

How to use feature branches:
In vscode, when commiting changes you will find the main is locked. Create new branch (name doesnt matter) and commit then publish. on github create a merge pull request. After another member approves pull request, merge and then delete branch. 

How to approve:
On github go to the pull requests tab. under there you will see the most recently created pull request. Read the changes made by team member. In the top right there will be a green button to review work, select the approve category and submit. You can then complete the pull request and delete branch or leave it to the team member that created the request initially.







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
