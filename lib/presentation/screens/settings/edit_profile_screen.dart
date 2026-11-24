import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/user_profile.dart';
import '../../../domain/repositories/user_repository.dart';

/// Screen for viewing and editing user profile details.
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
    _nameController = TextEditingController(
      text: widget.currentDisplayName ?? '',
    );
    _goalController = TextEditingController(text: p?.goal ?? '');
    _nicheController = TextEditingController(text: p?.niche ?? '');
    _fearController = TextEditingController(text: p?.fear ?? '');
    _experienceController = TextEditingController(text: p?.experience ?? '');

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

    final newName = _nameController.text.trim();
    final originalName = widget.currentDisplayName?.trim() ?? '';
    if (newName != originalName && newName.isNotEmpty) {
      final result = await userRepo.updateDisplayName(widget.userId, newName);
      result.fold(
        (f) {
          hasError = true;
        },
        (_) {},
      );
    }

    final updatedProfile = UserProfile(
      userId: widget.userId,
      goal: _goalController.text.trim().isEmpty
          ? null
          : _goalController.text.trim(),
      niche: _nicheController.text.trim().isEmpty
          ? null
          : _nicheController.text.trim(),
      fear: _fearController.text.trim().isEmpty
          ? null
          : _fearController.text.trim(),
      experience: _experienceController.text.trim().isEmpty
          ? null
          : _experienceController.text.trim(),
      timezone: widget.currentProfile?.timezone,
      createdAt: widget.currentProfile?.createdAt ?? DateTime.now(),
    );

    if (widget.currentProfile != null) {
      final result = await userRepo.updateProfile(updatedProfile);
      result.fold(
        (f) {
          hasError = true;
        },
        (_) {},
      );
    } else {
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
          (f) {
            hasError = true;
          },
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
        SnackBar(
          content: Text(
            'Some changes could not be saved. Please check your connection.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    } else {
      EasyLoading.showSuccess('Profile updated!');
      Navigator.of(context).pop(true);
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Unsaved Changes'),
        content: Text(
          'You have unsaved changes. Are you sure you want to leave?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Discard',
              style: TextStyle(color: AppColors.error),
            ),
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
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded),
            onPressed: () async {
              if (await _onWillPop()) {
                if (context.mounted) Navigator.of(context).pop();
              }
            },
          ),
          title: Text('Edit Profile'),
          actions: [
            if (_hasUnsavedChanges)
              TextButton(
                onPressed: _isSaving ? null : _save,
                child: Text('Save'),
              ),
          ],
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: AppColors.olivePillFill,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.olivePillBorder,
                          width: 1.6,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          (_nameController.text.isNotEmpty
                                  ? _nameController.text
                                  : 'C')
                              .characters
                              .first
                              .toUpperCase(),
                          style: GoogleFonts.manrope(
                            color: AppColors.primaryOlive,
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SageSectionHeader(title: 'IDENTITY'),
                  const SizedBox(height: 6),
                  SageCard(
                    padding: const EdgeInsets.all(18),
                    child: _buildField(
                      controller: _nameController,
                      label: 'Display Name',
                      hint: 'Your first name',
                      icon: Icons.person_outline_rounded,
                      validator: (v) {
                        if (v != null &&
                            v.isNotEmpty &&
                            v.trim().length < 2) {
                          return 'Name must be at least 2 characters';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 22),
                  SageSectionHeader(title: 'PERSONALIZATION'),
                  Text(
                    'These details shape your daily scripts. Update them anytime to refresh your content.',
                    style: AppTypography.body(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  SageCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        _buildField(
                          controller: _goalController,
                          label: 'Your Goal',
                          hint: 'e.g. Build confidence on camera',
                          icon: Icons.flag_outlined,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 14),
                        _buildField(
                          controller: _nicheController,
                          label: 'Your Niche / Topic',
                          hint: 'e.g. Fitness, Tech, Personal Finance',
                          icon: Icons.category_outlined,
                        ),
                        const SizedBox(height: 14),
                        _buildField(
                          controller: _fearController,
                          label: 'Your Biggest Fear',
                          hint: 'e.g. Looking awkward on camera',
                          icon: Icons.psychology_outlined,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 14),
                        _buildField(
                          controller: _experienceController,
                          label: 'Your Experience Level',
                          hint: 'e.g. Complete beginner, 1 year of YouTube',
                          icon: Icons.star_outline_rounded,
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SageStatusCard(
                    title: 'AI Script Personalization',
                    subtitle:
                        'Updating your goal or niche will improve future AI scripts. Existing scripts remain unchanged.',
                    actionLabel: 'Active',
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      child: _isSaving
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.background,
                              ),
                            )
                          : Text('Save Changes'),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
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
      style: AppTypography.bodyStrong(),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        fillColor: AppColors.background,
        prefixIcon: Icon(icon, color: AppColors.secondaryText, size: 20),
      ),
    );
  }
}
