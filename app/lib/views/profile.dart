// ============================================================
// views/profile.dart — Profile View
//
// Shows the logged-in user's profile and lets them:
//   • View and update their display name (calls ProfileService.updateUserName)
//   • Change their avatar by picking an image from the gallery or camera
//     (reads bytes, calls ProfileService.uploadProfileImage)
//   • See a read-only summary of their Calorie Coach results, loaded from
//     the SharedPreferences keys that CalorieCoachView writes (cc_* prefix)
//
// The avatar is displayed as a CircleAvatar; a GestureDetector wraps it so
// a tap opens a ModalBottomSheet with gallery/camera options. While an upload
// is in progress a semi-transparent overlay with CircularProgressIndicator
// is stacked on top of the avatar.
//
// Route: '/profile'  (navigated to from SettingsView)
// ============================================================

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:simplyserve/services/profile_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Displays and allows editing of the user's profile.
///
/// StatefulWidget is required because the page tracks loading state,
/// the current name/email/avatar, and the Calorie Coach summary values.
class ProfileView extends StatefulWidget {
  const ProfileView({Key? key}) : super(key: key);

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final ProfileService _profileService = ProfileService();

  /// Controller bound to the "Your Name" text field.
  final TextEditingController _nameController = TextEditingController();

  /// ImagePicker wraps the native gallery/camera picker UI.
  final ImagePicker _picker = ImagePicker();

  // ── Loading flags ─────────────────────────────────────────────────────

  /// True while the initial profile fetch is in progress.
  bool isLoading = true;

  /// True while the name save API call is in flight (disables the Save button).
  bool isSavingName = false;

  /// True while a picked image is being uploaded (shows avatar overlay spinner).
  bool isUploadingAvatar = false;

  // ── Profile data ──────────────────────────────────────────────────────

  String email = '';
  String displayName = 'SimplyServe User';

  /// Full URL of the user's uploaded profile photo, or null if none.
  String? profileImageUrl;

  // ── Calorie Coach summary fields ──────────────────────────────────────
  // These are read from the same SharedPreferences keys that CalorieCoachView
  // writes (all prefixed with 'cc_'). They are displayed read-only in
  // _buildCalorieCoachCard().
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
    // Both calls are independent so they run simultaneously.
    _loadCalorieCoachSummary();
    _fetchProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // ── Profile fetch ─────────────────────────────────────────────────────

  /// Calls ProfileService.getCurrentUser() and maps the JSON response
  /// to local state. The profile image URL may be a relative path from
  /// the server, so we prepend [ProfileService.baseUrl] when necessary.
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
            // Prepend base URL for relative paths returned by the server.
            final base =
                _profileService.baseUrl.replaceAll(RegExp(r'/$'), '');
            profileImageUrl =
                rawUrl.startsWith('http') ? rawUrl : '$base$rawUrl';
          }
        }
      });
    }
  }

  // ── Avatar upload ─────────────────────────────────────────────────────

  /// Opens a ModalBottomSheet asking whether to use the gallery or camera,
  /// then launches ImagePicker, reads the file as bytes, and uploads to
  /// the backend via ProfileService.uploadProfileImage().
  ///
  /// Pattern: showModalBottomSheet returns a Future<ImageSource?> so
  /// execution awaits the user's choice before calling the picker.
  Future<void> _pickAndUploadImage() async {
    // ── Source selection sheet ────────────────────────────────────
    final ImageSource? source =
        await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
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
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              // Gallery option — Navigator.pop delivers the chosen source.
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEDF7E5),
                  child: Icon(Icons.photo_library_outlined,
                      color: Color(0xFF74BC42)),
                ),
                title: const Text('Photo Library'),
                onTap: () =>
                    Navigator.pop(ctx, ImageSource.gallery),
              ),
              // Camera option
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEDF7E5),
                  child: Icon(Icons.camera_alt_outlined,
                      color: Color(0xFF74BC42)),
                ),
                title: const Text('Camera'),
                onTap: () =>
                    Navigator.pop(ctx, ImageSource.camera),
              ),
            ],
          ),
        ),
      ),
    );

    // User dismissed the sheet without choosing.
    if (source == null) return;

    // ── Pick image ────────────────────────────────────────────────
    // imageQuality=85 and maxWidth=800 reduce upload size without
    // visible quality loss for a profile thumbnail.
    final XFile? picked = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 800,
    );
    if (picked == null) return;

    setState(() => isUploadingAvatar = true);

    try {
      // Read raw bytes — the server expects a multipart/form-data upload.
      final bytes = await picked.readAsBytes();
      final fileName = picked.name;
      final newUrl =
          await _profileService.uploadProfileImage(bytes, fileName);

      if (mounted) {
        final base =
            _profileService.baseUrl.replaceAll(RegExp(r'/$'), '');
        setState(() {
          // Normalise the returned URL the same way as in _fetchProfile.
          profileImageUrl =
              newUrl.startsWith('http') ? newUrl : '$base$newUrl';
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

  // ── Name update ───────────────────────────────────────────────────────

  /// Reads [_nameController], validates it is non-empty, then calls
  /// ProfileService.updateUserName(). Dismisses the keyboard on success.
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
        // Dismiss the keyboard after a successful save.
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

  // ── Calorie Coach summary ─────────────────────────────────────────────

  /// Reads all Calorie Coach values from SharedPreferences.
  /// Keys use the 'cc_' prefix written by CalorieCoachView.
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

  // ── Unit formatters ───────────────────────────────────────────────────

  /// Height is stored internally in cm; convert to ft/in only for display.
  String _formatHeight(double cm) {
    if (_ccHeightUnit == 'ft') {
      final totalInches = cm / 2.54;
      final feet = (totalInches / 12).floor();
      final inches = (totalInches % 12).round();
      return "$feet'$inches\"";
    }
    return '${cm.toStringAsFixed(1)} cm';
  }

  /// Weight is stored internally in kg; convert to lb only for display.
  String _formatWeight(double kg) {
    if (_ccWeightUnit == 'lb') {
      return '${(kg / 0.453592).toStringAsFixed(1)} lb';
    }
    return '${kg.toStringAsFixed(1)} kg';
  }

  /// Human-readable label for the user's selected goal.
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

  // ── Calorie Coach card ─────────────────────────────────────────────────

  /// Builds a Card showing the Calorie Coach summary. Returns an empty
  /// SizedBox when no Coach data has been saved yet (so the card is
  /// invisible for first-time users who haven't completed the Coach flow).
  Widget _buildCalorieCoachCard() {
    // Guard: hide if no meaningful coach data is stored.
    if (_ccTdee == null && _ccBmr == null && _ccAge == null) {
      return const SizedBox.shrink();
    }

    // Compute carb and fat targets from the calorie target using a
    // 40% carbs / 30% fat split (protein target is stored directly).
    String fatStr = 'N/A';
    String carbStr = 'N/A';
    if (_ccCalorieTarget != null) {
      final carbTarget = (_ccCalorieTarget! * 0.40) / 4; // 4 kcal/g
      final fatTarget = (_ccCalorieTarget! * 0.30) / 9;  // 9 kcal/g
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
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Age: ${_ccAge ?? 'N/A'}'),
            Text('Height: ${_ccHeight != null ? _formatHeight(_ccHeight!) : 'N/A'}'),
            Text('Weight: ${_ccWeight != null ? _formatWeight(_ccWeight!) : 'N/A'}'),
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
            // Daily macro breakdown (40/30/30 carbs/fat/protein split).
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

  // ── Build ─────────────────────────────────────────────────────────────

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
          // RefreshIndicator wraps the ListView so pull-to-refresh
          // reloads the Calorie Coach summary.
          : RefreshIndicator(
              onRefresh: _loadCalorieCoachSummary,
              child: ListView(
                padding: const EdgeInsets.all(24.0),
                children: [
                  // ── Avatar ─────────────────────────────────────────
                  _buildAvatarSection(),
                  const SizedBox(height: 16),

                  // ── Display name + email ───────────────────────────
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

                  // ── Name edit card ─────────────────────────────────
                  _buildNameInputCard(),
                  const SizedBox(height: 16),

                  // ── Account actions stub ───────────────────────────
                  _buildProfileItem(
                      Icons.settings, 'Account Actions', 'Tap to edit settings'),

                  // ── Calorie Coach summary card ─────────────────────
                  // Hidden via SizedBox.shrink() if no coach data saved.
                  _buildCalorieCoachCard(),
                ],
              ),
            ),
    );
  }

  // ── Sub-widgets ───────────────────────────────────────────────────────

  /// Builds the avatar circle with an upload overlay and camera badge.
  ///
  /// Pattern: Stack with three layers:
  ///   1. CircleAvatar — shows the profile image or a person icon placeholder.
  ///   2. Upload overlay — semi-transparent dark circle + spinner shown
  ///      while isUploadingAvatar is true.
  ///   3. Camera badge — a small green circle icon in the bottom-right corner
  ///      that hints at the tap action.
  Widget _buildAvatarSection() {
    return GestureDetector(
      // Disable the tap while an upload is in progress.
      onTap: isUploadingAvatar ? null : _pickAndUploadImage,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ── Base avatar ─────────────────────────────────────────
          CircleAvatar(
            radius: 50,
            backgroundColor: const Color(0xFF74BC42),
            // NetworkImage is used when a URL is available.
            backgroundImage: profileImageUrl != null
                ? NetworkImage(profileImageUrl!)
                : null,
            // Person icon shown as fallback when no image is set.
            child: profileImageUrl == null
                ? const Icon(Icons.person,
                    size: 50, color: Colors.white)
                : null,
          ),

          // ── Upload spinner overlay ──────────────────────────────
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

          // ── Camera badge ────────────────────────────────────────
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

  /// Builds the name text field with a Save button.
  ///
  /// While [isSavingName] is true the button shows a spinner and is
  /// disabled (onPressed: null) to prevent double-submission.
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
              Icon(Icons.badge_outlined,
                  color: Color(0xFF74BC42), size: 28),
              SizedBox(width: 12),
              Text(
                'Your Name',
                style: TextStyle(color: Colors.grey, fontSize: 14),
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
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: Color(0xFF74BC42), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              // null onPressed disables the button while saving.
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
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// A simple icon + title + value info card for one profile attribute.
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
