import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_theme.dart';
import '../../bloc/settings/settings_bloc.dart';

class TeleprompterSettingsSheet extends StatefulWidget {
  final double initialSpeed;
  final double initialHeight;
  final double initialOpacity;
  final Function(double speed, double height, double opacity) onSettingsSaved;

  const TeleprompterSettingsSheet({
    super.key,
    required this.initialSpeed,
    required this.initialHeight,
    required this.initialOpacity,
    required this.onSettingsSaved,
  });

  @override
  State<TeleprompterSettingsSheet> createState() =>
      _TeleprompterSettingsSheetState();
}

class _TeleprompterSettingsSheetState extends State<TeleprompterSettingsSheet> {
  late double _currentSpeed;
  late double _currentHeight;
  late double _currentOpacity;

  @override
  void initState() {
    super.initState();
    _currentSpeed = widget.initialSpeed.clamp(0.5, 3.0);
    _currentHeight = widget.initialHeight.clamp(0.15, 0.55);
    _currentOpacity = widget.initialOpacity.clamp(0.10, 0.85);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Teleprompter Settings',
                style: AppTypography.headingMedium(fontSize: 20),
              ),
              const SizedBox(height: 16),
              SageCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                child: Column(
                  children: [
                    _buildSliderRow(
                      label: 'SCROLL SPEED',
                      value: _currentSpeed,
                      min: 0.5,
                      max: 3.0,
                      suffix: 'x',
                      onChanged: (v) => setState(() => _currentSpeed = v),
                    ),
                    const Divider(height: 16),
                    _buildSliderRow(
                      label: 'HEIGHT',
                      value: (_currentHeight * 100).clamp(15.0, 55.0),
                      min: 15,
                      max: 55,
                      suffix: '%',
                      onChanged: (v) => setState(() => _currentHeight = v / 100),
                    ),
                    const Divider(height: 16),
                    _buildSliderRow(
                      label: 'OPACITY',
                      value: (_currentOpacity * 100).clamp(10.0, 85.0),
                      min: 10,
                      max: 85,
                      suffix: '%',
                      onChanged: (v) =>
                          setState(() => _currentOpacity = v / 100),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    context
                        .read<SettingsBloc>()
                        .add(TeleprompterSpeedUpdated(_currentSpeed));
                    context
                        .read<SettingsBloc>()
                        .add(TeleprompterHeightUpdated(_currentHeight));
                    context
                        .read<SettingsBloc>()
                        .add(TeleprompterOpacityUpdated(_currentOpacity));
                    widget.onSettingsSaved(
                      _currentSpeed,
                      _currentHeight,
                      _currentOpacity,
                    );
                    Navigator.pop(context);
                  },
                  child: Text('Save Settings'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required String suffix,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                label,
                style: AppTypography.uppercaseLabel(
                  color: AppColors.secondaryText,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(width: 8),
            OlivePillBadge(label: '${value.toStringAsFixed(1)}$suffix'),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          activeColor: AppColors.primaryOlive,
          inactiveColor: AppColors.divider,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
