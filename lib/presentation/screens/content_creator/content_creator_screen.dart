import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection_container.dart';
import '../../bloc/content_creator/content_creator_bloc.dart';
import '../../bloc/content_creator/content_creator_event.dart';
import '../../bloc/content_creator/content_creator_state.dart';
import '../../bloc/settings/settings_bloc.dart';
import 'tabs/script_generator_tab.dart';
import 'tabs/my_scripts_tab.dart';
import 'tabs/record_tab.dart';
import 'tabs/my_videos_tab.dart';

/// Main Content Creator screen with tabbed interface.
/// Completely standalone from warmup/challenge modules.
class ContentCreatorScreen extends StatefulWidget {
  final String userId;

  const ContentCreatorScreen({super.key, required this.userId});

  @override
  State<ContentCreatorScreen> createState() => _ContentCreatorScreenState();
}

class _ContentCreatorScreenState extends State<ContentCreatorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ContentCreatorBloc>()..add(LoadScripts(widget.userId)),
      child: BlocProvider.value(
        value: context.read<SettingsBloc>(),
        child: Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0F0F1A), Color(0xFF1E1E2E)],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Header
                  _buildHeader(context),
                  // Tab Bar
                  _buildTabBar(),
                  // Tab Views
                  Expanded(
                    child: BlocBuilder<ContentCreatorBloc, ContentCreatorState>(
                      builder: (context, state) {
                        return TabBarView(
                          controller: _tabController,
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
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Content Creator',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Create and manage your content',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.white54),
                ),
              ],
            ),
          ),
          // Gradient icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.movie_creation_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        indicatorColor: const Color(0xFFEC4899),
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        tabs: const [
          Tab(icon: Icon(Icons.auto_awesome, size: 18), text: 'Generate'),
          Tab(
            icon: Icon(Icons.description_outlined, size: 18),
            text: 'Scripts',
          ),
          Tab(icon: Icon(Icons.videocam_rounded, size: 18), text: 'Record'),
          Tab(
            icon: Icon(Icons.video_library_rounded, size: 18),
            text: 'Videos',
          ),
        ],
      ),
    );
  }
}
