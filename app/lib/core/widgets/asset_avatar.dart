import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Reusable widget for displaying an asset or task avatar (image with network loading,
/// or fallback emoji / default icon).
class AssetAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? emoji;
  final double size;
  final double borderRadius;
  final double fontSize;
  final Color? backgroundColor;
  final IconData defaultIcon;

  const AssetAvatar({
    super.key,
    this.imageUrl,
    this.emoji,
    this.size = 40,
    this.borderRadius = 12,
    this.fontSize = 20,
    this.backgroundColor,
    this.defaultIcon = Icons.inventory_2_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? AppColors.primaryPurple.withAlpha(20);

    if (imageUrl != null && imageUrl!.trim().isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          width: size,
          height: size,
          color: bgColor,
          child: Image.network(
            imageUrl!,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildFallback(bgColor),
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: SizedBox(
                  width: size * 0.45,
                  height: size * 0.45,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            },
          ),
        ),
      );
    }

    return _buildFallback(bgColor);
  }

  Widget _buildFallback(Color bgColor) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Center(
        child: emoji != null && emoji!.trim().isNotEmpty
            ? Text(
                emoji!,
                style: TextStyle(fontSize: fontSize),
              )
            : Icon(
                defaultIcon,
                size: size * 0.55,
                color: AppColors.primaryPurple,
              ),
      ),
    );
  }
}
