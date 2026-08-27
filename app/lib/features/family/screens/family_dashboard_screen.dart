import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/utils/error_formatter.dart';
import '../../auth/models/user_model.dart';
import '../models/family_model.dart';
import '../models/family_member_model.dart';
import '../models/shared_asset_model.dart';
import '../widgets/shared_asset_card.dart';
import '../widgets/member_avatar_stack.dart';
import 'family_members_screen.dart';
import 'share_asset_screen.dart';
import 'share_asset_permissions_screen.dart';
import 'family_settings_screen.dart';

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

  void _openSettings() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => FamilySettingsScreen(
          family: widget.family,
          currentUser: widget.currentUser,
        ),
      ),
    );
    if (result == true) {
      widget.onFamilyUpdated();
    }
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

  void _openShareAsset() async {
    final shared = await ShareAssetScreen.navigateTo(
      context,
      family: widget.family,
      currentUser: widget.currentUser,
    );
    if (shared == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Asset shared with your family!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _managePermissions(SharedAssetModel asset) async {
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

  void _confirmUnshare(SharedAssetModel asset) async {
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
            child: const Text('Stop Sharing', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm == true) {
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: CustomScrollView(
        slivers: [
          // Dynamic Header App Bar
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: AppColors.heroDarkBg,
            elevation: 0,
            leading: const SizedBox.shrink(),
            leadingWidth: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined, color: Colors.white),
                tooltip: 'Family Settings',
                onPressed: _openSettings,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.heroGradient,
                ),
                padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: AppColors.logoGradient,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accentCyan.withAlpha(50),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(Icons.diversity_3_rounded, color: Colors.white, size: 28),
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
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              StreamBuilder<List<FamilyMemberModel>>(
                                stream: _familyRepository.streamFamilyMembers(widget.family.id),
                                builder: (context, snapshot) {
                                  final count = snapshot.data?.length ?? widget.family.memberCount;
                                  return Text(
                                    '$count ${count == 1 ? 'member' : 'members'} • Code: ${widget.family.inviteCode}',
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      color: AppColors.textWhite70,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Dashboard Body
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Members Section Card
                  StreamBuilder<List<FamilyMemberModel>>(
                    stream: _familyRepository.streamFamilyMembers(widget.family.id),
                    builder: (context, snapshot) {
                      final members = snapshot.data ?? [];
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceWhite,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.lightLavenderBorder),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(4),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Family Members',
                                    style: GoogleFonts.outfit(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${members.length} people connected',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            MemberAvatarStack(
                              members: members,
                              onTap: _openMembers,
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.primaryPurple),
                              onPressed: _openMembers,
                              tooltip: 'View all members',
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 28),

                  // Shared Assets Header
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Shared Assets',
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'Assets your family has chosen to share',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: _openShareAsset,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text('Share', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primaryPurple,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          backgroundColor: AppColors.primaryPurple.withAlpha(15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Shared Assets Stream
                  StreamBuilder<List<SharedAssetModel>>(
                    stream: _familyRepository.streamSharedAssets(widget.family.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: CircularProgressIndicator(color: AppColors.primaryPurple),
                          ),
                        );
                      }

                      final sharedAssets = snapshot.data ?? [];

                      if (sharedAssets.isEmpty) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceWhite,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.lightLavenderBorder),
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.lightLavender,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.inventory_2_outlined,
                                  color: AppColors.primaryPurple,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No shared assets yet',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Share an asset with your family to see it here.\nPersonal assets remain private by default.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: _openShareAsset,
                                icon: const Icon(Icons.share_rounded, size: 18),
                                label: const Text('Share an Asset'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryPurple,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 0,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: sharedAssets.length,
                        itemBuilder: (context, index) {
                          final asset = sharedAssets[index];
                          final isOwner = asset.ownerId == widget.currentUser.id;
                          return SharedAssetCard(
                            asset: asset,
                            isOwner: isOwner,
                            onManagePermissions: () => _managePermissions(asset),
                            onUnshare: () => _confirmUnshare(asset),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
