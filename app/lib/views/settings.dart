// ============================================================
// views/settings.dart — Settings View
//
// Two-tab settings screen accessible from the side drawer.
//
// Tab 1 – General
//   Organised into sections (Account, Preferences, About) using
//   card-based ListTiles. The Logout button clears the local
//   SharedPreferences login flag and navigates back to '/login',
//   clearing the entire route stack (pushNamedAndRemoveUntil).
//
// Tab 2 – Allergies
//   Lets users declare food allergens. The allergen list is
//   persisted locally via AllergyService (SharedPreferences).
//   AllergenFilterService.hiddenRecipes() is called after every
//   change to show how many catalog recipes are being hidden by
//   the current filter set. Preset allergens are displayed as
//   animated toggle chips; users can also type custom allergens.
//
// Route: '/settings'  (named route in main.dart)
// ============================================================

import 'package:flutter/material.dart';
import 'package:simplyserve/services/allergen_filter_service.dart';
import 'package:simplyserve/services/allergy_service.dart';
import 'package:simplyserve/services/recipe_catalog_service.dart';
import 'package:simplyserve/widgets/navbar.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The full-screen settings page with General and Allergies tabs.
///
/// Uses [StatefulWidget] + [SingleTickerProviderStateMixin] because the
/// [TabController] requires a vsync (TickerProvider) to drive its animation.
class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView>
    with SingleTickerProviderStateMixin {
  /// Controls which tab (General / Allergies) is active.
  /// Requires [SingleTickerProviderStateMixin] for the vsync parameter.
  late TabController _tabController;

  /// Text field controller for typing a custom allergen name.
  final TextEditingController _allergyController = TextEditingController();

  /// Service that reads/writes the allergen list from SharedPreferences.
  final AllergyService _allergyService = AllergyService();

  /// Service that fetches the full recipe catalog (needed to count how
  /// many recipes are hidden by the current allergen filters).
  final RecipeCatalogService _recipeCatalogService = RecipeCatalogService();

  /// The user's currently active allergen filters (case-insensitive).
  final List<String> _allergies = [];

  /// Titles of the recipes currently hidden by [_allergies].
  final List<String> _hiddenRecipeTitles = [];

  /// Whether the "hidden recipes" list is expanded in the UI.
  bool _showHidden = false;

  /// True while [_refreshHiddenRecipes] is running an async lookup.
  bool _isLoadingHiddenRecipes = false;

  @override
  void initState() {
    super.initState();
    // 2 tabs: General and Allergies.
    _tabController = TabController(length: 2, vsync: this);
    _loadAllergiesAndHiddenRecipes();
  }

  @override
  void dispose() {
    // Always dispose controllers to avoid memory leaks and ticker errors.
    _tabController.dispose();
    _allergyController.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  /// Capitalises the first letter of a string for display purposes.
  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  // ── Data loading ──────────────────────────────────────────────────────

  /// Called once on init. Loads the persisted allergen list then computes
  /// how many catalog recipes are hidden by those allergens.
  Future<void> _loadAllergiesAndHiddenRecipes() async {
    final storedAllergies = await _allergyService.loadAllergies();
    if (!mounted) return;

    setState(() {
      _allergies
        ..clear()
        ..addAll(storedAllergies);
    });

    await _refreshHiddenRecipes();
  }

  /// Queries the full recipe catalog and runs [AllergenFilterService.hiddenRecipes]
  /// to determine which recipes are currently blocked by [_allergies].
  ///
  /// Pattern: compute the intersection of the allergen set and the catalog
  /// client-side, so no extra backend endpoint is needed.
  Future<void> _refreshHiddenRecipes() async {
    if (_allergies.isEmpty) {
      if (!mounted) return;
      setState(() {
        _hiddenRecipeTitles.clear();
        _isLoadingHiddenRecipes = false;
        _showHidden = false;
      });
      return;
    }

    setState(() => _isLoadingHiddenRecipes = true);

    // Fetch all catalog recipes, then filter with the allergen service.
    final allRecipes = await _recipeCatalogService.getAllRecipes();
    final hiddenRecipes =
        AllergenFilterService.hiddenRecipes(allRecipes, _allergies);

    if (!mounted) return;

    setState(() {
      _hiddenRecipeTitles
        ..clear()
        ..addAll(hiddenRecipes.map((recipe) => recipe.title));
      _isLoadingHiddenRecipes = false;
    });
  }

  // ── Allergen CRUD ─────────────────────────────────────────────────────

  /// Adds a new allergen from [_allergyController] to [_allergies],
  /// persists the change, and refreshes the hidden-recipe count.
  /// Ignores duplicates (case-insensitive comparison).
  Future<void> _addAllergy() async {
    final value = _allergyController.text.trim();
    if (value.isEmpty) return;

    // Prevent case-insensitive duplicates.
    final exists = _allergies
        .any((allergy) => allergy.toLowerCase() == value.toLowerCase());
    if (exists) {
      _allergyController.clear();
      return;
    }

    setState(() {
      _allergies.add(value);
      _allergyController.clear();
    });

    // Persist to SharedPreferences, then recompute hidden recipes.
    await _allergyService.saveAllergies(_allergies);
    await _refreshHiddenRecipes();
  }

  /// Removes the allergen at [index] from [_allergies], persists the
  /// change, and refreshes the hidden-recipe count.
  Future<void> _removeAllergy(int index) async {
    setState(() => _allergies.removeAt(index));
    await _allergyService.saveAllergies(_allergies);
    await _refreshHiddenRecipes();
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return NavBarScaffold(
      title: 'Settings',
      body: Column(
        children: [
          // ── TabBar ────────────────────────────────────────────────────
          // Placed outside TabBarView so it stays fixed at the top while
          // the tab content scrolls independently.
          TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF74BC42),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF74BC42),
            tabs: const [
              Tab(text: 'General'),
              Tab(text: 'Allergies'),
            ],
          ),
          // TabBarView fills the remaining height; each tab is a scrollable
          // ListView built by its own helper method.
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildGeneralTab(),
                _buildAllergiesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab: General ──────────────────────────────────────────────────────

  /// Builds the General tab: grouped settings sections + logout button.
  ///
  /// Settings are organised into labelled Card sections (Account,
  /// Preferences, About) built by [_buildSettingsSection]. Each entry
  /// is a [ListTile] wrapped by [_buildSettingsTile].
  Widget _buildGeneralTab() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        const SizedBox(height: 8),

        // ── Account section ──────────────────────────────────────────
        _buildSettingsSection(
          title: 'Account',
          children: [
            _buildSettingsTile(
              icon: Icons.person,
              title: 'Profile',
              subtitle: 'Manage your profile information',
              onTap: () => Navigator.pushNamed(context, '/profile'),
            ),
            _buildSettingsTile(
              icon: Icons.delete_outline,
              title: 'Deleted Recipes',
              subtitle: 'View and restore deleted recipes',
              onTap: () =>
                  Navigator.pushNamed(context, '/deleted-recipes'),
            ),
            _buildSettingsTile(
              icon: Icons.lock,
              title: 'Privacy',
              subtitle: 'Control your privacy settings',
              onTap: () {}, // stub — not yet implemented
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Preferences section ──────────────────────────────────────
        _buildSettingsSection(
          title: 'Preferences',
          children: [
            _buildSettingsTile(
              icon: Icons.notifications,
              title: 'Notifications',
              subtitle: 'Manage notification preferences',
              onTap: () {}, // stub
            ),
            _buildSettingsTile(
              icon: Icons.palette,
              title: 'Appearance',
              subtitle: 'Customize app appearance',
              onTap: () {}, // stub
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── About section ────────────────────────────────────────────
        _buildSettingsSection(
          title: 'About',
          children: [
            _buildSettingsTile(
              icon: Icons.info,
              title: 'App Version',
              subtitle: '1.0.0',
              onTap: () {},
            ),
            _buildSettingsTile(
              icon: Icons.help,
              title: 'Help & Support',
              subtitle: 'Get help with the app',
              onTap: () {},
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ── Logout button ────────────────────────────────────────────
        // Auth state is local-only: we clear the SharedPreferences flag
        // (no server session to invalidate) then navigate to '/login'
        // with pushNamedAndRemoveUntil, which clears the entire stack
        // so the back button cannot return to a protected screen.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade50,
              foregroundColor: Colors.red,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('isLoggedIn', false);
              if (!mounted) return;
              // Clear all routes; the user must log in again to access
              // any protected content.
              Navigator.of(context)
                  .pushNamedAndRemoveUntil('/login', (route) => false);
            },
            child: const Text(
              'Log Out',
              style:
                  TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  // ── Tab: Allergies ────────────────────────────────────────────────────

  /// Builds the Allergies tab: preset allergen chips, custom allergen
  /// text input, active-filter chips, and a hidden-recipe count banner.
  Widget _buildAllergiesTab() {
    // The known allergen preset list is defined in AllergenFilterService.
    final presets = AllergenFilterService.knownAllergens;

    // Pre-compute a lowercase set for O(1) active-state lookup.
    final activeLower = _allergies.map((a) => a.toLowerCase()).toSet();

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        const SizedBox(height: 8),

        // ── Preset allergen chips ──────────────────────────────────
        // Each chip is an AnimatedContainer that smoothly transitions
        // between green (active) and grey (inactive) when tapped.
        // Tapping an active chip removes it; tapping an inactive chip
        // adds it to [_allergies].
        const Text(
          'Common Allergens',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF5FA832),
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Tap to add. Each allergen automatically covers related ingredients.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: presets.map((preset) {
            final active =
                activeLower.contains(preset.toLowerCase());
            return GestureDetector(
              onTap: () async {
                if (active) {
                  // Toggle off: find and remove by case-insensitive match.
                  final idx = _allergies.indexWhere(
                      (a) => a.toLowerCase() == preset.toLowerCase());
                  if (idx != -1) await _removeAllergy(idx);
                } else {
                  // Toggle on: add if not already present.
                  final already = _allergies.any(
                      (a) => a.toLowerCase() == preset.toLowerCase());
                  if (!already) {
                    setState(() => _allergies.add(preset));
                    await _allergyService.saveAllergies(_allergies);
                    await _refreshHiddenRecipes();
                  }
                }
              },
              // AnimatedContainer smoothly interpolates colors over 150ms
              // without rebuilding child widgets unnecessarily.
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: active
                      ? const Color(0xFF74BC42)
                      : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: active
                        ? const Color(0xFF74BC42)
                        : const Color(0xFFCCCCCC),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Show a checkmark when the allergen is active.
                    if (active) ...[
                      const Icon(Icons.check,
                          size: 13, color: Colors.white),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      _capitalize(preset),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: active
                            ? Colors.white
                            : const Color(0xFF555555),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 12),

        // ── Custom allergen input ──────────────────────────────────
        // A text field + "Add" button. The field also submits on the
        // keyboard Done action (onSubmitted) for convenience.
        const Text(
          'Custom Allergen',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF5FA832),
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _allergyController,
                decoration: InputDecoration(
                  hintText: 'e.g. kiwi, mango...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFF74BC42)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                ),
                // Also trigger add when the user presses the keyboard's
                // Done/Return button.
                onSubmitted: (_) => _addAllergy(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF74BC42),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
              ),
              onPressed: _addAllergy,
              child: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Active filters ─────────────────────────────────────────
        // Displayed as deletable Chip widgets so the user can see and
        // remove individual allergens without scrolling back to the
        // preset grid.
        if (_allergies.isNotEmpty) ...[
          const Text(
            'Active Filters',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF5FA832),
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            // asMap().entries gives both the index and the value so we
            // can pass the correct index to _removeAllergy().
            children: _allergies.asMap().entries.map((entry) {
              return Chip(
                label: Text(entry.value),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () => _removeAllergy(entry.key),
                backgroundColor:
                    const Color(0xFF74BC42).withValues(alpha: 0.1),
                labelStyle:
                    const TextStyle(color: Color(0xFF74BC42)),
                deleteIconColor: const Color(0xFF74BC42),
                side: const BorderSide(
                    color: Color(0xFF74BC42), width: 0.8),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
        ],

        // ── Hidden-recipe banner ───────────────────────────────────
        // Shows how many catalog recipes are currently hidden and
        // gives the user the option to reveal their titles inline.
        if (_allergies.isNotEmpty) ...[
          Card(
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Count header ──────────────────────────────────
                  Row(
                    children: [
                      const Icon(Icons.visibility_off,
                          color: Colors.orange),
                      const SizedBox(width: 8),
                      Text(
                        // Pluralise "recipe" / "recipes" correctly.
                        'Hidden ${_hiddenRecipeTitles.length} ${_hiddenRecipeTitles.length == 1 ? 'recipe' : 'recipes'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Warning notice with inline "show/hide" toggle ──
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.orange.shade700, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Wrap(
                            crossAxisAlignment:
                                WrapCrossAlignment.center,
                            children: [
                              const Text(
                                'The recipes hidden contain items you are allergic to. Are you sure you want to ',
                                style: TextStyle(fontSize: 13),
                              ),
                              // Inline tappable text toggle — more
                              // discoverable than a separate button.
                              GestureDetector(
                                onTap: () {
                                  setState(
                                      () => _showHidden = !_showHidden);
                                },
                                child: Text(
                                  _showHidden
                                      ? 'hide again'
                                      : 'show them',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.orange.shade800,
                                    fontWeight: FontWeight.w700,
                                    decoration:
                                        TextDecoration.underline,
                                  ),
                                ),
                              ),
                              const Text('?',
                                  style: TextStyle(fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Expandable recipe title list ───────────────────
                  if (_showHidden) ...[
                    const SizedBox(height: 12),
                    if (_isLoadingHiddenRecipes)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF74BC42)),
                        ),
                      )
                    else if (_hiddenRecipeTitles.isEmpty)
                      Text(
                        'No recipes currently match your allergy list.',
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontSize: 13,
                        ),
                      )
                    else
                      // Bulleted list of hidden recipe titles.
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.orange.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: _hiddenRecipeTitles
                              .map(
                                (title) => Padding(
                                  padding: const EdgeInsets.only(
                                      bottom: 8),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.circle,
                                          size: 8,
                                          color: Colors.orange),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          title,
                                          style: const TextStyle(
                                              fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 32),
      ],
    );
  }

  // ── Reusable section / tile builders ─────────────────────────────────

  /// Renders a labelled group of settings entries inside a [Card].
  Widget _buildSettingsSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF74BC42),
            ),
          ),
        ),
        // Card groups the tiles visually, providing the elevated surface
        // that separates sections on the white background.
        Card(
          margin: EdgeInsets.zero,
          child: Column(children: children),
        ),
      ],
    );
  }

  /// Returns a single [ListTile] formatted for the settings list.
  /// The trailing chevron implies the tile is navigable.
  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF74BC42)),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }
}
