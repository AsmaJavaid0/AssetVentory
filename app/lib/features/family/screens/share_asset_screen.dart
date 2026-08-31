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
  const ShareAssetScreen({super.key, required this.family, required this.currentUser});

  static Future<bool?> navigateTo(BuildContext context, {required FamilyModel family, required UserModel currentUser}) => Navigator.push<bool>(
    context, MaterialPageRoute(builder: (_) => ShareAssetScreen(family: family, currentUser: currentUser)),
  );

  @override
  State<ShareAssetScreen> createState() => _ShareAssetScreenState();
}

class _ShareAssetScreenState extends State<ShareAssetScreen> {
  final _assetRepository = serviceLocator.assetRepository;
  final _categoryRepository = serviceLocator.categoryRepository;
  final _familyRepository = serviceLocator.familyRepository;
  List<LocalAsset> _assets = [];
  Map<String, String> _categories = {};
  Set<String> _sharedIds = {};
  LocalAsset? _selected;
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      // Personal assets are local-only. Loading them must never depend on
      // Firestore, network connectivity, or shared-assets permissions.
      final assets = await _assetRepository.getAssets('local_user');
      final categories = await _categoryRepository.getCategories('local_user');

      // Shared-state lookup is optional. A Firestore permission/network issue
      // must not prevent the user from selecting a local asset to share.
      Set<String> sharedIds = {};
      try {
        final shared = await _familyRepository
            .streamSharedAssets(widget.family.id)
            .first
            .timeout(const Duration(seconds: 5));
        sharedIds = shared.map((s) => s.assetId).toSet();
      } catch (_) {
        sharedIds = {};
      }

      if (!mounted) return;
      setState(() {
        _assets = assets;
        _categories = {for (final c in categories) c.id: c.name};
        _sharedIds = sharedIds;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _continue() async {
    final asset = _selected;
    if (asset == null) return;
    final result = await ShareAssetPermissionsScreen.navigateTo(
      context,
      family: widget.family,
      currentUser: widget.currentUser,
      asset: asset,
      categoryName: asset.categoryId == null ? null : _categories[asset.categoryId],
    );
    if (result == true && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.scaffoldBg,
    appBar: AppBar(
      title: Text('Select Asset to Share', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      backgroundColor: Colors.white,
      elevation: 0,
    ),
    bottomNavigationBar: Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      color: Colors.white,
      child: SizedBox(
        height: 52,
        child: ElevatedButton(
          onPressed: _selected == null ? null : _continue,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryPurple,
            disabledBackgroundColor: AppColors.primaryPurple.withAlpha(70),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: const Text('Continue to Permissions'),
        ),
      ),
    ),
    body: _loading
      ? const Center(child: CircularProgressIndicator(color: AppColors.primaryPurple))
      : _error != null
        ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text('Could not load assets', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ])))
        : _assets.isEmpty
          ? const Center(child: Text('No Personal Assets Found'))
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _assets.length,
              itemBuilder: (_, index) {
                final asset = _assets[index];
                final already = _sharedIds.contains(asset.id);
                final selected = _selected?.id == asset.id;
                final category = asset.categoryId == null ? null : _categories[asset.categoryId];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceWhite,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: selected ? AppColors.primaryPurple : AppColors.lightLavenderBorder, width: selected ? 2 : 1),
                  ),
                  child: ListTile(
                    enabled: !already,
                    onTap: already ? null : () => setState(() => _selected = asset),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(color: AppColors.lightLavender, borderRadius: BorderRadius.circular(12)),
                      child: asset.imagePath != null && asset.imagePath!.isNotEmpty
                        ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(asset.imagePath!), fit: BoxFit.cover, errorBuilder: (_, _, _) => Center(child: Text(asset.emoji ?? '📦', style: const TextStyle(fontSize: 22)))))
                        : Center(child: Text(asset.emoji ?? '📦', style: const TextStyle(fontSize: 22))),
                    ),
                    title: Text(asset.name, style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                    subtitle: Text(already ? 'Already shared with family' : category ?? 'Uncategorized'),
                    trailing: already
                      ? const Icon(Icons.check_circle_rounded, color: AppColors.primaryPurple)
                      : Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: selected ? AppColors.primaryPurple : AppColors.inputHint),
                  ),
                );
              },
            ),
  );
}
