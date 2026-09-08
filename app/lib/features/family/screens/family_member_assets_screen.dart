import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/utils/error_formatter.dart';
import '../../auth/models/user_model.dart';
import '../models/shared_asset_model.dart';
import '../models/sharing_permissions_model.dart';
import '../repositories/family_repository.dart';
import 'share_asset_permissions_screen.dart';
import 'shared_asset_details_screen.dart';
import '../widgets/shared_asset_card.dart';

class FamilyMemberAssetsScreen extends StatefulWidget {
  final String familyId;
  final String ownerId;
  final String ownerName;
  final bool isCurrentUser;
  final UserModel currentUser;

  const FamilyMemberAssetsScreen({
    super.key,
    required this.familyId,
    required this.ownerId,
    required this.ownerName,
    required this.isCurrentUser,
    required this.currentUser,
  });

  @override
  State<FamilyMemberAssetsScreen> createState() =>
      _FamilyMemberAssetsScreenState();
}

class _FamilyMemberAssetsScreenState extends State<FamilyMemberAssetsScreen> {
  final _familyRepository = serviceLocator.familyRepository;
  late final TextEditingController _searchController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(() {
      final query = _searchController.text.trim().toLowerCase();
      if (query != _searchQuery) {
        setState(() => _searchQuery = query);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String get _title => widget.isCurrentUser
      ? 'My Assets'
      : "${widget.ownerName.isEmpty ? 'Member' : widget.ownerName}'s Assets";

  Future<void> _managePermissions(SharedAssetModel asset) async {
    final updated = await ShareAssetPermissionsScreen.navigateTo(
      context,
      sharedAsset: asset,
    );
    if (updated == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sharing permissions updated.'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _confirmUnshare(SharedAssetModel asset) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Stop Sharing Asset?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Are you sure you want to stop sharing "${asset.name}" with the family? Your local personal copy will not be affected.',
          style: GoogleFonts.outfit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Stop Sharing',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _familyRepository.unshareAsset(asset.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Asset is no longer shared with the family.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorFormatter.format(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _openSharedAsset(SharedAssetModel asset) {
    SharedAssetDetailsScreen.navigateTo(context, asset);
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightLavenderBorder),
      ),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        style: GoogleFonts.outfit(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search ${widget.isCurrentUser ? 'my' : widget.ownerName} assets...',
          hintStyle: GoogleFonts.outfit(
            fontSize: 14,
            color: AppColors.textMuted,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.primaryPurple,
            size: 21,
          ),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: _searchController.clear,
                  icon: const Icon(Icons.close_rounded, size: 19),
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({required bool hasSearch}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.lightLavenderBorder),
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.lightLavender,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              size: 30,
              color: AppColors.primaryPurple,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            hasSearch ? 'No matching assets' : 'No shared assets',
            style: GoogleFonts.outfit(
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasSearch
                ? 'Try a different asset name.'
                : 'There are no assets shared by this family member yet.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.scaffoldBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _title,
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                          gradient: AppColors.logoGradient,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            widget.isCurrentUser
                                ? (widget.currentUser.name.isNotEmpty
                                    ? widget.currentUser.name[0].toUpperCase()
                                    : 'M')
                                : (widget.ownerName.isNotEmpty
                                    ? widget.ownerName[0].toUpperCase()
                                    : '?'),
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Shared assets from ${widget.isCurrentUser ? 'you' : widget.ownerName}',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSearchField(),
                ],
              ),
            ),
          ),
          StreamBuilder<List<SharedAssetModel>>(
            stream: _familyRepository.streamSharedAssets(widget.familyId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryPurple,
                    ),
                  ),
                );
              }

              final assets = snapshot.data
                      ?.where((asset) => asset.ownerId == widget.ownerId)
                      .where(
                        (asset) => _searchQuery.isEmpty ||
                            asset.name.toLowerCase().contains(_searchQuery),
                      )
                      .toList() ??
                  [];

              if (assets.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                    child: _buildEmptyState(hasSearch: _searchQuery.isNotEmpty),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final asset = assets[index];
                      return SharedAssetCard(
                        asset: asset,
                        isOwner: asset.ownerId == widget.currentUser.id,
                        onTap: () => _openSharedAsset(asset),
                        onManagePermissions: () => _managePermissions(asset),
                        onUnshare: () => _confirmUnshare(asset),
                      );
                    },
                    childCount: assets.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
