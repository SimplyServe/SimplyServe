import 'package:flutter/material.dart';
import 'package:simplyserve/recipe_page.dart';
import 'package:simplyserve/services/recipe_service.dart';

class DeletedRecipesView extends StatefulWidget {
  const DeletedRecipesView({super.key});

  @override
  State<DeletedRecipesView> createState() => _DeletedRecipesViewState();
}

class _DeletedRecipesViewState extends State<DeletedRecipesView> {
  final RecipeService _recipeService = RecipeService();
  List<RecipeModel> _deletedRecipes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDeleted();
  }

  Future<void> _fetchDeleted() async {
    setState(() => _isLoading = true);
    final recipes = await _recipeService.getDeletedRecipes();
    if (mounted) {
      setState(() {
        _deletedRecipes = recipes;
        _isLoading = false;
      });
    }
  }

  // Soft-deleted recipes still have an id; permanent deletion removes them from the server
  Future<void> _permanentDelete(RecipeModel recipe) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Permanently'),
        content: Text(
            'Are you sure you want to permanently delete "${recipe.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final success = await _recipeService.permanentDeleteRecipe(recipe.id!);
    if (!mounted) return;
    if (success) {
      setState(() => _deletedRecipes.remove(recipe));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${recipe.title}" permanently deleted.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to permanently delete recipe.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _permanentDeleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete All Permanently'),
        content: const Text(
            'Are you sure you want to permanently delete all deleted recipes? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ids = _deletedRecipes.map((r) => r.id!).toList();
    final success = await _recipeService.permanentDeleteAllRecipes(ids);
    if (!mounted) return;
    if (success) {
      setState(() => _deletedRecipes.clear());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All deleted recipes permanently removed.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to permanently delete all recipes.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _restore(RecipeModel recipe) async {
    final success = await _recipeService.restoreRecipe(recipe.id!);
    if (!mounted) return;
    if (success) {
      setState(() => _deletedRecipes.remove(recipe));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${recipe.title}" restored.'),
          backgroundColor: const Color(0xFF74BC42),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to restore recipe.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deleted Recipes'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        actions: [
          if (_deletedRecipes.isNotEmpty)
            TextButton.icon(
              onPressed: _permanentDeleteAll,
              icon: const Icon(Icons.delete_forever, color: Colors.red),
              label: const Text(
                'Delete All',
                style: TextStyle(color: Colors.red),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF74BC42)),
            )
          : _deletedRecipes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.delete_outline,
                          size: 56, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text(
                        'No deleted recipes.',
                        style: TextStyle(color: Colors.grey[500], fontSize: 15),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchDeleted,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _deletedRecipes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final recipe = _deletedRecipes[index];
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 56,
                              height: 56,
                              child: recipe.imageUrl.startsWith('assets/')
                                  ? Image.asset(recipe.imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          _imagePlaceholder())
                                  : Image.network(recipe.imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          _imagePlaceholder()),
                            ),
                          ),
                          title: Text(
                            recipe.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          subtitle: Text(
                            recipe.summary,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton.icon(
                                onPressed: () => _restore(recipe),
                                icon: const Icon(Icons.restore,
                                    size: 18, color: Color(0xFF74BC42)),
                                label: const Text(
                                  'Restore',
                                  style: TextStyle(
                                    color: Color(0xFF74BC42),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => _permanentDelete(recipe),
                                icon: const Icon(Icons.delete_forever,
                                    color: Colors.red),
                                tooltip: 'Delete permanently',
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: const Color(0xFFE8F5E9),
      child: const Icon(Icons.restaurant, color: Colors.grey),
    );
  }
}
