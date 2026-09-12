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
import 'family_share_pin_screen.dart';
import 'invite_member_screen.dart';

class FamilySettingsScreen extends StatefulWidget {
  final FamilyModel family;
  final UserModel currentUser;
  const FamilySettingsScreen({super.key, required this.family, required this.currentUser});

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
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Family invite code copied!'), backgroundColor: AppColors.success));
  }

  Future<void> _openPinSettings() async {
    final changed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => FamilySharePinScreen(family: widget.family, currentUser: widget.currentUser)));
    if (changed == true && mounted) Navigator.pop(context, true);
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Log Out from Family Sharing?', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        content: Text('You will be signed out from Family Sharing on this device. Your local personal assets will remain safe.', style: GoogleFonts.outfit(height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white), child: const Text('Log Out')),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _isProcessing = true);
    try {
      await _authService.signOut();
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _showError(e);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleLeaveFamily() async {
    List<FamilyMemberModel> members = [];
    try { members = await _familyRepository.getFamilyMembers(widget.family.id); } catch (_) {}
    if (!mounted) return;
    if (_isOwner && members.length > 1) { _showOwnerLeaveDialog(members); return; }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(_isOwner ? 'Delete Family Group?' : 'Leave Family Group?', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        content: Text(_isOwner ? 'As the only member, leaving will permanently delete "${widget.family.name}".' : 'Are you sure you want to leave "${widget.family.name}"? Any assets you shared will be unshared.', style: GoogleFonts.outfit(height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text(_isOwner ? 'Delete Family' : 'Leave Family', style: const TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _isProcessing = true);
    try {
      if (_isOwner && members.length <= 1) {
        await _familyRepository.deleteFamily(widget.family.id);
      } else {
        await _familyRepository.leaveFamily(familyId: widget.family.id, userId: widget.currentUser.id);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _showError(e);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showOwnerLeaveDialog(List<FamilyMemberModel> members) {
    final others = members.where((m) => m.userId != widget.currentUser.id).toList();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Transfer Ownership Required', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Select a new owner before leaving "${widget.family.name}":', style: GoogleFonts.outfit(fontSize: 13)),
          const SizedBox(height: 12),
          ...others.map((m) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(backgroundColor: AppColors.primaryPurple, child: Text(m.name.isNotEmpty ? m.name[0].toUpperCase() : 'U', style: const TextStyle(color: Colors.white))),
            title: Text(m.name.isNotEmpty ? m.name : m.email, style: GoogleFonts.outfit(fontSize: 14)),
            subtitle: Text(m.role, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
            onTap: () async { Navigator.pop(c); await _transferAndLeave(m.userId); },
          )),
        ],
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel'))],
      ),
    );
  }

  Future<void> _transferAndLeave(String newOwnerId) async {
    setState(() => _isProcessing = true);
    try {
      await _familyRepository.transferOwnership(familyId: widget.family.id, currentOwnerId: widget.currentUser.id, newOwnerId: newOwnerId);
      await _familyRepository.leaveFamily(familyId: widget.family.id, userId: widget.currentUser.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _showError(e);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ErrorFormatter.format(error)), backgroundColor: AppColors.error));
  }

  @override
  Widget build(BuildContext context) {
    final created = '${widget.family.createdAt.day}/${widget.family.createdAt.month}/${widget.family.createdAt.year}';
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: Text('Family Settings', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), onPressed: () => Navigator.pop(context)),
      ),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryPurple))
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              children: [
                _sectionTitle('Your Account'),
                _card(Column(children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(backgroundColor: AppColors.primaryPurple, backgroundImage: widget.currentUser.photoUrl.isNotEmpty ? NetworkImage(widget.currentUser.photoUrl) : null, child: widget.currentUser.photoUrl.isEmpty ? Text(widget.currentUser.name.isNotEmpty ? widget.currentUser.name[0].toUpperCase() : 'U', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)) : null),
                    title: Text(widget.currentUser.name.isNotEmpty ? widget.currentUser.name : 'Family Member', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                    subtitle: Text(widget.currentUser.email, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
                    trailing: OutlinedButton.icon(onPressed: _handleLogout, icon: const Icon(Icons.logout_rounded, size: 16, color: AppColors.error), label: Text('Log Out', style: GoogleFonts.outfit(fontSize: 12, color: AppColors.error))),
                  ),
                ])),
                const SizedBox(height: 24),
                _sectionTitle('Family Information'),
                _card(Column(children: [
                  _SettingsRow(label: 'Family Name', value: widget.family.name, icon: Icons.home_rounded),
                  const Divider(height: 20, color: AppColors.lightLavenderBorder),
                  _SettingsRow(label: 'Invitation Code', value: widget.family.inviteCode, icon: Icons.vpn_key_rounded, trailing: IconButton(icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.primaryPurple), onPressed: _copyCode)),
                  const Divider(height: 20, color: AppColors.lightLavenderBorder),
                  _SettingsRow(label: 'Created On', value: created, icon: Icons.calendar_today_rounded),
                ])),
                const SizedBox(height: 28),
                _sectionTitle('Shared Assets Security'),
                _card(Column(children: [
                  ListTile(
                    leading: Icon(widget.family.pinEnabled ? Icons.lock_rounded : Icons.lock_open_rounded, color: AppColors.primaryPurple),
                    title: Text('Family Share PIN', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(widget.family.pinEnabled ? (_isOwner ? 'Enabled • change or remove the PIN' : 'Enabled • PIN required to view shared assets') : 'Protect shared assets with a 4–6 digit PIN', style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    onTap: _openPinSettings,
                  ),
                ])),
                const SizedBox(height: 28),
                _sectionTitle('Member Management'),
                _card(Column(children: [
                  ListTile(leading: const Icon(Icons.people_outline_rounded, color: AppColors.primaryPurple), title: Text('View Family Members', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14)), trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FamilyMembersScreen(family: widget.family, currentUser: widget.currentUser)))),
                  const Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.lightLavenderBorder),
                  ListTile(leading: const Icon(Icons.person_add_outlined, color: AppColors.primaryPurple), title: Text('Invite New Member', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14)), trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14), onTap: () => InviteMemberScreen.navigateTo(context, family: widget.family, currentUser: widget.currentUser)),
                ])),
                const SizedBox(height: 28),
                _sectionTitle('Danger Zone', color: AppColors.error),
                _card(ListTile(leading: const Icon(Icons.exit_to_app_rounded, color: AppColors.error), title: Text(_isOwner ? 'Leave or Delete Family' : 'Leave Family Group', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.error)), subtitle: Text('Your personal assets will remain on your device.', style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)), onTap: _handleLeaveFamily)),
              ],
            ),
    );
  }

  Widget _sectionTitle(String title, {Color? color}) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(title, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: color ?? AppColors.textSecondary)));

  Widget _card(Widget child) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.surfaceWhite, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.lightLavenderBorder)), child: child);
}

class _SettingsRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Widget? trailing;
  const _SettingsRow({required this.label, required this.value, required this.icon, this.trailing});

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 20, color: AppColors.primaryPurple),
    const SizedBox(width: 12),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textSecondary)), const SizedBox(height: 2), Text(value, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600))])),
    if (trailing != null) trailing!,
  ]);
}
