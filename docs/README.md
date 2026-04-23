# Documentation (Read the Docs)

This folder contains the Read the Docs setup and documentation source for the Simply Serve project.

## Software Idea

Simply Serve is a meal-planning and nutrition-tracking app built to make it easier to choose recipes, plan meals, log what was eaten, and manage a shopping list in one place. The app combines recipe discovery, dietary filtering, and daily nutrition summaries so users can keep meal planning simple without losing flexibility.

## Implementation Ideas

The original project explored a nutrition coach, an AI chatbot, a FAQ section, and stronger branding throughout the UI. Those ideas remain possible future enhancements rather than current features.

## Current App

Simply Serve is implemented as a Flutter frontend backed by a Python API. The app supports account access, recipe browsing, meal planning, meal logging, shopping list management, allergy filtering, and a profile/settings area.

## Implemented Features

- Authentication with register, log in, session persistence, and log out.
- Dashboard with daily calorie and macro summaries sourced from logged meals.
- Quick navigation from the dashboard to recipes, the meal spinner, and the calendar.
- Recipe browsing with search, advanced filters for tags, cuisine, difficulty, and duration, plus allergy-based hiding.
- Recipe detail pages with nutrition, ingredients, instructions, favourites, editing, deleting, and shopping list integration.
- Recipe creation and editing with ingredient search, step entry, and image upload.
- Meal spinner with breakfast, lunch, dinner, and snack filters for picking a random recipe.
- Meal calendar with separate Planning and Log tabs for assigning servings to dates.
- Shopping list with ingredient aggregation, quantity controls, and item removal.
- Settings page for managing stored allergies and viewing recipes hidden by those allergies.
- Profile page that displays the signed-in user email.

## Key Screens

- Dashboard shows the daily nutrition summary and links to other parts of the app.
- Recipes combines search, filtering, and recipe cards for browsing the catalogue.
- Meal Spinner provides a slot-machine style random meal picker.
- Meal Calendar lets users plan meals for future dates and log meals for today.
- Shopping List tracks ingredients added from recipes and keeps counts up to date.
- Settings stores allergies locally and uses them to hide matching recipes.

## Setup

1. Copy `sample.env` to `.env` in the `app` folder and set `BASE_URL` to the backend API.
2. Run `flutter pub get` inside `app`.
3. Start the backend API before launching the Flutter app.
4. Run `flutter run` from the `app` directory.

## Testing

Widget and service tests cover the main application areas, including login, dashboard, recipes, settings, shopping list, meal calendar, profile, and the meal spinner.

## Team Members

- Ben Charlton - UP2275414 - Git: 164635027
- Ben Brown - UP2268495 - Git: 235307323
- Geeth Alsawair - UP2248997 - Git: 235309289
- Ihor Savenko - UP2241487 - Git: 42842614
- Sujan Rajesh - UP2270752 - Git: 149666846
- James Hind - UP2267708 - Git: 200824129
- Dmitrijs Jefimovs - UP2210435 - Git: 116079463

## Local Docs Build

From project root:

```bash
pip install -r docs/requirements.txt
sphinx-build -b html docs docs/_build/html
```

Then open `docs/_build/html/index.html`.

## Key Docs Files

- `.readthedocs.yaml` - Read the Docs build configuration.
- `docs/conf.py` - Sphinx configuration.
- `docs/index.rst` - Documentation home page.
