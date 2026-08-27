import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/utils/error_formatter.dart';
import '../../assets/models/local_asset.dart';
import '../../auth/models/user_model.dart';
import '../models/family_model.dart';
import '../models/shared_asset_model.dart';
import '../models/sharing_permissions_model.dart';

class ShareAssetPermissionsScreen extends StatefulWidget {
  final FamilyModel? family;
  final UserModel? currentUser;
  final LocalAsset? asset;
  final String? categoryName;
  final SharedAssetModel? sharedAsset; // When editing existing permissions

  const ShareAssetPermissionsScreen({
    super.key,
    this.family,
    this.currentUser,
    this.asset,
    this.categoryName,
    this.sharedAsset,
  });

  static Future<bool?> navigateTo(
    BuildContext context, {
    FamilyModel? family,
    UserModel? currentUser,
    LocalAsset? asset,
    String? categoryName,
    SharedAssetModel? sharedAsset,
  }) {
    return Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ShareAssetPermissionsScreen(
          family: family,
          currentUser: currentUser,
          asset: asset,
          categoryName: categoryName,
          sharedAsset: sharedAsset,
        ),
      ),
    );
  }

  @override
  State<ShareAssetPermissionsScreen> createState() => _ShareAssetPermissionsScreenState();
}

class _ShareAssetPermissionsScreenState extends State<ShareAssetPermissionsScreen> {
  final _familyRepository = serviceLocator.familyRepository;

  late bool _viewDetails;
  late bool _viewLocation;
  late bool _viewDocuments;
  late bool _viewMaintenance;
  bool _isSaving = false;

  bool get _isEditing => widget.sharedAsset != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final perms = widget.sharedAsset!.permissions;
      _viewDetails = perms.viewDetails;
      _viewLocation = perms.viewLocation;
      _viewDocuments = perms.viewDocuments;
      _viewMaintenance = perms.viewMaintenance;
    } else {
      _viewDetails = true;
      _viewLocation = false;
      _viewDocuments = false;
      _viewMaintenance = false;
    }
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    final perms = SharingPermissionsModel(
      viewDetails: _viewDetails,
      viewLocation: _viewLocation,
      viewDocuments: _viewDocuments,
      viewMaintenance: _viewMaintenance,
    );

    try {
      if (_isEditing) {
        await _familyRepository.updateSharedAssetPermissions(
          sharedAssetId: widget.sharedAsset!.id,
          permissions: perms,
        );
      } else {
        await _familyRepository.shareAsset(
          familyId: widget.family!.id,
          asset: widget.asset!,
          owner: widget.currentUser!,
          categoryName: widget.categoryName,
          permissions: perms,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ErrorFormatter.format(e)),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final assetName = _isEditing ? widget.sharedAsset!.name : widget.asset!.name;
    final emoji = _isEditing ? widget.sharedAsset!.emoji : widget.asset!.emoji;
    final imagePath = _isEditing ? widget.sharedAsset!.imagePath : widget.asset!.imagePath;
    final category = _isEditing ? widget.sharedAsset!.categoryName : widget.categoryName;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Sharing Permissions' : 'Permissions',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.lightLavenderBorder)),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _handleSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    _isEditing ? 'Save Permissions' : 'Share with Family',
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Asset Summary Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceWhite,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.lightLavenderBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.lightLavender,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: imagePath != null && imagePath.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: imagePath.startsWith('http')
                                ? Image.network(imagePath, fit: BoxFit.cover)
                                : Image.file(File(imagePath), fit: BoxFit.cover),
                          )
                        : Center(child: Text(emoji ?? '📦', style: const TextStyle(fontSize: 26))),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          assetName,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          category ?? 'Uncategorized',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: AppColors.primaryPurple,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'Choose what family members can see',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Personal assets stay private. Toggle only the data you want to share.',
              style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),

            // Permission Switches
            _PermissionSwitchTile(
              title: 'View Details',
              subtitle: 'Basic asset information, title, category, and description',
              icon: Icons.info_outline_rounded,
              value: _viewDetails,
              onChanged: (val) => setState(() => _viewDetails = val),
            ),
            const SizedBox(height: 12),

            _PermissionSwitchTile(
              title: 'View Location',
              subtitle: 'Physical storage location (e.g. Living Room, Garage, Safe)',
              icon: Icons.location_on_outlined,
              value: _viewLocation,
              onChanged: (val) => setState(() => _viewLocation = val),
            ),
            const SizedBox(height: 12),

            _PermissionSwitchTile(
              title: 'View Documents',
              subtitle: 'Receipts, warranties, user manuals, and attached files',
              icon: Icons.description_outlined,
              value: _viewDocuments,
              onChanged: (val) => setState(() => _viewDocuments = val),
            ),
            const SizedBox(height: 12),

            _PermissionSwitchTile(
              title: 'View Maintenance & Reminders',
              subtitle: 'Upcoming maintenance schedules and reminder dates',
              icon: Icons.build_outlined,
              value: _viewMaintenance,
              onChanged: (val) => setState(() => _viewMaintenance = val),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionSwitchTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PermissionSwitchTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: value
              ? AppColors.primaryPurple.withAlpha(50)
              : AppColors.lightLavenderBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: value
                  ? AppColors.primaryPurple.withAlpha(20)
                  : AppColors.lightLavender,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: value ? AppColors.primaryPurple : AppColors.textSecondary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: AppColors.primaryPurple,
            activeTrackColor: AppColors.primaryPurple.withAlpha(80),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
