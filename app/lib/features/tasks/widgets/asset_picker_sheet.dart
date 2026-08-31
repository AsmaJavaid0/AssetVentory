import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/di/service_locator.dart';
import '../../assets/models/local_asset.dart';

class AssetPickerSheet extends StatefulWidget {
  final LocalAsset? selectedAsset;

  const AssetPickerSheet({
    super.key,
    this.selectedAsset,
  });

  static Future<LocalAsset?> show(
    BuildContext context, {
    LocalAsset? selectedAsset,
  }) {
    return showModalBottomSheet<LocalAsset?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AssetPickerSheet(selectedAsset: selectedAsset),
    );
  }

  @override
  State<AssetPickerSheet> createState() => _AssetPickerSheetState();
}

class _AssetPickerSheetState extends State<AssetPickerSheet> {
  final _assetRepository = serviceLocator.assetRepository;
  List<LocalAsset> _assets = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    try {
      final assets = await _assetRepository.getAssets('local_user');
      if (mounted) {
        setState(() {
          _assets = assets;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _assets = [];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredAssets = _assets.where((asset) {
      if (_searchQuery.isEmpty) return true;
      return asset.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (asset.location?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: AppColors.scaffoldBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textMuted.withAlpha(80),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Text(
                  'Select Asset',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search assets...',
                prefixIcon: const Icon(Icons.search_rounded),
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      // "No Asset" option
                      ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        tileColor: widget.selectedAsset == null
                            ? AppColors.primaryPurple.withAlpha(20)
                            : Colors.white,
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.lightLavender,
                          child: Icon(Icons.block_rounded, color: AppColors.textSecondary),
                        ),
                        title: Text(
                          'No Asset',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          'General task not tied to an asset',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        trailing: widget.selectedAsset == null
                            ? const Icon(Icons.check_circle_rounded, color: AppColors.primaryPurple)
                            : null,
                        onTap: () => Navigator.pop(context, null),
                      ),
                      const SizedBox(height: 8),
                      ...filteredAssets.map((asset) {
                        final isSelected = widget.selectedAsset?.id == asset.id;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            tileColor: isSelected
                                ? AppColors.primaryPurple.withAlpha(20)
                                : Colors.white,
                            leading: CircleAvatar(
                              backgroundColor: AppColors.lightLavender,
                              child: Text(
                                asset.emoji ?? '📦',
                                style: const TextStyle(fontSize: 20),
                              ),
                            ),
                            title: Text(
                              asset.name,
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            subtitle: asset.location != null && asset.location!.isNotEmpty
                                ? Text(
                                    '📍 ${asset.location}',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  )
                                : null,
                            trailing: isSelected
                                ? const Icon(Icons.check_circle_rounded, color: AppColors.primaryPurple)
                                : null,
                            onTap: () => Navigator.pop(context, asset),
                          ),
                        );
                      }),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
