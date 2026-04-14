import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

import '../../../core/di/injection_container.dart';
import '../../../domain/entities/user_profile.dart';
import '../../../domain/repositories/user_repository.dart';

/// Screen for viewing and editing user profile details.
///
/// Shows current [UserProfile] values pre-filled (if available) and lets the
/// user update: display name, goal, niche, fear, and experience.
/// Changes are saved immediately to Supabase via [UserRepository].
class EditProfileScreen extends StatefulWidget {
  final String userId;
  final String? currentDisplayName;
  final UserProfile? currentProfile;

  const EditProfileScreen({
    super.key,
    required this.userId,
    this.currentDisplayName,
    this.currentProfile,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _goalController;
  late final TextEditingController _nicheController;
  late final TextEditingController _fearController;
  late final TextEditingController _experienceController;

  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    final p = widget.currentProfile;
    _nameController = TextEditingController(text: widget.currentDisplayName ?? '');
    _goalController = TextEditingController(text: p?.goal ?? '');
    _nicheController = TextEditingController(text: p?.niche ?? '');
    _fearController = TextEditingController(text: p?.fear ?? '');
    _experienceController = TextEditingController(text: p?.experience ?? '');

    // Track changes
    for (final c in [
      _nameController,
      _goalController,
      _nicheController,
      _fearController,
      _experienceController,
    ]) {
      c.addListener(() => setState(() => _hasUnsavedChanges = true));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _goalController.dispose();
    _nicheController.dispose();
    _fearController.dispose();
    _experienceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    EasyLoading.show(status: 'Saving...');

    bool hasError = false;
    final userRepo = sl<UserRepository>();

    // 1. Update display name if changed
    final newName = _nameController.text.trim();
    final originalName = widget.currentDisplayName?.trim() ?? '';
    if (newName != originalName && newName.isNotEmpty) {
      final result = await userRepo.updateDisplayName(widget.userId, newName);
      result.fold(
        (f) { hasError = true; },
        (_) {},
      );
    }

    // 2. Update profile fields
    final updatedProfile = UserProfile(
      userId: widget.userId,
      goal: _goalController.text.trim().isEmpty ? null : _goalController.text.trim(),
      niche: _nicheController.text.trim().isEmpty ? null : _nicheController.text.trim(),
      fear: _fearController.text.trim().isEmpty ? null : _fearController.text.trim(),
      experience: _experienceController.text.trim().isEmpty
          ? null
          : _experienceController.text.trim(),
      timezone: widget.currentProfile?.timezone,
      createdAt: widget.currentProfile?.createdAt ?? DateTime.now(),
    );

    if (widget.currentProfile != null) {
      final result = await userRepo.updateProfile(updatedProfile);
      result.fold(
        (f) { hasError = true; },
        (_) {},
      );
    } else {
      // Profile doesn't exist yet — create it only if at least one field is filled
      final anyFilled = [
        _goalController,
        _nicheController,
        _fearController,
        _experienceController,
      ].any((c) => c.text.trim().isNotEmpty);

      if (anyFilled) {
        final result = await userRepo.createProfile(
          userId: widget.userId,
          goal: _goalController.text.trim(),
          niche: _nicheController.text.trim(),
          fear: _fearController.text.trim(),
          experience: _experienceController.text.trim(),
        );
        result.fold(
          (f) { hasError = true; },
          (_) {},
        );
      }
    }

    EasyLoading.dismiss();
    setState(() {
      _isSaving = false;
      if (!hasError) _hasUnsavedChanges = false;
    });

    if (!mounted) return;
    if (hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Some changes could not be saved. Please check your connection.'),
          backgroundColor: Colors.red,
        ),
      );
    } else {
      EasyLoading.showSuccess('Profile updated!');
      Navigator.of(context).pop(true); // signal that profile was updated
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text('Unsaved Changes', style: TextStyle(color: Colors.white)),
        content: const Text(
          'You have unsaved changes. Are you sure you want to leave?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          final shouldPop = await _onWillPop();
          if (shouldPop && context.mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0F0F1A), Color(0xFF1E1E2E)],
            ),
          ),
          child: SafeArea(
            child: Form(
              key: _formKey,
              child: CustomScrollView(
                slivers: [
                  // App bar with save button
                  SliverAppBar(
                    floating: true,
                    backgroundColor: Colors.transparent,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back_ios),
                      onPressed: () async {
                        if (await _onWillPop()) Navigator.of(context).pop();
                      },
                    ),
                    title: const Text('Edit Profile'),
                    actions: [
                      if (_hasUnsavedChanges)
                        TextButton(
                          onPressed: _isSaving ? null : _save,
                          child: const Text(
                            'Save',
                            style: TextStyle(
                              color: Color(0xFF6366F1),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                    ],
                  ),

                  SliverList(
                    delegate: SliverChildListDelegate([
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Profile avatar placeholder
                            Center(
                              child: Stack(
                                children: [
                                  Container(
                                    width: 88,
                                    height: 88,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          const Color(0xFF6366F1),
                                          const Color(0xFF22D3EE),
                                        ],
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        (_nameController.text.isNotEmpty
                                                ? _nameController.text
                                                : 'C')
                                            .characters
                                            .first
                                            .toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 36,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ).animate().fadeIn(duration: 400.ms),

                            const SizedBox(height: 32),

                            _buildSectionHeader('Identity'),
                            const SizedBox(height: 12),

                            _buildField(
                              controller: _nameController,
                              label: 'Display Name',
                              hint: 'Your first name',
                              icon: Icons.person_outline,
                              validator: (v) {
                                if (v != null && v.isNotEmpty && v.trim().length < 2) {
                                  return 'Name must be at least 2 characters';
                                }
                                return null;
                              },
                            ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

                            const SizedBox(height: 32),

                            _buildSectionHeader('Personalization'),
                            const SizedBox(height: 4),
                            Text(
                              'These details shape your daily scripts. Update them anytime to refresh your content.',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.white38,
                              ),
                            ),
                            const SizedBox(height: 16),

                            _buildField(
                              controller: _goalController,
                              label: 'Your Goal',
                              hint: 'e.g. Build confidence on camera',
                              icon: Icons.flag_outlined,
                              maxLines: 2,
                            ).animate().fadeIn(delay: 150.ms, duration: 400.ms),

                            const SizedBox(height: 16),

                            _buildField(
                              controller: _nicheController,
                              label: 'Your Niche / Topic',
                              hint: 'e.g. Fitness, Tech, Personal Finance',
                              icon: Icons.category_outlined,
                            ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

                            const SizedBox(height: 16),

                            _buildField(
                              controller: _fearController,
                              label: 'Your Biggest Fear',
                              hint: 'e.g. Looking awkward on camera',
                              icon: Icons.psychology_outlined,
                              maxLines: 2,
                            ).animate().fadeIn(delay: 250.ms, duration: 400.ms),

                            const SizedBox(height: 16),

                            _buildField(
                              controller: _experienceController,
                              label: 'Your Experience Level',
                              hint: 'e.g. Complete beginner, 1 year of YouTube',
                              icon: Icons.star_outline,
                              maxLines: 2,
                            ).animate().fadeIn(delay: 300.ms, duration: 400.ms),

                            const SizedBox(height: 32),

                            // Info card
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.info_outline,
                                    color: Color(0xFF6366F1),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Updating your goal or niche will improve future AI scripts. Existing scripts won\'t change until you regenerate them.',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Colors.white54,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ).animate().fadeIn(delay: 350.ms, duration: 400.ms),

                            const SizedBox(height: 32),

                            // Main save button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isSaving ? null : _save,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: _isSaving
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Save Changes',
                                        style: TextStyle(fontSize: 17),
                                      ),
                              ),
                            ).animate().fadeIn(delay: 400.ms, duration: 400.ms),

                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white54,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      textCapitalization: TextCapitalization.sentences,
      style: const TextStyle(color: Colors.white),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Colors.white54),
        hintStyle: const TextStyle(color: Colors.white24),
        prefixIcon: Icon(icon, color: Colors.white38, size: 20),
        filled: true,
        fillColor: const Color(0xFF252538),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      ),
    );
  }
}
