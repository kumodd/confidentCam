import 'dart:async';
import 'package:flutter/material.dart';

class TeleprompterWidget extends StatefulWidget {
  final String script;
  final String title;
  final bool isRecording;
  final double scrollSpeed;
  final double opacity;
  final double fontSize;
  final Color textColor;
  final Function(double) onSpeedChange;

  const TeleprompterWidget({
    super.key,
    required this.script,
    required this.title,
    required this.isRecording,
    required this.scrollSpeed,
    required this.opacity,
    this.fontSize = 16.0,
    this.textColor = Colors.white,
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
    final tickDuration = const Duration(milliseconds: 16);

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
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: widget.opacity),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isRecording ? Colors.red.withValues(alpha: 0.6) : const Color(0xFF6366F1).withValues(alpha: 0.6),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: widget.isRecording ? Colors.red.withValues(alpha: 0.2) : const Color(0xFF6366F1).withValues(alpha: 0.2),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: widget.isRecording ? Colors.red : const Color(0xFF6366F1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    widget.title,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                if (widget.isRecording) ...[
                  GestureDetector(
                    onTap: () => widget.onSpeedChange(-0.25),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                      child: const Icon(Icons.remove, color: Colors.white, size: 14),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      '${widget.scrollSpeed.toStringAsFixed(1)}x',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => widget.onSpeedChange(0.25),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                      child: const Icon(Icons.add, color: Colors.white, size: 14),
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  widget.isRecording ? '📖 Reading...' : '📖 Your Script',
                  style: TextStyle(color: widget.isRecording ? Colors.white : const Color(0xFFFBBF24), fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Expanded(
            child: ShaderMask(
              shaderCallback: (Rect bounds) {
                return LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white, Colors.white, Colors.white.withValues(alpha: 0.0)],
                  stops: const [0.0, 0.75, 1.0],
                ).createShader(bounds);
              },
              blendMode: BlendMode.dstIn,
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 40),
                physics: widget.isRecording ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
                child: Text(
                  widget.script,
                  style: TextStyle(color: widget.textColor, fontSize: widget.fontSize, height: 1.6, fontWeight: FontWeight.w400),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
