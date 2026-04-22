import 'package:flutter/material.dart';
import 'package:simplyserve/services/allergen_filter_service.dart';
import 'package:simplyserve/services/allergy_service.dart';
import 'package:simplyserve/services/recipe_catalog_service.dart';
import 'package:simplyserve/widgets/navbar.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _allergyController = TextEditingController();
  final AllergyService _allergyService = AllergyService();
  final RecipeCatalogService _recipeCatalogService = RecipeCatalogService();
  final List<String> _allergies = [];
  final List<String> _hiddenRecipeTitles = [];
  bool _showHidden = false;
  bool _isLoadingHiddenRecipes = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAllergiesAndHiddenRecipes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _allergyController.dispose();
    super.dispose();
  }

  Future<void> _loadAllergiesAndHiddenRecipes() async {
    final storedAllergies = await _allergyService.loadAllergies();
    if (!mounted) {
      return;
    }

    setState(() {
      _allergies
        ..clear()
        ..addAll(storedAllergies);
    });

    await _refreshHiddenRecipes();
  }

  Future<void> _refreshHiddenRecipes() async {
    if (_allergies.isEmpty) {
      if (!mounted) {
        return;
      }

      setState(() {
        _hiddenRecipeTitles.clear();
        _isLoadingHiddenRecipes = false;
        _showHidden = false;
      });
      return;
    }

    setState(() {
      _isLoadingHiddenRecipes = true;
    });

    final allRecipes = await _recipeCatalogService.getAllRecipes();
    final hiddenRecipes =
        AllergenFilterService.hiddenRecipes(allRecipes, _allergies);

    if (!mounted) {
      return;
    }

    setState(() {
      _hiddenRecipeTitles
        ..clear()
        ..addAll(hiddenRecipes.map((recipe) => recipe.title));
      _isLoadingHiddenRecipes = false;
    });
  }

  Future<void> _addAllergy() async {
    final value = _allergyController.text.trim();
    if (value.isEmpty) return;

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

    await _allergyService.saveAllergies(_allergies);
    await _refreshHiddenRecipes();
  }

  Future<void> _removeAllergy(int index) async {
    setState(() {
      _allergies.removeAt(index);
    });

    await _allergyService.saveAllergies(_allergies);
    await _refreshHiddenRecipes();
  }

  @override
  Widget build(BuildContext context) {
    return NavBarScaffold(
      title: 'Settings',
      body: Column(
        children: [
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

  Widget _buildGeneralTab() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        const SizedBox(height: 8),
        _buildSettingsSection(
          title: 'Account',
          children: [
            _buildSettingsTile(
              icon: Icons.person,
              title: 'Profile',
              subtitle: 'Manage your profile information',
              onTap: () {
                Navigator.pushNamed(context, '/profile');
              },
            ),
            _buildSettingsTile(
              icon: Icons.delete_outline,
              title: 'Deleted Recipes',
              subtitle: 'View and restore deleted recipes',
              onTap: () => Navigator.pushNamed(context, '/deleted-recipes'),
            ),
            _buildSettingsTile(
              icon: Icons.lock,
              title: 'Privacy',
              subtitle: 'Control your privacy settings',
              onTap: () {},
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildSettingsSection(
          title: 'Preferences',
          children: [
            _buildSettingsTile(
              icon: Icons.notifications,
              title: 'Notifications',
              subtitle: 'Manage notification preferences',
              onTap: () {},
            ),
            _buildSettingsTile(
              icon: Icons.palette,
              title: 'Appearance',
              subtitle: 'Customize app appearance',
              onTap: () {},
            ),
          ],
        ),
        const SizedBox(height: 16),
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
              Navigator.of(context)
                  .pushNamedAndRemoveUntil('/login', (route) => false);
            },
            child: const Text(
              'Log Out',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildAllergiesTab() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        const SizedBox(height: 8),
        // Input row
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _allergyController,
                decoration: InputDecoration(
                  hintText: 'e.g. peanuts, gluten, dairy...',
                  labelText: 'Add an allergen',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF74BC42)),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
              onPressed: _addAllergy,
              child: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Allergy chips
        if (_allergies.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allergies.asMap().entries.map((entry) {
              return Chip(
                label: Text(entry.value),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () => _removeAllergy(entry.key),
                backgroundColor: const Color(0xFF74BC42).withValues(alpha: 0.1),
                labelStyle: const TextStyle(color: Color(0xFF74BC42)),
                deleteIconColor: const Color(0xFF74BC42),
                side: const BorderSide(color: Color(0xFF74BC42), width: 0.8),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
        ],
        // Hidden recipes banner
        if (_allergies.isNotEmpty) ...[
          Card(
            margin: EdgeInsets.zero,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.visibility_off, color: Colors.orange),
                      const SizedBox(width: 8),
                      Text(
                        'Hidden ${_hiddenRecipeTitles.length} ${_hiddenRecipeTitles.length == 1 ? 'recipe' : 'recipes'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.orange.shade700, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Text(
                                'The recipes hidden contain items you are allergic to. Are you sure you want to ',
                                style: TextStyle(fontSize: 13),
                              ),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _showHidden = !_showHidden;
                                  });
                                },
                                child: Text(
                                  _showHidden ? 'hide again' : 'show them',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.orange.shade800,
                                    fontWeight: FontWeight.w700,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                              const Text(
                                '?',
                                style: TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_showHidden) ...[
                    const SizedBox(height: 12),
                    if (_isLoadingHiddenRecipes)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF74BC42),
                          ),
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
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _hiddenRecipeTitles
                              .map(
                                (title) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.circle,
                                        size: 8,
                                        color: Colors.orange,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          title,
                                          style: const TextStyle(fontSize: 13),
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

  Widget _buildSettingsSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF74BC42),
            ),
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          child: Column(children: children),
        ),
      ],
    );
  }

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
