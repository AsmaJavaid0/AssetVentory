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
  Stream<List<FamilyInvitationModel>>? _invitationStream;
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
        _pendingInvitations = [];
        _invitationStream = null;
        _isLoading = false;
      });
      return;
    }

    try {
      final userResult = await _firestoreService.getUser(firebaseUser.uid);
      final user = userResult.orNull ?? UserModel(
        id: firebaseUser.uid,
        name: firebaseUser.displayName ?? '',
        email: firebaseUser.email ?? '',
        photoUrl: firebaseUser.photoURL ?? '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final family = await _familyRepository.getUserFamily(user.id);
      final invitations = family == null && user.email.isNotEmpty
          ? await _familyRepository.getPendingInvitationsForEmail(user.email)
          : <FamilyInvitationModel>[];

      if (!mounted) return;
      setState(() {
        _currentUser = user;
        _family = family;
        _pendingInvitations = invitations;
        _invitationStream = family == null && user.email.isNotEmpty
            ? _familyRepository.streamPendingInvitationsForEmail(user.email)
            : null;
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
      await _loadState();
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
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: AppColors.scaffoldBg,
        appBar: AppBar(title: const Text('Family Sharing')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off_rounded, size: 56),
                const SizedBox(height: 16),
                Text('Connection Notice', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(_errorMessage!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _loadState, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    if (_currentUser == null) {
      return const Scaffold(body: FamilyAuthPrompt());
    }

    if (_family != null) {
      return FamilyDashboardScreen(family: _family!, currentUser: _currentUser!);
    }

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: Text('Family Sharing', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<List<FamilyInvitationModel>>(
        stream: _invitationStream,
        initialData: _pendingInvitations,
        builder: (context, snapshot) {
          final invitations = snapshot.data ?? _pendingInvitations;
          if (snapshot.hasError) {
            return _buildEmptyFamilyState('Unable to load invitations. Please check your connection and try again.');
          }

          return RefreshIndicator(
            onRefresh: _loadState,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (invitations.isNotEmpty) ...[
                  Text('Family Invitations', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  ...invitations.map((invite) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InvitationBanner(
                      invitation: invite,
                      onAccept: () => _acceptInvitation(invite),
                      onDecline: () => _declineInvitation(invite),
                    ),
                  )),
                  const SizedBox(height: 20),
                ],
                FamilyEmptyState(
                  title: invitations.isEmpty ? 'No Family Yet' : 'Want to join another way?',
                  subtitle: 'Create a family or enter an invitation code from a family admin.',
                  primaryButtonText: 'Create Family',
                  onPrimaryPressed: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => CreateFamilyScreen(currentUser: _currentUser!)));
                    _loadState();
                  },
                  secondaryButtonText: 'Join Family',
                  onSecondaryPressed: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => JoinFamilyScreen(currentUser: _currentUser!)));
                    _loadState();
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyFamilyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
