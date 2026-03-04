// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
// Mock data model
// ─────────────────────────────────────────────

class RecipeModel {
  final String title;
  final String summary;
  final String imageUrl;
  final String prepTime;
  final String cookTime;
  final String totalTime;
  final int servings;
  final String difficulty;
  final NutritionInfo nutrition;
  final List<String> ingredients;
  final List<String> steps;
  final List<String> tags;

  const RecipeModel({
    required this.title,
    required this.summary,
    required this.imageUrl,
    required this.prepTime,
    required this.cookTime,
    required this.totalTime,
    required this.servings,
    required this.difficulty,
    required this.nutrition,
    required this.ingredients,
    required this.steps,
    this.tags = const [],
  });
}

class NutritionInfo {
  final int calories;
  final String protein;
  final String carbs;
  final String fats;

  const NutritionInfo({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
  });
}

// ─────────────────────────────────────────────
// Recipe data
// ─────────────────────────────────────────────

final RecipeModel kSalmonRecipe = RecipeModel(
  title: 'Creamy Tuscan Salmon',
  summary:
      'A restaurant-quality dish ready in under 30 minutes. Pan-seared salmon fillets'
      ' bathed in a rich garlic cream sauce with sun-dried tomatoes and fresh spinach.',
  imageUrl:
      'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?w=1200&q=80',
  prepTime: '10 min',
  cookTime: '20 min',
  totalTime: '30 min',
  servings: 4,
  difficulty: 'Easy',
  tags: const ['High Protein', 'Gluten Free'],
  nutrition: const NutritionInfo(
    calories: 520,
    protein: '42 g',
    carbs: '12 g',
    fats: '34 g',
  ),
  ingredients: [
    '4 salmon fillets (approx. 150 g each)',
    '3 cloves garlic, minced',
    '1 cup heavy cream',
    '½ cup sun-dried tomatoes, drained and chopped',
    '2 cups fresh baby spinach',
    '½ cup grated Parmesan cheese',
    '1 tbsp olive oil',
    '1 tsp Italian seasoning',
    'Salt and black pepper to taste',
    'Fresh basil leaves, to garnish',
  ],
  steps: [
    'Pat the salmon fillets dry with paper towels and season both sides generously with salt, black pepper, and Italian seasoning.',
    'Heat olive oil in a large skillet over medium-high heat. Once shimmering, place the salmon skin-side down and sear for 4–5 minutes until the skin is crispy.',
    'Flip the salmon and cook for a further 3–4 minutes. Remove from the skillet and set aside on a warm plate.',
    'In the same skillet, reduce the heat to medium. Add the minced garlic and sauté for 30 seconds until fragrant, scraping up any browned bits.',
    'Pour in the heavy cream and bring to a gentle simmer. Stir in the Parmesan cheese until fully melted into the sauce.',
    'Add the sun-dried tomatoes and fresh spinach. Stir until the spinach wilts and the sauce thickens slightly, about 2 minutes.',
    'Return the salmon to the skillet and spoon the sauce over the fillets. Simmer together for 1–2 minutes to marry the flavours.',
    'Garnish with fresh basil leaves and serve immediately over pasta, rice, or crusty bread.',
  ],
);

final RecipeModel kChickenTacosRecipe = RecipeModel(
  title: 'Crispy Chicken Tacos',
  summary:
      'Street-style chicken tacos with a smoky chipotle marinade, fresh pico de gallo,'
      ' creamy avocado, and a squeeze of lime — ready in 35 minutes.',
  imageUrl:
      'https://images.unsplash.com/photo-1565299585323-38d6b0865b47?w=1200&q=80',
  prepTime: '15 min',
  cookTime: '20 min',
  totalTime: '35 min',
  servings: 4,
  difficulty: 'Easy',
  tags: const ['High Protein', 'Dairy Free'],
  nutrition: const NutritionInfo(
    calories: 430,
    protein: '34 g',
    carbs: '38 g',
    fats: '16 g',
  ),
  ingredients: [
    '500 g boneless chicken thighs',
    '2 tbsp chipotle paste',
    '1 tbsp olive oil',
    '1 tsp smoked paprika',
    '1 tsp ground cumin',
    '½ tsp garlic powder',
    '8 small corn or flour tortillas',
    '2 ripe avocados, sliced',
    '2 limes, cut into wedges',
    '1 cup pico de gallo (or fresh salsa)',
    '½ cup sour cream',
    'Fresh coriander leaves, to garnish',
    'Salt and black pepper to taste',
  ],
  steps: [
    'In a bowl, mix the chipotle paste, olive oil, smoked paprika, cumin, and garlic powder. Season with salt and pepper.',
    'Add the chicken thighs to the marinade and toss to coat. Leave for at least 10 minutes (or up to 24 hours in the fridge).',
    'Heat a large griddle or skillet over high heat. Cook the chicken for 5–6 minutes per side until charred and cooked through. Rest for 5 minutes.',
    'Slice or shred the rested chicken into bite-sized pieces.',
    'Warm the tortillas directly over a gas flame for 15–20 seconds per side, or in a dry pan, until pliable and lightly charred.',
    'To assemble: spread a little sour cream on each tortilla, then top with chicken, avocado slices, and pico de gallo.',
    'Garnish with fresh coriander and a squeeze of lime. Serve immediately.',
  ],
);

final RecipeModel kCarbonaraRecipe = RecipeModel(
  title: 'Spaghetti Carbonara',
  summary:
      'The ultimate Roman classic made in just 20 minutes. Silky egg-and-Pecorino sauce'
      ' clings to al-dente spaghetti with crispy guanciale — no cream required.',
  imageUrl:
      'https://images.unsplash.com/photo-1612874742237-6526221588e3?w=1200&q=80',
  prepTime: '5 min',
  cookTime: '15 min',
  totalTime: '20 min',
  servings: 2,
  difficulty: 'Medium',
  tags: const ['Comfort Food'],
  nutrition: const NutritionInfo(
    calories: 610,
    protein: '28 g',
    carbs: '72 g',
    fats: '22 g',
  ),
  ingredients: [
    '200 g spaghetti',
    '100 g guanciale (or pancetta), cut into small cubes',
    '2 large eggs',
    '2 egg yolks',
    '60 g Pecorino Romano, finely grated',
    '30 g Parmesan, finely grated',
    '1 tsp freshly cracked black pepper',
    'Salt (for pasta water)',
  ],
  steps: [
    'Bring a large pot of salted water to a rolling boil. Cook the spaghetti until al dente according to package instructions. Reserve 1 cup of pasta water before draining.',
    'While the pasta cooks, place the guanciale in a cold skillet. Set over medium heat and cook, stirring occasionally, until the fat has rendered and the pieces are golden and crispy, about 6–8 minutes. Remove from heat.',
    'In a bowl, whisk together the eggs, egg yolks, Pecorino Romano, and Parmesan until smooth. Season generously with cracked black pepper.',
    'Drain the spaghetti and immediately add it to the skillet with the guanciale (off the heat). Toss to coat the pasta in the rendered fat.',
    'Add a splash of the reserved pasta water to the egg mixture and stir to temper it. Pour the mixture over the pasta, tossing quickly and continuously so the eggs emulsify into a creamy sauce rather than scrambling.',
    'Add more pasta water, a little at a time, until the sauce reaches a glossy, coating consistency.',
    'Serve immediately in warm bowls, topped with extra Pecorino and a crack of black pepper.',
  ],
);

final RecipeModel kBeefStirFryRecipe = RecipeModel(
  title: 'Beef & Broccoli Stir Fry',
  summary:
      'A takeaway favourite made at home in 25 minutes. Tender strips of beef and'
      ' crisp broccoli tossed in a rich, glossy soy-ginger sauce.',
  imageUrl:
      'https://images.unsplash.com/photo-1603133872878-684f208fb84b?w=1200&q=80',
  prepTime: '10 min',
  cookTime: '15 min',
  totalTime: '25 min',
  servings: 3,
  difficulty: 'Easy',
  tags: const ['High Protein', 'Dairy Free'],
  nutrition: const NutritionInfo(
    calories: 380,
    protein: '38 g',
    carbs: '22 g',
    fats: '14 g',
  ),
  ingredients: [
    '400 g beef sirloin or flank steak, thinly sliced',
    '2 cups broccoli florets',
    '3 cloves garlic, minced',
    '1 tsp fresh ginger, grated',
    '3 tbsp soy sauce',
    '1 tbsp oyster sauce',
    '1 tbsp sesame oil',
    '1 tsp cornstarch',
    '1 tsp brown sugar',
    '2 tbsp vegetable oil',
    'Sesame seeds and spring onions, to garnish',
    'Steamed rice, to serve',
  ],
  steps: [
    'In a bowl, toss the sliced beef with 1 tbsp soy sauce and the cornstarch. Set aside to marinate for 5 minutes.',
    'Whisk together the remaining soy sauce, oyster sauce, sesame oil, and brown sugar in a small bowl to make the stir-fry sauce.',
    'Heat 1 tbsp vegetable oil in a wok or large skillet over high heat until smoking. Add the beef in a single layer and cook for 1–2 minutes per side until browned. Remove and set aside.',
    'Add the remaining oil to the wok. Stir-fry the broccoli for 2–3 minutes until bright green and just tender.',
    'Add the garlic and ginger and stir-fry for 30 seconds until fragrant.',
    'Return the beef to the wok and pour over the sauce. Toss everything together over high heat for 1 minute until the sauce thickens and coats the beef and broccoli.',
    'Scatter with sesame seeds and sliced spring onions. Serve immediately over steamed rice.',
  ],
);

final RecipeModel kMasalaDaalRecipe = RecipeModel(
  title: 'Masala Daal',
  summary:
      'A warming, deeply spiced Indian red lentil soup tempered with caramelised onions,'
      ' tomatoes, and aromatics. Naturally vegan and packed with plant-based protein.',
  imageUrl:
      'https://images.unsplash.com/photo-1546549032-9571cd6b27df?w=1200&q=80',
  prepTime: '10 min',
  cookTime: '30 min',
  totalTime: '40 min',
  servings: 4,
  difficulty: 'Easy',
  tags: const ['Vegan', 'High Fibre', 'High Protein'],
  nutrition: const NutritionInfo(
    calories: 310,
    protein: '18 g',
    carbs: '48 g',
    fats: '6 g',
  ),
  ingredients: [
    '250 g red lentils, rinsed',
    '1 large onion, finely sliced',
    '3 cloves garlic, minced',
    '1 tsp fresh ginger, grated',
    '2 ripe tomatoes, diced',
    '2 tbsp vegetable oil or ghee',
    '1 tsp cumin seeds',
    '1 tsp ground turmeric',
    '1 tsp ground coriander',
    '½ tsp chilli flakes (or to taste)',
    '900 ml vegetable stock',
    'Salt to taste',
    'Fresh coriander and a squeeze of lemon, to serve',
  ],
  steps: [
    'Place the rinsed lentils in a saucepan with the vegetable stock and turmeric. Bring to a boil, then reduce heat and simmer for 20 minutes, stirring occasionally, until the lentils are completely soft and mushy.',
    'Meanwhile, heat the oil in a separate pan over medium heat. Add the cumin seeds and let them sizzle for 30 seconds.',
    'Add the sliced onions and cook for 8–10 minutes, stirring frequently, until deep golden brown.',
    'Stir in the garlic, ginger, ground coriander, and chilli flakes. Cook for 1 minute until fragrant.',
    'Add the diced tomatoes and cook for 5 minutes until they break down into a thick paste.',
    'Pour the onion-tomato tarka into the cooked lentils. Stir well to combine and season with salt. Simmer together for 5 minutes to let the flavours meld.',
    'Finish with a squeeze of lemon juice and scatter with fresh coriander. Serve with warm naan or steamed basmati rice.',
  ],
);

// ─────────────────────────────────────────────
// Route-passable entry point
// ─────────────────────────────────────────────

/// Pass an optional [recipe] argument via `Navigator.pushNamed` arguments,
/// or leave it null to display the built-in dummy recipe.
class RecipePage extends StatefulWidget {
  final RecipeModel? recipe;

  const RecipePage({super.key, this.recipe});

  @override
  State<RecipePage> createState() => _RecipePageState();
}

class _RecipePageState extends State<RecipePage> {
  bool _isFavourited = false;

  static const Color _brand = Color(0xFF74BC42);

  RecipeModel get _recipe => widget.recipe ?? kSalmonRecipe;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TitleSection(recipe: _recipe),
                      const SizedBox(height: 28),
                      _MetadataRow(recipe: _recipe),
                      const SizedBox(height: 28),
                      _SectionHeader(title: 'Nutrition per Serving'),
                      const SizedBox(height: 16),
                      _NutritionGrid(nutrition: _recipe.nutrition),
                      const SizedBox(height: 28),
                      _SectionHeader(title: 'Ingredients'),
                      const SizedBox(height: 16),
                      _IngredientsList(ingredients: _recipe.ingredients),
                      const SizedBox(height: 28),
                      _SectionHeader(title: 'Instructions'),
                      const SizedBox(height: 16),
                      _InstructionsList(steps: _recipe.steps),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sliver App Bar with hero image ──────────────────────────────────────

  SliverAppBar _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 360,
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 1,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: _CircleIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          onTap: () => Navigator.maybePop(context),
          tooltip: 'Back',
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: _CircleIconButton(
            icon: _isFavourited
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            iconColor: _isFavourited ? Colors.redAccent : Colors.black87,
            onTap: () => setState(() => _isFavourited = !_isFavourited),
            tooltip:
                _isFavourited ? 'Remove from Favourites' : 'Add to Favourites',
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
          child: Image.network(
            _recipe.imageUrl,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                color: const Color(0xFFE8F5E9),
                child: Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                    color: _brand,
                  ),
                ),
              );
            },
            errorBuilder: (_, __, ___) => Container(
              color: const Color(0xFFE8F5E9),
              child: const Center(
                child: Icon(Icons.broken_image_outlined,
                    size: 64, color: Colors.grey),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Reusable sub-widgets
// ─────────────────────────────────────────────

/// Circular icon button used for back/favourite actions.
class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final VoidCallback onTap;
  final String tooltip;

  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(50),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                // ignore: deprecated_member_use
                color: Colors.black.withOpacity(0.12),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon,
            size: 20,
            color: iconColor ?? Colors.black87,
          ),
        ),
      ),
    );
  }
}

/// Title and summary block.
class _TitleSection extends StatelessWidget {
  final RecipeModel recipe;

  const _TitleSection({required this.recipe});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          recipe.title,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          recipe.summary,
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey[600],
            height: 1.6,
          ),
        ),
      ],
    );
  }
}

/// Bold section heading with a green left accent bar.
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 22,
          decoration: BoxDecoration(
            color: const Color(0xFF74BC42),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
      ],
    );
  }
}

/// Horizontal scrollable row of metadata chips.
class _MetadataRow extends StatelessWidget {
  final RecipeModel recipe;

  const _MetadataRow({required this.recipe});

  @override
  Widget build(BuildContext context) {
    final items = [
      _MetaItem(
          icon: Icons.timer_outlined, label: 'Prep', value: recipe.prepTime),
      _MetaItem(
          icon: Icons.local_fire_department_outlined,
          label: 'Cook',
          value: recipe.cookTime),
      _MetaItem(
          icon: Icons.schedule_outlined,
          label: 'Total',
          value: recipe.totalTime),
      _MetaItem(
          icon: Icons.people_outline_rounded,
          label: 'Serves',
          value: '${recipe.servings}'),
      _MetaItem(
          icon: Icons.bar_chart_rounded,
          label: 'Difficulty',
          value: recipe.difficulty),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items
            .map((item) => Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _MetaChip(item: item),
                ))
            .toList(),
      ),
    );
  }
}

class _MetaItem {
  final IconData icon;
  final String label;
  final String value;

  const _MetaItem(
      {required this.icon, required this.label, required this.value});
}

class _MetaChip extends StatelessWidget {
  final _MetaItem item;

  const _MetaChip({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(item.icon, color: const Color(0xFF74BC42), size: 22),
          const SizedBox(height: 6),
          Text(
            item.value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.label,
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}

/// Responsive 2×2 nutrition grid.
class _NutritionGrid extends StatelessWidget {
  final NutritionInfo nutrition;

  const _NutritionGrid({required this.nutrition});

  @override
  Widget build(BuildContext context) {
    final cards = [
      _NutritionCard(
        label: 'Calories',
        value: '${nutrition.calories}',
        unit: 'kcal',
        icon: Icons.local_fire_department_rounded,
        color: const Color(0xFFFF7043),
      ),
      _NutritionCard(
        label: 'Protein',
        value: nutrition.protein,
        unit: '',
        icon: Icons.fitness_center_rounded,
        color: const Color(0xFF42A5F5),
      ),
      _NutritionCard(
        label: 'Carbs',
        value: nutrition.carbs,
        unit: '',
        icon: Icons.grain_rounded,
        color: const Color(0xFFFFCA28),
      ),
      _NutritionCard(
        label: 'Fats',
        value: nutrition.fats,
        unit: '',
        icon: Icons.water_drop_rounded,
        color: const Color(0xFF74BC42),
      ),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final crossCount = constraints.maxWidth > 500 ? 4 : 2;
      return GridView.count(
        crossAxisCount: crossCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.4,
        children: cards,
      );
    });
  }
}

class _NutritionCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;

  const _NutritionCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              // ignore: deprecated_member_use
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  if (unit.isNotEmpty) ...[
                    const SizedBox(width: 3),
                    Text(
                      unit,
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ],
              ),
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bullet-point ingredients list.
class _IngredientsList extends StatelessWidget {
  final List<String> ingredients;

  const _IngredientsList({required this.ingredients});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: ingredients.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          indent: 56,
          color: Colors.grey[100],
        ),
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF74BC42),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    ingredients[index],
                    style: const TextStyle(
                        fontSize: 14, height: 1.5, color: Color(0xFF333333)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Numbered step-by-step instructions list.
class _InstructionsList extends StatelessWidget {
  final List<String> steps;

  const _InstructionsList({required this.steps});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(steps.length, (index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _StepCard(stepNumber: index + 1, instruction: steps[index]),
        );
      }),
    );
  }
}

class _StepCard extends StatelessWidget {
  final int stepNumber;
  final String instruction;

  const _StepCard({required this.stepNumber, required this.instruction});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step number badge
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF74BC42),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              '$stepNumber',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                instruction,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF333333),
                  height: 1.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
