# Simply Serve - Smart Meal Planner

A cross-platform Flutter meal planning and nutrition tracking application with a Python FastAPI backend, designed to help users manage their dietary needs, discover recipes, plan meals, and track nutrition.

<!-- Screenshots: Add app screenshots here -->
<!-- ![App Screenshots](docs/images/app-overview.png) -->

## Table of Contents

- [Project Overview](#project-overview)
- [Features](#features)
- [Screenshots](#screenshots)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Getting Started](#getting-started)
- [Running Tests](#running-tests)
- [API Endpoints](#api-endpoints)
- [Development Workflow](#development-workflow)
- [Troubleshooting](#troubleshooting)
- [Team Members](#team-members)

## Project Overview

**Simply Serve** is a mobile application built for health-conscious individuals seeking an integrated solution for meal planning, nutrition tracking, recipe discovery, and dietary management. The app combines a Flutter frontend with a FastAPI backend and SQLite database.

## Features

### Authentication & User Management
- Secure email-based registration and login with JWT tokens
- Persistent sessions via encrypted token storage
- User profiles with display name and avatar upload

### Recipe Management
- **Recipe Catalogue** — Browse recipes from bundled local data and the API, merged seamlessly
- **Create & Edit Recipes** — Full CRUD with image upload and custom ingredient support
- **Advanced Search & Filtering** — Filter by tags (Vegan, High Protein, Gluten Free, etc.), cuisine, difficulty, and duration
- **Nutritional Info** — Per-serving nutrition grid (calories, protein, carbs, fats)
- **Custom Ingredients** — Add ingredients with nutritional data (calories, protein, carbs, fats per 100g/ml)

### Meal Planning & Logging
- **Meal Calendar** — Dual-tab calendar for planning (future dates) and logging (today)
- **Daily Nutrition Tracking** — Automatic totals from logged meals displayed on the dashboard
- **Meal Spinner** — Animated slot-machine-style random meal picker with audio feedback, meal type filters, and reroll avoidance

### Shopping List
- Auto-generated from planned meal ingredients
- Smart merging of duplicate items with quantity aggregation
- Track which recipes each item comes from

### Nutrition & Health
- **Calorie Coach** — Interactive questionnaire (age, height, weight, sex, activity level, goal) that calculates BMR, TDEE, and daily macro targets using the Mifflin-St Jeor formula
- **Dashboard Nutrition Ring** — Visual progress indicator showing actual vs. target calories
- Calorie coach results displayed on dashboard and profile

### Allergy & Dietary Management
- Add/remove allergens from a predefined list (Gluten, Dairy, Eggs, Peanuts, Tree Nuts, Fish, Shellfish, Soy, Sesame, etc.)
- Recipes containing allergen ingredients are automatically hidden
- View hidden recipes in a dedicated "Deleted Recipes" screen

### Additional Features
- Favourite recipes (persisted locally)
- Private notes on recipes
- Custom recipe tags
- Navigation drawer with active route highlighting
- Responsive, modern UI with brand colour (#74BC42)

## Screenshots

<!--
Add screenshots of the app here. Recommended screenshots:

1. Login / Registration screen
2. Dashboard with nutrition ring
3. Recipe catalogue (with tag chips visible)
4. Recipe detail page
5. Recipe creation form
6. Meal Spinner (slot machine)
7. Meal Calendar (planning or logging tab)
8. Shopping List
9. Calorie Coach questionnaire
10. Profile page
11. Settings / Allergy management
12. Deleted Recipes view

Example format:
| Dashboard | Recipe Catalogue | Meal Spinner |
|:---------:|:----------------:|:------------:|
| ![Dashboard](docs/images/dashboard.png) | ![Recipes](docs/images/recipes.png) | ![Spinner](docs/images/spinner.png) |
-->

## Tech Stack

| Layer | Technology |
|-------|------------|
| Frontend | Flutter (Dart) |
| State Management | ChangeNotifier + setState (singleton services) |
| HTTP Client | Dio |
| Local Storage | SharedPreferences, flutter_secure_storage |
| Backend | Python FastAPI |
| Database | SQLite (via SQLAlchemy async + aiosqlite) |
| Authentication | OAuth2 with JWT (python-jose, passlib/bcrypt) |
| Documentation | Sphinx (Read the Docs) |

## Project Structure

```
Software-Engineering-CW2/
├── app/                          # Flutter frontend
│   ├── lib/
│   │   ├── main.dart             # Entry point & routing
│   │   ├── authorisation.dart    # Login / Register UI
│   │   ├── homepage.dart         # Root scaffold wrapper
│   │   ├── recipe_page.dart      # Recipe detail view + data models
│   │   ├── services/             # Business logic layer
│   │   │   ├── authorisation.dart
│   │   │   ├── profile_service.dart
│   │   │   ├── recipe_service.dart
│   │   │   ├── recipe_catalog_service.dart
│   │   │   ├── meal_log_service.dart
│   │   │   ├── meal_plan_service.dart
│   │   │   ├── shopping_list_service.dart
│   │   │   ├── allergy_service.dart
│   │   │   ├── allergen_filter_service.dart
│   │   │   ├── favourites_service.dart
│   │   │   ├── custom_tag_service.dart
│   │   │   ├── private_notes_service.dart
│   │   │   └── reroll_avoidance_service.dart
│   │   ├── views/                # Full-screen pages
│   │   │   ├── nutritional_dashboard.dart
│   │   │   ├── recipes.dart
│   │   │   ├── recipe_form.dart
│   │   │   ├── meal_spinner_page.dart
│   │   │   ├── meal_calendar.dart
│   │   │   ├── shopping_list.dart
│   │   │   ├── settings.dart
│   │   │   ├── profile.dart
│   │   │   ├── calorie_coach.dart
│   │   │   └── deleted_recipes.dart
│   │   └── widgets/              # Reusable components
│   │       ├── navbar.dart
│   │       ├── spinning_wheel.dart
│   │       └── widgets.dart
│   ├── test/                     # Unit & widget tests
│   └── integration_test/         # End-to-end tests
│
├── backend/                      # Python FastAPI backend
│   ├── main.py                   # API server & endpoints
│   ├── models.py                 # SQLAlchemy ORM models
│   ├── schemas.py                # Pydantic schemas
│   ├── auth.py                   # JWT authentication
│   ├── database.py               # Async DB session setup
│   └── tests/                    # Backend test suite
│
├── docs/                         # Sphinx documentation
└── README.md
```

## Getting Started

### Prerequisites

- **Flutter SDK** 3.35.5 or later
- **Dart SDK** 3.9.2 or later
- **Python** 3.11+
- **Poetry** (recommended) or pip
- Android Studio / VS Code with Flutter extensions
- Android Emulator or physical device

### Backend Setup

```bash
cd backend

# Install dependencies
poetry install
# or: pip install fastapi uvicorn sqlalchemy aiosqlite pydantic[email] passlib[bcrypt] python-jose[cryptography] python-multipart email-validator

# Start the server
uvicorn main:app --reload
# Server runs at http://localhost:8000
```

### Frontend Setup

```bash
cd app

# Configure environment
# Create a .env file with:
#   BASE_URL=http://10.0.2.2:8000   (for Android emulator)
#   or BASE_URL=http://localhost:8000 (for web/desktop)

# Install dependencies
flutter pub get

# Run the app
flutter run
```

## Running Tests

### Frontend Tests

```bash
# All unit and widget tests
flutter test

# Integration tests (requires emulator/device)
flutter test integration_test

# Specific test file
flutter test test/views/recipes_test.dart

# Verbose output
flutter test --reporter expanded
```

### Backend Tests

```bash
cd backend

# All tests
pytest tests/

# Specific test file
pytest tests/test_auth.py
```

### Test Coverage

**Frontend:**
- Dashboard tests — rendering, navigation, nutrition display
- Recipes tests — search, filtering, tag display
- Settings tests — allergen management, navigation
- Service tests — auth, meal logging, meal planning, shopping list, notes, reroll avoidance
- Profile tests — display, calorie coach summary
- Recipe form tests — creation, ingredient search
- Integration tests — end-to-end user flows

**Backend:**
- Authentication & JWT tests
- Recipe CRUD & fetching tests
- User profile management tests
- Helper function tests

## API Endpoints

| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| POST | `/token` | Login (OAuth2 form) | No |
| POST | `/register` | User registration | No |
| GET | `/users/me` | Get current user profile | Yes |
| PUT | `/users/me` | Update display name | Yes |
| POST | `/users/me/avatar` | Upload profile image | Yes |
| GET | `/recipes` | List all recipes | Yes |
| POST | `/recipes` | Create recipe (multipart) | Yes |
| GET | `/ingredients?q=&limit=` | Search ingredients | Yes |

## Development Workflow

### Branch Management

Use feature branches for all work. Each pull request requires approval from at least one team member.

1. Create a new branch from `main`
2. Commit and push your changes
3. Open a pull request on GitHub
4. Alert the team in the group chat
5. After approval, merge and delete the branch

### Approving Pull Requests

1. Go to the **Pull Requests** tab on GitHub
2. Review changes under **Files Changed**
3. Click **Review** → select **Approve** → submit
4. Merge the PR and delete the branch

## Troubleshooting

### Windows Symlinks
If `flutter pub get` or `flutter run` fails with symlink errors, enable **Developer Mode** in Windows Settings > Privacy & security > For developers.

### Android Emulator
- Use `10.0.2.2:8000` as the backend URL to connect to localhost from the emulator
- Ensure the emulator has sufficient storage and RAM allocated

### Backend Connection Issues
- Verify the backend is running (`uvicorn main:app --reload`)
- Check the `.env` file has the correct `BASE_URL`
- For emulator, use `http://10.0.2.2:8000` instead of `localhost`

### Test Failures
- Run `flutter clean && flutter pub get` to refresh dependencies
- Ensure all files are saved before running tests
- Verify correct Flutter/Dart SDK version is installed

## Team Members

- **Ben Charlton** — UP2275414
- **Ben Brown** — UP2268495
- **Geeth Alsawair** — UP2248997
- **Ihor Savenko** — UP2241487
- **Sujan Rajesh** — UP2270752
- **James Hind** — UP2267708
- **Dmitrijs Jefimovs** — UP2210435

## License

This project is developed as part of a Software Engineering coursework (CW2).

---

**Last Updated:** May 10, 2026
