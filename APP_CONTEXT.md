# Simply Serve — App Context for Report Writing

> Paste this document (or relevant sections) into any AI Model conversation when asking for help with your report.

---

## What the App Is

**Simply Serve** is a cross-platform mobile meal-planning and nutrition-tracking application built with Flutter. It targets health-conscious users who want to simplify meal planning without losing flexibility.

Core user-facing features:
- Browse and search a recipe catalogue (local + API-backed)
- Filter recipes by tags, cuisine, difficulty, duration, dietary needs, and allergens
- Plan meals on a calendar for future dates
- Log meals consumed today and track daily nutrition (calories, protein, carbs, fats)
- Generate a shopping list aggregated from all planned recipes
- Spin a random meal picker (avoids repeating choices in the same day)
- Set allergy/dietary preferences that automatically hide unsafe recipes
- Use an AI-style Calorie Coach questionnaire to calculate personalised daily nutrition targets
- Manage a profile with name, avatar, and saved calorie goals

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Language | Dart |
| Framework | Flutter (SDK >=2.17.0 <4.0.0) |
| HTTP client | `dio` ^5.9.2 |
| Local persistence | `shared_preferences` ^2.2.2 |
| Secure storage | `flutter_secure_storage` ^10.0.0 |
| Image picking | `image_picker` ^1.2.1 |
| Environment config | `flutter_dotenv` ^6.0.0 |
| Auth (configured) | `google_sign_in` ^6.2.1 |
| Backend | Python FastAPI + SQLAlchemy (async) + SQLite |
| Backend base URL | Loaded from `.env` (default `http://localhost:8000`) |

---

## Architecture Overview

The project follows a service-layer architecture with no third-party state management framework. Views manage their own local state via `setState()` and listen to singleton `ChangeNotifier` services for shared state.

```
app/lib/
├── main.dart                        # Entry point; route table; session check on startup
├── authorisation.dart               # Login / Register UI
├── recipe_page.dart                 # Recipe detail view + core data models
├── homepage.dart                    # Root scaffold (nav drawer wrapper)
│
├── views/                           # Full-screen pages
│   ├── nutritional_dashboard.dart   # Home dashboard; daily nutrition summary
│   ├── recipes.dart                 # Recipe catalogue; search & filter
│   ├── recipe_form.dart             # Create / edit recipes
│   ├── meal_spinner_page.dart       # Random meal picker (animated wheel)
│   ├── meal_calendar.dart           # Meal planning (future) & logging (today)
│   ├── shopping_list.dart           # Aggregated shopping list
│   ├── settings.dart                # Allergy management
│   ├── profile.dart                 # User profile & calorie coach summary
│   ├── calorie_coach.dart           # Guided nutrition questionnaire
│   └── deleted_recipes.dart         # Recipes hidden by current allergies
│
├── services/                        # Business logic & API calls
│   ├── authorisation.dart           # Login, register, token management
│   ├── profile_service.dart         # User profile CRUD
│   ├── recipe_service.dart          # Recipe CRUD + ingredient search
│   ├── recipe_catalog_service.dart  # Merges local JSON + API recipes
│   ├── meal_log_service.dart        # Today's logged meals (singleton)
│   ├── meal_plan_service.dart       # Planned meals by date (singleton)
│   ├── shopping_list_service.dart   # Shopping items (singleton ChangeNotifier)
│   ├── allergy_service.dart         # Persists user allergen list
│   ├── allergen_filter_service.dart # Maps allergen names to ingredient keywords
│   ├── favourites_service.dart      # Persists favourite recipe titles
│   ├── custom_tag_service.dart      # User-created recipe tags
│   ├── private_notes_service.dart   # Per-recipe user notes
│   └── reroll_avoidance_service.dart# Tracks spun recipes within the day
│
├── widgets/                         # Reusable UI components
│   ├── navbar.dart                  # Navigation drawer scaffold
│   ├── spinning_wheel.dart          # Animated spinner widget
│   └── widgets.dart                 # Other shared UI helpers
│
└── assets/
    ├── images/                      # App icons and default avatars
    └── data/                        # Bundled local recipe JSON
        ├── recipe_attributes.json
        ├── recipe_ingredients.json
        └── recipe_steps.json
```

---

## Key Data Models

```dart
// Core recipe model (recipe_page.dart)
class RecipeModel {
  final String title, summary, imageUrl;
  final String prepTime, cookTime, totalTime;
  final int servings;
  final String difficulty;          // "Easy" | "Medium" | "Hard"
  final NutritionInfo nutrition;
  final List<IngredientEntry> ingredients;
  final List<String> steps;
  final List<String> tags;
  final int? id;                    // null = local JSON recipe; set = API recipe
}

class NutritionInfo {
  final int calories;
  final String protein, carbs, fats;  // e.g. "25g"
}

class IngredientEntry {
  final String name;
  final double quantity;
  final String unit;  // "tsp" | "tbsp" | "cup" | "ml" | "g" | "kg" | "oz" | "lb" | "pcs"
}

// Meal logging (meal_log_service.dart)
class LoggedMeal {
  final String recipeTitle;
  final int servings;
  final int caloriesPerServing;
  final double proteinPerServing, carbsPerServing, fatsPerServing;
}

class DailyNutritionTotals {
  final int totalRecipes, totalServings;
  final double calories, protein, carbs, fats;
}

// Meal planning (meal_plan_service.dart)
class PlannedMeal {
  final String recipeTitle;
  final int servings;
}

// Shopping list (shopping_list_service.dart)
class ShoppingItem {
  final String id;
  String name;
  int quantity;
  final Set<String> recipeTitles;
}
```

---

## API Endpoints

| Method | Path | Purpose | Auth required |
|--------|------|---------|---------------|
| POST | `/token` | Login (form-encoded email + password) | No |
| POST | `/register` | New user registration | No |
| GET | `/users/me` | Fetch current user profile | Bearer |
| PUT | `/users/me` | Update display name | Bearer |
| POST | `/users/me/avatar` | Upload profile image (multipart) | Bearer |
| GET | `/recipes` | List all recipes | Bearer |
| POST | `/recipes` | Create recipe (multipart) | Bearer |
| GET | `/ingredients?q=&limit=` | Search ingredient database | Bearer |

Authentication uses OAuth2 Bearer tokens. The token is stored in `flutter_secure_storage` and sent as `Authorization: Bearer <token>` on every authenticated request. A 401 response clears the token and redirects to login.

---

## State Management

**Approach:** Raw `ChangeNotifier` singletons + `setState()`. No Provider, Riverpod, or GetX.

| State type | Mechanism |
|-----------|-----------|
| Shared mutable state (meals, shopping list) | Singleton `ChangeNotifier` services; views call `addListener`/`removeListener` |
| View-local state | `setState()` inside `StatefulWidget` |
| Persistent preferences | `SharedPreferences` (allergies, favourites, tags, notes, calorie goals) |
| Auth token | `flutter_secure_storage` (encrypted, platform-native) |
| Bundled recipe data | JSON asset files loaded once at startup |

---

## Authentication Flow

1. User submits email + password on `LoginPage`.
2. `AuthService.login()` → POST `/token` (form-encoded).
3. API returns `access_token`; stored in `FlutterSecureStorage`.
4. `SharedPreferences` flag `isLoggedIn = true` set.
5. App navigates to dashboard.
6. On cold start: if `isLoggedIn` is true, skip login; otherwise show `LoginPage`.
7. Logout: token deleted, flag cleared, redirect to login.

---

## Recipe Catalogue Strategy

`RecipeCatalogService.getAllRecipes()` merges two sources:
1. **Local JSON** (bundled in assets) — loaded first; used as the base catalogue.
2. **API recipes** (from `/recipes`) — appended; deduplicated by title (local takes precedence).

This makes the app functional offline (with bundled recipes) while allowing the backend to add community recipes.

---

## Allergen Filtering

`AllergenFilterService` holds a static map of allergen names to ingredient keyword lists:

```
"dairy"   → ["milk", "cheese", "butter", "cream", "yogurt", ...]
"gluten"  → ["wheat", "flour", "pasta", "bread", "barley", ...]
"nuts"    → ["peanut", "almond", "walnut", "cashew", ...]
...
```

When allergens are active, any recipe containing a matching ingredient keyword is hidden from the catalogue and marked as "deleted" in the Settings view.

---

## Calorie Coach

An interactive questionnaire (`calorie_coach.dart`) that collects:
- Age, height, weight, biological sex
- Activity level (sedentary → very active)
- Goal (lose / maintain / gain weight)

Calculates BMR (Mifflin-St Jeor formula) and TDEE, then derives daily macro targets. Results are saved to `SharedPreferences` and displayed on the Profile page and the Dashboard progress ring.

---

## Testing

| Type | Location | Count |
|------|---------|-------|
| Unit tests (services, logic) | `test/services/`, `test/logic/` | Many |
| Widget tests (views) | `test/views/` | Many |
| Integration tests | `integration_test/app_test.dart` | End-to-end |

Total: 36+ passing tests at time of writing.

---

## Notable Design Decisions

- **Singleton services for shared state** — `MealLogService`, `MealPlanService`, `ShoppingListService` use a factory constructor with a static `_instance` to guarantee a single object in memory.
- **Local-first data** — The bundled JSON recipe catalogue means users see content immediately without a network request.
- **No DI container** — Services are instantiated directly in views (`final _service = RecipeService()`).
- **Reroll avoidance** — The meal spinner tracks which recipes it has already spun today, preventing repeats until all eligible recipes are exhausted.
- **Tag system** — Recipes carry both predefined tags (Breakfast, Vegan, High Protein, …) and user-created custom tags. Tags are colour-coded in the UI.
- **Brand colour** — Primary green `#74BC42` used throughout the UI.
