import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../services/video_storage_service.dart';
import '../../../bloc/content_creator/content_creator_bloc.dart';
import '../../../bloc/content_creator/content_creator_state.dart';

/// Tab showing recorded content videos.
class MyVideosTab extends StatelessWidget {
  final String userId;

  const MyVideosTab({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ContentCreatorBloc, ContentCreatorState>(
      builder: (context, state) {
        if (state is ContentCreatorLoading) {
          return Center(
            child: CircularProgressIndicator(color: AppColors.primaryOlive),
          );
        }

        if (state is ContentCreatorLoaded) {
          if (state.videos.isEmpty) return _buildEmptyState(context);
          return _buildVideoGrid(context, state.videos);
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SageCard(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.olivePillFill,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.olivePillBorder),
                ),
                child: Icon(
                  Icons.video_library_outlined,
                  size: 36,
                  color: AppColors.primaryOlive,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'No Videos Yet',
                style: AppTypography.headingMedium(fontSize: 20),
              ),
              const SizedBox(height: 6),
              Text(
                'Record your first video in the Record tab.',
                textAlign: TextAlign.center,
                style: AppTypography.body(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoGrid(BuildContext context, List<VideoInfo> videos) {
    return GridView.builder(
      padding: const EdgeInsets.all(18),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.78,
      ),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final video = videos[index];
        return _VideoCard(
          video: video,
          onTap: () => _playVideo(context, video),
          onDelete: () => _confirmDelete(context, video),
          onExport: () => _exportVideo(context, video),
        );
      },
    );
  }

  void _playVideo(BuildContext context, VideoInfo video) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _VideoPlayerScreen(
          videoPath: video.path,
          title: video.displayName,
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, VideoInfo video) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Video'),
        content: Text('Delete "${video.displayName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final service = sl<VideoStorageService>();
              await service.deleteVideo(video.path);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Video deleted')),
                );
              }
            },
            child: Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  void _exportVideo(BuildContext context, VideoInfo video) {
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
            ListTile(
              leading: Icon(
                Icons.photo_library_outlined,
                color: AppColors.secondaryGreen,
              ),
              title: Text('Save to Gallery', style: AppTypography.bodyStrong()),
              onTap: () async {
                Navigator.pop(ctx);
                final service = sl<VideoStorageService>();
                await service.exportToGallery(video.path);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Saved to Photos')),
                  );
                }
              },
            ),
            ListTile(
              leading: Icon(
                Icons.share_outlined,
                color: AppColors.primaryOlive,
              ),
              title: Text('Share', style: AppTypography.bodyStrong()),
              onTap: () async {
                Navigator.pop(ctx);
                final service = sl<VideoStorageService>();
                await service.shareVideo(video.path);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoCard extends StatelessWidget {
  final VideoInfo video;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onExport;

  const _VideoCard({
    required this.video,
    required this.onTap,
    required this.onDelete,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    return SageCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OlivePillBadge(label: 'Content'),
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
                width: 52,
                height: 52,
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
                const SizedBox(height: 2),
                Text(
                  _formatDate(video.createdAt),
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
                onTap();
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

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final file = File(widget.videoPath);
    if (!await file.exists()) {
      if (mounted) Navigator.pop(context);
      return;
    }
    _controller = VideoPlayerController.file(file);
    await _controller!.initialize();
    if (mounted) {
      setState(() => _isInitialized = true);
      _controller!.play();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: _isInitialized && _controller != null
            ? Padding(
                padding: const EdgeInsets.all(18),
                child: ClipRRect(
                  borderRadius: AppRadii.cardLargeBorder,
                  child: AspectRatio(
                    aspectRatio: _controller!.value.aspectRatio,
                    child: VideoPlayer(_controller!),
                  ),
                ),
              )
            : CircularProgressIndicator(color: AppColors.primaryOlive),
      ),
      floatingActionButton: _isInitialized
          ? FloatingActionButton(
              backgroundColor: AppColors.primaryOlive,
              foregroundColor: AppColors.background,
              onPressed: () => setState(
                () => _controller!.value.isPlaying
                    ? _controller!.pause()
                    : _controller!.play(),
              ),
              child: Icon(
                _controller!.value.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
              ),
            )
          : null,
    );
  }
}
