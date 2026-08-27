import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/di/service_locator.dart';
import '../../assets/models/local_asset.dart';
import '../../auth/models/user_model.dart';
import '../models/family_model.dart';
import 'share_asset_permissions_screen.dart';

class ShareAssetScreen extends StatefulWidget {
  final FamilyModel family;
  final UserModel currentUser;

  const ShareAssetScreen({
    super.key,
    required this.family,
    required this.currentUser,
  });

  static Future<bool?> navigateTo(
    BuildContext context, {
    required FamilyModel family,
    required UserModel currentUser,
  }) {
    return Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ShareAssetScreen(
          family: family,
          currentUser: currentUser,
        ),
      ),
    );
  }

  @override
  State<ShareAssetScreen> createState() => _ShareAssetScreenState();
}

class _ShareAssetScreenState extends State<ShareAssetScreen> {
  final _assetRepository = serviceLocator.assetRepository;
  final _categoryRepository = serviceLocator.categoryRepository;
  final _familyRepository = serviceLocator.familyRepository;

  List<LocalAsset> _personalAssets = [];
  Map<String, String> _categoryNames = {};
  Set<String> _alreadySharedAssetIds = {};
  LocalAsset? _selectedAsset;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    try {
      // 1. Fetch personal assets
      final assets = await _assetRepository.getAssets('local_user');
      final categories = await _categoryRepository.getCategories('local_user');
      final catMap = {for (var c in categories) c.id: c.name};

      // 2. Fetch already shared assets in this family
      final sharedSnapshot = await _familyRepository.streamSharedAssets(widget.family.id).first;
      final sharedIds = sharedSnapshot.map((s) => s.assetId).toSet();

      if (!mounted) return;
      setState(() {
        _personalAssets = assets;
        _categoryNames = catMap;
        _alreadySharedAssetIds = sharedIds;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _proceedToPermissions() async {
    if (_selectedAsset == null) return;
    final catName = _selectedAsset!.categoryId != null
        ? _categoryNames[_selectedAsset!.categoryId]
        : null;

    final shared = await ShareAssetPermissionsScreen.navigateTo(
      context,
      family: widget.family,
      currentUser: widget.currentUser,
      asset: _selectedAsset!,
      categoryName: catName,
    );

    if (shared == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: Text(
          'Select Asset to Share',
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
            onPressed: _selectedAsset != null ? _proceedToPermissions : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: Text(
              'Continue to Permissions',
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryPurple))
          : _personalAssets.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.textMuted),
                        const SizedBox(height: 14),
                        Text(
                          'No Personal Assets Found',
                          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Add assets in your personal vault first before sharing with family.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  itemCount: _personalAssets.length,
                  itemBuilder: (context, index) {
                    final asset = _personalAssets[index];
                    final isAlreadyShared = _alreadySharedAssetIds.contains(asset.id);
                    final isSelected = _selectedAsset?.id == asset.id;
                    final catName = asset.categoryId != null ? _categoryNames[asset.categoryId] : null;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceWhite,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primaryPurple
                              : AppColors.lightLavenderBorder,
                          width: isSelected ? 2 : 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isSelected
                                ? AppColors.primaryPurple.withAlpha(15)
                                : Colors.black.withAlpha(4),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        enabled: !isAlreadyShared,
                        onTap: isAlreadyShared
                            ? null
                            : () => setState(() => _selectedAsset = asset),
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.lightLavender,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: asset.imagePath != null && asset.imagePath!.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(
                                    File(asset.imagePath!),
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Center(
                                      child: Text(asset.emoji ?? '📦', style: const TextStyle(fontSize: 22)),
                                    ),
                                  ),
                                )
                              : Center(
                                  child: Text(asset.emoji ?? '📦', style: const TextStyle(fontSize: 22)),
                                ),
                        ),
                        title: Text(
                          asset.name,
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isAlreadyShared ? AppColors.textMuted : AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          isAlreadyShared
                              ? 'Already shared with family'
                              : catName ?? 'Uncategorized',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: isAlreadyShared ? AppColors.primaryPurple : AppColors.textSecondary,
                            fontWeight: isAlreadyShared ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        trailing: isAlreadyShared
                            ? const Icon(Icons.check_circle_rounded, color: AppColors.primaryPurple, size: 22)
                            : Icon(
                                isSelected
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_off_rounded,
                                color: isSelected ? AppColors.primaryPurple : AppColors.inputHint,
                                size: 22,
                              ),
                      ),
                    );
                  },
                ),
    );
  }
}
