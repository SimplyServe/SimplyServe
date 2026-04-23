import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:simplyserve/recipe_page.dart';
import 'package:simplyserve/services/allergen_filter_service.dart';
import 'package:simplyserve/services/allergy_service.dart';
import 'package:simplyserve/services/recipe_service.dart';

/// Stays fast for a long time, then dramatically creeps to a stop —
/// like a real slot machine building tension on the final items.
class _CasinoCurve extends Curve {
  const _CasinoCurve();
  @override
  double transformInternal(double t) => 1.0 - math.pow(1.0 - t, 5).toDouble();
}

class SpinningWheelWidget extends StatefulWidget {
  const SpinningWheelWidget({super.key});

  @override
  State<SpinningWheelWidget> createState() => _SpinningWheelWidgetState();
}

class _SpinningWheelWidgetState extends State<SpinningWheelWidget>
    with WidgetsBindingObserver {
  final RecipeService _recipeService = RecipeService();
  final AllergyService _allergyService = AllergyService();
  bool _isLoading = true;
  bool _isSpinning = false;

  final Map<String, RecipeModel> _recipeMap = {};

  static const List<String> _kMealTypes = [
    'Breakfast',
    'Lunch',
    'Dinner',
    'Snack',
  ];
  String? _activeMealFilter;

  List<String> get _meals {
    if (_activeMealFilter == null) return _recipeMap.keys.toList();
    return _recipeMap.entries
        .where((e) => e.value.tags.contains(_activeMealFilter))
        .map((e) => e.key)
        .toList();
  }

  String _selectedMeal = '';

  late FixedExtentScrollController _scrollController;
  static const int _virtualMultiplier = 100;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController = FixedExtentScrollController();
    _fetchRecipes();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _fetchRecipes();
  }

  Future<void> _fetchRecipes() async {
    List<RecipeModel> apiRecipes = [];
    try {
      apiRecipes = await _recipeService.getRecipes();
    } catch (_) {}

    List<RecipeModel> localRecipes = [];
    try {
      final attrsJson =
          await rootBundle.loadString('assets/data/recipe_attributes.json');
      final ingredientsJson =
          await rootBundle.loadString('assets/data/recipe_ingredients.json');
      final stepsJson =
          await rootBundle.loadString('assets/data/recipe_steps.json');

      final attrs = json.decode(attrsJson) as Map<String, dynamic>;
      final ingredients = json.decode(ingredientsJson) as Map<String, dynamic>;
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
          ingredients: List<String>.from(ingredients[title] ?? [])
              .map(IngredientEntry.fromLegacy)
              .toList(),
          steps: List<String>.from(steps[title] ?? []),
          tags: List<String>.from(a['tags'] ?? []),
        ));
      }
    } catch (_) {}

    final allergies = await _allergyService.loadAllergies();

    if (mounted) {
      setState(() {
        _recipeMap.clear();
        for (final r in apiRecipes) {
          if (!AllergenFilterService.recipeContainsAnyAllergen(r, allergies)) {
            _recipeMap[r.title] = r;
          }
        }
        for (final r in localRecipes) {
          if (!AllergenFilterService.recipeContainsAnyAllergen(r, allergies)) {
            _recipeMap.putIfAbsent(r.title, () => r);
          }
        }
        _isLoading = false;
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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  void _spin() async {
    if (_isSpinning || _meals.isEmpty) return;

    setState(() {
      _isSpinning = true;
      _selectedMeal = '';
    });

    final random = math.Random();
    final targetOffset = random.nextInt(_meals.length);

    // Phase 1: fast linear spin — items blur past like a real slot machine
    final phase1Target = _currentIndex + 7 * _meals.length;
    await _scrollController.animateToItem(
      phase1Target,
      duration: const Duration(milliseconds: 1400),
      curve: Curves.linear,
    );

    // Phase 2: stays fast for a long time then creeps to a stop, building tension
    final finalTarget = phase1Target + 5 * _meals.length + targetOffset;
    await _scrollController.animateToItem(
      finalTarget,
      duration: const Duration(milliseconds: 3200),
      curve: const _CasinoCurve(),
    );

    if (mounted) {
      setState(() {
        _currentIndex = finalTarget;
        _isSpinning = false;
        _selectedMeal = _meals[finalTarget % _meals.length];
      });
    }
  }

  void _onFilterChanged(String? mealType) {
    if (_isSpinning) return;
    setState(() {
      _activeMealFilter = (_activeMealFilter == mealType) ? null : mealType;
      _selectedMeal = '';
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
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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
                    color: isSelected ? Colors.white : const Color(0xFF666666),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

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
          Container(
            height: 4,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF74BC42), Color(0xFF4E8A2B)],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
          ),
          const SizedBox(height: 14),
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
          _buildMealFilterRow(),
          const SizedBox(height: 12),
          _buildSlotMachine(),
          const SizedBox(height: 16),
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
          AnimatedOpacity(
            opacity: _selectedMeal.isNotEmpty ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: IgnorePointer(
              ignoring: _selectedMeal.isEmpty,
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF74BC42).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF74BC42)),
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
                        padding: const EdgeInsets.symmetric(vertical: 14),
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

  Widget _buildSlotMachine() {
    if (_isLoading) {
      return const SizedBox(
        height: 160,
        child:
            Center(child: CircularProgressIndicator(color: Color(0xFF74BC42))),
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

    final virtualItems = List.generate(
      _meals.length * _virtualMultiplier,
      (i) => _meals[i % _meals.length],
    );

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C2A45),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Highlight strip for the selected (centre) item
          Container(
            height: 52,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF74BC42).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF74BC42), width: 1.5),
            ),
          ),
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
                      padding: const EdgeInsets.symmetric(horizontal: 16),
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
          // Top fade
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
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
          // Bottom fade
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(16)),
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
