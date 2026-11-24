import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/daily_script.dart';

/// Teleprompter widget for displaying scrolling script text.
class Teleprompter extends StatefulWidget {
  final String text;
  final double scrollSpeed;
  final double fontSize;
  final Color? textColor;
  final bool isPlaying;
  final VoidCallback? onComplete;

  const Teleprompter({
    super.key,
    required this.text,
    this.scrollSpeed = 1.0,
    this.fontSize = 24,
    this.textColor,
    this.isPlaying = false,
    this.onComplete,
  });

  @override
  State<Teleprompter> createState() => TeleprompterState();
}

class TeleprompterState extends State<Teleprompter> {
  late ScrollController _scrollController;
  Timer? _scrollTimer;
  bool _isScrolling = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void didUpdateWidget(Teleprompter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        startScrolling();
      } else {
        pauseScrolling();
      }
    }
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void startScrolling() {
    if (_isScrolling) return;
    _isScrolling = true;

    final scrollIncrement = widget.scrollSpeed * 0.8;

    _scrollTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        final currentScroll = _scrollController.offset;

        if (currentScroll >= maxScroll) {
          timer.cancel();
          _isScrolling = false;
          widget.onComplete?.call();
        } else {
          _scrollController.jumpTo(currentScroll + scrollIncrement);
        }
      }
    });
  }

  void pauseScrolling() {
    _scrollTimer?.cancel();
    _isScrolling = false;
  }

  void resetScroll() {
    _scrollController.jumpTo(0);
  }

  void jumpToPosition(double position) {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(position);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) {
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.white,
            Colors.white,
            Colors.white,
            Colors.transparent,
          ],
          stops: [0.0, 0.1, 0.5, 0.9, 1.0],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(
          vertical: MediaQuery.of(context).size.height * 0.4,
          horizontal: 24,
        ),
        child: Text(
          widget.text,
          style: TextStyle(
            color: widget.textColor ?? AppColors.primaryText,
            fontSize: widget.fontSize,
            fontWeight: FontWeight.w500,
            height: 1.8,
            letterSpacing: 0.5,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// Overlay teleprompter that sits on top of camera preview.
class TeleprompterOverlay extends StatelessWidget {
  final String text;
  final double scrollSpeed;
  final double fontSize;
  final Color? textColor;
  final bool isPlaying;
  final double opacity;
  final GlobalKey<TeleprompterState>? teleprompterKey;

  const TeleprompterOverlay({
    super.key,
    required this.text,
    this.scrollSpeed = 1.0,
    this.fontSize = 20,
    this.textColor,
    this.isPlaying = false,
    this.opacity = 0.9,
    this.teleprompterKey,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedColor = textColor ?? const Color(0xFFF7F8F0);
    final bgAlpha = (opacity * 0.6).clamp(0.06, 0.62);
    return Container(
      color: const Color(0xFF121512).withValues(alpha: bgAlpha),
      child: Teleprompter(
        key: teleprompterKey,
        text: text,
        scrollSpeed: scrollSpeed,
        fontSize: fontSize,
        textColor: resolvedColor,
        isPlaying: isPlaying,
      ),
    );
  }
}

/// Segmented script display for days 1-5.
class SegmentedScriptDisplay extends StatelessWidget {
  final List<ScriptSegment> segments;
  final int currentSegment;
  final ValueChanged<int>? onSegmentTap;

  const SegmentedScriptDisplay({
    super.key,
    required this.segments,
    required this.currentSegment,
    this.onSegmentTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(segments.length, (index) {
            final isActive = index == currentSegment;
            final isDone = index < currentSegment;

            return Expanded(
              child: GestureDetector(
                onTap: () => onSegmentTap?.call(index),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDone
                        ? AppColors.secondaryGreen
                        : isActive
                            ? AppColors.primaryOlive
                            : AppColors.divider,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
        if (currentSegment < segments.length) ...[
          Text(
            'PART ${currentSegment + 1}',
            style: AppTypography.uppercaseLabel(
              color: AppColors.primaryOlive,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            segments[currentSegment].text,
            style: AppTypography.headingMedium(fontSize: 18),
          ),
          if (segments[currentSegment].focus.isNotEmpty) ...[
            const SizedBox(height: 12),
            OlivePillBadge(
              label: 'Focus: ${segments[currentSegment].focus}',
              icon: Icons.lightbulb_outline_rounded,
            ),
          ],
        ],
      ],
    );
  }
}
