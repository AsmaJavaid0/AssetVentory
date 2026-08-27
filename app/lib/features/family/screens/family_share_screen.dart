import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/utils/error_formatter.dart';
import '../../auth/models/user_model.dart';
import '../../auth/services/auth_service.dart';
import '../../auth/services/firestore_service.dart';
import '../models/family_model.dart';
import '../models/family_invitation_model.dart';
import '../widgets/family_empty_state.dart';
import '../widgets/invitation_banner.dart';
import '../widgets/family_auth_prompt.dart';
import 'create_family_screen.dart';
import 'join_family_screen.dart';
import 'family_dashboard_screen.dart';

class FamilyShareScreen extends StatefulWidget {
  const FamilyShareScreen({super.key});

  @override
  State<FamilyShareScreen> createState() => _FamilyShareScreenState();
}

class _FamilyShareScreenState extends State<FamilyShareScreen> {
  final _familyRepository = serviceLocator.familyRepository;
  final _firestoreService = FirestoreService();
  final _authService = AuthService();
  final _auth = FirebaseAuth.instance;

  UserModel? _currentUser;
  FamilyModel? _family;
  List<FamilyInvitationModel> _pendingInvitations = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadState();
    _auth.authStateChanges().listen((user) {
      if (mounted) _loadState();
    });
  }

  Future<void> _loadState() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      if (!mounted) return;
      setState(() {
        _currentUser = null;
        _family = null;
        _isLoading = false;
      });
      return;
    }

    try {
      // 1. Fetch user model
      final userResult = await _firestoreService.getUser(firebaseUser.uid);
      final user = userResult.orNull ??
          UserModel(
            id: firebaseUser.uid,
            name: firebaseUser.displayName ?? '',
            email: firebaseUser.email ?? '',
            photoUrl: firebaseUser.photoURL ?? '',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

      // 2. Fetch family
      final family = await _familyRepository.getUserFamily(user.id);

      // 3. Fetch pending invitations if no family
      List<FamilyInvitationModel> invitations = [];
      if (family == null && user.email.isNotEmpty) {
        try {
          invitations = await _familyRepository.getPendingInvitationsForEmail(user.email);
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _currentUser = user;
        _family = family;
        _pendingInvitations = invitations;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = ErrorFormatter.format(e);
      });
    }
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
          'Your local personal vault and assets will remain safe on your device.',
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

    try {
      await _authService.signOut();
      if (!mounted) return;
      _loadState();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Logged out from Family Sharing.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ErrorFormatter.format(e)),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _acceptInvitation(FamilyInvitationModel invite) async {
    if (_currentUser == null) return;
    try {
      final family = await _familyRepository.acceptInvitation(
        invitation: invite,
        user: _currentUser!,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Joined "${family.name}" successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
      _loadState();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ErrorFormatter.format(e)),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _declineInvitation(FamilyInvitationModel invite) async {
    try {
      await _familyRepository.declineInvitation(invite.id);
      if (!mounted) return;
      setState(() {
        _pendingInvitations.removeWhere((i) => i.id == invite.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitation declined.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ErrorFormatter.format(e)),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.scaffoldBg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                color: AppColors.primaryPurple,
                strokeWidth: 3,
              ),
              const SizedBox(height: 16),
              Text(
                'Loading Family Sharing...',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: AppColors.scaffoldBg,
        appBar: AppBar(
          title: Text(
            'Family Sharing',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off_rounded, size: 56, color: AppColors.textMuted),
                const SizedBox(height: 16),
                Text(
                  'Connection Notice',
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _loadState,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry Connection'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // State B: User belongs to a family -> Show Family Dashboard
    if (_currentUser != null && _family != null) {
      return FamilyDashboardScreen(
        family: _family!,
        currentUser: _currentUser!,
        onFamilyUpdated: _loadState,
      );
    }

    // State A: User does not belong to a family -> Show Landing Empty State
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: Text(
          'Family Sharing',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (_currentUser != null)
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: AppColors.textSecondary),
              tooltip: 'Log Out (${_currentUser!.email})',
              onPressed: _handleLogout,
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (_currentUser != null)
              Container(
                margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primaryPurple.withAlpha(12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_circle_outlined, size: 18, color: AppColors.primaryPurple),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Signed in as ${_currentUser!.email}',
                        style: GoogleFonts.outfit(fontSize: 12, color: AppColors.primaryPurple, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InkWell(
                      onTap: _handleLogout,
                      child: Text(
                        'Switch',
                        style: GoogleFonts.outfit(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            if (_pendingInvitations.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: InvitationBanner(
                  invitations: _pendingInvitations,
                  onAccept: _acceptInvitation,
                  onDecline: _declineInvitation,
                ),
              ),
            FamilyEmptyState(
              onCreateFamily: () async {
                if (_currentUser == null) {
                  FamilyAuthPrompt.show(context, onSignedIn: _loadState);
                  return;
                }
                final created = await CreateFamilyScreen.navigateTo(context, _currentUser!);
                if (created == true) _loadState();
              },
              onJoinFamily: () async {
                if (_currentUser == null) {
                  FamilyAuthPrompt.show(context, onSignedIn: _loadState);
                  return;
                }
                final joined = await JoinFamilyScreen.navigateTo(context, _currentUser!);
                if (joined == true) _loadState();
              },
            ),
          ],
        ),
      ),
    );
  }
}
