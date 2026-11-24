import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:video_player/video_player.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../services/video_storage_service.dart';

/// My Videos screen showing all recorded videos in the sage & olive design system.
class MyVideosScreen extends StatefulWidget {
  const MyVideosScreen({super.key});

  @override
  State<MyVideosScreen> createState() => _MyVideosScreenState();
}

class _MyVideosScreenState extends State<MyVideosScreen> {
  List<VideoInfo> _videos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    final service = sl<VideoStorageService>();
    final videos = await service.getAllVideos();
    if (mounted) {
      setState(() {
        _videos = videos;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'My Videos',
                      style: AppTypography.headingLarge(fontSize: 25),
                    ),
                    OlivePillBadge(
                      label: '${_videos.length} Saved',
                      icon: Icons.videocam_outlined,
                    ),
                  ],
                ),
              ),
            ),
            if (_isLoading)
              SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryOlive,
                  ),
                ),
              )
            else if (_videos.isEmpty)
              SliverFillRemaining(child: _buildEmptyState())
            else
              SliverPadding(
                padding: const EdgeInsets.all(18),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.76,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _VideoCard(
                      video: _videos[index],
                      onDelete: () => _deleteVideo(_videos[index]),
                      onExport: () => _exportVideo(_videos[index]),
                    ),
                    childCount: _videos.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SageCard(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: AppColors.olivePillFill,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.olivePillBorder),
                ),
                child: Icon(
                  Icons.video_library_outlined,
                  size: 38,
                  color: AppColors.primaryOlive,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'No Videos Yet',
                style: AppTypography.headingMedium(fontSize: 21),
              ),
              const SizedBox(height: 8),
              Text(
                'Complete warmups and daily challenges\nto see your recorded videos here.',
                textAlign: TextAlign.center,
                style: AppTypography.body(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteVideo(VideoInfo video) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Video'),
        content: Text(
          'Delete "${video.displayName}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final service = sl<VideoStorageService>();
      await service.deleteVideo(video.path);
      _loadVideos();
    }
  }

  Future<void> _exportVideo(VideoInfo video) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.ios_share_rounded,
                  color: AppColors.primaryOlive,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Export ${video.displayName}',
                        style: AppTypography.headingMedium(fontSize: 18),
                      ),
                      Text(
                        _formatBytes(video.sizeBytes),
                        style: AppTypography.body(fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.navPill,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.photo_library_outlined,
                  color: AppColors.secondaryGreen,
                ),
              ),
              title: Text('Save to Gallery', style: AppTypography.bodyStrong()),
              subtitle: Text(
                'Export to camera roll / gallery',
                style: AppTypography.body(fontSize: 12.5),
              ),
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: AppColors.secondaryText,
              ),
              onTap: () => _handleExportToGallery(ctx, video),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.olivePillFill,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.share_outlined,
                  color: AppColors.primaryOlive,
                ),
              ),
              title: Text('Share', style: AppTypography.bodyStrong()),
              subtitle: Text(
                'Share via apps',
                style: AppTypography.body(fontSize: 12.5),
              ),
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: AppColors.secondaryText,
              ),
              onTap: () => _handleShare(ctx, video),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleExportToGallery(
    BuildContext ctx,
    VideoInfo video,
  ) async {
    Navigator.pop(ctx);
    EasyLoading.show(status: 'Saving to Photos...');
    final service = sl<VideoStorageService>();
    final success = await service.exportToGallery(video.path);
    EasyLoading.dismiss();
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Video saved! Check your Photos app.'),
        ),
      );
    }
  }

  Future<void> _handleShare(BuildContext ctx, VideoInfo video) async {
    Navigator.pop(ctx);
    EasyLoading.show(status: 'Preparing to share...');
    final service = sl<VideoStorageService>();
    await service.shareVideo(video.path);
    EasyLoading.dismiss();
  }

  String _formatBytes(int bytes) => formatBytes(bytes);
}

class _VideoCard extends StatelessWidget {
  final VideoInfo video;
  final VoidCallback onDelete;
  final VoidCallback onExport;

  const _VideoCard({
    required this.video,
    required this.onDelete,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final isWarmup = video.type == 'warmup';
    return SageCard(
      padding: EdgeInsets.zero,
      onTap: () => _playVideo(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OlivePillBadge(
                  label: isWarmup ? 'Warmup' : 'Day',
                  backgroundColor:
                      isWarmup ? AppColors.navPill : AppColors.olivePillFill,
                  borderColor: isWarmup
                      ? AppColors.secondaryGreen
                      : AppColors.olivePillBorder,
                  textColor: isWarmup
                      ? AppColors.secondaryGreen
                      : AppColors.primaryOlive,
                ),
                GestureDetector(
                  onTap: () => _showOptions(context),
                  child: Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.more_vert_rounded,
                      color: AppColors.secondaryText,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1.2, color: AppColors.divider),
          Expanded(
            child: Center(
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: AppColors.olivePillFill,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.olivePillBorder),
                ),
                child: Icon(
                  Icons.play_arrow_rounded,
                  size: 30,
                  color: AppColors.primaryOlive,
                ),
              ),
            ),
          ),
          Container(height: 1.2, color: AppColors.divider),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  video.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyStrong(fontSize: 14),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_formatDate(video.createdAt)} • ${_formatSize(video.sizeBytes)}',
                  style: AppTypography.body(
                    color: AppColors.mutedText,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _playVideo(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _VideoPlayerScreen(
          videoPath: video.path,
          title: video.displayName,
        ),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                Icons.play_arrow_rounded,
                color: AppColors.primaryOlive,
              ),
              title: Text('Play', style: AppTypography.bodyStrong()),
              onTap: () {
                Navigator.pop(ctx);
                _playVideo(context);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.share_outlined,
                color: AppColors.secondaryGreen,
              ),
              title: Text('Export', style: AppTypography.bodyStrong()),
              onTap: () {
                Navigator.pop(ctx);
                onExport();
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline_rounded,
                color: AppColors.error,
              ),
              title: Text(
                'Delete',
                style: AppTypography.bodyStrong(color: AppColors.error),
              ),
              onTap: () {
                Navigator.pop(ctx);
                onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
  String _formatSize(int bytes) => formatBytes(bytes);
}

class _VideoPlayerScreen extends StatefulWidget {
  final String videoPath;
  final String title;

  const _VideoPlayerScreen({required this.videoPath, required this.title});

  @override
  State<_VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<_VideoPlayerScreen> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      final file = File(widget.videoPath);
      if (!await file.exists()) {
        throw Exception('Video file not found');
      }

      _controller = VideoPlayerController.file(file);
      await _controller!.initialize();
      if (mounted) {
        setState(() => _isInitialized = true);
      }
      _controller!.play();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load video'),
            backgroundColor: AppColors.error,
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(widget.title)),
      body: GestureDetector(
        onTap: _toggleControls,
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardSurface,
                    borderRadius: AppRadii.cardLargeBorder,
                    border: Border.all(color: AppColors.divider, width: 1.5),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _isInitialized && _controller != null
                      ? Center(
                          child: AspectRatio(
                            aspectRatio: _controller!.value.aspectRatio,
                            child: VideoPlayer(_controller!),
                          ),
                        )
                      : Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryOlive,
                          ),
                        ),
                ),
              ),
            ),
            if (_showControls && _isInitialized && _controller != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                child: SageCard(
                  padding: const EdgeInsets.all(16),
                  child: ValueListenableBuilder<VideoPlayerValue>(
                    valueListenable: _controller!,
                    builder: (context, value, child) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          VideoProgressIndicator(
                            _controller!,
                            allowScrubbing: true,
                            colors: VideoProgressColors(
                              playedColor: AppColors.primaryOlive,
                              bufferedColor: AppColors.olivePillBorder,
                              backgroundColor: AppColors.divider,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.replay_10_rounded,
                                  color: AppColors.primaryText,
                                  size: 28,
                                ),
                                onPressed: () {
                                  final pos = value.position;
                                  _controller?.seekTo(
                                    pos - const Duration(seconds: 10),
                                  );
                                },
                              ),
                              const SizedBox(width: 20),
                              IconButton(
                                icon: Icon(
                                  value.isPlaying
                                      ? Icons.pause_circle_filled_rounded
                                      : Icons.play_circle_filled_rounded,
                                  color: AppColors.primaryOlive,
                                  size: 52,
                                ),
                                onPressed: () {
                                  if (value.isPlaying) {
                                    _controller?.pause();
                                  } else {
                                    _controller?.play();
                                  }
                                },
                              ),
                              const SizedBox(width: 20),
                              IconButton(
                                icon: Icon(
                                  Icons.forward_10_rounded,
                                  color: AppColors.primaryText,
                                  size: 28,
                                ),
                                onPressed: () {
                                  final pos = value.position;
                                  _controller?.seekTo(
                                    pos + const Duration(seconds: 10),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
