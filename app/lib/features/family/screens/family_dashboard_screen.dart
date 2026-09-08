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
import 'share_asset_permissions_screen.dart';
import 'family_settings_screen.dart';
import 'family_member_assets_screen.dart';
import 'shared_asset_details_screen.dart';

class FamilyDashboardScreen extends StatefulWidget {
  final FamilyModel family;
  final UserModel currentUser;
  final VoidCallback onFamilyUpdated;

  const FamilyDashboardScreen({super.key, required this.family, required this.currentUser, required this.onFamilyUpdated});

  @override
  State<FamilyDashboardScreen> createState() => _FamilyDashboardScreenState();
}

class _FamilyDashboardScreenState extends State<FamilyDashboardScreen> {
  final _familyRepository = serviceLocator.familyRepository;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final query = _searchController.text.trim().toLowerCase();
      if (query != _searchQuery) setState(() => _searchQuery = query);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openSettings() async {
    final result = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => FamilySettingsScreen(family: widget.family, currentUser: widget.currentUser)));
    if (result == true) widget.onFamilyUpdated();
  }

  void _openMembers() => Navigator.push(context, MaterialPageRoute(builder: (_) => FamilyMembersScreen(family: widget.family, currentUser: widget.currentUser)));

  Future<void> _openShareAsset() async {
    final shared = await ShareAssetScreen.navigateTo(context, family: widget.family, currentUser: widget.currentUser);
    if (shared == true && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Asset shared with your family!'), backgroundColor: AppColors.success));
  }

  Future<void> _managePermissions(SharedAssetModel asset) async {
    final updated = await ShareAssetPermissionsScreen.navigateTo(context, sharedAsset: asset);
    if (updated == true && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sharing permissions updated.'), backgroundColor: AppColors.success));
  }

  void _openSharedAsset(SharedAssetModel asset) => SharedAssetDetailsScreen.navigateTo(context, asset);

  Future<void> _confirmUnshare(SharedAssetModel asset) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Stop Sharing Asset?', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to stop sharing "${asset.name}" with the family? Your local personal copy will not be affected.', style: GoogleFonts.outfit()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Stop Sharing', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _familyRepository.unshareAsset(asset.id);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Asset is no longer shared with the family.'), backgroundColor: AppColors.success));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ErrorFormatter.format(e)), backgroundColor: AppColors.error));
    }
  }

  Widget _buildHeader(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(20, top + 14, 16, 20),
      decoration: const BoxDecoration(gradient: AppColors.heroGradient, borderRadius: BorderRadius.vertical(bottom: Radius.circular(24))),
      child: Row(children: [
        Container(width: 48, height: 48, decoration: const BoxDecoration(gradient: AppColors.logoGradient, shape: BoxShape.circle), child: const Icon(Icons.diversity_3_rounded, color: Colors.white, size: 26)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.family.name, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          StreamBuilder<List<FamilyMemberModel>>(stream: _familyRepository.streamFamilyMembers(widget.family.id), builder: (context, snapshot) {
            final count = snapshot.data?.length ?? widget.family.memberCount;
            return Text('$count ${count == 1 ? 'member' : 'members'} • Code: ${widget.family.inviteCode}', style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textWhite70));
          }),
        ])),
        const SizedBox(width: 8),
        Material(color: Colors.white.withAlpha(24), shape: const CircleBorder(), child: InkWell(customBorder: const CircleBorder(), onTap: _openSettings, child: const SizedBox(width: 42, height: 42, child: Icon(Icons.settings_outlined, color: Colors.white, size: 22)))),
      ]),
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(color: AppColors.surfaceWhite, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.lightLavenderBorder)),
      child: TextField(
        controller: _searchController,
        style: GoogleFonts.outfit(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search shared assets...',
          hintStyle: GoogleFonts.outfit(fontSize: 14, color: AppColors.textMuted),
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primaryPurple, size: 21),
          suffixIcon: _searchQuery.isEmpty ? null : IconButton(onPressed: _searchController.clear, icon: const Icon(Icons.close_rounded, size: 19)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        ),
      ),
    );
  }

  Widget _buildMemberCard({required FamilyMemberModel member, required List<SharedAssetModel> assets}) {
    final memberAssets = assets.where((asset) => asset.ownerId == member.userId).toList();
    final visibleAssets = _searchQuery.isEmpty ? memberAssets : memberAssets.where((asset) => asset.name.toLowerCase().contains(_searchQuery)).toList();
    if (_searchQuery.isNotEmpty && visibleAssets.isEmpty) return const SizedBox.shrink();
    final displayName = member.userId == widget.currentUser.id ? 'My Assets' : "${member.name.isEmpty ? 'Member' : member.name}'s Assets";
    final initial = member.name.isNotEmpty ? member.name[0].toUpperCase() : '?';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: AppColors.surfaceWhite, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.lightLavenderBorder)),
      child: Material(color: Colors.transparent, borderRadius: BorderRadius.circular(18), child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FamilyMemberAssetsScreen(familyId: widget.family.id, ownerId: member.userId, ownerName: member.name, isCurrentUser: member.userId == widget.currentUser.id, currentUser: widget.currentUser))),
        child: Padding(padding: const EdgeInsets.all(15), child: Row(children: [
          Container(width: 50, height: 50, decoration: const BoxDecoration(gradient: AppColors.logoGradient, shape: BoxShape.circle), child: Center(child: Text(initial, style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)))),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(displayName, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Text('${visibleAssets.length} ${visibleAssets.length == 1 ? 'asset' : 'assets'}', style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
          ])),
          const Icon(Icons.arrow_forward_ios_rounded, size: 17, color: AppColors.primaryPurple),
        ])),
      )),
    );
  }

  Widget _buildNoAssetsState({required bool search}) {
    return Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34), decoration: BoxDecoration(color: AppColors.surfaceWhite, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.lightLavenderBorder)), child: Column(children: [
      const Icon(Icons.inventory_2_outlined, size: 40, color: AppColors.primaryPurple),
      const SizedBox(height: 12),
      Text(search ? 'No matching assets' : 'No shared assets yet', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text(search ? 'Try a different asset name.' : 'Use the Share Asset button above to share an asset with your family.', textAlign: TextAlign.center, style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary)),
    ]));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: _buildHeader(context)),
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 0), child: StreamBuilder<List<FamilyMemberModel>>(stream: _familyRepository.streamFamilyMembers(widget.family.id), builder: (context, snapshot) {
          final members = snapshot.data ?? [];
          return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.surfaceWhite, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.lightLavenderBorder)), child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Family Members', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700)), const SizedBox(height: 2), Text('${members.length} people connected', style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary))])),
            MemberAvatarStack(members: members, onTap: _openMembers), const SizedBox(width: 8), IconButton(icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.primaryPurple), onPressed: _openMembers),
          ]));
        }))),
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 28, 20, 0), child: Row(children: [Expanded(child: Text('Shared Assets', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary))), const SizedBox(width: 12), ElevatedButton.icon(onPressed: _openShareAsset, icon: const Icon(Icons.share_rounded, size: 16), label: const Text('Share Asset'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), textStyle: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600)))]))),
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 0), child: _buildSearchField())),
        StreamBuilder<List<FamilyMemberModel>>(stream: _familyRepository.streamFamilyMembers(widget.family.id), builder: (context, memberSnapshot) {
          return StreamBuilder<List<SharedAssetModel>>(stream: _familyRepository.streamSharedAssets(widget.family.id), builder: (context, assetSnapshot) {
            if (assetSnapshot.connectionState == ConnectionState.waiting || memberSnapshot.connectionState == ConnectionState.waiting) return const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator(color: AppColors.primaryPurple)));
            final members = memberSnapshot.data ?? [];
            final assets = assetSnapshot.data ?? [];
            final hasVisible = members.any((member) => assets.any((asset) => asset.ownerId == member.userId && (_searchQuery.isEmpty || asset.name.toLowerCase().contains(_searchQuery))));
            if (!hasVisible) return SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 32), child: _buildNoAssetsState(search: _searchQuery.isNotEmpty)));
            return SliverPadding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 32), sliver: SliverList(delegate: SliverChildBuilderDelegate((context, index) => _buildMemberCard(member: members[index], assets: assets), childCount: members.length)));
          });
        }),
      ]),
    );
  }
}
