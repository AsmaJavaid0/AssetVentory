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
  body: Column(
    children: [
      _buildHeader(context),
      Expanded(
        child: StreamBuilder<List<FamilyInvitationModel>>(
          stream: _invitationStream,
          initialData: _pendingInvitations,
          builder: (context, snapshot) {
            final invitations = snapshot.data ?? _pendingInvitations;

            if (snapshot.hasError) {
              return SingleChildScrollView(
                child: Column(
                  children: [
                    if (_currentUser != null)
                      Container(
                        margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryPurple.withAlpha(12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.account_circle_outlined,
                              size: 18,
                              color: AppColors.primaryPurple,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Signed in as ${_currentUser!.email}',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: AppColors.primaryPurple,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            InkWell(
                              onTap: _handleLogout,
                              child: Text(
                                'Switch',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: AppColors.error,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.wifi_off_rounded,
                            size: 48,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Unable to load invitations.',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Please check your connection and try again.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadState,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: _loadState,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    if (_currentUser != null)
                      Container(
                        margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryPurple.withAlpha(12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.account_circle_outlined,
                              size: 18,
                              color: AppColors.primaryPurple,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Signed in as ${_currentUser!.email}',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: AppColors.primaryPurple,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            InkWell(
                              onTap: _handleLogout,
                              child: Text(
                                'Switch',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: AppColors.error,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Realtime pending invitations.
                    if (invitations.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: InvitationBanner(
                          invitations: invitations,
                          onAccept: _acceptInvitation,
                          onDecline: _declineInvitation,
                        ),
                      ),

                    FamilyEmptyState(
                      onCreateFamily: () async {
                        if (_currentUser == null) {
                          FamilyAuthPrompt.show(
                            context,
                            onSignedIn: _loadState,
                          );
                          return;
                        }

                        final created =
                            await CreateFamilyScreen.navigateTo(
                          context,
                          _currentUser!,
                        );

                        if (created == true) {
                          _loadState();
                        }
                      },
                      onJoinFamily: () async {
                        if (_currentUser == null) {
                          FamilyAuthPrompt.show(
                            context,
                            onSignedIn: _loadState,
                          );
                          return;
                        }

                        final joined =
                            await JoinFamilyScreen.navigateTo(
                          context,
                          _currentUser!,
                        );

                        if (joined == true) {
                          _loadState();
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ],
  ),
);
}

Widget _buildHeader(BuildContext context) {
  final top = MediaQuery.of(context).padding.top;

  return Container(
    padding: EdgeInsets.fromLTRB(20, top + 16, 12, 20),
    decoration: const BoxDecoration(
      color: AppColors.heroDarkBg,
      borderRadius: BorderRadius.vertical(
        bottom: Radius.circular(24),
      ),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            'Family Sharing',
            style: GoogleFonts.outfit(
              fontSize: 24,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (_currentUser != null)
          IconButton(
            icon: const Icon(
              Icons.logout_rounded,
              color: Colors.white,
            ),
            tooltip: 'Log Out (${_currentUser!.email})',
            onPressed: _handleLogout,
          ),
      ],
    ),
  );
}