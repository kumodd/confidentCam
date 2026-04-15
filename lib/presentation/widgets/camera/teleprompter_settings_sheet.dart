import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/settings/settings_bloc.dart';
import '../../bloc/settings/settings_event.dart';

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
  State<TeleprompterSettingsSheet> createState() => _TeleprompterSettingsSheetState();
}

class _TeleprompterSettingsSheetState extends State<TeleprompterSettingsSheet> {
  late double _currentSpeed;
  late double _currentHeight;
  late double _currentOpacity;

  @override
  void initState() {
    super.initState();
    _currentSpeed = widget.initialSpeed;
    _currentHeight = widget.initialHeight;
    _currentOpacity = widget.initialOpacity;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Teleprompter Settings',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          _buildSliderRow(
            label: 'Scroll Speed',
            value: _currentSpeed,
            min: 0.5,
            max: 3.0,
            suffix: 'x',
            onChanged: (v) => setState(() => _currentSpeed = v),
          ),
          const SizedBox(height: 16),
          _buildSliderRow(
            label: 'Height',
            value: _currentHeight * 100,
            min: 15,
            max: 80,
            suffix: '%',
            onChanged: (v) => setState(() => _currentHeight = v / 100),
          ),
          const SizedBox(height: 16),
          _buildSliderRow(
            label: 'Opacity',
            value: _currentOpacity * 100,
            min: 50,
            max: 100,
            suffix: '%',
            onChanged: (v) => setState(() => _currentOpacity = v / 100),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                context.read<SettingsBloc>().add(TeleprompterSpeedUpdated(_currentSpeed));
                context.read<SettingsBloc>().add(TeleprompterHeightUpdated(_currentHeight));
                context.read<SettingsBloc>().add(TeleprompterOpacityUpdated(_currentOpacity));
                widget.onSettingsSaved(_currentSpeed, _currentHeight, _currentOpacity);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22D3EE),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Save Settings'),
            ),
          ),
          const SizedBox(height: 16),
        ],
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
            Text(label, style: const TextStyle(color: Colors.white70)),
            Text(
              '${value.toStringAsFixed(1)}$suffix',
              style: const TextStyle(color: Color(0xFF22D3EE), fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          activeColor: const Color(0xFF22D3EE),
          inactiveColor: Colors.white24,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
