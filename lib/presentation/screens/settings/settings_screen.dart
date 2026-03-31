import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/di/injection_container.dart';
import '../../../services/video_storage_service.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../../bloc/auth/auth_state.dart';
import '../../bloc/settings/settings_bloc.dart';
import '../auth/qr_scanner_screen.dart';

/// Fully functional settings screen.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _storageBytes = 0;
  bool _loadingStorage = true;

  @override
  void initState() {
    super.initState();
    _loadStorage();
    // Ensure settings are loaded
    context.read<SettingsBloc>().add(const SettingsLoaded());
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

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthLoggedOut) {
          EasyLoading.dismiss();
          EasyLoading.showSuccess('Account deleted');
        } else if (state is AuthFailure) {
          EasyLoading.dismiss();
          EasyLoading.showError(state.message);
        }
      },
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F0F1A), Color(0xFF1E1E2E)],
          ),
        ),
        child: SafeArea(
          child: BlocBuilder<SettingsBloc, SettingsState>(
            builder: (context, state) {
              final settings =
                  state is SettingsLoadSuccess
                      ? state.settings
                      : Settings.defaults();

              return CustomScrollView(
                slivers: [
                  const SliverAppBar(
                    floating: true,
                    backgroundColor: Colors.transparent,
                    title: Text('Settings'),
                  ),
                  SliverList(
                    delegate: SliverChildListDelegate([
                      // Teleprompter Section
                      _SettingsSection(
                        title: 'Teleprompter',
                        children: [
                          // Auto-scroll toggle
                          SwitchListTile(
                            secondary: const Icon(
                              Icons.play_arrow_outlined,
                              color: Colors.white54,
                            ),
                            title: const Text(
                              'Auto-Scroll',
                              style: TextStyle(color: Colors.white),
                            ),
                            subtitle: const Text(
                              'Automatically scroll teleprompter during recording',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                            value: settings.autoScrollEnabled,
                            activeColor: const Color(0xFF22D3EE),
                            onChanged: (v) {
                              context.read<SettingsBloc>().add(
                                AutoScrollToggled(v),
                              );
                            },
                          ),
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
                          _SliderTile(
                            icon: Icons.height_outlined,
                            title: 'Display Height',
                            value: settings.teleprompterHeight * 100,
                            min: 15,
                            max: 80,
                            suffix: '%',
                            onChanged: (v) {
                              context.read<SettingsBloc>().add(
                                TeleprompterHeightUpdated(v / 100),
                              );
                            },
                          ),
                          _SliderTile(
                            icon: Icons.opacity_outlined,
                            title: 'Background Opacity',
                            value: settings.teleprompterOpacity * 100,
                            min: 30,
                            max: 100,
                            suffix: '%',
                            onChanged: (v) {
                              context.read<SettingsBloc>().add(
                                TeleprompterOpacityUpdated(v / 100),
                              );
                            },
                          ),
                          _DropdownTile(
                            icon: Icons.text_fields_outlined,
                            title: 'Font Size',
                            value: settings.teleprompterFontSize,
                            options: const {
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
                          _DropdownTile(
                            icon: Icons.palette_outlined,
                            title: 'Text Color',
                            value: settings.teleprompterTextColor,
                            options: const {
                              'white': 'White',
                              'yellow': 'Yellow',
                              'cyan': 'Cyan',
                              'green': 'Green',
                              'pink': 'Pink',
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
                          _SettingsTile(
                            icon: Icons.delete_sweep_outlined,
                            title: 'Clear All Videos',
                            subtitle: 'Delete all warmups and daily videos',
                            onTap: _clearAllVideos,
                          ),
                        ],
                      ),

                      // Camera Section
                      _SettingsSection(
                        title: 'Camera',
                        children: [
                          _DropdownTile(
                            icon: Icons.videocam_outlined,
                            title: 'Default Camera',
                            value: settings.defaultCamera,
                            options: const {
                              'front': 'Front Camera',
                              'back': 'Back Camera',
                            },
                            onChanged: (v) {
                              context.read<SettingsBloc>().add(
                                DefaultCameraUpdated(v),
                              );
                            },
                          ),
                        ],
                      ),

                      // Language Section
                      _SettingsSection(
                        title: 'Language',
                        children: [
                          _DropdownTile(
                            icon: Icons.language_outlined,
                            title: 'Script Language',
                            value: settings.languagePreference,
                            options: const {
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
                        ],
                      ),

                      // Notifications Section
                      _SettingsSection(
                        title: 'Notifications',
                        children: [
                          _SettingsTile(
                            icon: Icons.alarm_outlined,
                            title: 'Daily Reminder',
                            subtitle: _formatTime(settings.reminderTime),
                            onTap:
                                () => _pickReminderTime(settings.reminderTime),
                          ),
                        ],
                      ),

                      // Support Section
                      _SettingsSection(
                        title: 'Support',
                        children: [
                          _SettingsTile(
                            icon: Icons.qr_code_scanner,
                            title: 'Web Login',
                            subtitle: 'Scan QR to login on web portal',
                            onTap: _openQrScanner,
                          ),
                          _SettingsTile(
                            icon: Icons.help_outline,
                            title: 'Help Center',
                            subtitle: 'Get help via email',
                            onTap:
                                () => _launchUrl(
                                  'mailto:support@confidentcam.app?subject=Help%20Request',
                                ),
                          ),
                          _SettingsTile(
                            icon: Icons.privacy_tip_outlined,
                            title: 'Privacy Policy',
                            subtitle: 'How we handle your data',
                            onTap:
                                () => _launchUrl(
                                  'https://confidentcam.app/privacy-policy.html',
                                ),
                          ),
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

                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: OutlinedButton(
                          onPressed: _logout,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                          ),
                          child: const Text('Logout'),
                        ),
                      ),

                      // Danger Zone
                      _SettingsSection(
                        title: 'Danger Zone',
                        children: [
                          _SettingsTile(
                            icon: Icons.delete_forever,
                            title: 'Delete Account',
                            subtitle: 'Permanently delete all your data',
                            onTap: _deleteAccount,
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),
                      Center(
                        child: Text(
                          'ConfidentCam v1.0.0',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.white38),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ]),
                  ),
                ],
              );
            },
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
      const SnackBar(
        content: Text(
          'Language updated! New scripts will be generated in the selected language.',
        ),
        backgroundColor: Color(0xFF6366F1),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _openQrScanner() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const QrScannerScreen()));
  }

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open link'),
            backgroundColor: Colors.red,
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
            title: const Text('Clear All Videos'),
            content: const Text(
              'This will delete ALL your warmup and daily challenge videos. '
              'This cannot be undone. Are you sure?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Delete All',
                  style: TextStyle(color: Colors.red),
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
            title: const Text('Logout'),
            content: const Text('Are you sure you want to logout?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.read<AuthBloc>().add(const LogoutRequested());
                },
                child: const Text('Logout'),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteAccount() async {
    // First confirmation
    final firstConfirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete Account'),
            content: const Text(
              'This will permanently delete:\n\n'
              '• Your account\n'
              '• All your videos\n'
              '• All your progress\n'
              '• All your settings\n\n'
              'This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Continue',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (firstConfirm != true || !mounted) return;

    // Second confirmation - require typing DELETE
    String typedText = '';
    final finalConfirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text('Final Confirmation'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Type DELETE to confirm account deletion:'),
                      const SizedBox(height: 16),
                      TextField(
                        autofocus: true,
                        onChanged:
                            (value) => setDialogState(() => typedText = value),
                        decoration: const InputDecoration(
                          hintText: 'Type DELETE',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
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
                      child: const Text(
                        'Delete Forever',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
          ),
    );

    if (finalConfirm != true || !mounted) return;

    // Show loading and perform deletion
    EasyLoading.show(status: 'Deleting account...');

    try {
      // Clear local videos first
      final videoService = sl<VideoStorageService>();
      await videoService.clearAllVideos();

      if (!mounted) {
        EasyLoading.dismiss();
        return;
      }

      // Delete account via AuthBloc - this will trigger AuthLoggedOut
      context.read<AuthBloc>().add(const AccountDeletionRequested());
    } catch (e) {
      EasyLoading.dismiss();
      EasyLoading.showError('Failed to delete account');
    }
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
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white54,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2E),
            borderRadius: BorderRadius.circular(12),
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
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.white54),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: const Icon(Icons.chevron_right, color: Colors.white24),
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
    // Update local value when prop changes (after bloc update)
    if (oldWidget.value != widget.value) {
      _currentValue = widget.value.clamp(widget.min, widget.max);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(widget.icon, color: Colors.white54, size: 20),
              const SizedBox(width: 12),
              Text(widget.title, style: const TextStyle(color: Colors.white)),
              const Spacer(),
              Text(
                '${_currentValue.toStringAsFixed(1)}${widget.suffix}',
                style: const TextStyle(
                  color: Color(0xFF22D3EE),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Slider(
            value: _currentValue,
            min: widget.min,
            max: widget.max,
            activeColor: const Color(0xFF22D3EE),
            inactiveColor: Colors.white24,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.white54, size: 20),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(color: Colors.white)),
          const Spacer(),
          DropdownButton<String>(
            value: options.containsKey(value) ? value : options.keys.first,
            dropdownColor: const Color(0xFF1E1E2E),
            underline: const SizedBox.shrink(),
            items:
                options.entries.map((e) {
                  return DropdownMenuItem(
                    value: e.key,
                    child: Text(
                      e.value,
                      style: const TextStyle(color: Color(0xFF22D3EE)),
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
