import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';

class TeleprompterWidget extends StatefulWidget {
  final String script;
  final String title;
  final bool isRecording;
  final double scrollSpeed;
  final double opacity;
  final double fontSize;
  final Color? textColor;
  final Function(double) onSpeedChange;

  const TeleprompterWidget({
    super.key,
    required this.script,
    required this.title,
    required this.isRecording,
    required this.scrollSpeed,
    required this.opacity,
    this.fontSize = 16.0,
    this.textColor,
    required this.onSpeedChange,
  });

  @override
  State<TeleprompterWidget> createState() => _TeleprompterWidgetState();
}

class _TeleprompterWidgetState extends State<TeleprompterWidget> {
  final ScrollController _scrollController = ScrollController();
  Timer? _scrollTimer;
  bool _isScrolling = false;

  @override
  void didUpdateWidget(TeleprompterWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording && !oldWidget.isRecording) {
      _startAutoScroll();
    }
    if (!widget.isRecording && oldWidget.isRecording) {
      _stopAutoScroll();
    }
    if (widget.isRecording && widget.scrollSpeed != oldWidget.scrollSpeed) {
      _stopAutoScroll();
      _startAutoScroll();
    }
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    if (_isScrolling) return;
    _isScrolling = true;
    final pixelsPerTick = 0.5 * widget.scrollSpeed;
    const tickDuration = Duration(milliseconds: 16);

    _scrollTimer = Timer.periodic(tickDuration, (timer) {
      if (!_scrollController.hasClients) return;
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.offset;

      if (currentScroll < maxScroll) {
        _scrollController.jumpTo(currentScroll + pixelsPerTick);
      } else {
        timer.cancel();
        _isScrolling = false;
      }
    });
  }

  void _stopAutoScroll() {
    _scrollTimer?.cancel();
    _isScrolling = false;
  }

  @override
  Widget build(BuildContext context) {
    // Smoked translucent camera-glass surface so live video stays visible behind script
    final resolvedTextColor = (widget.textColor == null ||
            widget.textColor == Colors.white ||
            widget.textColor == AppColors.primaryText)
        ? const Color(0xFFF7F8F0)
        : widget.textColor!;
    final bgAlpha = (widget.opacity * 0.65).clamp(0.06, 0.62);
    final headerAlpha = (bgAlpha + 0.12).clamp(0.14, 0.68);
    const onGlassText = Color(0xFFF7F8F0);
    const pillOliveText = Color(0xFFD8D478);
    const glassShadows = [
      Shadow(color: Color(0xCC000000), blurRadius: 6, offset: Offset(0, 1)),
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF121512).withValues(alpha: bgAlpha),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: widget.isRecording
              ? AppColors.error.withValues(alpha: 0.85)
              : Colors.white.withValues(alpha: 0.22),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF121512).withValues(alpha: headerAlpha),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: widget.isRecording
                        ? AppColors.error
                        : Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: widget.isRecording
                          ? AppColors.error
                          : pillOliveText.withValues(alpha: 0.55),
                    ),
                  ),
                  child: Text(
                    widget.title,
                    style: GoogleFonts.manrope(
                      color: widget.isRecording ? onGlassText : pillOliveText,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (widget.isRecording) ...[
                  GestureDetector(
                    onTap: () => widget.onSpeedChange(-0.25),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                      ),
                      child: const Icon(
                        Icons.remove,
                        color: onGlassText,
                        size: 14,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      '${widget.scrollSpeed.toStringAsFixed(1)}x',
                      style: GoogleFonts.manrope(
                        color: onGlassText,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => widget.onSpeedChange(0.25),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: onGlassText,
                        size: 14,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  widget.isRecording ? 'READING' : 'YOUR SCRIPT',
                  style: AppTypography.uppercaseLabel(
                    color: widget.isRecording
                        ? const Color(0xFFFF8A8A)
                        : const Color(0xFFA6E3B4),
                    fontSize: 10.5,
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1.0, color: Colors.white.withValues(alpha: 0.12)),
          Expanded(
            child: ShaderMask(
              shaderCallback: (Rect bounds) {
                return LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white,
                    Colors.white,
                    Colors.white.withValues(alpha: 0.0),
                  ],
                  stops: [0.0, 0.78, 1.0],
                ).createShader(bounds);
              },
              blendMode: BlendMode.dstIn,
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 34),
                physics: widget.isRecording
                    ? const NeverScrollableScrollPhysics()
                    : const BouncingScrollPhysics(),
                child: Text(
                  widget.script,
                  style: GoogleFonts.inter(
                    color: resolvedTextColor,
                    fontSize: widget.fontSize,
                    height: 1.6,
                    fontWeight: FontWeight.w500,
                    shadows: glassShadows,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
