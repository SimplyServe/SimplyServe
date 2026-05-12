// ignore_for_file: use_build_context_synchronously
// ============================================================
// views/recipe_form.dart
// ============================================================
// Create / Edit recipe form. Opened via:
//   • FAB on RecipesView → create mode (existingRecipe == null)
//   • Edit button on RecipePage → edit mode  (existingRecipe.id != null)
//
// _isEditMode = existingRecipe?.id != null
//
// Key patterns:
//
// Image picker:
//   ImagePicker.pickImage(source: ImageSource.gallery) → XFile
//   Preview: kIsWeb → NetworkImage(path), mobile → FileImage(File(path))
//
// Ingredient search with debounce guard:
//   _searchIngredients() saves the query, fires the API, then checks
//   _ingredientSearchController.text against the saved query before
//   applying results — discards stale responses when the user keeps typing.
//
// _showIngredientDetailDialog():
//   AlertDialog + StatefulBuilder + Form with validation.
//   Custom ingredients (isCustom=true) show extra nutrition fields.
//   Unit selection uses DropdownButtonFormField<String>.
//
// Tag sections:
//   FilterChip widgets with selectedColor: Color(0xFF74BC42).
//   Three preset groups: meal type, dietary/nutrition, cuisine.
//   CustomTagService manages a fourth user-defined group (add/rename/delete).
//   Long-press on a custom tag opens showModalBottomSheet with edit/delete options.
//
// _submit():
//   1. Validates the Form and checks ingredient list non-empty.
//   2. Builds RecipeModel — uses 'New' sentinel tag if no tags were selected.
//   3. Calls RecipeService.createRecipe or updateRecipe.
//   4. Saves private note via PrivateNotesService.
//   5. Patches nutrition by accumulating custom-ingredient macros on top of
//      the backend-returned totals (via RecipeModel.copyWith).
//   6. Pops the route, returning the patched RecipeModel to the caller.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:simplyserve/recipe_page.dart';
import 'package:simplyserve/services/recipe_service.dart';
import 'package:simplyserve/services/custom_tag_service.dart';
import 'package:simplyserve/services/private_notes_service.dart';
import 'dart:io' show File;

// ── Tag constant lists ────────────────────────────────────────────────────
// Three groups of preset tags. These mirror the tag strings used by the
// recipe catalog so that filtering in RecipesView works correctly.

/// Meal-type tags (when in the day the recipe is eaten).
const List<String> _kMealTypeTags = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];

/// Dietary and nutritional characteristic tags.
const List<String> _kDietaryAndNutritionTags = [
  'Vegan',
  'High Protein',
  'High Fibre',
  'Gluten Free',
  'Dairy Free',
  'Quick & Easy',
  'Budget Friendly',
];

/// Cuisine / regional tags.
const List<String> _kCuisineTags = [
  'European',
  'Asian',
  'African',
  'Middle Eastern',
  'American',
  'Latin American',
  'Caribbean',
  'Mediterranean',
];

/// Units available in the ingredient detail dialog's dropdown.
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

// ─────────────────────────────────────────────────────────────────────────
// RecipeFormView
// StatefulWidget with an optional existingRecipe for edit mode.
// ─────────────────────────────────────────────────────────────────────────
class RecipeFormView extends StatefulWidget {
  /// When provided, the form pre-populates with this recipe's data.
  /// id != null means the recipe exists in the backend database (edit mode).
  final RecipeModel? existingRecipe;

  const RecipeFormView({super.key, this.existingRecipe});

  @override
  State<RecipeFormView> createState() => _RecipeFormViewState();
}

class _RecipeFormViewState extends State<RecipeFormView> {
  final _formKey = GlobalKey<FormState>();

  // ── Text controllers (one per form field) ─────────────────────────────
  final _titleController = TextEditingController();
  final _summaryController = TextEditingController();
  final _prepTimeController = TextEditingController();
  final _cookTimeController = TextEditingController();
  final _servingsController = TextEditingController();
  final _ingredientSearchController = TextEditingController();
  final _stepsController = TextEditingController();
  final _notesController = TextEditingController();
  final _customTagController = TextEditingController();

  /// Picked image file (null when no image was selected or in edit mode
  /// where the existing imageUrl is preserved).
  XFile? _imageFile;

  /// Currently selected tags from all three preset groups + custom tags.
  final Set<String> _selectedTags = {};

  /// User-defined tags loaded from CustomTagService (SharedPreferences).
  List<String> _customTags = [];

  bool _isLoading = false;
  bool _isSearchingIngredients = false;

  /// API suggestions returned by the ingredient search endpoint.
  List<String> _ingredientSuggestions = [];

  /// Ordered list of ingredients the user has added to the recipe.
  final List<IngredientEntry> _selectedIngredients = [];

  final ImagePicker _picker = ImagePicker();
  final RecipeService _recipeService = RecipeService();
  final CustomTagService _customTagService = CustomTagService();
  final PrivateNotesService _notesService = PrivateNotesService();

  /// True when editing an existing user-created recipe (id != null).
  bool get _isEditMode => widget.existingRecipe?.id != null;

  @override
  void initState() {
    super.initState();
    // Pre-populate form fields when editing an existing recipe
    final recipe = widget.existingRecipe;
    if (recipe != null) {
      _titleController.text = recipe.title;
      _summaryController.text = recipe.summary;
      _prepTimeController.text = recipe.prepTime;
      _cookTimeController.text = recipe.cookTime;
      _servingsController.text = recipe.servings.toString();
      // Join steps with newlines; the user sees one step per line
      _stepsController.text = recipe.steps.join('\n');
      _selectedIngredients.addAll(recipe.ingredients);
      _selectedTags.addAll(recipe.tags);
    }
    _loadCustomTags();
    _loadPrivateNote();
  }

  /// Loads user-defined tags from CustomTagService (SharedPreferences).
  Future<void> _loadCustomTags() async {
    final tags = await _customTagService.loadTags();
    if (mounted) {
      setState(() => _customTags = tags);
    }
  }

  /// Loads the private note for the recipe being edited, if any.
  Future<void> _loadPrivateNote() async {
    final recipe = widget.existingRecipe;
    if (recipe == null) return;
    final note = await _notesService.getNote(
      id: recipe.id,
      title: recipe.title,
    );
    if (mounted && note.isNotEmpty) {
      _notesController.text = note;
    }
  }

  /// Opens the gallery image picker and stores the resulting XFile.
  /// On web: XFile.path is a blob URL usable with NetworkImage.
  /// On mobile: XFile.path is a file system path usable with FileImage.
  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _imageFile = picked;
      });
    }
  }

  /// Validates and submits the form.
  ///
  /// Flow:
  ///   1. Form.validate() — aborts if any field fails its validator.
  ///   2. Guard: at least one ingredient required.
  ///   3. Build RecipeModel with steps split on newlines.
  ///   4. 'New' sentinel tag: prevents sending an empty tag list to the API,
  ///      which would be treated as "no classification" on the backend.
  ///   5. Create or update via RecipeService.
  ///   6. Save private note (even if empty, to clear an old one).
  ///   7. Patch custom-ingredient nutrition on top of the backend total
  ///      using RecipeModel.copyWith + accumulating fold().
  ///   8. Pop with the patched RecipeModel so RecipePage can update in-place.
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
    // Split the textarea on newlines, trim each line, drop blanks
    final List<String> steps = _stepsController.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final recipePayload = RecipeModel(
      title: title,
      summary: summary,
      imageUrl: widget.existingRecipe?.imageUrl ?? '',
      prepTime: prepTime,
      cookTime: cookTime,
      totalTime:
          '$prepTime + $cookTime', // stored as display string, not a computed sum
      servings: servings,
      difficulty: 'Medium',
      // Placeholder nutrition — real values come from the backend after creation
      nutrition: const NutritionInfo(
          calories: 0, protein: '0g', carbs: '0g', fats: '0g'),
      ingredients: List<IngredientEntry>.from(_selectedIngredients),
      steps: steps,
      // 'New' is a sentinel so the backend never receives an empty tag list.
      // If the user selects at least one tag, the sentinel is not used.
      tags: _selectedTags.isEmpty
          ? const ['New']
          : _selectedTags.toList(),
      id: widget.existingRecipe?.id,
    );

    final RecipeModel? result;
    if (_isEditMode) {
      result = await _recipeService.updateRecipe(
        widget.existingRecipe!.id!,
        recipePayload,
        _imageFile,
      );
    } else {
      result = await _recipeService.createRecipe(recipePayload, _imageFile);
    }

    if (mounted) {
      setState(() => _isLoading = false);
      if (result != null) {
        // Save private note to SharedPreferences keyed by id+title
        final noteText = _notesController.text.trim();
        await _notesService.saveNote(
          id: result.id,
          title: result.title,
          note: noteText,
        );

        // Patch custom-ingredient macros onto the server-returned nutrition.
        // The backend only calculates nutrition for known ingredients; custom
        // ingredients must be accumulated locally and added on top.
        final customIngredients =
            _selectedIngredients.where((i) => i.isCustom).toList();
        final patchedResult = customIngredients.isEmpty
            ? result
            : result.copyWith(
                nutrition: NutritionInfo(
                  calories: result.nutrition.calories +
                      customIngredients
                          .fold<double>(0, (s, i) => s + i.calories)
                          .round(),
                  protein:
                      '${(_parseGrams(result.nutrition.protein) + customIngredients.fold<double>(0, (s, i) => s + i.protein)).toStringAsFixed(1)}g',
                  carbs:
                      '${(_parseGrams(result.nutrition.carbs) + customIngredients.fold<double>(0, (s, i) => s + i.carbs)).toStringAsFixed(1)}g',
                  fats:
                      '${(_parseGrams(result.nutrition.fats) + customIngredients.fold<double>(0, (s, i) => s + i.fats)).toStringAsFixed(1)}g',
                ),
              );

        // Return the patched recipe so the caller (RecipePage) can update in-place
        if (mounted) Navigator.of(context).pop(patchedResult);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditMode
                ? 'Failed to update recipe'
                : 'Failed to post recipe'),
          ),
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
    _notesController.dispose();
    _customTagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: Text(_isEditMode ? 'Edit Recipe' : 'Create Recipe')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // ── Image picker area ────────────────────────────────
                    // GestureDetector calls _pickImage() on tap.
                    // Preview: kIsWeb → NetworkImage (blob URL from XFile.path),
                    //          mobile → FileImage(File(path)) cast to ImageProvider.
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

                    // ── Basic recipe metadata fields ────────────────────
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
                    // Prep and cook time side by side
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

                    // ── Tag sections ─────────────────────────────────────
                    // Three preset groups (meal type, dietary, cuisine).
                    // Each uses FilterChip with selectedColor: brand-green.
                    _buildTagSection(
                      context: context,
                      title: 'Meal Type',
                      options: _kMealTypeTags,
                    ),
                    const SizedBox(height: 12),
                    _buildTagSection(
                      context: context,
                      title: 'Dietary & Nutrition',
                      options: _kDietaryAndNutritionTags,
                    ),
                    const SizedBox(height: 12),
                    _buildTagSection(
                      context: context,
                      title: 'Cuisine',
                      options: _kCuisineTags,
                    ),
                    const SizedBox(height: 12),
                    // User-defined tags (add/rename/delete via CustomTagService)
                    _buildCustomTagSection(context),
                    const SizedBox(height: 16),

                    // ── Ingredient search area ────────────────────────────
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Ingredients',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Search field — calls _searchIngredients(query) on each change
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
                    // Slim loading bar while the API request is in flight
                    if (_isSearchingIngredients)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                    // Suggestion panel appears only when the search field is non-empty
                    if (_ingredientSearchController.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildSuggestionPanel(),
                    ],
                    const SizedBox(height: 12),

                    // ── Selected ingredients list ─────────────────────────
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
                        // NeverScrollableScrollPhysics: scrolling handled by
                        // the outer SingleChildScrollView.
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
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Edit: re-opens the ingredient detail dialog with current values
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () => _editIngredient(index),
                                ),
                                // Delete: removes the ingredient from the list
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () {
                                    setState(() {
                                      _selectedIngredients.removeAt(index);
                                    });
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 16),

                    // ── Instructions textarea ─────────────────────────────
                    // One step per line; _submit splits on '\n' and trims.
                    TextFormField(
                      controller: _stepsController,
                      decoration: const InputDecoration(
                          labelText: 'Instructions (One step per line)',
                          border: OutlineInputBorder()),
                      maxLines: 5,
                    ),
                    const SizedBox(height: 16),

                    // ── Private notes ─────────────────────────────────────
                    // Stored locally via PrivateNotesService (SharedPreferences).
                    // Not sent to the API; shown only to the current user.
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          const Icon(Icons.lock_outline,
                              size: 18, color: Color(0xFF888888)),
                          const SizedBox(width: 6),
                          Text(
                            'Private Notes',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Only visible to you. Not shared with the recipe.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'Add private notes...',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 4,
                    ),
                    const SizedBox(height: 24),

                    // ── Submit button ─────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF74BC42)),
                        onPressed: _submit,
                        child: Text(
                          _isEditMode ? 'Save Changes' : 'Post Recipe',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // ── Tag section builders ──────────────────────────────────────────────

  /// Renders a labelled section of FilterChip widgets for [options].
  /// Calls _buildTagChip for each option to produce the individual chips.
  Widget _buildTagSection({
    required BuildContext context,
    required String title,
    required List<String> options,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map(_buildTagChip).toList(),
        ),
      ],
    );
  }

  /// Builds a single FilterChip for [tag].
  /// selectedColor: brand-green fills the chip when selected.
  /// checkmarkColor: white so the checkmark is visible on the green fill.
  Widget _buildTagChip(String tag) {
    final selected = _selectedTags.contains(tag);
    return FilterChip(
      label: Text(tag),
      selected: selected,
      onSelected: (val) {
        setState(() {
          if (val) {
            _selectedTags.add(tag);
          } else {
            _selectedTags.remove(tag);
          }
        });
      },
      selectedColor: const Color(0xFF74BC42),
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: selected ? Colors.white : null,
      ),
    );
  }

  /// Builds the custom tags section with an add-tag text field + button.
  ///
  /// Custom tag chips show a ⋮ icon; long-press opens a bottom sheet with
  /// edit and delete options via _showCustomTagOptions().
  Widget _buildCustomTagSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Custom Tags',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        // Add custom tag: text field + "Add" button
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customTagController,
                decoration: const InputDecoration(
                  hintText: 'New tag name...',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF74BC42),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: () async {
                final name = _customTagController.text.trim();
                if (name.isEmpty) return;
                final added = await _customTagService.addTag(name);
                if (!added && mounted) {
                  // ignore: duplicate_ignore
                  // ignore: use_build_context_synchronously
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tag already exists.')),
                  );
                  return;
                }
                _customTagController.clear();
                await _loadCustomTags(); // reload to show new tag
              },
              child: const Text('Add',
                  style: TextStyle(color: Colors.white, fontSize: 14)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_customTags.isEmpty)
          const Text(
            'No custom tags yet.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _customTags.map((tag) {
              final selected = _selectedTags.contains(tag);
              return GestureDetector(
                // Long-press opens edit/delete options bottom sheet
                onLongPress: () => _showCustomTagOptions(tag),
                child: FilterChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(tag),
                      const SizedBox(width: 4),
                      // ⋮ icon hints that long-press has actions
                      Icon(
                        Icons.more_vert,
                        size: 14,
                        color: selected ? Colors.white70 : Colors.grey,
                      ),
                    ],
                  ),
                  selected: selected,
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _selectedTags.add(tag);
                      } else {
                        _selectedTags.remove(tag);
                      }
                    });
                  },
                  selectedColor: const Color(0xFF74BC42),
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : null,
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  /// Shows a bottom sheet with Edit and Delete options for a custom tag.
  /// Destructive delete also removes the tag from _selectedTags if present.
  void _showCustomTagOptions(String tag) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text('Edit "$tag"'),
              onTap: () {
                Navigator.of(ctx).pop();
                _editCustomTag(tag);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: Text('Delete "$tag"',
                  style: const TextStyle(color: Colors.redAccent)),
              onTap: () async {
                Navigator.of(ctx).pop();
                _selectedTags.remove(tag); // remove from active selection
                await _customTagService.deleteTag(tag);
                await _loadCustomTags(); // reload to remove chip from UI
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Opens an AlertDialog for renaming a custom tag.
  ///
  /// If the tag was selected, it is removed from _selectedTags before rename
  /// and re-added under the new name after the rename completes so the form
  /// state remains consistent.
  void _editCustomTag(String tag) {
    final controller = TextEditingController(text: tag);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Tag'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Tag name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) return;
              // Update the selected tags set if this tag was selected
              final wasSelected = _selectedTags.remove(tag);
              await _customTagService.renameTag(tag, newName);
              if (wasSelected) _selectedTags.add(newName); // re-add under new name
              await _loadCustomTags();
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ── Ingredient search ─────────────────────────────────────────────────

  /// Builds the suggestion dropdown panel below the ingredient search field.
  ///
  /// Renders API suggestions as tappable list tiles. If the current query
  /// doesn't exactly match any suggestion, an "Add as new ingredient" option
  /// appears at the bottom with isCustom=true so the nutrition fields are shown.
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
              // Tapping a suggestion opens the quantity/unit/nutrition dialog
              onTap: () => _selectIngredient(suggestion),
            ),
          // "Add as new ingredient" appears when no exact match exists.
          // isCustom=true causes the nutrition fields to appear in the dialog.
          if (query.isNotEmpty && !hasExactMatch)
            ListTile(
              dense: true,
              leading: const Icon(Icons.add_circle_outline),
              title: Text('Add "$query" as new ingredient'),
              onTap: () => _selectIngredient(query, isCustom: true),
            ),
        ],
      ),
    );
  }

  /// Strips non-numeric characters from a macro string (e.g. "25g" → 25.0).
  double _parseGrams(String value) {
    return double.tryParse(value.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
  }

  /// Debounce-guarded ingredient search.
  ///
  /// The guard works by comparing the controller text after the API responds
  /// to the trimmed query that was sent. If the user typed more characters
  /// while the request was in flight, the stale results are discarded silently.
  /// This prevents older slow responses from replacing newer fast ones.
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
    // Debounce guard: discard results if the query changed while in-flight
    if (_ingredientSearchController.text.trim() != trimmed) {
      return;
    }

    setState(() {
      _ingredientSuggestions = results;
      _isSearchingIngredients = false;
    });
  }

  /// Opens the ingredient detail dialog to collect quantity, unit, and
  /// (for custom ingredients) nutrition values. On confirm, appends the
  /// new IngredientEntry to _selectedIngredients and clears the search field.
  Future<void> _selectIngredient(String ingredientName,
      {bool isCustom = false}) async {
    final IngredientEntry? ingredient =
        await _showIngredientDetailDialog(ingredientName, isCustom: isCustom);
    if (ingredient == null || !mounted) {
      return;
    }

    setState(() {
      _selectedIngredients.add(ingredient);
      _ingredientSearchController.clear();
      _ingredientSuggestions = [];
    });
  }

  /// Re-opens the ingredient detail dialog for an existing ingredient at [index].
  /// On confirm, replaces the entry at that index with the updated values.
  Future<void> _editIngredient(int index) async {
    final current = _selectedIngredients[index];
    final IngredientEntry? updated = await _showIngredientDetailDialog(
      current.name,
      initialIngredient: current,
    );
    if (updated == null || !mounted) {
      return;
    }

    setState(() {
      _selectedIngredients[index] = updated;
    });
  }

  /// Shows an AlertDialog for entering/editing ingredient details.
  ///
  /// Uses StatefulBuilder so the DropdownButtonFormField can update
  /// [selectedUnit] within the dialog without a full-page rebuild.
  ///
  /// [showNutrition]: true when adding a custom ingredient or editing
  /// an existing custom ingredient. Shows calories, protein, carbs, and
  /// fats fields so the user can supply macros the backend cannot look up.
  ///
  /// Returns the constructed IngredientEntry on confirm, or null on cancel.
  Future<IngredientEntry?> _showIngredientDetailDialog(
    String ingredientName, {
    IngredientEntry? initialIngredient,
    bool isCustom = false,
  }) {
    // showNutrition: show extra fields for custom ingredients
    final bool showNutrition = isCustom || (initialIngredient?.isCustom ?? false);

    final nameController = TextEditingController(
      text: initialIngredient?.name ?? ingredientName,
    );
    final quantityController = TextEditingController(
      text: (initialIngredient?.quantity ?? 1).toString(),
    );
    final caloriesController = TextEditingController(
      text: (initialIngredient?.calories ?? 0).toString(),
    );
    final proteinController = TextEditingController(
      text: (initialIngredient?.protein ?? 0).toString(),
    );
    final carbsController = TextEditingController(
      text: (initialIngredient?.carbs ?? 0).toString(),
    );
    final fatsController = TextEditingController(
      text: (initialIngredient?.fats ?? 0).toString(),
    );
    final formKey = GlobalKey<FormState>();

    // Normalise the initial unit: lower-case and validate against _allowedUnits
    final initialUnit =
        (initialIngredient?.unit ?? _allowedUnits.first).toLowerCase();
    String selectedUnit =
        _allowedUnits.contains(initialUnit) ? initialUnit : _allowedUnits.first;

    return showDialog<IngredientEntry>(
      context: context,
      builder: (context) {
        // StatefulBuilder: selectedUnit can change inside the dialog via the
        // DropdownButtonFormField without needing a new StatefulWidget class.
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(initialIngredient == null
                  ? 'Add $ingredientName'
                  : 'Edit Ingredient'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name field (editable so "2 salmon fillets" can be cleaned up)
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Ingredient',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) {
                            return 'Enter an ingredient name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      // Quantity field — decimal allowed
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
                      // Unit dropdown — limited to _allowedUnits
                      DropdownButtonFormField<String>(
                        initialValue: selectedUnit,
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
                      // ── Custom ingredient nutrition fields ─────────────
                      // Only shown for custom (unknown) ingredients where the
                      // backend cannot auto-calculate nutrition.
                      if (showNutrition) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Nutrition (per serving)',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: caloriesController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Calories',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                validator: (v) {
                                  if (double.tryParse((v ?? '').trim()) == null) {
                                    return 'Invalid';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: proteinController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Protein (g)',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                validator: (v) {
                                  if (double.tryParse((v ?? '').trim()) == null) {
                                    return 'Invalid';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: carbsController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Carbs (g)',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                validator: (v) {
                                  if (double.tryParse((v ?? '').trim()) == null) {
                                    return 'Invalid';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: fatsController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Fats (g)',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                validator: (v) {
                                  if (double.tryParse((v ?? '').trim()) == null) {
                                    return 'Invalid';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
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
                    // Pop the dialog, returning the constructed IngredientEntry
                    Navigator.of(context).pop(
                      IngredientEntry(
                        name: nameController.text.trim(),
                        quantity: quantity,
                        unit: selectedUnit,
                        isCustom: showNutrition, // marks as custom for nutrition patching
                        calories: showNutrition
                            ? (double.tryParse(caloriesController.text.trim()) ?? 0)
                            : 0,
                        protein: showNutrition
                            ? (double.tryParse(proteinController.text.trim()) ?? 0)
                            : 0,
                        carbs: showNutrition
                            ? (double.tryParse(carbsController.text.trim()) ?? 0)
                            : 0,
                        fats: showNutrition
                            ? (double.tryParse(fatsController.text.trim()) ?? 0)
                            : 0,
                      ),
                    );
                  },
                  child: Text(initialIngredient == null ? 'Add' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
