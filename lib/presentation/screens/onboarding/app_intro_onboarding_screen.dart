import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/datasources/local/hive_settings_datasource.dart';

/// 5-Screen Onboarding Walkthrough introducing ConfidentCam's core features
/// in the signature sage & olive design language (Light & Dark adaptive).
class AppIntroOnboardingScreen extends StatefulWidget {
  final VoidCallback? onFinished;

  const AppIntroOnboardingScreen({
    super.key,
    this.onFinished,
  });

  @override
  State<AppIntroOnboardingScreen> createState() =>
      _AppIntroOnboardingScreenState();
}

class _AppIntroOnboardingScreenState extends State<AppIntroOnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  static const int _totalPages = 5;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeIntro() async {
    try {
      final settingsDataSource = sl<HiveSettingsDataSource>();
      await settingsDataSource.saveSetting(
        AppConstants.hasSeenIntroOnboardingKey,
        true,
      );
    } catch (_) {}

    if (widget.onFinished != null) {
      widget.onFinished!();
    } else if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      _completeIntro();
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar with step badge and Skip button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 16, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OlivePillBadge(
                    label: 'STEP 0${_currentPage + 1} OF 0$_totalPages',
                    icon: Icons.auto_awesome_outlined,
                  ),
                  TextButton(
                    onPressed: _completeIntro,
                    child: Text(
                      _currentPage == _totalPages - 1 ? 'Done' : 'Skip',
                      style: GoogleFonts.manrope(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.secondaryGreen,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 5 Onboarding Slides
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                children: [
                  _buildSlide1ConfidenceArc(),
                  _buildSlide2Warmups(),
                  _buildSlide3Teleprompter(),
                  _buildSlide4AiScriptStudio(),
                  _buildSlide5ReflectionAndProgress(),
                ],
              ),
            ),

            // Bottom indicator + Back / Next controls
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_totalPages, (index) {
                      final isSelected = index == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isSelected ? 28 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primaryOlive
                              : AppColors.divider,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      if (_currentPage > 0) ...[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _prevPage,
                            style: OutlinedButton.styleFrom(
                              backgroundColor: AppColors.cardSurface,
                              foregroundColor: AppColors.primaryText,
                              side: BorderSide(
                                color: AppColors.divider,
                                width: 1.3,
                              ),
                            ),
                            child: const Text('Back'),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _nextPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryOlive,
                            foregroundColor: AppColors.background,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _currentPage == _totalPages - 1
                                    ? 'Get Started'
                                    : 'Continue',
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                _currentPage == _totalPages - 1
                                    ? Icons.check_rounded
                                    : Icons.arrow_forward_rounded,
                                size: 19,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Slide 1: 30-Day Camera Confidence Journey
  Widget _buildSlide1ConfidenceArc() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: OliveArcGauge(
              progress: 0.92,
              primaryValue: '30',
              primaryUnit: 'd',
              statusLabel: 'CAMERA CONFIDENCE',
              pillText: '1 Video Challenge / Day',
              size: 248,
            ),
          ),
          const SizedBox(height: 6),
          const SageStatusCard(
            title: 'Structured 30-Day Habit',
            subtitle:
                'Overcome camera shyness through short, guided daily recordings designed for real growth',
            actionLabel: 'Active',
          ),
          const SizedBox(height: 18),
          Text(
            'Speak on Camera with Natural Confidence',
            style: AppTypography.headingLarge(fontSize: 23),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Whether you are creating content, leading meetings, or sharing your story, ConfidentCam turns camera anxiety into calm, authentic presence in 30 days.',
            style: AppTypography.body(fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Slide 2: 3-Stage Progressive Warmups
  Widget _buildSlide2Warmups() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildWarmupPreviewCard(
            step: 'WARMUP 01',
            title: 'Deep Breathing & Presence',
            subtitle: 'Calm your nerves and center your voice',
            duration: '~1 min',
            isDone: true,
          ),
          const SizedBox(height: 10),
          _buildWarmupPreviewCard(
            step: 'WARMUP 02',
            title: 'Genuine Smile & Eye Contact',
            subtitle: 'Relax facial tension and connect with the lens',
            duration: '~1 min',
            isDone: true,
          ),
          const SizedBox(height: 10),
          _buildWarmupPreviewCard(
            step: 'WARMUP 03',
            title: 'Vocal Energy & Pacing',
            subtitle: 'Project clearly without rushing your thoughts',
            duration: '~1 min',
            isDone: false,
          ),
          const SizedBox(height: 18),
          Text(
            '3 Guided Warmups Before Day 1',
            style: AppTypography.headingLarge(fontSize: 23),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'No cold starts. Complete three 60-second warmup exercises to relax your breathing, expression, and voice before unlocking your 30-day challenge.',
            style: AppTypography.body(fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildWarmupPreviewCard({
    required String step,
    required String title,
    required String subtitle,
    required String duration,
    required bool isDone,
  }) {
    return SageCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isDone
                          ? Icons.check_circle_rounded
                          : Icons.play_circle_outline_rounded,
                      size: 17,
                      color: isDone
                          ? AppColors.secondaryGreen
                          : AppColors.primaryOlive,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      step,
                      style: AppTypography.uppercaseLabel(
                        fontSize: 10.5,
                        color: isDone
                            ? AppColors.secondaryGreen
                            : AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
                OlivePillBadge(label: isDone ? 'Completed' : duration),
              ],
            ),
          ),
          Container(height: 1.2, color: AppColors.divider),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.sectionTitle(fontSize: 15.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTypography.body(fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.secondaryText,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Slide 3: Smart Teleprompter Overlay
  Widget _buildSlide3Teleprompter() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SageCard(
            padding: EdgeInsets.zero,
            borderColor: AppColors.olivePillBorder,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const OlivePillBadge(
                        label: 'Day 1 • Teleprompter',
                        icon: Icons.videocam_outlined,
                      ),
                      Text(
                        '1.0x AUTO-SCROLL',
                        style: AppTypography.uppercaseLabel(
                          fontSize: 10.5,
                          color: AppColors.secondaryGreen,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(height: 1.2, color: AppColors.divider),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const OlivePillBadge(label: 'HOOK'),
                      const SizedBox(height: 6),
                      Text(
                        '"Hi everyone! Today is Day 1 of building my camera confidence..."',
                        style: AppTypography.bodyStrong(fontSize: 14.5),
                      ),
                      const SizedBox(height: 10),
                      const OlivePillBadge(label: 'KEY TAKEAWAY'),
                      const SizedBox(height: 6),
                      Text(
                        '"Progress beats perfection — showing up every day is what counts."',
                        style: AppTypography.body(
                          fontSize: 13.5,
                          color: AppColors.primaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: const [
              Expanded(
                child: SageMetricCard(
                  icon: Icons.speed_outlined,
                  label: 'SCROLL SPEED',
                  value: '0.5x – 3.0x',
                  subtitle: 'Live pace control',
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: SageMetricCard(
                  icon: Icons.visibility_outlined,
                  label: 'EYE LINE',
                  value: 'Top Lens',
                  subtitle: 'Natural eye contact',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Built-In Teleprompter Near the Lens',
            style: AppTypography.headingLarge(fontSize: 23),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Never blank out mid-sentence. Your script scrolls right below the front camera lens with customizable speed, font size, height, and opacity.',
            style: AppTypography.body(fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Slide 4: AI Content Creator Studio & Multi-Language Scripts
  Widget _buildSlide4AiScriptStudio() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: const [
              Expanded(
                child: SageMetricCard(
                  icon: Icons.auto_awesome_outlined,
                  label: 'AI STUDIO',
                  value: '3-Part Script',
                  subtitle: 'Hook • Body • Close',
                  showWaveAccent: true,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: SageMetricCard(
                  icon: Icons.language_rounded,
                  label: 'LANGUAGES',
                  value: 'EN • HI',
                  subtitle: 'English & Hinglish',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: const [
              Expanded(
                child: SageMetricCard(
                  icon: Icons.theater_comedy_outlined,
                  label: 'TONE',
                  value: '5 Styles',
                  subtitle: 'Casual to Authority',
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: SageMetricCard(
                  icon: Icons.edit_note_rounded,
                  label: 'CUSTOM',
                  value: 'Markdown',
                  subtitle: 'Write & highlight',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const SageStatusCard(
            title: 'Personalized to Your Niche',
            subtitle:
                'Generate instant scripts for any topic, target audience, and cultural context',
            actionLabel: 'AI Ready',
          ),
          const SizedBox(height: 18),
          Text(
            'AI Script Generator & Creator Studio',
            style: AppTypography.headingLarge(fontSize: 23),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Create structured Hook-Body-Ending scripts in seconds or write your own with bold keyword highlights for effortless delivery.',
            style: AppTypography.body(fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Slide 5: Mindful Self-Reflection & Local Video Vault
  Widget _buildSlide5ReflectionAndProgress() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: const [
              Expanded(
                child: SageMetricCard(
                  icon: Icons.local_fire_department_outlined,
                  label: 'STREAK',
                  value: 'Daily Habit',
                  subtitle: 'Track best streak',
                  showWaveAccent: true,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: SageMetricCard(
                  icon: Icons.checklist_rtl_rounded,
                  label: 'REFLECTION',
                  value: '6 Checks',
                  subtitle: 'Mindful self-review',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SageCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'POST-RECORDING CHECKLIST',
                      style: AppTypography.uppercaseLabel(fontSize: 11),
                    ),
                    const OlivePillBadge(label: '3/3 Minimum'),
                  ],
                ),
                const SizedBox(height: 10),
                _buildChecklistPreviewItem('I looked at the camera lens'),
                const SizedBox(height: 8),
                _buildChecklistPreviewItem(
                  'I spoke clearly and at a good pace',
                ),
                const SizedBox(height: 8),
                _buildChecklistPreviewItem(
                  'I felt more confident than yesterday',
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Track Streaks & Own Your Recordings',
            style: AppTypography.headingLarge(fontSize: 23),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Compare multiple takes, reflect on your delivery after each session, and keep all your recorded videos privately on your device.',
            style: AppTypography.body(fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistPreviewItem(String text) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: AppColors.secondaryGreen,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            Icons.check_rounded,
            size: 15,
            color: AppColors.background,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodyStrong(fontSize: 14),
          ),
        ),
      ],
    );
  }
}
