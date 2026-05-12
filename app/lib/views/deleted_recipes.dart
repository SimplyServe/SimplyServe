// ============================================================
// views/deleted_recipes.dart — Deleted Recipes View
//
// Displays recipes the user has soft-deleted from the "My Recipes"
// tab. Recipes are NOT erased on the server when first deleted;
// instead the backend marks them with a deleted flag so they can
// be restored. This view provides two final actions:
//   • Restore  — calls PUT /recipes/{id}/restore (marks active again)
//   • Permanent Delete — calls DELETE /recipes/{id} (irreversible)
//
// Both actions update the local list immediately via setState()
// so the UI feels responsive without a full reload. A
// RefreshIndicator allows pull-to-refresh at any time.
//
// Route: '/deleted-recipes'  (navigated to from SettingsView)
// ============================================================

import 'package:flutter/material.dart';
import 'package:simplyserve/recipe_page.dart';
import 'package:simplyserve/services/recipe_service.dart';

/// Shows the user's soft-deleted recipes with restore and permanent-delete
/// options. Uses [StatefulWidget] because the list mutates as the user
/// takes actions.
class DeletedRecipesView extends StatefulWidget {
  const DeletedRecipesView({super.key});

  @override
  State<DeletedRecipesView> createState() => _DeletedRecipesViewState();
}

class _DeletedRecipesViewState extends State<DeletedRecipesView> {
  final RecipeService _recipeService = RecipeService();

  /// The current list of soft-deleted recipes fetched from the server.
  List<RecipeModel> _deletedRecipes = [];

  /// True while the initial fetch (or a refresh) is in progress.
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Fetch the deleted-recipes list as soon as the view mounts.
    _fetchDeleted();
  }

  // ── Data Fetching ─────────────────────────────────────────────────────

  /// Loads the list of soft-deleted recipes from the backend.
  /// Sets [_isLoading] to true while the request is in flight so the
  /// build method can show a spinner instead of stale data.
  Future<void> _fetchDeleted() async {
    setState(() => _isLoading = true);
    final recipes = await _recipeService.getDeletedRecipes();
    // Guard: only call setState if the widget is still mounted. Async
    // calls can complete after the user navigates away.
    if (mounted) {
      setState(() {
        _deletedRecipes = recipes;
        _isLoading = false;
      });
    }
  }

  // ── Permanent Delete (single) ─────────────────────────────────────────

  /// Asks the user to confirm, then permanently removes one recipe from the
  /// server. On success the item is removed from [_deletedRecipes] via
  /// setState() — no full re-fetch needed.
  ///
  /// Pattern: showDialog returns a Future<bool?> which we await to get the
  /// user's choice before making the destructive API call.
  Future<void> _permanentDelete(RecipeModel recipe) async {
    // ── Confirmation dialog ─────────────────────────────────────
    // showDialog is awaited so execution pauses until the user taps
    // Cancel or Delete. Returns null if dismissed by tapping outside.
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
            // Red style signals a destructive action to the user.
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    // Short-circuit if user cancelled or the widget was disposed while
    // the dialog was open.
    if (confirmed != true || !mounted) return;

    // ── API call ─────────────────────────────────────────────────
    final success = await _recipeService.permanentDeleteRecipe(recipe.id!);
    if (!mounted) return;

    if (success) {
      // Optimistic UI update: remove from local list immediately
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

  // ── Permanent Delete (all) ────────────────────────────────────────────

  /// Confirms and then bulk-deletes all soft-deleted recipes in a single
  /// API call. Collects all IDs from [_deletedRecipes] and passes them to
  /// [RecipeService.permanentDeleteAllRecipes] which sends them as a batch.
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

    // Collect every ID before the async call in case the list changes.
    final ids = _deletedRecipes.map((r) => r.id!).toList();
    final success = await _recipeService.permanentDeleteAllRecipes(ids);
    if (!mounted) return;

    if (success) {
      // Clear local list entirely — no items remain.
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

  // ── Restore ───────────────────────────────────────────────────────────

  /// Calls the restore endpoint for a single recipe. On success the recipe
  /// is removed from this view's list (it becomes active again and will
  /// reappear in "My Recipes").
  Future<void> _restore(RecipeModel recipe) async {
    final success = await _recipeService.restoreRecipe(recipe.id!);
    if (!mounted) return;

    if (success) {
      // Remove from the deleted list — the recipe is live again.
      setState(() => _deletedRecipes.remove(recipe));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${recipe.title}" restored.'),
          // Brand green confirms a positive action.
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

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deleted Recipes'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        // "Delete All" button appears only when there is something to delete.
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

      // ── Body: three possible states ──────────────────────────────────
      // 1. Loading spinner  — fetch in progress
      // 2. Empty state      — no deleted recipes
      // 3. List             — recipes wrapped in RefreshIndicator
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
                        style:
                            TextStyle(color: Colors.grey[500], fontSize: 15),
                      ),
                    ],
                  ),
                )
              // ── RefreshIndicator ──────────────────────────────────────
              // Pull-to-refresh calls _fetchDeleted again so the user can
              // verify the current server state without restarting the app.
              : RefreshIndicator(
                  onRefresh: _fetchDeleted,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _deletedRecipes.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final recipe = _deletedRecipes[index];

                      // ── Recipe card ─────────────────────────────────
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  Colors.black.withValues(alpha: 0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),

                          // ── Thumbnail ───────────────────────────────
                          // Differentiates asset images (bundled with the
                          // app) from network images (uploaded by users).
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

                          // ── Action buttons ───────────────────────────
                          // Row contains Restore (green) and Delete (red).
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton.icon(
                                onPressed: () => _restore(recipe),
                                icon: const Icon(Icons.restore,
                                    size: 18,
                                    color: Color(0xFF74BC42)),
                                label: const Text(
                                  'Restore',
                                  style: TextStyle(
                                    color: Color(0xFF74BC42),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () =>
                                    _permanentDelete(recipe),
                                icon: const Icon(
                                    Icons.delete_forever,
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

  /// Returns a placeholder widget shown when a recipe image fails to load.
  Widget _imagePlaceholder() {
    return Container(
      color: const Color(0xFFE8F5E9),
      child: const Icon(Icons.restaurant, color: Colors.grey),
    );
  }
}
