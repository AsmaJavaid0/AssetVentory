import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/utils/error_formatter.dart';
import '../../auth/models/user_model.dart';
import '../../auth/services/auth_service.dart';
import '../models/family_model.dart';
import '../models/family_member_model.dart';
import 'family_members_screen.dart';
import 'invite_member_screen.dart';

class FamilySettingsScreen extends StatefulWidget {
  final FamilyModel family;
  final UserModel currentUser;

  const FamilySettingsScreen({
    super.key,
    required this.family,
    required this.currentUser,
  });

  @override
  State<FamilySettingsScreen> createState() => _FamilySettingsScreenState();
}

class _FamilySettingsScreenState extends State<FamilySettingsScreen> {
  final _familyRepository = serviceLocator.familyRepository;
  final _authService = AuthService();
  bool _isProcessing = false;

  bool get _isOwner => widget.family.ownerId == widget.currentUser.id;

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: widget.family.inviteCode));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Family invite code copied to clipboard!'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Log Out from Family Sharing?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'You will be signed out from Family Sharing on this device. '
          'Your local personal assets and vault data will remain completely safe.',
          style: GoogleFonts.outfit(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      await _authService.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Logged out successfully.'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true); // Pop settings and refresh landing tab
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ErrorFormatter.format(e)),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleLeaveFamily() async {
    List<FamilyMemberModel> members = [];
    try {
      members = await _familyRepository.getFamilyMembers(widget.family.id);
    } catch (_) {}

    if (!mounted) return;

    if (_isOwner && members.length > 1) {
      _showOwnerLeaveDialog(members);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          _isOwner ? 'Delete Family Group?' : 'Leave Family Group?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
        content: Text(
          _isOwner
              ? 'As the only member, leaving will permanently delete "${widget.family.name}". Your local personal assets will remain safe on your device.'
              : 'Are you sure you want to leave "${widget.family.name}"? Any assets you shared will be unshared. Your local personal assets will remain safe on your device.',
          style: GoogleFonts.outfit(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              _isOwner ? 'Delete Family' : 'Leave Family',
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      if (_isOwner && members.length <= 1) {
        await _familyRepository.deleteFamily(widget.family.id);
      } else {
        await _familyRepository.leaveFamily(
          familyId: widget.family.id,
          userId: widget.currentUser.id,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isOwner ? 'Family deleted.' : 'You left the family.'),
          backgroundColor: AppColors.success,
        ),
      );
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
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showOwnerLeaveDialog(List<FamilyMemberModel> members) {
    final otherMembers = members.where((m) => m.userId != widget.currentUser.id).toList();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Transfer Ownership Required',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Before leaving "${widget.family.name}", please select a new owner for the family group:',
              style: GoogleFonts.outfit(fontSize: 13),
            ),
            const SizedBox(height: 12),
            ...otherMembers.map((m) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primaryPurple,
                    child: Text(
                      m.name.isNotEmpty ? m.name[0].toUpperCase() : 'U',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                  title: Text(m.name.isNotEmpty ? m.name : m.email, style: GoogleFonts.outfit(fontSize: 14)),
                  subtitle: Text(m.role, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () async {
                    Navigator.pop(dialogContext);
                    await _transferAndLeave(m.userId);
                  },
                )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _transferAndLeave(String newOwnerId) async {
    setState(() => _isProcessing = true);
    try {
      await _familyRepository.transferOwnership(
        familyId: widget.family.id,
        currentOwnerId: widget.currentUser.id,
        newOwnerId: newOwnerId,
      );
      await _familyRepository.leaveFamily(
        familyId: widget.family.id,
        userId: widget.currentUser.id,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ownership transferred and left family.'),
          backgroundColor: AppColors.success,
        ),
      );
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
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final createdDateStr = '${widget.family.createdAt.day}/${widget.family.createdAt.month}/${widget.family.createdAt.year}';

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: Text(
          'Family Settings',
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
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryPurple))
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              children: [
                // Account Profile Card
                Text(
                  'Your Account',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceWhite,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.lightLavenderBorder),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: AppColors.primaryPurple,
                        backgroundImage: widget.currentUser.photoUrl.isNotEmpty
                            ? NetworkImage(widget.currentUser.photoUrl)
                            : null,
                        child: widget.currentUser.photoUrl.isEmpty
                            ? Text(
                                widget.currentUser.name.isNotEmpty
                                    ? widget.currentUser.name[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              )
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.currentUser.name.isNotEmpty
                                  ? widget.currentUser.name
                                  : 'Family Member',
                              style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              widget.currentUser.email,
                              style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _handleLogout,
                        icon: const Icon(Icons.logout_rounded, size: 16, color: AppColors.error),
                        label: Text('Log Out', style: GoogleFonts.outfit(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.error, width: 1.2),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Family Info Section
                Text(
                  'Family Information',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceWhite,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.lightLavenderBorder),
                  ),
                  child: Column(
                    children: [
                      _SettingsRow(
                        label: 'Family Name',
                        value: widget.family.name,
                        icon: Icons.home_rounded,
                      ),
                      const Divider(height: 20, color: AppColors.lightLavenderBorder),
                      _SettingsRow(
                        label: 'Invitation Code',
                        value: widget.family.inviteCode,
                        icon: Icons.vpn_key_rounded,
                        trailing: IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.primaryPurple),
                          onPressed: _copyCode,
                        ),
                      ),
                      const Divider(height: 20, color: AppColors.lightLavenderBorder),
                      _SettingsRow(
                        label: 'Created On',
                        value: createdDateStr,
                        icon: Icons.calendar_today_rounded,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Management Actions
                Text(
                  'Member Management',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceWhite,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.lightLavenderBorder),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.people_outline_rounded, color: AppColors.primaryPurple),
                        title: Text('View Family Members', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14)),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FamilyMembersScreen(
                              family: widget.family,
                              currentUser: widget.currentUser,
                            ),
                          ),
                        ),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.lightLavenderBorder),
                      ListTile(
                        leading: const Icon(Icons.person_add_outlined, color: AppColors.primaryPurple),
                        title: Text('Invite New Member', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14)),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                        onTap: () => InviteMemberScreen.navigateTo(
                          context,
                          family: widget.family,
                          currentUser: widget.currentUser,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Danger Zone
                Text(
                  'Danger Zone',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceWhite,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.error.withAlpha(50)),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.exit_to_app_rounded, color: AppColors.error),
                    title: Text(
                      _isOwner ? 'Leave or Delete Family' : 'Leave Family Group',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.error,
                      ),
                    ),
                    subtitle: Text(
                      'Your personal assets will remain on your device.',
                      style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    onTap: _handleLeaveFamily,
                  ),
                ),
              ],
            ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Widget? trailing;

  const _SettingsRow({
    required this.label,
    required this.value,
    required this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.lightLavender,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primaryPurple, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary),
              ),
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}
