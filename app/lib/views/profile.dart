import 'package:flutter/material.dart';
import 'package:simplyserve/services/profile_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({Key? key}) : super(key: key);

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final ProfileService _profileService = ProfileService();
  final TextEditingController _nameController = TextEditingController();
  bool isLoading = true;
  bool isSavingName = false;
  String email = '';
  String displayName = 'SimplyServe User';

  // Calorie Coach fields (persisted keys match calorie_coach.dart)
  int? _ccAge;
  double? _ccHeight;
  double? _ccWeight;
  String? _ccGender;
  String? _ccActivity;
  double? _ccBmr;
  double? _ccTdee;

  @override
  void initState() {
    super.initState();
    _loadCalorieCoachSummary();
    _fetchProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _fetchProfile() async {
    final userData = await _profileService.getCurrentUser();
    if (mounted) {
      setState(() {
        isLoading = false;
        if (userData != null) {
          email = userData['email'] ?? 'No email set';
          if (userData['name'] != null && userData['name'].toString().isNotEmpty) {
            displayName = userData['name'];
            _nameController.text = userData['name'];
          }
        }
      });
    }
  }

  Future<void> _submitName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name')),
      );
      return;
    }

    setState(() => isSavingName = true);

    try {
      await _profileService.updateUserName(name);
      if (mounted) {
        setState(() {
          displayName = name;
          isSavingName = false;
        });
        FocusScope.of(context).unfocus();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Name updated successfully'),
            backgroundColor: Color(0xFF74BC42),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => isSavingName = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update name: $e')),
        );
      }
    }
  }

  Future<void> _loadCalorieCoachSummary() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _ccAge = prefs.getInt('cc_age');
      _ccHeight = prefs.getDouble('cc_height');
      _ccWeight = prefs.getDouble('cc_weight');
      _ccGender = prefs.getString('cc_gender');
      _ccActivity = prefs.getString('cc_activity');
      _ccBmr = prefs.getDouble('cc_bmr');
      _ccTdee = prefs.getDouble('cc_tdee');
    });
  }

  Widget _buildCalorieCoachCard() {
    // hide if no saved results
    if (_ccTdee == null && _ccBmr == null && _ccAge == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Calorie Coach', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Age: ${_ccAge ?? 'N/A'}'),
            Text('Height: ${_ccHeight != null ? '${_ccHeight!.toStringAsFixed(1)} cm' : 'N/A'}'),
            Text('Weight: ${_ccWeight != null ? '${_ccWeight!.toStringAsFixed(1)} kg' : 'N/A'}'),
            Text('Gender: ${_ccGender ?? 'N/A'}'),
            Text('Activity: ${_ccActivity ?? 'N/A'}'),
            const SizedBox(height: 8),
            Text('BMR: ${_ccBmr != null ? '${_ccBmr!.round()} kcal/day' : 'N/A'}'),
            Text('Estimated needs (TDEE): ${_ccTdee != null ? '${_ccTdee!.round()} kcal/day' : 'N/A'}'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6FB),
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadCalorieCoachSummary,
              child: ListView(
                padding: const EdgeInsets.all(24.0),
                children: [
                  const CircleAvatar(
                    radius: 50,
                    backgroundColor: Color(0xFF74BC42),
                    child: Icon(Icons.person, size: 50, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    email,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildNameInputCard(),
                  const SizedBox(height: 16),
                  _buildProfileItem(Icons.settings, 'Account Actions', 'Tap to edit settings'),
                  _buildCalorieCoachCard(), // inserted calorie coach summary
                ],
              ),
            ),
    );
  }

  Widget _buildNameInputCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.badge_outlined, color: Color(0xFF74BC42), size: 28),
              SizedBox(width: 12),
              Text(
                'Your Name',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Enter your name',
              hintStyle: const TextStyle(color: Colors.grey),
              filled: true,
              fillColor: const Color(0xFFF8F6FB),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF74BC42), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isSavingName ? null : _submitName,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF74BC42),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: isSavingName
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Save Name',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileItem(IconData icon, String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF74BC42), size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
