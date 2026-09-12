import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/utils/error_formatter.dart';
import '../../auth/models/user_model.dart';
import '../models/family_model.dart';
import '../models/family_member_model.dart';
import '../models/shared_asset_model.dart';
import '../widgets/member_avatar_stack.dart';
import 'family_members_screen.dart';
import 'share_asset_screen.dart';
import 'family_settings_screen.dart';
import 'family_member_assets_screen.dart';
import 'shared_asset_details_screen.dart';

class FamilyDashboardScreen extends StatefulWidget {
  final FamilyModel family;
  final UserModel currentUser;
  final VoidCallback onFamilyUpdated;

  const FamilyDashboardScreen({
    super.key,
    required this.family,
    required this.currentUser,
    required this.onFamilyUpdated,
  });

  @override
  State<FamilyDashboardScreen> createState() => _FamilyDashboardScreenState();
}

class _FamilyDashboardScreenState extends State<FamilyDashboardScreen> {
  final _familyRepository = serviceLocator.familyRepository;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openSettings() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => FamilySettingsScreen(
          family: widget.family,
          currentUser: widget.currentUser,
        ),
      ),
    );
    if (result == true && mounted) widget.onFamilyUpdated();
  }

  void _openMembers() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FamilyMembersScreen(
          family: widget.family,
          currentUser: widget.currentUser,
        ),
      ),
    );
  }

  Future<void> _openShareAsset() async {
    final shared = await ShareAssetScreen.navigateTo(
      context,
      family: widget.family,
      currentUser: widget.currentUser,
    );
    if (shared == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Asset shared with your family!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _openSharedAsset(SharedAssetModel asset) {
    SharedAssetDetailsScreen.navigateTo(context, asset);
  }

  Future<void> _openSearch() async {
    _searchController.text = _searchQuery;
    _searchController.selection = TextSelection.collapsed(
      offset: _searchController.text.length,
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            'Search shared assets',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
          ),
          content: TextField(
            controller: _searchController,
            autofocus: true,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Asset name',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                onPressed: _searchController.clear,
                icon: const Icon(Icons.close_rounded),
              ),
            ),
            onChanged: (value) {
              if (mounted) setState(() => _searchQuery = value.trim().toLowerCase());
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() => _searchQuery = '');
                _searchController.clear();
                Navigator.pop(dialogContext);
              },
              child: const Text('Clear'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
              ),
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(20, top + 14, 16, 20),
      decoration: const BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(35),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withAlpha(90), width: 1.2),
            ),
            child: const Icon(
              Icons.diversity_3_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.family.name,
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                StreamBuilder<List<FamilyMemberModel>>(
                  stream: _familyRepository.streamFamilyMembers(widget.family.id),
                  builder: (context, snapshot) {
                    final count = snapshot.data?.length ?? widget.family.memberCount;
                    return Text(
                      '$count ${count == 1 ? 'member' : 'members'} • Code: ${widget.family.inviteCode}',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppColors.textWhite70,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Search',
            onPressed: _openSearch,
            icon: const Icon(Icons.search_rounded, color: Colors.white, size: 24),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_outlined, color: Colors.white, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCard({
    required String ownerId,
    required String ownerName,
    required bool isCurrentUser,
    required List<SharedAssetModel> assets,
  }) {
    final visibleAssets = assets
        .where((asset) => asset.ownerId == ownerId)
        .where((asset) => _searchQuery.isEmpty || asset.name.toLowerCase().contains(_searchQuery))
        .toList();

    if (visibleAssets.isEmpty) return const SizedBox.shrink();

    final cleanName = ownerName.trim().isEmpty ? 'Member' : ownerName.trim();
    final displayName = isCurrentUser ? 'My Assets' : "$cleanName's Assets";
    final initial = cleanName[0].toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.lightLavenderBorder),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FamilyMemberAssetsScreen(
                  familyId: widget.family.id,
                  ownerId: ownerId,
                  ownerName: cleanName,
                  isCurrentUser: isCurrentUser,
                  currentUser: widget.currentUser,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.lightLavender,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primaryPurple.withAlpha(150),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: GoogleFonts.outfit(
                        color: AppColors.primaryPurple,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${visibleAssets.length} ${visibleAssets.length == 1 ? 'asset' : 'assets'}',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 17,
                  color: AppColors.primaryPurple,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoAssetsState({required bool search}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.lightLavenderBorder),
      ),
      child: Column(
        children: [
          const Icon(Icons.inventory_2_outlined, size: 40, color: AppColors.primaryPurple),
          const SizedBox(height: 12),
          Text(
            search ? 'No matching assets' : 'No shared assets yet',
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            search ? 'Try a different asset name.' : 'Use Share Asset to share an asset with your family.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildStreamError(Object error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.lightLavenderBorder),
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 40, color: AppColors.error),
          const SizedBox(height: 10),
          Text(
            'Could not load shared assets',
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            ErrorFormatter.format(error),
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(context)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: StreamBuilder<List<FamilyMemberModel>>(
                stream: _familyRepository.streamFamilyMembers(widget.family.id),
                builder: (context, snapshot) {
                  final members = snapshot.data ?? [];
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceWhite,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.lightLavenderBorder),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Family Members', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Text('${members.length} people connected', style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        MemberAvatarStack(members: members, onTap: _openMembers),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.primaryPurple),
                          onPressed: _openMembers,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Shared Assets', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  ),
                  ElevatedButton.icon(
                    onPressed: _openShareAsset,
                    icon: const Icon(Icons.share_rounded, size: 16),
                    label: const Text('Share Asset'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryPurple,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
          StreamBuilder<List<SharedAssetModel>>(
            stream: _familyRepository.streamSharedAssets(widget.family.id),
            builder: (context, assetSnapshot) {
              if (assetSnapshot.hasError) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    child: _buildStreamError(assetSnapshot.error!),
                  ),
                );
              }

              if (assetSnapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator(color: AppColors.primaryPurple)),
                );
              }

              final assets = assetSnapshot.data ?? [];
              final groupedOwners = <String, String>{};
              for (final asset in assets) {
                if (asset.ownerId.isNotEmpty) {
                  groupedOwners[asset.ownerId] = asset.ownerName.trim().isEmpty ? 'Member' : asset.ownerName.trim();
                }
              }

              return FutureBuilder<List<FamilyMemberModel>>(
                future: _familyRepository.getFamilyMembers(widget.family.id),
                builder: (context, memberSnapshot) {
                  final members = memberSnapshot.data ?? [];
                  for (final member in members) {
                    if (groupedOwners.containsKey(member.userId)) {
                      groupedOwners[member.userId] = member.familyDisplayName;
                    }
                  }

                  final ownerIds = groupedOwners.keys.where((ownerId) {
                    if (_searchQuery.isEmpty) return true;
                    return assets.any((asset) => asset.ownerId == ownerId && asset.name.toLowerCase().contains(_searchQuery));
                  }).toList();

                  if (ownerIds.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                        child: _buildNoAssetsState(search: _searchQuery.isNotEmpty),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final ownerId = ownerIds[index];
                          return _buildMemberCard(
                            ownerId: ownerId,
                            ownerName: groupedOwners[ownerId] ?? 'Member',
                            isCurrentUser: ownerId == widget.currentUser.id,
                            assets: assets,
                          );
                        },
                        childCount: ownerIds.length,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
