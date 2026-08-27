import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/wave_clipper.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/widgets/asset_logo.dart';
import '../../../core/utils/result.dart';
import '../services/auth_service.dart';
import 'forgot_password_screen.dart';
import '../../home/screens/main_navigation_screen.dart';

class LoginSignupScreen extends StatefulWidget {
  final bool initialIsSignUp;

  const LoginSignupScreen({
    super.key,
    this.initialIsSignUp = false,
  });

  @override
  State<LoginSignupScreen> createState() => _LoginSignupScreenState();
}

class _LoginSignupScreenState extends State<LoginSignupScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();

  late bool _isSignUp;
  bool _isEmailLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _inlineError;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  late AnimationController _tabAnimController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _isSignUp = widget.initialIsSignUp;
    _tabAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _fadeAnim = CurvedAnimation(parent: _tabAnimController, curve: Curves.easeInOut);
    _tabAnimController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _tabAnimController.dispose();
    super.dispose();
  }

  void _switchTab(bool toSignUp) {
    if (_isSignUp == toSignUp) return;
    _tabAnimController.reverse().then((_) {
      setState(() {
        _isSignUp = toSignUp;
        _inlineError = null;
        _formKey.currentState?.reset();
      });
      _tabAnimController.forward();
    });
  }

  Future<void> _submitEmailAuth() async {
    setState(() => _inlineError = null);
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _isEmailLoading = true);

    try {
      final dynamic result;
      if (_isSignUp) {
        result = await _authService.signUpWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          name: _nameController.text.trim(),
        );
      } else {
        result = await _authService.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }

      if (result.isFailure) {
        if (!mounted) return;
        setState(() => _inlineError = _getAuthErrorMessage(result.error));
        return;
      }

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _inlineError = ErrorFormatter.format(e));
    } finally {
      if (mounted) setState(() => _isEmailLoading = false);
    }
  }

  Future<void> _submitGoogleAuth() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _isGoogleLoading = true;
      _inlineError = null;
    });

    try {
      final result = await _authService.signInWithGoogle();
      if (result.isFailure) {
        if (mounted) setState(() => _inlineError = _getAuthErrorMessage(result.error));
        return;
      }

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _inlineError = ErrorFormatter.format(e));
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  String _getAuthErrorMessage(dynamic error) {
    if (error is AuthException) {
      switch (error.code) {
        case 'user-not-found':
          return 'No account found with this email. Did you mean to Sign Up?';
        case 'wrong-password':
        case 'invalid-credential':
          return 'Incorrect email or password. Please try again.';
        case 'email-already-in-use':
          return 'An account already exists for this email. Please Log In instead.';
        case 'invalid-email':
          return 'Please enter a valid email address.';
        case 'weak-password':
          return 'Password must be at least 6 characters long.';
        case 'network-request-failed':
          return 'No internet connection. Please check your network and try again.';
        case 'operation-not-allowed':
          return 'Sign-in failed. Please try again or use Continue with Google.';
        case 'too-many-requests':
          return 'Too many failed attempts. Please wait a few minutes and try again.';
        case 'user-disabled':
          return 'This account has been disabled. Please contact support.';
        case 'account-exists-with-different-credential':
          return 'An account with this email already exists. Try a different sign-in method.';
        case 'popup-closed-by-user':
        case 'cancelled-popup-request':
          return 'Sign-in was cancelled. Please try again.';
        case 'requires-recent-login':
          return 'For security, please log out and log back in to continue.';
        default:
          return 'Sign-in failed. Please check your details and try again.';
      }
    }
    return ErrorFormatter.format(error);
  }

  bool get _isAnyLoading => _isEmailLoading || _isGoogleLoading;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeroHeader(),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: Form(
                  key: _formKey,
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildTabSwitcher(),
                        const SizedBox(height: 28),
                        _buildGoogleButton(),
                        const SizedBox(height: 22),
                        _buildDivider(),
                        const SizedBox(height: 22),

                        // Name field (sign up only)
                        if (_isSignUp) ...[
                          _buildLabel('Full Name'),
                          const SizedBox(height: 6),
                          _buildInputField(
                            controller: _nameController,
                            hint: 'Your full name',
                            icon: Icons.person_outline_rounded,
                            validator: (val) =>
                                val == null || val.trim().isEmpty ? 'Please enter your name' : null,
                          ),
                          const SizedBox(height: 16),
                        ],

                        _buildLabel('Email Address'),
                        const SizedBox(height: 6),
                        _buildInputField(
                          controller: _emailController,
                          hint: 'you@example.com',
                          icon: Icons.mail_outline_rounded,
                          keyboardType: TextInputType.emailAddress,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Email is required';
                            if (!val.contains('@') || !val.contains('.')) {
                              return 'Please enter a valid email address';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        _buildLabel('Password'),
                        const SizedBox(height: 6),
                        _buildInputField(
                          controller: _passwordController,
                          hint: _isSignUp ? 'At least 6 characters' : 'Enter your password',
                          icon: Icons.lock_outline_rounded,
                          obscureText: _obscurePassword,
                          suffixIcon: _eyeIcon(
                            obscured: _obscurePassword,
                            onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) return 'Password is required';
                            if (val.length < 6) return 'Password must be at least 6 characters';
                            return null;
                          },
                        ),

                        // Confirm Password (sign up only)
                        if (_isSignUp) ...[
                          const SizedBox(height: 16),
                          _buildLabel('Confirm Password'),
                          const SizedBox(height: 6),
                          _buildInputField(
                            controller: _confirmPasswordController,
                            hint: 'Repeat your password',
                            icon: Icons.lock_outline_rounded,
                            obscureText: _obscureConfirmPassword,
                            suffixIcon: _eyeIcon(
                              obscured: _obscureConfirmPassword,
                              onToggle: () => setState(
                                  () => _obscureConfirmPassword = !_obscureConfirmPassword),
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty) return 'Please confirm your password';
                              if (val != _passwordController.text) return 'Passwords do not match';
                              return null;
                            },
                          ),
                        ],

                        const SizedBox(height: 14),

                        // Forgot password row (login only)
                        if (!_isSignUp)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ForgotPasswordScreen(
                                    initialEmail: _emailController.text.trim(),
                                  ),
                                ),
                              ),
                              child: Text(
                                'Forgot password?',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  color: AppColors.primaryPurple,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),

                        const SizedBox(height: 24),

                        // Inline error banner
                        if (_inlineError != null) _buildErrorBanner(_inlineError!),
                        if (_inlineError != null) const SizedBox(height: 16),

                        // Primary CTA Button
                        _buildPrimaryButton(),

                        const SizedBox(height: 24),

                        // Switch auth mode link
                        _buildSwitchModeRow(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Widgets ──────────────────────────────────────────────────────────────

  Widget _buildHeroHeader() {
    return ClipPath(
      clipper: WaveClipper(),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
        padding: EdgeInsets.fromLTRB(
          20,
          MediaQuery.of(context).padding.top + 20,
          20,
          48,
        ),
        child: Column(
          children: [
            // Top row: back / help
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (Navigator.of(context).canPop())
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                else
                  const SizedBox(width: 40),
                const SizedBox(width: 40),
              ],
            ),
            const SizedBox(height: 4),
            const AssetLogo(size: 64, showText: true, isDarkBackground: true),
            const SizedBox(height: 20),
            Text(
              _isSignUp ? 'Create your account' : 'Welcome back!',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _isSignUp
                  ? 'Start managing your assets securely.'
                  : AppStrings.loginSubtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: const Color(0xFFB3A8D2),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSwitcher() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.lightLavender,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _tabItem(label: 'Log In', selected: !_isSignUp, onTap: () => _switchTab(false)),
          _tabItem(label: 'Sign Up', selected: _isSignUp, onTap: () => _switchTab(true)),
        ],
      ),
    );
  }

  Widget _tabItem({required String label, required bool selected, required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [BoxShadow(color: Colors.black.withAlpha(18), blurRadius: 8, offset: const Offset(0, 2))]
                : [],
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.primaryPurple : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleButton() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _isAnyLoading ? null : _submitGoogleAuth,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2DCF3), width: 1.5),
          ),
          child: _isGoogleLoading
              ? const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryPurple),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.network(
                      'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                      width: 20,
                      height: 20,
                      errorBuilder: (context, error, _) =>
                          const Icon(Icons.login, size: 20, color: AppColors.textSecondary),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Continue with Google',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0xFFE5E2F0), thickness: 1.2)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'or',
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Expanded(child: Divider(color: Color(0xFFE5E2F0), thickness: 1.2)),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.outfit(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      style: GoogleFonts.outfit(fontSize: 15, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.outfit(fontSize: 14, color: AppColors.inputHint),
        prefixIcon: Icon(icon, size: 20, color: AppColors.textMuted),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2DCF3), width: 1.4),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryPurple, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 1.4),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 1.8),
        ),
        errorStyle: GoogleFonts.outfit(fontSize: 12, color: AppColors.error),
      ),
    );
  }

  Widget _eyeIcon({required bool obscured, required VoidCallback onToggle}) {
    return IconButton(
      icon: Icon(
        obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        color: AppColors.textMuted,
        size: 20,
      ),
      onPressed: onToggle,
    );
  }

  Widget _buildErrorBanner(String message) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOut,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.error.withAlpha(15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.error.withAlpha(60), width: 1.2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: AppColors.error,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _inlineError = null),
              child: const Icon(Icons.close_rounded, size: 16, color: AppColors.error),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryButton() {
    return SizedBox(
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: _isAnyLoading
              ? const LinearGradient(colors: [Color(0xFFB8AFDC), Color(0xFFB8AFDC)])
              : AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: _isAnyLoading
              ? []
              : [
                  BoxShadow(
                    color: AppColors.primaryPurple.withAlpha(80),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  )
                ],
        ),
        child: ElevatedButton(
          onPressed: _isAnyLoading ? null : _submitEmailAuth,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: _isEmailLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Text(
                  _isSignUp ? 'Create Account' : 'Log In',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildSwitchModeRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _isSignUp ? 'Already have an account? ' : "Don't have an account? ",
          style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary),
        ),
        GestureDetector(
          onTap: () => _switchTab(!_isSignUp),
          child: Text(
            _isSignUp ? 'Log In' : 'Sign Up',
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryPurple,
            ),
          ),
        ),
      ],
    );
  }
}
