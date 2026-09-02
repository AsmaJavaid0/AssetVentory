import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import '../../../core/constants/app_colors.dart';

/// Full-screen zoomable image viewer.
/// Uses [PhotoView] for pinch-to-zoom and pan gestures.
class FullScreenImageViewer extends StatelessWidget {
  final String imagePath;
  final String? title;

  const FullScreenImageViewer({
    super.key,
    required this.imagePath,
    this.title,
  });

  static Future<void> show(BuildContext context, {required String imagePath, String? title}) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FullScreenImageViewer(imagePath: imagePath, title: title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: title != null
            ? Text(
                title!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              )
            : null,
      ),
      body: PhotoView(
        imageProvider: FileImage(File(imagePath)),
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 3.0,
        loadingBuilder: (context, event) => const Center(
          child: CircularProgressIndicator(color: AppColors.primaryPurple),
        ),
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image_outlined, size: 64, color: Colors.white38),
              SizedBox(height: 12),
              Text('Could not load image', style: TextStyle(color: Colors.white54)),
            ],
          ),
        ),
      ),
    );
  }
}
