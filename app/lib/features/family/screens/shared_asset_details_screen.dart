import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../models/shared_asset_model.dart';
import '../services/family_file_service.dart';

/// Read-only view for family-shared data. It deliberately only renders fields
/// that the owner included through the sharing permissions.
class SharedAssetDetailsScreen extends StatelessWidget {
  final SharedAssetModel asset;

  const SharedAssetDetailsScreen({super.key, required this.asset});

  static Future<void> navigateTo(BuildContext context, SharedAssetModel asset) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SharedAssetDetailsScreen(asset: asset),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final permissions = asset.permissions;
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: Text(
          'Shared Asset',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          _buildImage(),
          const SizedBox(height: 18),
          Text(
            asset.name,
            style: GoogleFonts.outfit(
              fontSize: 26,
              height: 1.15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Shared by ${asset.ownerName}',
            style: GoogleFonts.outfit(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 18),
          _infoCard([
            if (asset.categoryName?.isNotEmpty == true)
              _InfoRow(
                'Category',
                asset.categoryName!,
                Icons.category_outlined,
              ),
            if (permissions.viewLocation && asset.location?.isNotEmpty == true)
              _InfoRow('Location', asset.location!, Icons.location_on_outlined),
            if (permissions.viewDetails &&
                asset.description?.isNotEmpty == true)
              _InfoRow('Description', asset.description!, Icons.notes_rounded),
          ]),
        ],
      ),
    );
  }

  Widget _buildImage() {
    final storagePath = asset.imageStoragePath;
    if (storagePath != null && storagePath.isNotEmpty) {
      return FutureBuilder<String>(
        future: FamilyFileService().getDownloadUrl(
          familyId: asset.familyId,
          path: storagePath,
        ),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            return _imageFrame(
              Image.network(snapshot.data!, fit: BoxFit.contain),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _imageFrame(
              const Center(child: CircularProgressIndicator()),
            );
          }
          return _emojiFrame();
        },
      );
    }
    final url = asset.displayImageUrl;
    if (url != null && url.isNotEmpty && url.startsWith('http')) {
      return _imageFrame(Image.network(url, fit: BoxFit.contain));
    }
    return _emojiFrame();
  }

  Widget _imageFrame(Widget child) => Container(
    height: 240,
    width: double.infinity,
    decoration: BoxDecoration(
      color: AppColors.lightLavender,
      borderRadius: BorderRadius.circular(22),
    ),
    clipBehavior: Clip.antiAlias,
    child: child,
  );

  Widget _emojiFrame() => _imageFrame(
    Center(
      child: Text(asset.emoji ?? '📦', style: const TextStyle(fontSize: 72)),
    ),
  );

  Widget _infoCard(List<_InfoRow> rows) {
    if (rows.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: _cardDecoration(),
        child: Text(
          'The owner has not shared additional details for this asset.',
          style: GoogleFonts.outfit(color: AppColors.textSecondary),
        ),
      );
    }
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            rows[index],
            if (index < rows.length - 1)
              const Divider(height: 1, color: AppColors.lightLavenderBorder),
          ],
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: AppColors.lightLavenderBorder),
  );
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoRow(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.primaryPurple),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.outfit(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
