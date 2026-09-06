import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import '../../../core/constants/app_colors.dart';

/// Full-screen zoomable image viewer.
/// Supports both a single image and a swipeable image gallery.
class FullScreenImageViewer extends StatefulWidget {
  final String imagePath;
  final String? title;
  final List<String>? imagePaths;
  final int initialIndex;

  const FullScreenImageViewer({
    super.key,
    required this.imagePath,
    this.title,
    this.imagePaths,
    this.initialIndex = 0,
  });

  static Future<void> show(
    BuildContext context, {
    required String imagePath,
    String? title,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FullScreenImageViewer(
          imagePath: imagePath,
          title: title,
        ),
      ),
    );
  }

  /// Opens a swipeable gallery. Images are expected to be local paths or URLs.
  static Future<void> showGallery(
    BuildContext context, {
    required List<String> imagePaths,
    String? title,
    int initialIndex = 0,
  }) {
    if (imagePaths.isEmpty) return Future<void>.value();

    final safeIndex = initialIndex.clamp(0, imagePaths.length - 1).toInt();
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FullScreenImageViewer(
          imagePath: imagePaths[safeIndex],
          imagePaths: imagePaths,
          title: title,
          initialIndex: safeIndex,
        ),
      ),
    );
  }

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  late final PageController _pageController;
  late int _currentIndex;

  List<String> get _images =>
      widget.imagePaths == null || widget.imagePaths!.isEmpty
          ? [widget.imagePath]
          : widget.imagePaths!;

  bool get _isGallery => _images.length > 1;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, _images.length - 1).toInt();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  ImageProvider _providerFor(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return NetworkImage(path);
    }
    return FileImage(File(path));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.title ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          if (_isGallery)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${_currentIndex + 1}/${_images.length}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: _images.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) {
              return PhotoView(
                imageProvider: _providerFor(_images[index]),
                backgroundDecoration:
                    const BoxDecoration(color: Colors.black),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 3.0,
                loadingBuilder: (context, event) => const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryPurple,
                  ),
                ),
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.broken_image_outlined,
                        size: 64,
                        color: Colors.white38,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Could not load image',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (_isGallery)
            Positioned(
              left: 0,
              right: 0,
              bottom: 18,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _images.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: index == _currentIndex ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: index == _currentIndex
                          ? Colors.white
                          : Colors.white38,
                      borderRadius: BorderRadius.circular(99),
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
