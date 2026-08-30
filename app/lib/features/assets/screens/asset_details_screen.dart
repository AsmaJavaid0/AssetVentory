import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/utils/error_formatter.dart';
import '../../auth/models/user_model.dart';
import '../../family/models/family_model.dart';
import '../../family/models/shared_asset_model.dart';
import '../../family/screens/share_asset_permissions_screen.dart';
import '../../family/widgets/family_auth_prompt.dart';
import '../models/local_asset.dart';
import '../models/local_asset_document.dart';
import '../models/local_category.dart';
import 'edit_asset_screen.dart';

class AssetDetailsScreen extends StatefulWidget {
  final LocalAsset asset;
  const AssetDetailsScreen({super.key, required this.asset});

  static Future<void> navigateTo(BuildContext context, LocalAsset asset) {
    return Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AssetDetailsScreen(asset: asset)));
  }

  @override
  State<AssetDetailsScreen> createState() => _AssetDetailsScreenState();
}

class _AssetDetailsScreenState extends State<AssetDetailsScreen> {
  late LocalAsset _asset;
  late Future<List<LocalAssetDocument>> _documentsFuture;
  late Future<List<LocalCategory>> _categoriesFuture;
  FamilyModel? _userFamily;
  SharedAssetModel? _sharedAsset;

  @override
  void initState() {
    super.initState();
    _asset = widget.asset;
    _documentsFuture = _loadDocuments();
    _categoriesFuture = serviceLocator.categoryRepository.getCategories('local_user');
    _checkFamilySharing();
  }

  Future<List<LocalAssetDocument>> _loadDocuments() => serviceLocator.assetDocumentRepository.getDocuments(_asset.id);

  Future<void> _checkFamilySharing() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      if (mounted) {
        setState(() {
          _userFamily = null;
          _sharedAsset = null;
        });
      }
      return;
    }

    try {
      final family = await serviceLocator.familyRepository.getUserFamily(firebaseUser.uid);
      if (family != null) {
        final sharedAssets = await serviceLocator.familyRepository.streamSharedAssets(family.id).first;
        final matched = sharedAssets.where((s) => s.assetId == _asset.id).firstOrNull;
        if (mounted) {
          setState(() {
            _userFamily = family;
            _sharedAsset = matched;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _userFamily = null;
            _sharedAsset = null;
          });
        }
      }
    } catch (_) {
    }
  }

  String _categoryName(List<LocalCategory> categories) {
    if (_asset.categoryId == null) return 'Uncategorized';
    for (final category in categories) {
      if (category.id == _asset.categoryId) return category.name;
    }
    return 'Uncategorized';
  }

  Future<void> _edit() async {
    await Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (_) => EditAssetScreen(asset: _asset)));
    if (!mounted) return;
    final updated = await serviceLocator.assetRepository.getAsset(_asset.id);
    if (!mounted) return;
    if (updated == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _asset = updated;
      _documentsFuture = _loadDocuments();
    });
    await _checkFamilySharing();
  }

  Future<void> _handleShareAsset() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      await FamilyAuthPrompt.show(context);
      if (!mounted) return;
      await _checkFamilySharing();
      if (FirebaseAuth.instance.currentUser != null) {
        await _handleShareAsset();
      }
      return;
    }

    try {
      final family = await serviceLocator.familyRepository.getUserFamily(firebaseUser.uid);
      if (!mounted) return;

      if (family == null) {
        showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text('Family Sharing', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
            content: Text(
              'To share this asset, you need to create or join a family circle first in the Family tab.',
              style: GoogleFonts.outfit(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      // Check if already shared
      final sharedAssets = await serviceLocator.familyRepository.streamSharedAssets(family.id).first;
      final existingShared = sharedAssets.where((s) => s.assetId == _asset.id).firstOrNull;

      if (!mounted) return;

      if (existingShared != null) {
        final updated = await ShareAssetPermissionsScreen.navigateTo(
          context,
          sharedAsset: existingShared,
        );
        if (updated == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sharing permissions updated.'), backgroundColor: AppColors.success),
          );
          await _checkFamilySharing();
        }
        return;
      }

      final categories = await _categoriesFuture;
      final userModel = UserModel(
        id: firebaseUser.uid,
        name: firebaseUser.displayName ?? '',
        email: firebaseUser.email ?? '',
        photoUrl: firebaseUser.photoURL ?? '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (!mounted) return;

      final shared = await ShareAssetPermissionsScreen.navigateTo(
        context,
        family: family,
        currentUser: userModel,
        asset: _asset,
        categoryName: _categoryName(categories),
      );

      if (shared == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Asset shared with your family!'), backgroundColor: AppColors.success),
        );
        await _checkFamilySharing();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorFormatter.format(e)), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _confirmUnshare() async {
    if (_sharedAsset == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Stop Sharing Asset?', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        content: Text(
          'Are you sure you want to stop sharing "${_asset.name}" with your family? Your local personal copy will remain unaffected.',
          style: GoogleFonts.outfit(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Stop Sharing', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await serviceLocator.familyRepository.unshareAsset(_sharedAsset!.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Asset is no longer shared with the family.'), backgroundColor: AppColors.success),
        );
        await _checkFamilySharing();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorFormatter.format(e)), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _refresh() async {
    final updated = await serviceLocator.assetRepository.getAsset(_asset.id);
    if (!mounted) return;
    if (updated == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _asset = updated;
      _documentsFuture = _loadDocuments();
      _categoriesFuture = serviceLocator.categoryRepository.getCategories('local_user');
    });
    await _checkFamilySharing();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: Text('Asset Details', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        actions: [
          IconButton(
            tooltip: _sharedAsset != null ? 'Manage Family Sharing' : 'Share with Family',
            onPressed: _handleShareAsset,
            icon: Icon(
              _sharedAsset != null ? Icons.share_rounded : Icons.share_outlined,
              color: _sharedAsset != null ? AppColors.primaryPurple : null,
            ),
          ),
          IconButton(tooltip: 'Edit asset', onPressed: _edit, icon: const Icon(Icons.edit_outlined)),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primaryPurple,
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          children: [
            _buildPhoto(),
            const SizedBox(height: 18),
            Text(_asset.name, maxLines: 3, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontSize: 26, height: 1.15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            _buildFamilySharingCard(),
            const SizedBox(height: 18),
            FutureBuilder<List<LocalCategory>>(future: _categoriesFuture, builder: (context, snapshot) => _buildInfoCard(snapshot.data ?? const <LocalCategory>[])),
            const SizedBox(height: 18),
            _buildDocumentsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildFamilySharingCard() {
    final isShared = _sharedAsset != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isShared ? AppColors.primaryPurple.withAlpha(50) : const Color(0xFFEFEBF6),
          width: isShared ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isShared ? AppColors.primaryPurple.withAlpha(10) : Colors.black.withAlpha(3),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isShared ? AppColors.primaryPurple.withAlpha(20) : AppColors.lightLavender,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isShared ? Icons.diversity_3_rounded : Icons.share_rounded,
                  color: AppColors.primaryPurple,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isShared ? 'Shared with Family' : 'Family Sharing',
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    Text(
                      isShared
                          ? (_userFamily != null ? 'Active in "${_userFamily!.name}"' : 'Active in your family circle')
                          : 'Share this asset securely with your family members',
                      style: GoogleFonts.outfit(fontSize: 12, color: isShared ? AppColors.primaryPurple : AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (isShared) ...[
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _permissionBadge('Details', _sharedAsset!.permissions.viewDetails),
                _permissionBadge('Location', _sharedAsset!.permissions.viewLocation),
                _permissionBadge('Documents', _sharedAsset!.permissions.viewDocuments),
                _permissionBadge('Maintenance', _sharedAsset!.permissions.viewMaintenance),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _handleShareAsset,
                    icon: const Icon(Icons.security_rounded, size: 16),
                    label: const Text('Edit Permissions'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryPurple,
                      side: const BorderSide(color: AppColors.primaryPurple),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  tooltip: 'Stop sharing with family',
                  onPressed: _confirmUnshare,
                  icon: const Icon(Icons.link_off_rounded, color: AppColors.error),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.error.withAlpha(15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _handleShareAsset,
                icon: const Icon(Icons.share_rounded, size: 18),
                label: const Text('Share with Family'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _permissionBadge(String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF10B981).withAlpha(20) : Colors.grey.withAlpha(25),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            active ? Icons.check_circle_outline_rounded : Icons.lock_outline_rounded,
            size: 12,
            color: active ? const Color(0xFF10B981) : AppColors.textMuted,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: active ? const Color(0xFF047857) : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoto() {
    final path = _asset.imagePath;
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 180, maxHeight: 360),
        color: AppColors.primaryPurple.withValues(alpha: 0.06),
        child: path != null && path.isNotEmpty
            ? Image.file(File(path), fit: BoxFit.contain, errorBuilder: (_, _, _) => _emojiPlaceholder())
            : _emojiPlaceholder(),
      ),
    );
  }

  Widget _emojiPlaceholder() => Container(color: AppColors.primaryPurple.withValues(alpha: 0.08), alignment: Alignment.center, child: Text(_asset.emoji ?? '📦', style: const TextStyle(fontSize: 64)));

  Widget _buildInfoCard(List<LocalCategory> categories) {
    final category = _categoryName(categories);
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFEFEBF6))),
      child: Column(children: [
        _infoRow('Category', category), _divider(),
        _infoRow('Location', _asset.location?.isNotEmpty == true ? _asset.location! : 'Not specified'), _divider(),
        _infoRow('Description', _asset.description?.isNotEmpty == true ? _asset.description! : 'No description'), _divider(),
        _infoRow('QR Code', _asset.qrEnabled ? 'Enabled' : 'Disabled'),
        if (_asset.customFields.isNotEmpty) ...[
          _divider(),
          ..._asset.customFields.entries.map((entry) => Padding(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text(entry.key, maxLines: 3, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontWeight: FontWeight.w600))),
            const SizedBox(width: 12),
            Expanded(child: Text(entry.value, textAlign: TextAlign.right, style: GoogleFonts.outfit(color: AppColors.textSecondary))),
          ]))),
        ],
      ]),
    );
  }

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 96, child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
      const SizedBox(width: 10),
      Expanded(child: Text(value, style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
    ]),
  );

  Widget _divider() => const Divider(height: 1, indent: 18, endIndent: 18);

  Widget _buildDocumentsCard() {
    return FutureBuilder<List<LocalAssetDocument>>(
      future: _documentsFuture,
      builder: (context, snapshot) {
        final documents = snapshot.data ?? const <LocalAssetDocument>[];
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFEFEBF6))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Documents', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
            else if (documents.isEmpty)
              Text('No documents attached.', style: GoogleFonts.outfit(color: AppColors.textSecondary))
            else
              ...documents.map(_documentTile),
          ]),
        );
      },
    );
  }

  Widget _documentTile(LocalAssetDocument document) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        if (document.filePath.isNotEmpty) {
          final result = await OpenFilex.open(document.filePath);
          if (result.type != ResultType.done && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not open file: ${result.message}')),
            );
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(color: AppColors.scaffoldBg, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          const Icon(Icons.description_outlined, color: AppColors.primaryPurple), const SizedBox(width: 10),
          Expanded(child: Text(document.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontWeight: FontWeight.w600))),
          if (document.fileType != null) Padding(padding: const EdgeInsets.only(left: 8), child: Text(document.fileType!.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontSize: 10, color: AppColors.textMuted))),
        ]),
      ),
    ),
  );
}

