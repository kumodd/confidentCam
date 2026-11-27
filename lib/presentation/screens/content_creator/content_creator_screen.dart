import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/theme/app_theme.dart';
import '../../bloc/content_creator/content_creator_bloc.dart';
import '../../bloc/content_creator/content_creator_event.dart';
import '../../bloc/content_creator/content_creator_state.dart';
import '../../bloc/settings/settings_bloc.dart';
import 'tabs/script_generator_tab.dart';
import 'tabs/my_scripts_tab.dart';
import 'tabs/record_tab.dart';
import 'tabs/my_videos_tab.dart';

/// InheritedWidget to access tab controller and recording state from child widgets
class ContentCreatorTabController extends InheritedWidget {
  final TabController tabController;
  final ValueNotifier<bool> isRecordingNotifier;

  const ContentCreatorTabController({
    super.key,
    required this.tabController,
    required this.isRecordingNotifier,
    required super.child,
  });

  static ContentCreatorTabController? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ContentCreatorTabController>();
  }

  void switchToTab(int index) {
    FocusManager.instance.primaryFocus?.unfocus();
    tabController.animateTo(index);
  }

  void setRecording(bool value) {
    isRecordingNotifier.value = value;
  }

  @override
  bool updateShouldNotify(ContentCreatorTabController oldWidget) {
    return tabController != oldWidget.tabController ||
        isRecordingNotifier != oldWidget.isRecordingNotifier;
  }
}

/// Main Content Creator screen with tabbed interface in the sage & olive design system.
class ContentCreatorScreen extends StatefulWidget {
  final String userId;

  const ContentCreatorScreen({super.key, required this.userId});

  @override
  State<ContentCreatorScreen> createState() => _ContentCreatorScreenState();
}

class _ContentCreatorScreenState extends State<ContentCreatorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ValueNotifier<bool> _isRecordingNotifier = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index != 0) {
        FocusManager.instance.primaryFocus?.unfocus();
      }
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _isRecordingNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ContentCreatorBloc>()..add(LoadScripts(widget.userId)),
      child: BlocProvider.value(
        value: context.read<SettingsBloc>(),
        child: ContentCreatorTabController(
          tabController: _tabController,
          isRecordingNotifier: _isRecordingNotifier,
          child: ValueListenableBuilder<bool>(
            valueListenable: _isRecordingNotifier,
            builder: (context, isRecording, child) {
              // Use the entire edge-to-edge display on the Record tab (both pre-record
              // and while recording) so it feels like a native camera app with
              // 100% consistent framing before and during capture.
              final isFullScreenCamera =
                  isRecording || _tabController.index == 2;

              return PopScope(
                canPop: !isFullScreenCamera,
                onPopInvokedWithResult: (didPop, _) {
                  if (didPop) return;
                  if (!isRecording && _tabController.index == 2) {
                    _tabController.animateTo(1);
                  }
                },
                child: Scaffold(
                  backgroundColor:
                      isFullScreenCamera ? Colors.black : AppColors.background,
                  resizeToAvoidBottomInset: _tabController.index == 0,
                  body: SafeArea(
                    top: !isFullScreenCamera,
                    bottom: !isFullScreenCamera,
                    left: !isFullScreenCamera,
                    right: !isFullScreenCamera,
                    child: Column(
                      children: [
                        if (!isFullScreenCamera) _buildHeader(context),
                        if (!isFullScreenCamera) _buildTabBar(),
                        Expanded(
                          child: BlocBuilder<
                            ContentCreatorBloc,
                            ContentCreatorState
                          >(
                            builder: (context, state) {
                              return TabBarView(
                                controller: _tabController,
                                physics:
                                    isFullScreenCamera
                                        ? const NeverScrollableScrollPhysics()
                                        : const ScrollPhysics(),
                                children: [
                                  ScriptGeneratorTab(userId: widget.userId),
                                  MyScriptsTab(userId: widget.userId),
                                  RecordTab(userId: widget.userId),
                                  MyVideosTab(userId: widget.userId),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 18, 6),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: AppColors.primaryText),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Content Creator',
                  style: AppTypography.headingLarge(fontSize: 22),
                ),
                Text(
                  'Create and manage your scripts & videos',
                  style: AppTypography.body(fontSize: 12.5),
                ),
              ],
            ),
          ),
          OlivePillBadge(label: 'AI Studio', icon: Icons.auto_awesome_outlined),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider, width: 1.2),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: false,
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        labelColor: AppColors.primaryText,
        unselectedLabelColor: AppColors.secondaryText,
        indicator: BoxDecoration(
          color: AppColors.navPill,
          borderRadius: BorderRadius.circular(15),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelStyle: GoogleFonts.manrope(
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: GoogleFonts.manrope(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        tabs: [
          Tab(
            icon: Icon(Icons.auto_awesome_outlined, size: 18),
            text: 'Generate',
          ),
          Tab(
            icon: Icon(Icons.description_outlined, size: 18),
            text: 'Scripts',
          ),
          Tab(icon: Icon(Icons.videocam_outlined, size: 18), text: 'Record'),
          Tab(
            icon: Icon(Icons.video_library_outlined, size: 18),
            text: 'Videos',
          ),
        ],
      ),
    );
  }
}
