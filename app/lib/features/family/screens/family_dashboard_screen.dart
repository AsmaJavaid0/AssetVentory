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
import 'family_share_pin_screen.dart';
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
  bool _shareUnlocked = false;
  bool _checkingPin = true;

  @override
  void initState() {
    super.initState();
    _refreshPinAccess();
  }

  @override
  void didUpdateWidget(covariant FamilyDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.family.pinEnabled != widget.family.pinEnabled || oldWidget.family.id != widget.family.id) _refreshPinAccess();
  }

  Future<void> _refreshPinAccess() async {
    setState(() => _checkingPin = true);
    try {
      final unlocked = await _familyRepository.isFamilyShareUnlocked(widget.family.id);
      if (mounted) setState(() => _shareUnlocked = unlocked);
    } catch (_) {
      if (mounted) setState(() => _shareUnlocked = false);
    } finally {
      if (mounted) setState(() => _checkingPin = false);
    }
  }

  Future<void> _unlockSharedAssets() async {
    final unlocked = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => FamilySharePinScreen(family: widget.family, currentUser: widget.currentUser, unlockOnly: true)));
    if (unlocked == true && mounted) setState(() => _shareUnlocked = true);
  }

  Future<void> _openSettings() async {
    final result = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => FamilySettingsScreen(family: widget.family, currentUser: widget.currentUser)));
    if (result == true) {
      widget.onFamilyUpdated();
      await _refreshPinAccess();
    }
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

  Future<void> _confirmUnshare(SharedAssetModel asset) async {
    final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('Stop Sharing Asset?'), content: Text('Stop sharing "${asset.name}" with the family?'), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Stop Sharing', style: TextStyle(color: AppColors.error)))]));
    if (confirm != true) return;
    try {
      await _familyRepository.unshareAsset(asset.id);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Asset is no longer shared.'), backgroundColor: AppColors.success));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ErrorFormatter.format(e)), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 180, pinned: true, backgroundColor: AppColors.heroDarkBg, elevation: 0,
          leading: const SizedBox.shrink(), leadingWidth: 0,
          actions: [IconButton(icon: const Icon(Icons.settings_outlined, color: Colors.white), tooltip: 'Family Settings', onPressed: _openSettings)],
          flexibleSpace: FlexibleSpaceBar(background: Container(decoration: const BoxDecoration(gradient: AppColors.heroGradient), padding: const EdgeInsets.fromLTRB(20, 50, 20, 20), child: Column(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 52, height: 52, decoration: const BoxDecoration(gradient: AppColors.logoGradient, shape: BoxShape.circle), child: const Icon(Icons.diversity_3_rounded, color: Colors.white, size: 28)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.family.name, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                StreamBuilder<List<FamilyMemberModel>>(stream: _familyRepository.streamFamilyMembers(widget.family.id), builder: (context, snapshot) { final count = snapshot.data?.length ?? widget.family.memberCount; return Text('$count ${count == 1 ? 'member' : 'members'} • Code: ${widget.family.inviteCode}', style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textWhite70)); }),
              ])),
            ]),
          ]))),
        ),
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          StreamBuilder<List<FamilyMemberModel>>(stream: _familyRepository.streamFamilyMembers(widget.family.id), builder: (context, snapshot) { final members = snapshot.data ?? []; return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.surfaceWhite, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.lightLavenderBorder)), child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Family Members', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700)), const SizedBox(height: 2), Text('${members.length} people connected', style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary))])), MemberAvatarStack(members: members, onTap: _openMembers), const SizedBox(width: 8), IconButton(icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.primaryPurple), onPressed: _openMembers)])); }),
          const SizedBox(height: 28),
          Row(children: [Expanded(child: Text('Shared Assets', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700))), if (_shareUnlocked || !widget.family.pinEnabled) ElevatedButton.icon(onPressed: _openShareAsset, icon: const Icon(Icons.share_rounded, size: 18), label: const Text('Share Asset'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))]),
          const SizedBox(height: 16),
          if (_checkingPin) const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: AppColors.primaryPurple)))
          else if (widget.family.pinEnabled && !_shareUnlocked) _LockedSharedAssetsCard(onUnlock: _unlockSharedAssets)
          else StreamBuilder<List<SharedAssetModel>>(stream: _familyRepository.streamSharedAssets(widget.family.id), builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
            final assets = snapshot.data ?? [];
            if (assets.isEmpty) return Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20), decoration: BoxDecoration(color: AppColors.surfaceWhite, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.lightLavenderBorder)), child: Column(children: [const Icon(Icons.inventory_2_outlined, size: 40, color: AppColors.primaryPurple), const SizedBox(height: 12), Text('No shared assets yet', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700)), const SizedBox(height: 6), Text('Use Share Asset to share an asset with your family.', textAlign: TextAlign.center, style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary))]));
            return ListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: assets.length, itemBuilder: (context, index) { final asset = assets[index]; return SharedAssetCard(asset: asset, isOwner: asset.ownerId == widget.currentUser.id, onTap: () => SharedAssetDetailsScreen.navigateTo(context, asset), onManagePermissions: () => _managePermissions(asset), onUnshare: () => _confirmUnshare(asset)); });
          }),
          const SizedBox(height: 32),
        ]))),
      ]),
    );
  }
}

class _LockedSharedAssetsCard extends StatelessWidget {
  final VoidCallback onUnlock;
  const _LockedSharedAssetsCard({required this.onUnlock});
  @override
  Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.all(28), decoration: BoxDecoration(color: AppColors.surfaceWhite, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.lightLavenderBorder)), child: Column(children: [
    Container(width: 64, height: 64, decoration: BoxDecoration(color: AppColors.primaryPurple.withAlpha(18), shape: BoxShape.circle), child: const Icon(Icons.lock_rounded, color: AppColors.primaryPurple, size: 30)),
    const SizedBox(height: 14), Text('Shared Assets Locked', style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w700)),
    const SizedBox(height: 6), Text('Enter the Family Share PIN to view or manage shared assets.', textAlign: TextAlign.center, style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
    const SizedBox(height: 18), FilledButton.icon(onPressed: onUnlock, icon: const Icon(Icons.lock_open_rounded, size: 18), label: const Text('Enter PIN'), style: FilledButton.styleFrom(backgroundColor: AppColors.primaryPurple)),
  ]));
}
