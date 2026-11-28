import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/config/remote_config_service.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/user_profile.dart';
import '../../../domain/repositories/user_repository.dart';
import '../../../services/video_storage_service.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../../bloc/auth/auth_state.dart';
import '../../bloc/settings/settings_bloc.dart';
import '../auth/qr_scanner_screen.dart';
import '../onboarding/app_intro_onboarding_screen.dart';
import 'edit_profile_screen.dart';

/// Fully functional settings screen in the sage & olive design system.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _storageBytes = 0;
  bool _loadingStorage = true;
  UserProfile? _currentProfile;
  String? _currentUserId;
  String? _currentDisplayName;
  bool _deletingAccount = false;

  @override
  void initState() {
    super.initState();
    _loadStorage();
    _loadProfile();
    context.read<SettingsBloc>().add(SettingsLoaded());
  }

  Future<void> _loadStorage() async {
    final service = sl<VideoStorageService>();
    final bytes = await service.getStorageUsedBytes();
    if (mounted) {
      setState(() {
        _storageBytes = bytes;
        _loadingStorage = false;
      });
    }
  }

  Future<void> _loadProfile() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthSuccess) {
      _currentUserId = authState.user.id;
      _currentDisplayName = authState.user.displayName;

      final result = await sl<UserRepository>().getProfile(authState.user.id);
      result.fold((_) {}, (profile) {
        if (mounted) setState(() => _currentProfile = profile);
      });
    }
  }

  Future<void> _openEditProfile() async {
    if (_currentUserId == null) return;
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder:
            (_) => EditProfileScreen(
              userId: _currentUserId!,
              currentDisplayName: _currentDisplayName,
              currentProfile: _currentProfile,
            ),
      ),
    );
    if (updated == true) _loadProfile();
  }

  String _formatBytes(int bytes) => formatBytes(bytes);

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthDeletingAccount) {
          _deletingAccount = true;
        } else if (state is AuthLoggedOut) {
          EasyLoading.dismiss();
          if (_deletingAccount) {
            _deletingAccount = false;
            EasyLoading.showSuccess('Account deleted');
          }
        } else if (state is AuthFailure) {
          _deletingAccount = false;
          EasyLoading.dismiss();
          EasyLoading.showError(state.message);
        }
      },
      child: BlocListener<SettingsBloc, SettingsState>(
        listener: (context, state) {
          if (state is SettingsNotificationError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Reminder saved, but you must enable notifications for ConfidentCam in your phone settings to receive them.',
                ),
                duration: const Duration(seconds: 4),
                action: SnackBarAction(
                  label: 'Settings',
                  onPressed: () {
                    openAppSettings();
                  },
                ),
              ),
            );
          }
        },
        child: Container(
          color: AppColors.background,
          child: SafeArea(
            child: BlocBuilder<SettingsBloc, SettingsState>(
              builder: (context, state) {
                final settings =
                    (state is SettingsLoadSuccess)
                        ? state.settings
                        : (state is SettingsNotificationError)
                        ? state.settings
                        : Settings.defaults();

                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(22, 16, 22, 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Settings',
                              style: AppTypography.headingLarge(fontSize: 25),
                            ),
                            OlivePillBadge(label: 'v${AppConfig.appVersion}'),
                          ],
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildListDelegate([
                        // Profile Card
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 6, 18, 4),
                          child: SageCard(
                            padding: const EdgeInsets.all(18),
                            onTap: _openEditProfile,
                            child: Row(
                              children: [
                                Container(
                                  width: 54,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    color: AppColors.olivePillFill,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.olivePillBorder,
                                      width: 1.4,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      (_currentDisplayName?.isNotEmpty == true
                                              ? _currentDisplayName!
                                              : 'C')
                                          .characters
                                          .first
                                          .toUpperCase(),
                                      style: GoogleFonts.manrope(
                                        color: AppColors.primaryOlive,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _currentDisplayName ??
                                            'Confident Creator',
                                        style: AppTypography.sectionTitle(
                                          fontSize: 16.5,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _currentProfile?.goal ??
                                            'Tap to personalize your profile',
                                        style: AppTypography.body(
                                          fontSize: 12.5,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: _openEditProfile,
                                  icon: Icon(Icons.edit_outlined, size: 16),
                                  label: Text('Edit'),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Quick 2-column metric cards for Storage & Reminder
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                          child: Row(
                            children: [
                              Expanded(
                                child: SageMetricCard(
                                  icon: Icons.folder_outlined,
                                  iconColor: AppColors.primaryOlive,
                                  label: 'STORAGE',
                                  value:
                                      _loadingStorage
                                          ? '...'
                                          : _formatBytes(_storageBytes),
                                  onTap: _clearAllVideos,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: SageMetricCard(
                                  icon: Icons.alarm_outlined,
                                  iconColor: AppColors.secondaryGreen,
                                  label: 'REMINDER',
                                  value: _formatTime(settings.reminderTime),
                                  onTap:
                                      () => _pickReminderTime(
                                        settings.reminderTime,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Teleprompter Section
                        _SettingsSection(
                          title: 'Teleprompter',
                          children: [
                            SwitchListTile(
                              secondary: Icon(
                                Icons.play_arrow_outlined,
                                color: AppColors.primaryOlive,
                              ),
                              title: Text(
                                'Auto-Scroll',
                                style: AppTypography.bodyStrong(),
                              ),
                              subtitle: Text(
                                'Automatically scroll teleprompter during recording',
                                style: AppTypography.body(fontSize: 12.5),
                              ),
                              value: settings.autoScrollEnabled,
                              activeThumbColor: AppColors.secondaryGreen,
                              activeTrackColor: AppColors.navPill,
                              onChanged: (v) {
                                context.read<SettingsBloc>().add(
                                  AutoScrollToggled(v),
                                );
                              },
                            ),
                            const Divider(height: 1),
                            SwitchListTile(
                              secondary: Icon(
                                Icons.mic_none_rounded,
                                color: AppColors.primaryOlive,
                              ),
                              title: Text(
                                'Voice-Following Scroll',
                                style: AppTypography.bodyStrong(),
                              ),
                              subtitle: Text(
                                'Follow spoken sentences to auto-scroll smoothly',
                                style: AppTypography.body(fontSize: 12.5),
                              ),
                              value: settings.voiceSyncEnabled,
                              activeThumbColor: AppColors.secondaryGreen,
                              activeTrackColor: AppColors.navPill,
                              onChanged: (v) {
                                context.read<SettingsBloc>().add(
                                  VoiceSyncToggled(v),
                                );
                              },
                            ),
                            const Divider(height: 1),
                            SwitchListTile(
                              secondary: Icon(
                                Icons.flip_rounded,
                                color: AppColors.primaryOlive,
                              ),
                              title: Text(
                                'Mirror Text (Beam Splitter)',
                                style: AppTypography.bodyStrong(),
                              ),
                              subtitle: Text(
                                'Flip script horizontally for physical mirror teleprompters',
                                style: AppTypography.body(fontSize: 12.5),
                              ),
                              value: settings.teleprompterMirrorText,
                              activeThumbColor: AppColors.secondaryGreen,
                              activeTrackColor: AppColors.navPill,
                              onChanged: (v) {
                                context.read<SettingsBloc>().add(
                                  TeleprompterMirrorToggled(v),
                                );
                              },
                            ),
                            const Divider(height: 1),
                            _DropdownTile(
                              icon: Icons.view_agenda_outlined,
                              title: 'Recording Layout',
                              value: settings.recordingLayoutTemplate,
                              options: {
                                for (final t in RecordingLayoutTemplate.values)
                                  t.key: t.label,
                              },
                              onChanged: (v) {
                                context.read<SettingsBloc>().add(
                                  RecordingLayoutTemplateUpdated(v),
                                );
                              },
                            ),
                            const Divider(height: 1),
                            _DropdownTile(
                              icon: Icons.timer_outlined,
                              title: 'Record Countdown',
                              value: '${settings.recordingCountdownSeconds}',
                              options: const {
                                '0': 'Instant (0s)',
                                '3': '3 Seconds',
                                '5': '5 Seconds',
                              },
                              onChanged: (v) {
                                final secs = int.tryParse(v) ?? 3;
                                context.read<SettingsBloc>().add(
                                  RecordingCountdownUpdated(secs),
                                );
                              },
                            ),
                            const Divider(height: 1),
                            SwitchListTile(
                              secondary: Icon(
                                Icons.notifications_off_outlined,
                                color: AppColors.primaryOlive,
                              ),
                              title: Text(
                                'Silence Alerts While Recording',
                                style: AppTypography.bodyStrong(),
                              ),
                              subtitle: Text(
                                'Mute notification pings and system sounds during takes',
                                style: AppTypography.body(fontSize: 12.5),
                              ),
                              value:
                                  settings.silenceNotificationsDuringRecording,
                              activeThumbColor: AppColors.secondaryGreen,
                              activeTrackColor: AppColors.navPill,
                              onChanged: (v) {
                                context.read<SettingsBloc>().add(
                                  SilenceNotificationsToggled(v),
                                );
                              },
                            ),
                            const Divider(height: 1),
                            _SliderTile(
                              icon: Icons.speed_outlined,
                              title: 'Scroll Speed',
                              value: settings.teleprompterSpeed,
                              min: 0.5,
                              max: 3.0,
                              suffix: 'x',
                              onChanged: (v) {
                                context.read<SettingsBloc>().add(
                                  TeleprompterSpeedUpdated(v),
                                );
                              },
                            ),
                            const Divider(height: 1),
                            _SliderTile(
                              icon: Icons.height_outlined,
                              title: 'Display Height',
                              value: (settings.teleprompterHeight * 100).clamp(
                                15.0,
                                90.0,
                              ),
                              min: 15,
                              max: 90,
                              suffix: '%',
                              onChanged: (v) {
                                context.read<SettingsBloc>().add(
                                  TeleprompterHeightUpdated(v / 100),
                                );
                              },
                            ),
                            const Divider(height: 1),
                            _SliderTile(
                              icon: Icons.opacity_outlined,
                              title: 'Background Opacity',
                              value: (settings.teleprompterOpacity * 100).clamp(
                                10.0,
                                85.0,
                              ),
                              min: 10,
                              max: 85,
                              suffix: '%',
                              onChanged: (v) {
                                context.read<SettingsBloc>().add(
                                  TeleprompterOpacityUpdated(v / 100),
                                );
                              },
                            ),
                            const Divider(height: 1),
                            _DropdownTile(
                              icon: Icons.text_fields_outlined,
                              title: 'Font Size',
                              value: settings.teleprompterFontSize,
                              options: {
                                'small': 'Small',
                                'medium': 'Medium',
                                'large': 'Large',
                                'extra_large': 'Extra Large',
                              },
                              onChanged: (v) {
                                context.read<SettingsBloc>().add(
                                  TeleprompterFontSizeUpdated(v),
                                );
                              },
                            ),
                            const Divider(height: 1),
                            _DropdownTile(
                              icon: Icons.palette_outlined,
                              title: 'Text Color',
                              value: settings.teleprompterTextColor,
                              options: {
                                'white': 'Warm White',
                                'yellow': 'Olive',
                                'cyan': 'Sage Green',
                                'green': 'Forest Green',
                                'pink': 'Crimson',
                              },
                              onChanged: (v) {
                                context.read<SettingsBloc>().add(
                                  TeleprompterTextColorUpdated(v),
                                );
                              },
                            ),
                          ],
                        ),

                        // Storage Section
                        _SettingsSection(
                          title: 'Storage',
                          children: [
                            _SettingsTile(
                              icon: Icons.folder_outlined,
                              title: 'Storage Used',
                              subtitle:
                                  _loadingStorage
                                      ? 'Calculating...'
                                      : _formatBytes(_storageBytes),
                              onTap: () {},
                            ),
                            const Divider(height: 1),
                            _SettingsTile(
                              icon: Icons.delete_sweep_outlined,
                              title: 'Clear All Videos',
                              subtitle: 'Delete all warmups and daily videos',
                              onTap: _clearAllVideos,
                            ),
                          ],
                        ),

                        // Camera & Language Section
                        _SettingsSection(
                          title: 'Camera & Language',
                          children: [
                            _DropdownTile(
                              icon: Icons.videocam_outlined,
                              title: 'Default Camera',
                              value: settings.defaultCamera,
                              options: {
                                'front': 'Front Camera',
                                'back': 'Back Camera',
                              },
                              onChanged: (v) {
                                context.read<SettingsBloc>().add(
                                  DefaultCameraUpdated(v),
                                );
                              },
                            ),
                            const Divider(height: 1),
                            _DropdownTile(
                              icon: Icons.language_outlined,
                              title: 'Script Language',
                              value: settings.languagePreference,
                              options: {
                                'en': 'English',
                                'hi': 'Hindi (हिन्दी)',
                                'hinglish': 'Hinglish',
                              },
                              onChanged: (v) {
                                context.read<SettingsBloc>().add(
                                  LanguagePreferenceUpdated(v),
                                );
                                _showLanguageChangeWarning(context);
                              },
                            ),
                            const Divider(height: 1),
                            _SettingsTile(
                              icon: Icons.alarm_outlined,
                              title: 'Daily Reminder',
                              subtitle: _formatTime(settings.reminderTime),
                              onTap:
                                  () =>
                                      _pickReminderTime(settings.reminderTime),
                            ),
                          ],
                        ),

                        // Support Section
                        _SettingsSection(
                          title: 'Support',
                          children: [
                            _SettingsTile(
                              icon: Icons.auto_awesome_outlined,
                              title: 'App Intro Tour',
                              subtitle: 'Replay the 5-step onboarding guide',
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => AppIntroOnboardingScreen(),
                                  ),
                                );
                              },
                            ),
                            if (!sl.isRegistered<RemoteConfigService>() ||
                                sl<RemoteConfigService>().qrLoginEnabled) ...[
                              const Divider(height: 1),
                              _SettingsTile(
                                icon: Icons.qr_code_scanner_rounded,
                                title: 'Web Login',
                                subtitle: 'Scan QR to login on web portal',
                                onTap: _openQrScanner,
                              ),
                            ],
                            const Divider(height: 1),
                            _SettingsTile(
                              icon: Icons.help_outline_rounded,
                              title: 'Help Center',
                              subtitle: 'Get help via email',
                              onTap:
                                  () => _launchUrl(
                                    'mailto:support@confidentcam.app?subject=Help%20Request',
                                  ),
                            ),
                            const Divider(height: 1),
                            _SettingsTile(
                              icon: Icons.privacy_tip_outlined,
                              title: 'Privacy Policy',
                              subtitle: 'How we handle your data',
                              onTap:
                                  () => _launchUrl(
                                    'https://confidentcam.app/privacy-policy.html',
                                  ),
                            ),
                            const Divider(height: 1),
                            _SettingsTile(
                              icon: Icons.description_outlined,
                              title: 'Terms of Service',
                              subtitle: 'Usage terms and conditions',
                              onTap:
                                  () => _launchUrl(
                                    'https://confidentcam.app/terms-of-service.html',
                                  ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: OutlinedButton.icon(
                            onPressed: _logout,
                            icon: Icon(
                              Icons.logout_rounded,
                              color: AppColors.error,
                              size: 19,
                            ),
                            label: Text('Logout'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: BorderSide(
                                color: AppColors.error,
                                width: 1.3,
                              ),
                            ),
                          ),
                        ),

                        // Danger Zone
                        _SettingsSection(
                          title: 'Danger Zone',
                          children: [
                            _SettingsTile(
                              icon: Icons.delete_forever_outlined,
                              title: 'Delete Account',
                              subtitle: 'Permanently delete all your data',
                              iconColor: AppColors.error,
                              onTap: _deleteAccount,
                            ),
                          ],
                        ),

                        const SizedBox(height: 28),
                        Center(
                          child: Text(
                            'ConfidentCam v${AppConfig.appVersion}',
                            style: AppTypography.body(
                              fontSize: 12.5,
                              color: AppColors.mutedText,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                      ]),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<void> _pickReminderTime(TimeOfDay current) async {
    final picked = await showTimePicker(context: context, initialTime: current);
    if (picked != null && mounted) {
      context.read<SettingsBloc>().add(ReminderTimeUpdated(picked));
    }
  }

  void _showLanguageChangeWarning(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Language updated! New scripts will be generated in the selected language.',
        ),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _openQrScanner() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => QrScannerScreen()));
  }

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open link'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _clearAllVideos() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text('Clear All Videos'),
            content: Text(
              'This will delete ALL your warmup and daily challenge videos. '
              'This cannot be undone. Are you sure?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  'Delete All',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      EasyLoading.show(status: 'Deleting...');
      final service = sl<VideoStorageService>();
      await service.clearAllVideos();
      await _loadStorage();
      EasyLoading.showSuccess('Videos deleted');
    }
  }

  void _logout() {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text('Logout'),
            content: Text('Are you sure you want to logout?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.read<AuthBloc>().add(LogoutRequested());
                },
                child: Text('Logout'),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteAccount() async {
    final firstConfirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.error,
                  size: 26,
                ),
                SizedBox(width: 10),
                Text(
                  'Delete Account',
                  style: TextStyle(color: AppColors.error),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This will permanently delete:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('• Your Supabase account & authentication'),
                Text('• All your scripts (30-day challenge scripts)'),
                Text('• All your progress & streaks'),
                Text('• All settings and preferences'),
                Text('• Your user profile and personalization'),
                SizedBox(height: 12),
                Text(
                  'What will NOT be deleted:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondaryGreen,
                  ),
                ),
                SizedBox(height: 6),
                Text('• Recorded videos (saved on your device)'),
                SizedBox(height: 12),
                Text(
                  'This action CANNOT be undone.',
                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  'Continue',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
            ],
          ),
    );

    if (firstConfirm != true || !mounted) return;

    String typedText = '';
    final finalConfirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: Text('Final Confirmation'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Type DELETE to confirm account deletion:'),
                      const SizedBox(height: 16),
                      TextField(
                        autofocus: true,
                        onChanged:
                            (value) => setDialogState(() => typedText = value),
                        decoration: InputDecoration(hintText: 'Type DELETE'),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        if (typedText.toUpperCase() == 'DELETE') {
                          Navigator.pop(ctx, true);
                        } else {
                          EasyLoading.showError(
                            'Please type DELETE to confirm',
                          );
                        }
                      },
                      child: Text(
                        'Delete Forever',
                        style: TextStyle(color: AppColors.error),
                      ),
                    ),
                  ],
                ),
          ),
    );

    if (finalConfirm != true || !mounted) return;

    _deletingAccount = true;
    EasyLoading.show(status: 'Deleting account...');
    context.read<AuthBloc>().add(AccountDeletionRequested());
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
          child: Text(
            title.toUpperCase(),
            style: AppTypography.uppercaseLabel(
              fontSize: 11.5,
              color: AppColors.secondaryText,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: AppRadii.cardBorder,
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? iconColor;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
      leading: Icon(icon, color: iconColor ?? AppColors.primaryOlive, size: 21),
      title: Text(
        title,
        style: AppTypography.bodyStrong(
          color: iconColor ?? AppColors.primaryText,
        ),
      ),
      subtitle:
          subtitle != null
              ? Text(subtitle!, style: AppTypography.body(fontSize: 12.5))
              : null,
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: AppColors.secondaryText,
      ),
      onTap: onTap,
    );
  }
}

class _SliderTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final double value;
  final double min;
  final double max;
  final String suffix;
  final ValueChanged<double> onChanged;

  const _SliderTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.suffix,
    required this.onChanged,
  });

  @override
  State<_SliderTile> createState() => _SliderTileState();
}

class _SliderTileState extends State<_SliderTile> {
  late double _currentValue;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.value.clamp(widget.min, widget.max);
  }

  @override
  void didUpdateWidget(_SliderTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _currentValue = widget.value.clamp(widget.min, widget.max);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(widget.icon, color: AppColors.primaryOlive, size: 20),
              const SizedBox(width: 12),
              Text(widget.title, style: AppTypography.bodyStrong()),
              const Spacer(),
              OlivePillBadge(
                label: '${_currentValue.toStringAsFixed(1)}${widget.suffix}',
              ),
            ],
          ),
          Slider(
            value: _currentValue,
            min: widget.min,
            max: widget.max,
            activeColor: AppColors.primaryOlive,
            inactiveColor: AppColors.divider,
            onChanged: (v) {
              setState(() => _currentValue = v);
              widget.onChanged(v);
            },
          ),
        ],
      ),
    );
  }
}

class _DropdownTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;

  const _DropdownTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryOlive, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: AppTypography.bodyStrong(),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          DropdownButton<String>(
            value: options.containsKey(value) ? value : options.keys.first,
            dropdownColor: AppColors.background,
            underline: const SizedBox.shrink(),
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.secondaryText,
            ),
            items:
                options.entries.map((e) {
                  return DropdownMenuItem(
                    value: e.key,
                    child: Text(
                      e.value,
                      style: GoogleFonts.manrope(
                        color: AppColors.secondaryGreen,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  );
                }).toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ],
      ),
    );
  }
}
