import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:simplyserve/recipe_page.dart';
import 'package:simplyserve/services/recipe_service.dart';
import 'dart:io' show File;

const List<String> _allowedUnits = [
  'tsp',
  'tbsp',
  'cup',
  'ml',
  'l',
  'g',
  'kg',
  'oz',
  'lb',
  'pcs',
];

class RecipeFormView extends StatefulWidget {
  const RecipeFormView({super.key});

  @override
  State<RecipeFormView> createState() => _RecipeFormViewState();
}

class _RecipeFormViewState extends State<RecipeFormView> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _summaryController = TextEditingController();
  final _prepTimeController = TextEditingController();
  final _cookTimeController = TextEditingController();
  final _servingsController = TextEditingController();
  final _ingredientSearchController = TextEditingController();
  final _stepsController = TextEditingController();
  XFile? _imageFile;
  bool _isLoading = false;
  bool _isSearchingIngredients = false;
  List<String> _ingredientSuggestions = [];
  final List<IngredientEntry> _selectedIngredients = [];

  final ImagePicker _picker = ImagePicker();
  final RecipeService _recipeService = RecipeService();

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _imageFile = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedIngredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one ingredient.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final title = _titleController.text.trim();
    final summary = _summaryController.text.trim();
    final prepTime = _prepTimeController.text.trim();
    final cookTime = _cookTimeController.text.trim();
    final servings = int.tryParse(_servingsController.text.trim()) ?? 1;
    final List<String> steps = _stepsController.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final newRecipe = RecipeModel(
      title: title,
      summary: summary,
      imageUrl: '',
      prepTime: prepTime,
      cookTime: cookTime,
      totalTime: '$prepTime + $cookTime',
      servings: servings,
      difficulty: 'Medium',
      nutrition: const NutritionInfo(
          calories: 0, protein: '0g', carbs: '0g', fats: '0g'),
      ingredients: List<IngredientEntry>.from(_selectedIngredients),
      steps: steps,
      tags: const ['New'],
    );

    final success = await _recipeService.createRecipe(newRecipe, _imageFile);

    if (mounted) {
      setState(() => _isLoading = false);
      if (success != null) {
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to post recipe')),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _prepTimeController.dispose();
    _cookTimeController.dispose();
    _servingsController.dispose();
    _ingredientSearchController.dispose();
    _stepsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Recipe')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                          image: _imageFile != null
                              ? DecorationImage(
                                  image: kIsWeb
                                      ? NetworkImage(_imageFile!.path)
                                      : FileImage(File(_imageFile!.path))
                                          as ImageProvider,
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: _imageFile == null
                            ? const Center(
                                child: Text('Tap to upload image',
                                    style: TextStyle(color: Colors.grey)))
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                          labelText: 'Recipe Title',
                          border: OutlineInputBorder()),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _summaryController,
                      decoration: const InputDecoration(
                          labelText: 'Summary', border: OutlineInputBorder()),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                            child: TextFormField(
                                controller: _prepTimeController,
                                decoration: const InputDecoration(
                                    labelText: 'Prep Time (e.g. 10 min)',
                                    border: OutlineInputBorder()))),
                        const SizedBox(width: 16),
                        Expanded(
                            child: TextFormField(
                                controller: _cookTimeController,
                                decoration: const InputDecoration(
                                    labelText: 'Cook Time (e.g. 20 min)',
                                    border: OutlineInputBorder()))),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _servingsController,
                      decoration: const InputDecoration(
                          labelText: 'Servings', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Ingredients',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _ingredientSearchController,
                      onChanged: _searchIngredients,
                      decoration: InputDecoration(
                        labelText: 'Search ingredient',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _ingredientSearchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _ingredientSearchController.clear();
                                  setState(() {
                                    _ingredientSuggestions = [];
                                  });
                                },
                              )
                            : null,
                      ),
                    ),
                    if (_isSearchingIngredients)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                    if (_ingredientSearchController.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildSuggestionPanel(),
                    ],
                    const SizedBox(height: 12),
                    if (_selectedIngredients.isEmpty)
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'No ingredients selected yet.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _selectedIngredients.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final ingredient = _selectedIngredients[index];
                          return ListTile(
                            tileColor: const Color(0xFFF6F8F3),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            title: Text(ingredient.name),
                            subtitle: Text(
                                '${ingredient.quantity} ${ingredient.unit}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () {
                                setState(() {
                                  _selectedIngredients.removeAt(index);
                                });
                              },
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _stepsController,
                      decoration: const InputDecoration(
                          labelText: 'Instructions (One step per line)',
                          border: OutlineInputBorder()),
                      maxLines: 5,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF74BC42)),
                        onPressed: _submit,
                        child: const Text('Post Recipe',
                            style:
                                TextStyle(color: Colors.white, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSuggestionPanel() {
    final query = _ingredientSearchController.text.trim();
    final lowerQuery = query.toLowerCase();
    final hasExactMatch =
        _ingredientSuggestions.any((item) => item.toLowerCase() == lowerQuery);

    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE0E0E0)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final suggestion in _ingredientSuggestions)
            ListTile(
              dense: true,
              leading: const Icon(Icons.food_bank_outlined),
              title: Text(suggestion),
              onTap: () => _selectIngredient(suggestion),
            ),
          if (query.isNotEmpty && !hasExactMatch)
            ListTile(
              dense: true,
              leading: const Icon(Icons.add_circle_outline),
              title: Text('Add "$query" as new ingredient'),
              onTap: () => _selectIngredient(query),
            ),
        ],
      ),
    );
  }

  Future<void> _searchIngredients(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      if (!mounted) return;
      setState(() {
        _ingredientSuggestions = [];
        _isSearchingIngredients = false;
      });
      return;
    }

    setState(() {
      _isSearchingIngredients = true;
    });

    final results = await _recipeService.searchIngredients(trimmed);
    if (!mounted) return;
    if (_ingredientSearchController.text.trim() != trimmed) {
      return;
    }

    setState(() {
      _ingredientSuggestions = results;
      _isSearchingIngredients = false;
    });
  }

  Future<void> _selectIngredient(String ingredientName) async {
    final IngredientEntry? ingredient =
        await _showIngredientDetailDialog(ingredientName);
    if (ingredient == null || !mounted) {
      return;
    }

    setState(() {
      _selectedIngredients.add(ingredient);
      _ingredientSearchController.clear();
      _ingredientSuggestions = [];
    });
  }

  Future<IngredientEntry?> _showIngredientDetailDialog(String ingredientName) {
    final quantityController = TextEditingController(text: '1');
    final formKey = GlobalKey<FormState>();
    String selectedUnit = _allowedUnits.first;

    return showDialog<IngredientEntry>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Add $ingredientName'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: quantityController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final parsed = double.tryParse((value ?? '').trim());
                        if (parsed == null || parsed <= 0) {
                          return 'Enter a valid quantity';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedUnit,
                      items: _allowedUnits
                          .map((unit) => DropdownMenuItem<String>(
                              value: unit, child: Text(unit)))
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          selectedUnit = value;
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'Unit',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) {
                      return;
                    }
                    final quantity =
                        double.parse(quantityController.text.trim());
                    Navigator.of(context).pop(
                      IngredientEntry(
                        name: ingredientName,
                        quantity: quantity,
                        unit: selectedUnit,
                      ),
                    );
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
