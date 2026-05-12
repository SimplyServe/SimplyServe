// ============================================================
// widgets/spinning_wheel.dart — Spinning Wheel Widget
//
// A slot-machine-style meal randomiser card. Key technical highlights:
//
// Animation — two-phase spin using FixedExtentScrollController:
//   Phase 1 (1400 ms): linear fast spin — items blur past
//   Phase 2 (4400 ms): _CasinoCurve deceleration — dramatic slow-down
//
// _CasinoCurve — custom Curve subclass:
//   Uses 1 - (1-t)^5 so the wheel decelerates sharply at the end,
//   building tension on the final items like a real slot machine.
//
// Virtual list trick:
//   The scroll list is _virtualMultiplier (100) × real list length.
//   This allows effectively unlimited scrolling in one direction
//   without hitting list boundaries, making the spin feel seamless.
//
// Data sources:
//   • API recipes (RecipeService.getRecipes) — user-created recipes
//   • Local JSON bundle (assets/data/recipe_attributes.json etc.)
//     — SimplyServe catalog bundled with the app
//   Both are merged into _recipeMap (title → RecipeModel), with API
//   recipes taking priority (putIfAbsent keeps the first entry).
//
// Allergen filtering:
//   After loading, AllergenFilterService.recipeContainsAnyAllergen
//   is used to skip recipes containing any of the user's allergens.
//
// Reroll avoidance:
//   RerollAvoidanceService tracks which recipes were rolled today
//   (persisted across restarts). Rolled recipes are excluded from
//   the spin pool. The "Reset" link clears today's rolled list.
//
// Meal type filter:
//   FilterChip row above the wheel. Selecting a type limits _meals
//   to recipes tagged with that meal type.
//
// Audio:
//   AudioPlayer playback rate is scaled so the sound track finishes
//   exactly when the spinner stops (total spin ≈ 7800 ms).
// ============================================================

import 'dart:convert';
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:simplyserve/recipe_page.dart';
import 'package:simplyserve/services/allergen_filter_service.dart';
import 'package:simplyserve/services/allergy_service.dart';
import 'package:simplyserve/services/recipe_service.dart';
import 'package:simplyserve/services/reroll_avoidance_service.dart';

// ── Custom animation curve ────────────────────────────────────────────────────

/// A Curve that stays fast for a long time then creeps to a stop.
///
/// Formula: `1 - (1-t)^5`
/// The exponent 5 produces a very shallow slope at t≈1, mimicking a real
/// slot machine that visibly crawls before halting. This builds audience
/// tension during a live demo.
class _CasinoCurve extends Curve {
  const _CasinoCurve();
  @override
  double transformInternal(double t) =>
      1.0 - math.pow(1.0 - t, 5).toDouble();
}

// ── SpinningWheelWidget ────────────────────────────────────────────────────────

/// A StatefulWidget that renders the full slot-machine card.
/// All spin logic lives here; [SpinWheelView] is just a thin wrapper.
class SpinningWheelWidget extends StatefulWidget {
  const SpinningWheelWidget({super.key});

  @override
  State<SpinningWheelWidget> createState() =>
      _SpinningWheelWidgetState();
}

class _SpinningWheelWidgetState extends State<SpinningWheelWidget>
    with WidgetsBindingObserver {
  final RecipeService _recipeService = RecipeService();
  final AllergyService _allergyService = AllergyService();
  final RerollAvoidanceService _rerollService = RerollAvoidanceService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isLoading = true;
  bool _isSpinning = false;

  /// Titles of recipes rolled today (managed by RerollAvoidanceService).
  Set<String> _rolledToday = {};

  /// Master map of all available recipes (title → RecipeModel).
  /// API recipes are inserted first; local catalog fills gaps via putIfAbsent.
  final Map<String, RecipeModel> _recipeMap = {};

  static const List<String> _kMealTypes = [
    'Breakfast',
    'Lunch',
    'Dinner',
    'Snack',
  ];

  /// The currently active meal-type filter, or null for "All".
  String? _activeMealFilter;

  /// Computed spin pool: recipes matching the active filter,
  /// excluding any already rolled today.
  List<String> get _meals {
    List<String> base;
    if (_activeMealFilter == null) {
      base = _recipeMap.keys.toList();
    } else {
      // Only include recipes tagged with the selected meal type.
      base = _recipeMap.entries
          .where((e) => e.value.tags.contains(_activeMealFilter))
          .map((e) => e.key)
          .toList();
    }
    // Exclude recipes already seen today (reroll avoidance).
    return base
        .where((title) => !_rolledToday.contains(title))
        .toList();
  }

  /// The recipe title that most recently won the spin.
  String _selectedMeal = '';

  // ── Scroll controller ─────────────────────────────────────────────────

  /// Controls the ListWheelScrollView. FixedExtentScrollController is
  /// required for animateToItem(), which is the API used by the two-phase spin.
  late FixedExtentScrollController _scrollController;

  /// Multiplier for the virtual list. Total items = real items × 100.
  /// Keeps the scroll position well away from the list boundaries so the
  /// user can never see the wheel wrap around.
  static const int _virtualMultiplier = 100;

  /// The current virtual index. Stored so we can compute where to animate
  /// to in the next spin without resetting position.
  int _currentIndex = 0;

  // ── Lifecycle ─────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    // Register as an AppLifecycle observer so we refresh recipes when
    // the user returns to the app (e.g. after creating a new recipe).
    WidgetsBinding.instance.addObserver(this);
    _scrollController = FixedExtentScrollController();
    _loadRolledAndFetch();
  }

  /// Loads today's rolled set first so it's ready before the recipe list
  /// is rendered. Then fetches recipes.
  Future<void> _loadRolledAndFetch() async {
    _rolledToday = await _rerollService.getRolledToday();
    _fetchRecipes();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-fetch recipes when the app comes back to the foreground, in case
    // the user created or deleted a recipe in another screen.
    if (state == AppLifecycleState.resumed) _fetchRecipes();
  }

  // ── Data loading ──────────────────────────────────────────────────────

  /// Fetches recipes from both the API and the bundled local JSON, merges
  /// them into [_recipeMap], and applies allergen filtering.
  ///
  /// Data structure of local bundle:
  ///   assets/data/recipe_attributes.json  — title → {summary, imageUrl, tags, ...}
  ///   assets/data/recipe_ingredients.json — title → [ingredient strings]
  ///   assets/data/recipe_steps.json       — title → [step strings]
  Future<void> _fetchRecipes() async {
    // ── API recipes ───────────────────────────────────────────────────
    List<RecipeModel> apiRecipes = [];
    try {
      apiRecipes = await _recipeService.getRecipes();
    } catch (_) {
      // Network failure is non-fatal — local recipes will still be shown.
    }

    // ── Local JSON bundle ─────────────────────────────────────────────
    List<RecipeModel> localRecipes = [];
    try {
      final attrsJson =
          await rootBundle.loadString('assets/data/recipe_attributes.json');
      final ingredientsJson =
          await rootBundle.loadString('assets/data/recipe_ingredients.json');
      final stepsJson =
          await rootBundle.loadString('assets/data/recipe_steps.json');

      final attrs = json.decode(attrsJson) as Map<String, dynamic>;
      final ingredients =
          json.decode(ingredientsJson) as Map<String, dynamic>;
      final steps = json.decode(stepsJson) as Map<String, dynamic>;

      for (final entry in attrs.entries) {
        final title = entry.key;
        final a = entry.value as Map<String, dynamic>;
        final n = a['nutrition'] as Map<String, dynamic>? ?? {};
        localRecipes.add(RecipeModel(
          title: title,
          summary: a['summary'] ?? '',
          imageUrl: a['imageUrl'] ?? '',
          prepTime: a['prepTime'] ?? '',
          cookTime: a['cookTime'] ?? '',
          totalTime: a['totalTime'] ?? '',
          servings: a['servings'] ?? 1,
          difficulty: a['difficulty'] ?? 'Easy',
          nutrition: NutritionInfo(
            calories: n['calories'] ?? 0,
            protein: n['protein'] ?? '0g',
            carbs: n['carbs'] ?? '0g',
            fats: n['fats'] ?? '0g',
          ),
          // Legacy ingredients are plain strings; wrap with fromLegacy.
          ingredients: List<String>.from(ingredients[title] ?? [])
              .map(IngredientEntry.fromLegacy)
              .toList(),
          steps: List<String>.from(steps[title] ?? []),
          tags: List<String>.from(a['tags'] ?? []),
        ));
      }
    } catch (_) {
      // Asset loading failure is non-fatal — API recipes will still be shown.
    }

    final allergies = await _allergyService.loadAllergies();

    if (mounted) {
      setState(() {
        _recipeMap.clear();
        // API recipes take priority.
        for (final r in apiRecipes) {
          if (!AllergenFilterService.recipeContainsAnyAllergen(
              r, allergies)) {
            _recipeMap[r.title] = r;
          }
        }
        // Local recipes fill in gaps (putIfAbsent never overwrites).
        for (final r in localRecipes) {
          if (!AllergenFilterService.recipeContainsAnyAllergen(
              r, allergies)) {
            _recipeMap.putIfAbsent(r.title, () => r);
          }
        }
        _isLoading = false;
        if (_meals.isNotEmpty) {
          // Start the virtual index in the middle of the virtual list so
          // there is room to spin forward without hitting the end.
          _currentIndex = (_virtualMultiplier ~/ 2) * _meals.length;
          // addPostFrameCallback ensures the controller is attached before
          // we try to jump to the initial index.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.jumpToItem(_currentIndex);
            }
          });
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // ── Spin logic ────────────────────────────────────────────────────────

  /// Executes the two-phase slot-machine animation.
  ///
  /// 1. Play sound immediately (rate scaled to match total spin duration).
  /// 2. Wait 2000 ms for a dramatic pause before spinning.
  /// 3. Phase 1: animateToItem with Curves.linear (fast blur spin).
  /// 4. Phase 2: animateToItem with _CasinoCurve (tense slowdown).
  /// 5. Mark the result in RerollAvoidanceService and display it.
  void _spin() async {
    if (_isSpinning || _meals.isEmpty) return;

    setState(() {
      _isSpinning = true;
      _selectedMeal = '';
    });

    // ── Audio ─────────────────────────────────────────────────────────
    // playbackRate is scaled so the track ends when the spinner stops.
    // Total spin = 2000ms delay + 1400ms phase1 + 4400ms phase2 = 7800ms.
    try {
      await _audioPlayer.stop();
      await _audioPlayer.setSource(
          AssetSource('sounds/spinner_sound.mp3'));
      final audioDuration = await _audioPlayer.getDuration();
      if (audioDuration != null && audioDuration.inMilliseconds > 0) {
        final rate =
            (audioDuration.inMilliseconds / 7800).clamp(0.5, 4.0);
        await _audioPlayer.setPlaybackRate(rate);
      }
      await _audioPlayer.setVolume(1);
      _audioPlayer.resume();
    } catch (_) {
      // Audio is non-essential; silently skip if it fails.
    }

    // Brief pause before spinning starts — builds anticipation.
    await Future.delayed(const Duration(milliseconds: 2000));

    final random = math.Random();
    final targetOffset = random.nextInt(_meals.length);

    // ── Phase 1: linear fast spin ─────────────────────────────────────
    // Scroll forward by 7 full rotations so items blur past visually.
    final phase1Target = _currentIndex + 7 * _meals.length;
    await _scrollController.animateToItem(
      phase1Target,
      duration: const Duration(milliseconds: 1400),
      curve: Curves.linear,
    );

    // ── Phase 2: _CasinoCurve deceleration ───────────────────────────
    // Add 5 more full rotations plus a random offset so the final item
    // is unpredictable. The custom curve provides the dramatic slowdown.
    final finalTarget =
        phase1Target + 5 * _meals.length + targetOffset;
    await _scrollController.animateToItem(
      finalTarget,
      duration: const Duration(milliseconds: 4400),
      curve: const _CasinoCurve(),
    );

    if (mounted) {
      final selected = _meals[finalTarget % _meals.length];
      await _rerollService.markRolled(selected);
      _rolledToday = await _rerollService.getRolledToday();
      setState(() {
        _currentIndex = finalTarget;
        _isSpinning = false;
        _selectedMeal = selected;
      });
    }
  }

  // ── Filter logic ──────────────────────────────────────────────────────

  /// Toggles the active meal-type filter. Selecting the same filter again
  /// clears it (returns to "All"). Resets the scroll controller because the
  /// _meals list length may have changed.
  void _onFilterChanged(String? mealType) {
    if (_isSpinning) return;
    setState(() {
      _activeMealFilter =
          (_activeMealFilter == mealType) ? null : mealType;
      _selectedMeal = '';
      // Dispose and recreate the controller so the new virtual list length
      // is used for the initial jump.
      _scrollController.dispose();
      _scrollController = FixedExtentScrollController();
      if (_meals.isNotEmpty) {
        _currentIndex = (_virtualMultiplier ~/ 2) * _meals.length;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpToItem(_currentIndex);
          }
        });
      }
    });
  }

  // ── Build helpers ─────────────────────────────────────────────────────

  /// Horizontal row of meal-type FilterChip pills.
  /// Tapping a chip calls _onFilterChanged; tapping the active chip clears it.
  Widget _buildMealFilterRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _kMealTypes.map((type) {
          final isSelected = _activeMealFilter == type;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => _onFilterChanged(type),
              // AnimatedContainer smoothly transitions colours when selected.
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF74BC42)
                      : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF74BC42)
                        : const Color(0xFFDDDDDD),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  type,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : const Color(0xFF666666),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Brand-green top stripe
          Container(
            height: 4,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF74BC42), Color(0xFF4E8A2B)],
              ),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(20)),
            ),
          ),
          const SizedBox(height: 14),

          // ── Card title ────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF74BC42).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.casino_outlined,
                    color: Color(0xFF74BC42), size: 18),
              ),
              const SizedBox(width: 8),
              const Text(
                'What to eat?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1C2A45),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Meal-type filter chips ────────────────────────────────
          _buildMealFilterRow(),

          // ── Reroll avoidance status + Reset link ──────────────────
          if (_rolledToday.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline,
                      size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    '${_rolledToday.length} recipe${_rolledToday.length == 1 ? '' : 's'} rolled today',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey[500]),
                  ),
                  const SizedBox(width: 6),
                  // "Reset" clears the reroll list so all recipes are
                  // available again for today's session.
                  GestureDetector(
                    onTap: () async {
                      await _rerollService.clearRolledToday();
                      _rolledToday = {};
                      setState(() {
                        _selectedMeal = '';
                        _scrollController.dispose();
                        _scrollController = FixedExtentScrollController();
                        if (_meals.isNotEmpty) {
                          _currentIndex =
                              (_virtualMultiplier ~/ 2) * _meals.length;
                          WidgetsBinding.instance
                              .addPostFrameCallback((_) {
                            if (_scrollController.hasClients) {
                              _scrollController.jumpToItem(_currentIndex);
                            }
                          });
                        }
                      });
                    },
                    child: const Text(
                      'Reset',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF74BC42),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),

          // ── Slot machine viewport ────────────────────────────────
          _buildSlotMachine(),
          const SizedBox(height: 16),

          // ── Roll button ───────────────────────────────────────────
          // Disabled (null onPressed) while spinning to prevent double-tap.
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSpinning ? null : _spin,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1C2A45),
                disabledBackgroundColor: Colors.grey[300],
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                _isSpinning ? 'Rolling...' : 'Roll',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Result panel (fades in after spin) ────────────────────
          // AnimatedOpacity fades the panel in without a layout shift.
          // IgnorePointer prevents the "Go to Recipe" button from being
          // tapped while the panel is invisible.
          AnimatedOpacity(
            opacity: _selectedMeal.isNotEmpty ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: IgnorePointer(
              ignoring: _selectedMeal.isEmpty,
              child: Column(
                children: [
                  // "Selected: ___" confirmation banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF74BC42).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFF74BC42)),
                    ),
                    child: Text(
                      'Selected: $_selectedMeal',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF74BC42),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // "Go to Recipe" navigates to RecipePage with the
                  // winning recipe passed as a named route argument.
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final recipe = _recipeMap[_selectedMeal];
                        Navigator.pushNamed(
                          context,
                          '/recipe',
                          arguments: recipe,
                        );
                      },
                      icon: const Icon(Icons.menu_book_rounded,
                          color: Colors.white),
                      label: const Text(
                        'Go to Recipe',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF74BC42),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Slot machine viewport ─────────────────────────────────────────────

  /// Builds the dark rounded container that houses the ListWheelScrollView.
  ///
  /// The virtual item list has [_meals.length × _virtualMultiplier] entries;
  /// each entry is [meals[i % meals.length]] so the wheel cycles seamlessly.
  /// NeverScrollableScrollPhysics prevents the user from manually scrolling —
  /// only the programmatic animateToItem calls move the wheel.
  ///
  /// Top and bottom gradient overlays fade the items near the edges,
  /// reinforcing the illusion that the list continues beyond the viewport.
  Widget _buildSlotMachine() {
    if (_isLoading) {
      return const SizedBox(
        height: 160,
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFF74BC42)),
        ),
      );
    }

    if (_meals.isEmpty) {
      return SizedBox(
        height: 160,
        child: Center(
          child: Text(
            _activeMealFilter != null
                ? 'No $_activeMealFilter recipes available'
                : 'No recipes available',
            style: const TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ),
      );
    }

    // Virtual list: index modulo real list length gives the real item.
    final virtualItems = List.generate(
      _meals.length * _virtualMultiplier,
      (i) => _meals[i % _meals.length],
    );

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C2A45),
        borderRadius: BorderRadius.circular(16),
      ),
      padding:
          const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Highlight strip for the centred (selected) item
          Container(
            height: 52,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF74BC42).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: const Color(0xFF74BC42), width: 1.5),
            ),
          ),

          // ── ListWheelScrollView ──────────────────────────────────
          // itemExtent = fixed height of each wheel item (52 px).
          // perspective and diameterRatio create the 3-D drum effect.
          // NeverScrollableScrollPhysics + programmatic animateToItem
          // means only _spin() can move the wheel.
          SizedBox(
            height: 160,
            child: ListWheelScrollView.useDelegate(
              controller: _scrollController,
              itemExtent: 52,
              physics: const NeverScrollableScrollPhysics(),
              perspective: 0.003,
              diameterRatio: 2.5,
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: virtualItems.length,
                builder: (context, index) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16),
                      child: Text(
                        virtualItems[index],
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Top fade gradient — items fade out toward the top edge.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF1C2A45),
                    const Color(0xFF1C2A45).withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),

          // Bottom fade gradient — items fade out toward the bottom edge.
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(16)),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    const Color(0xFF1C2A45),
                    const Color(0xFF1C2A45).withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
