import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
  final ImagePicker _picker = ImagePicker();

  bool isLoading = true;
  bool isSavingName = false;
  bool isUploadingAvatar = false;

  String email = '';
  String displayName = 'SimplyServe User';
  String? profileImageUrl;

  // Calorie Coach fields (persisted keys match calorie_coach.dart)
  int? _ccAge;
  double? _ccHeight;
  double? _ccWeight;
  String? _ccGender;
  String? _ccActivity;
  double? _ccBmr;
  double? _ccTdee;
  String? _ccHeightUnit;
  String? _ccWeightUnit;
  String? _ccGoal;
  double? _ccTargetWeight;
  double? _ccCalorieTarget;
  double? _ccProteinTarget;

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
          if (userData['name'] != null &&
              userData['name'].toString().isNotEmpty) {
            displayName = userData['name'];
            _nameController.text = userData['name'];
          }
          if (userData['profile_image_url'] != null) {
            final rawUrl = userData['profile_image_url'] as String;
            // Build full URL from the relative path returned by the server
            final base = _profileService.baseUrl.replaceAll(RegExp(r'/$'), '');
            profileImageUrl =
                rawUrl.startsWith('http') ? rawUrl : '$base$rawUrl';
          }
        }
      });
    }
  }

  Future<void> _pickAndUploadImage() async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Choose photo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEDF7E5),
                  child: Icon(Icons.photo_library_outlined,
                      color: Color(0xFF74BC42)),
                ),
                title: const Text('Photo Library'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEDF7E5),
                  child:
                      Icon(Icons.camera_alt_outlined, color: Color(0xFF74BC42)),
                ),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    final XFile? picked = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 800,
    );
    if (picked == null) return;

    setState(() => isUploadingAvatar = true);
    try {
      final bytes = await picked.readAsBytes();
      final fileName = picked.name;
      final newUrl = await _profileService.uploadProfileImage(bytes, fileName);
      if (mounted) {
        final base = _profileService.baseUrl.replaceAll(RegExp(r'/$'), '');
        setState(() {
          profileImageUrl = newUrl.startsWith('http') ? newUrl : '$base$newUrl';
          isUploadingAvatar = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo updated'),
            backgroundColor: Color(0xFF74BC42),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => isUploadingAvatar = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload photo: $e')),
        );
      }
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
      _ccHeightUnit = prefs.getString('cc_height_unit') ?? 'cm';
      _ccWeightUnit = prefs.getString('cc_weight_unit') ?? 'kg';
      _ccGoal = prefs.getString('cc_goal');
      _ccTargetWeight = prefs.getDouble('cc_target_weight');
      _ccCalorieTarget = prefs.getDouble('cc_calorie_target');
      _ccProteinTarget = prefs.getDouble('cc_protein_target');
    });
  }

  String _formatHeight(double cm) {
    if (_ccHeightUnit == 'ft') {
      final totalInches = cm / 2.54;
      final feet = (totalInches / 12).floor();
      final inches = (totalInches % 12).round();
      return "$feet'$inches\"";
    }
    return '${cm.toStringAsFixed(1)} cm';
  }

  String _formatWeight(double kg) {
    if (_ccWeightUnit == 'lb') {
      return '${(kg / 0.453592).toStringAsFixed(1)} lb';
    }
    return '${kg.toStringAsFixed(1)} kg';
  }

  String get _goalLabel {
    switch (_ccGoal) {
      case 'gain':
        return 'Gain Weight';
      case 'lose':
        return 'Lose Weight';
      case 'maintain':
        return 'Maintain Weight';
      default:
        return 'N/A';
    }
  }

  Widget _buildCalorieCoachCard() {
    // hide if no saved results
    if (_ccTdee == null && _ccBmr == null && _ccAge == null) {
      return const SizedBox.shrink();
    }

    // Compute macro breakdown (40/30/30 split)
    String fatStr = 'N/A';
    String carbStr = 'N/A';
    if (_ccCalorieTarget != null) {
      final carbTarget = (_ccCalorieTarget! * 0.40) / 4;
      final fatTarget = (_ccCalorieTarget! * 0.30) / 9;
      fatStr = '${fatTarget.round()}g/day';
      carbStr = '${carbTarget.round()}g/day';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Calorie Coach',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Age: ${_ccAge ?? 'N/A'}'),
            Text(
                'Height: ${_ccHeight != null ? _formatHeight(_ccHeight!) : 'N/A'}'),
            Text(
                'Weight: ${_ccWeight != null ? _formatWeight(_ccWeight!) : 'N/A'}'),
            Text('Gender: ${_ccGender ?? 'N/A'}'),
            Text('Activity: ${_ccActivity ?? 'N/A'}'),
            if (_ccGoal != null) Text('Goal: $_goalLabel'),
            if (_ccGoal != null &&
                _ccGoal != 'maintain' &&
                _ccTargetWeight != null)
              Text('Target weight: ${_formatWeight(_ccTargetWeight!)}'),
            const SizedBox(height: 8),
            Text(
                'BMR: ${_ccBmr != null ? '${_ccBmr!.round()} kcal/day' : 'N/A'}'),
            Text(
                'Daily calorie target: ${_ccCalorieTarget != null ? '${_ccCalorieTarget!.round()} kcal/day' : (_ccTdee != null ? '${_ccTdee!.round()} kcal/day' : 'N/A')}'),
            if (_ccProteinTarget != null || _ccCalorieTarget != null) ...[
              const SizedBox(height: 8),
              const Text('Daily Macros (40/30/30):',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              if (_ccProteinTarget != null)
                Text('  Protein (30%): ${_ccProteinTarget!.round()}g/day'),
              Text('  Carbs (40%): $carbStr'),
              Text('  Fat (30%): $fatStr'),
            ],
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
                  _buildAvatarSection(),
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
                  _buildProfileItem(Icons.settings, 'Account Actions',
                      'Tap to edit settings'),
                  _buildCalorieCoachCard(), // inserted calorie coach summary
                ],
              ),
            ),
    );
  }

  Widget _buildAvatarSection() {
    return GestureDetector(
      onTap: isUploadingAvatar ? null : _pickAndUploadImage,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: const Color(0xFF74BC42),
            backgroundImage:
                profileImageUrl != null ? NetworkImage(profileImageUrl!) : null,
            child: profileImageUrl == null
                ? const Icon(Icons.person, size: 50, color: Colors.white)
                : null,
          ),
          if (isUploadingAvatar)
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                // ignore: deprecated_member_use
                color: Colors.black.withOpacity(0.4),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            ),
          if (!isUploadingAvatar)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF74BC42),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
        ],
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
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFF74BC42), width: 1.5),
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
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
