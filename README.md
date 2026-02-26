# Please use feature branches to publish your work
each pull request needs approval from another team member, so when you create a pull request send a message in the group chat to alert other team members.

How to use feature branches: In vscode, when commiting changes you will find the main is locked. Create new branch (name doesnt matter) and commit then publish. on github create a merge pull request. After another member approves pull request, merge and then delete branch.

How to approve: On github go to the pull requests tab. under there you will see the most recently created pull request. Read the changes made by team member under the files changed tab. In the top right there will be a green button to review work, select the approve category and submit. You can then complete the pull request and delete branch or leave it to the team member that created the request initially.


# Simply Serve - Smart Meal Planner

A Flutter-based meal planning application that helps users manage their nutrition and discover recipes tailored to their dietary needs.

## Project Overview

**Simply Serve** is a mobile application designed to simplify meal planning and nutrition tracking. The app provides an intuitive interface for users to navigate through various features including a dashboard, recipe browser, and personalized settings.

### Key Features

- ✅ **User Authentication** - Secure login page with Google Sign-In integration
- ✅ **Dashboard** - Welcome screen with quick access to nutrition information and meal plans
- ✅ **Recipe Browser** - Browse and discover delicious meal recipes tailored to dietary needs
- ✅ **Settings** - Comprehensive settings with account management, preferences, and app information
- ✅ **Navigation Drawer** - Consistent navigation across all views with active route highlighting
- ✅ **Responsive Design** - Clean, modern UI with custom theme color (#74BC42)

### App Structure

```
lib/
├── main.dart                    # App entry point with routing configuration
├── authorisation.dart           # Login page with authentication
├── views/
│   ├── dashboard.dart          # Dashboard view with nutrition info
│   ├── recipes.dart            # Recipe browsing interface
│   └── settings.dart           # Settings and preferences
└── widgets/
    ├── navbar.dart             # Reusable navigation drawer
    └── widgets.dart            # Shared widget components
```

## Getting Started

### Prerequisites
- Flutter SDK (3.35.5 or later)
- Dart SDK (3.9.2 or later)
- Android Studio / VS Code with Flutter extensions
- Android Emulator or physical device for testing

### Installation

1. **Clone the repository:**
```bash
git clone https://github.com/sushisuj/Software-Engineering-CW2.git
cd Software-Engineering-CW2/app
```

2. **Install dependencies:**
```bash
flutter pub get
```

3. **Run the application:**
```bash
flutter run
```

### Running on Emulator
- Ensure an Android emulator is running or a device is connected
- The app will automatically detect and deploy to the available device

## Testing

The project includes comprehensive testing coverage with **36 passing tests** across unit, widget, and integration test suites.

### Test Structure

```
test/
├── widget_test.dart            # Main app and login tests (3 tests)
└── views/
    ├── dashboard_test.dart     # Dashboard view tests (6 tests)
    ├── recipes_test.dart       # Recipes view tests (9 tests)
    └── settings_test.dart      # Settings view tests (14 tests)

integration_test/
└── app_test.dart               # End-to-end integration tests (4 tests)
```

### Running Tests

**Run all unit and widget tests:**
```bash
flutter test
```

**Run integration tests:**
```bash
flutter test integration_test
```

**Run specific test file:**
```bash
flutter test test/views/dashboard_test.dart
```

**Run with verbose output:**
```bash
flutter test --reporter expanded
```

### Test Coverage

- **Unit/Widget Tests:** 32/32 passing ✅
  - Dashboard: 6 tests (rendering, buttons, SnackBar, drawer navigation, theme)
  - Recipes: 9 tests (rendering, search functionality, icons, colors, drawer)
  - Settings: 14 tests (sections, items, styling, navigation, drawer)
  - Main App: 3 tests (app initialization, login, navigation)

- **Integration Tests:** 4/4 passing ✅
  - Full app launch and navigation flows
  - Drawer-based navigation between all pages
  - End-to-end user journeys

## Development Workflow

### Branch Management

**Please use feature branches to publish your work.** Each pull request needs approval from another team member.

#### Creating a Feature Branch:
1. In VS Code, when committing changes, create a new branch (descriptive name recommended)
2. Commit and publish your changes
3. On GitHub, create a merge pull request
4. Send a message in the group chat to alert team members
5. After approval, merge and delete the branch

#### Approving Pull Requests:
1. Go to the **Pull Requests** tab on GitHub
2. Review the changes under the **Files Changed** tab
3. Click the green **Review** button in the top right
4. Select **Approve** and submit
5. Complete the pull request and delete the branch

## Dependencies

### Core Dependencies
- **flutter** - Flutter SDK
- **cupertino_icons** (^1.0.0) - iOS-style icons
- **shared_preferences** (^2.2.2) - Local data persistence
- **google_sign_in** (^6.2.1) - Google authentication

### Dev Dependencies
- **flutter_test** - Testing framework
- **flutter_lints** (^2.0.0) - Linting rules
- **integration_test** - Integration testing support

## Project Configuration

- **App Name:** Simply Serve
- **Package Name:** simplyserve
- **Version:** 1.0.0+1
- **Theme Color:** #74BC42 (Green)
- **Minimum SDK:** Dart 2.17.0

## Troubleshooting

### Windows Symlinks
If `flutter pub get` or `flutter run` fails with symlink errors:
- Enable **Developer Mode** in Windows Settings > Privacy & security > For developers

### Android Emulator
- Use `10.0.2.2:8000` to connect to localhost from the emulator
- Ensure emulator has sufficient storage and RAM allocated

### Test Failures
- Run `flutter clean` and `flutter pub get` to refresh dependencies
- Ensure all files are saved before running tests
- Check that the correct Flutter/Dart SDK version is installed

## Future Enhancements

Planned features for upcoming releases:
- [ ] Recipe search and filtering functionality
- [ ] Nutrition tracking and calorie counter
- [ ] Meal planning calendar
- [ ] User profile management
- [ ] Recipe favorites and custom collections
- [ ] Dietary preference customization
- [ ] Meal randomizer ("Spin the wheel" feature)
- [ ] Backend API integration
- [ ] User registration system

## Team Members

- **Ben Charlton** - UP2275414 (Git: 164635027)
- **Ben Brown** - UP2268495 (Git: 235307323)
- **Geeth Alsawair** - UP2248997 (Git: 235309289)
- **Ihor Savenko** - UP2241487 (Git: 42842614)
- **Sujan Rajesh** - UP2270752 (Git: 149666846)
- **James Hind** - UP2267708 (Git: 200824129)
- **Dmitrijs Jefimovs** - UP2210435 (Git: 116079463)

## License

This project is developed as part of a Software Engineering coursework (CW2).

---

**Last Updated:** February 26, 2026
