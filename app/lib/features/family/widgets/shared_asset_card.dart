import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../models/shared_asset_model.dart';
import '../services/family_file_service.dart';

class SharedAssetCard extends StatelessWidget {
  final SharedAssetModel asset;
  final bool isOwner;
  final VoidCallback? onTap;
  final VoidCallback? onManagePermissions;
  final VoidCallback? onUnshare;

  const SharedAssetCard({super.key, required this.asset, this.isOwner = false, this.onTap, this.onManagePermissions, this.onUnshare});

  @override
  Widget build(BuildContext context) {
    final legacyImageUrl = asset.displayImageUrl;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(color: AppColors.surfaceWhite, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.lightLavenderBorder, width: 1.2), boxShadow: [BoxShadow(color: AppColors.primaryPurple.withAlpha(8), blurRadius: 12, offset: const Offset(0, 4))]),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 58, height: 58, decoration: BoxDecoration(color: AppColors.lightLavender, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.primaryPurple.withAlpha(40))), child: _buildThumbnail(legacyImageUrl)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(asset.name, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    if (isOwner) PopupMenuButton<String>(icon: const Icon(Icons.more_vert_rounded, color: AppColors.textSecondary, size: 20), padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), onSelected: (value) { if (value == 'permissions') onManagePermissions?.call(); else if (value == 'unshare') onUnshare?.call(); }, itemBuilder: (context) => [
                      PopupMenuItem(value: 'permissions', child: Row(children: [const Icon(Icons.security_rounded, size: 18, color: AppColors.primaryPurple), const SizedBox(width: 10), Text('Edit Permissions', style: GoogleFonts.outfit(fontSize: 14))])),
                      PopupMenuItem(value: 'unshare', child: Row(children: [const Icon(Icons.link_off_rounded, size: 18, color: AppColors.error), const SizedBox(width: 10), Text('Stop Sharing', style: GoogleFonts.outfit(fontSize: 14, color: AppColors.error))])),
                    ]),
                  ]),
                  const SizedBox(height: 4),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    if (asset.categoryName != null && asset.categoryName!.isNotEmpty) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: AppColors.lightLavender, borderRadius: BorderRadius.circular(8)), child: Text(asset.categoryName!, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primaryPurple))),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: isOwner ? AppColors.primaryPurple.withAlpha(20) : const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(8)), child: Text(isOwner ? 'Shared by you' : 'Owned by ${asset.ownerName}', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w500, color: isOwner ? AppColors.primaryPurple : AppColors.textSecondary))),
                  ]),
                ])),
              ]),
              if (asset.permissions.viewLocation && asset.location != null && asset.location!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(children: [const Icon(Icons.location_on_outlined, size: 15, color: AppColors.primaryPurple), const SizedBox(width: 6), Expanded(child: Text(asset.location!, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis))]),
              ],
              if (asset.permissions.viewDetails && asset.description != null && asset.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(asset.description!, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textMuted), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.lightLavenderBorder),
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 4, children: [
                _PermissionPill(label: 'Details', active: asset.permissions.viewDetails, icon: Icons.info_outline_rounded),
                _PermissionPill(label: 'Location', active: asset.permissions.viewLocation, icon: Icons.place_outlined),
                _PermissionPill(label: 'Documents', active: asset.permissions.viewDocuments, icon: Icons.description_outlined),
                _PermissionPill(label: 'Maintenance', active: asset.permissions.viewMaintenance, icon: Icons.build_outlined),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(String? legacyImageUrl) {
    final storagePath = asset.imageStoragePath;
    if (storagePath != null && storagePath.isNotEmpty) {
      return FutureBuilder<String>(
        future: FamilyFileService().getDownloadUrl(familyId: asset.familyId, path: storagePath),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            return ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.network(snapshot.data!, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => _fallbackIcon()));
          }
          if (snapshot.hasError) return _fallbackIcon();
          return const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)));
        },
      );
    }
    if (legacyImageUrl != null && legacyImageUrl.isNotEmpty) return _buildLegacyImage(legacyImageUrl);
    return _fallbackIcon();
  }

  Widget _buildLegacyImage(String path) {
    if (path.startsWith('http')) {
      return ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.network(path, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => _fallbackIcon()));
    }
    return ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.file(File(path), fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => _fallbackIcon()));
  }

  Widget _fallbackIcon() => Center(child: Text(asset.emoji ?? '📦', style: const TextStyle(fontSize: 28)));
}

class _PermissionPill extends StatelessWidget {
  final String label;
  final bool active;
  final IconData icon;

  const _PermissionPill({required this.label, required this.active, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: active ? const Color(0xFF10B981).withAlpha(15) : Colors.grey.withAlpha(20), borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(active ? Icons.check_circle_outline_rounded : Icons.lock_outline_rounded, size: 11, color: active ? const Color(0xFF10B981) : AppColors.textMuted),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, color: active ? const Color(0xFF047857) : AppColors.textMuted)),
      ]),
    );
  }
}
