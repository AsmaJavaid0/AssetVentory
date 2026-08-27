import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../auth/models/user_model.dart';
import '../models/family_model.dart';
import '../models/family_invitation_model.dart';

class InviteMemberScreen extends StatefulWidget {
  final FamilyModel family;
  final UserModel currentUser;

  const InviteMemberScreen({
    super.key,
    required this.family,
    required this.currentUser,
  });

  static Future<void> navigateTo(
    BuildContext context, {
    required FamilyModel family,
    required UserModel currentUser,
  }) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InviteMemberScreen(
          family: family,
          currentUser: currentUser,
        ),
      ),
    );
  }

  @override
  State<InviteMemberScreen> createState() => _InviteMemberScreenState();
}

class _InviteMemberScreenState extends State<InviteMemberScreen> {
  final _emailController = TextEditingController();
  final _familyRepository = serviceLocator.familyRepository;

  bool _isSending = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String _buildInviteMessage({String? recipientEmail}) {
    return 'Hey! I\'ve invited you to join our family "${widget.family.name}" on AssetVentory.\n\n'
        '1. Open the AssetVentory app\n'
        '2. Go to Family > Join Family\n'
        '3. Enter this invitation code:\n👉 ${widget.family.inviteCode}\n\n'
        'Let\'s manage and track our shared family assets together!';
  }

  Future<void> _shareViaNativeSheet() async {
    final message = _buildInviteMessage();
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: message,
          subject: 'Invitation to join ${widget.family.name} on AssetVentory',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open share menu: $e')),
      );
    }
  }

  Future<void> _openEmailApp(String toEmail) async {
    final subject = Uri.encodeComponent('Join ${widget.family.name} on AssetVentory');
    final body = Uri.encodeComponent(_buildInviteMessage(recipientEmail: toEmail));
    final emailUri = Uri.parse('mailto:$toEmail?subject=$subject&body=$body');

    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback to native share sheet
        await SharePlus.instance.share(
          ShareParams(
            text: _buildInviteMessage(recipientEmail: toEmail),
            subject: 'Join ${widget.family.name} on AssetVentory',
          ),
        );
      }
    } catch (_) {
      await SharePlus.instance.share(
        ShareParams(
          text: _buildInviteMessage(recipientEmail: toEmail),
          subject: 'Join ${widget.family.name} on AssetVentory',
        ),
      );
    }
  }

  Future<void> _sendInvite() async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid email address (e.g. name@example.com)'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    bool isOfflineQueued = false;
    try {
      await _familyRepository.sendInvitation(
        familyId: widget.family.id,
        familyName: widget.family.name,
        sender: widget.currentUser,
        receiverEmail: email,
      );
    } on TimeoutException {
      isOfflineQueued = true;
    } on SocketException {
      isOfflineQueued = true;
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('offline') || errStr.contains('unavailable') || errStr.contains('network')) {
        isOfflineQueued = true;
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send invite: $e'), backgroundColor: AppColors.error),
        );
        setState(() => _isSending = false);
        return;
      }
    }

    _emailController.clear();
    if (!mounted) return;
    setState(() => _isSending = false);

    // Show confirmation dialog with direct Email/App dispatch options
    _showInviteSentDialog(email, isOfflineQueued);
  }

  void _showInviteSentDialog(String targetEmail, bool isOfflineQueued) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isOfflineQueued ? Colors.amber.withAlpha(30) : AppColors.success.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isOfflineQueued ? Icons.cloud_queue_rounded : Icons.check_circle_rounded,
                color: isOfflineQueued ? Colors.amber.shade800 : AppColors.success,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isOfflineQueued ? 'Invite Queued Offline' : 'Invite Registered!',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isOfflineQueued
                  ? 'Your internet is currently offline. The invitation is saved and will sync automatically when reconnected.'
                  : 'An in-app invitation has been registered for $targetEmail. When they log into AssetVentory, they will see it automatically.',
              style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.lightLavender,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.primaryPurple),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'You can also send this invitation directly to their Email or WhatsApp now:',
                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Done', style: GoogleFonts.outfit(color: AppColors.textSecondary)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              _openEmailApp(targetEmail);
            },
            icon: const Icon(Icons.mail_outline_rounded, size: 18),
            label: Text('Open Email App', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelInvite(String inviteId) async {
    try {
      await _familyRepository.cancelInvitation(inviteId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitation cancelled.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  void _copyInviteCode() {
    Clipboard.setData(ClipboardData(text: widget.family.inviteCode));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invitation code copied to clipboard!'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: Text(
          'Invite Member',
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Code Share Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryPurple.withAlpha(50),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Family Quick Join Code',
                    style: GoogleFonts.outfit(
                      color: Colors.white.withAlpha(200),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.family.inviteCode,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: _copyInviteCode,
                            icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 22),
                            tooltip: 'Copy Code',
                          ),
                          const SizedBox(width: 4),
                          ElevatedButton.icon(
                            onPressed: _shareViaNativeSheet,
                            icon: const Icon(Icons.share_rounded, size: 16, color: AppColors.primaryPurple),
                            label: Text(
                              'Share',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryPurple,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Share this code or invite link via WhatsApp, Email, or SMS to connect instantly.',
                    style: GoogleFonts.outfit(
                      color: Colors.white.withAlpha(220),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Email Invite Section
            Text(
              'Invite by Email',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Enables in-app invitation & sends direct email options',
              style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceWhite,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.lightLavenderBorder),
              ),
              child: Column(
                children: [
                  CustomTextField(
                    controller: _emailController,
                    hintText: 'e.g. member@example.com',
                    labelText: 'Recipient Email Address',
                    prefixIcon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.send,
                    onFieldSubmitted: (_) => _sendInvite(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _isSending ? null : _sendInvite,
                            icon: _isSending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.send_rounded, size: 18),
                            label: Text(
                              _isSending ? 'Sending...' : 'Send Invitation',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryPurple,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Sent Invitations List
            Text(
              'Active Invitations',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<FamilyInvitationModel>>(
              stream: _familyRepository.streamFamilySentInvitations(widget.family.id),
              builder: (context, snapshot) {
                final invites = snapshot.data ?? [];
                if (invites.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceWhite,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.lightLavenderBorder),
                    ),
                    child: Center(
                      child: Text(
                        'No active pending invitations.',
                        style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ),
                  );
                }

                return Column(
                  children: invites.map((invite) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceWhite,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.lightLavenderBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.lightLavender,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.outgoing_mail, color: AppColors.primaryPurple, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  invite.receiverEmail,
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  'In-App Status: Pending',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: Colors.amber.shade800,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.share_outlined, size: 20, color: AppColors.primaryPurple),
                            tooltip: 'Resend via Email/Share',
                            onPressed: () => _openEmailApp(invite.receiverEmail),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.error),
                            tooltip: 'Cancel Invite',
                            onPressed: () => _cancelInvite(invite.id),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
