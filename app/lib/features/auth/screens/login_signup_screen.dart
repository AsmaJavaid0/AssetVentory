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
  final bool returnToCaller;
  const LoginSignupScreen({super.key, this.initialIsSignUp = false, this.returnToCaller = false});
  @override State<LoginSignupScreen> createState() => _LoginSignupScreenState();
}

class _LoginSignupScreenState extends State<LoginSignupScreen> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  late bool _isSignUp;
  bool _isEmailLoading = false, _isGoogleLoading = false, _obscurePassword = true, _obscureConfirmPassword = true;
  String? _inlineError;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(), _emailController = TextEditingController(), _passwordController = TextEditingController(), _confirmPasswordController = TextEditingController();
  late AnimationController _tabAnimController;
  late Animation<double> _fadeAnim;

  @override void initState() { super.initState(); _isSignUp = widget.initialIsSignUp; _tabAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 260)); _fadeAnim = CurvedAnimation(parent: _tabAnimController, curve: Curves.easeInOut); _tabAnimController.forward(); }
  @override void dispose() { _nameController.dispose(); _emailController.dispose(); _passwordController.dispose(); _confirmPasswordController.dispose(); _tabAnimController.dispose(); super.dispose(); }
  void _switchTab(bool value) { if (_isSignUp == value) return; _tabAnimController.reverse().then((_) { if (!mounted) return; setState(() { _isSignUp = value; _inlineError = null; _formKey.currentState?.reset(); }); _tabAnimController.forward(); }); }

  Future<void> _finishAuthentication() async {
    if (!mounted) return;
    if (widget.returnToCaller) { Navigator.of(context).pop(true); return; }
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const MainNavigationScreen()), (route) => false);
  }

  Future<void> _submitEmailAuth() async {
    setState(() => _inlineError = null);
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus(); setState(() => _isEmailLoading = true);
    try {
      final dynamic result = _isSignUp
          ? await _authService.signUpWithEmailAndPassword(email: _emailController.text.trim(), password: _passwordController.text, name: _nameController.text.trim())
          : await _authService.signInWithEmailAndPassword(email: _emailController.text.trim(), password: _passwordController.text);
      if (result.isFailure) { if (mounted) setState(() => _inlineError = _getAuthErrorMessage(result.error)); return; }
      await _finishAuthentication();
    } catch (e) { if (mounted) setState(() => _inlineError = ErrorFormatter.format(e)); }
    finally { if (mounted) setState(() => _isEmailLoading = false); }
  }

  Future<void> _submitGoogleAuth() async {
    FocusScope.of(context).unfocus(); setState(() { _isGoogleLoading = true; _inlineError = null; });
    try {
      final result = await _authService.signInWithGoogle();
      if (result.isFailure) { if (mounted) setState(() => _inlineError = _getAuthErrorMessage(result.error)); return; }
      await _finishAuthentication();
    } catch (e) { if (mounted) setState(() => _inlineError = ErrorFormatter.format(e)); }
    finally { if (mounted) setState(() => _isGoogleLoading = false); }
  }

  String _getAuthErrorMessage(dynamic error) {
    if (error is AuthException) { switch (error.code) {
      case 'user-not-found': return 'No account found with this email. Did you mean to Sign Up?';
      case 'wrong-password': case 'invalid-credential': return 'Incorrect email or password. Please try again.';
      case 'email-already-in-use': return 'An account already exists for this email. Please Log In instead.';
      case 'invalid-email': return 'Please enter a valid email address.';
      case 'weak-password': return 'Password must be at least 6 characters long.';
      case 'network-request-failed': return 'No internet connection. Please check your network and try again.';
      case 'operation-not-allowed': return 'Sign-in failed. Please try again or use Continue with Google.';
      case 'too-many-requests': return 'Too many failed attempts. Please wait a few minutes and try again.';
      case 'user-disabled': return 'This account has been disabled. Please contact support.';
      case 'account-exists-with-different-credential': return 'An account with this email already exists. Try a different sign-in method.';
      default: return 'Sign-in failed. Please check your details and try again.';
    }} return ErrorFormatter.format(error);
  }
  bool get _isAnyLoading => _isEmailLoading || _isGoogleLoading;

  @override Widget build(BuildContext context) => Scaffold(backgroundColor: AppColors.scaffoldBg, body: GestureDetector(onTap: () => FocusScope.of(context).unfocus(), child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [_buildHeroHeader(), Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 32), child: Form(key: _formKey, child: FadeTransition(opacity: _fadeAnim, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [_buildTabSwitcher(), const SizedBox(height: 28), _buildGoogleButton(), const SizedBox(height: 22), _buildDivider(), const SizedBox(height: 22), if (_isSignUp) ...[_buildLabel('Full Name'), const SizedBox(height: 6), _buildInputField(controller: _nameController, hint: 'Your full name', icon: Icons.person_outline_rounded, validator: (v) => v == null || v.trim().isEmpty ? 'Please enter your name' : null), const SizedBox(height: 16)], _buildLabel('Email Address'), const SizedBox(height: 6), _buildInputField(controller: _emailController, hint: 'you@example.com', icon: Icons.mail_outline_rounded, keyboardType: TextInputType.emailAddress, validator: (v) => v == null || v.trim().isEmpty ? 'Email is required' : (!v.contains('@') || !v.contains('.') ? 'Please enter a valid email address' : null)), const SizedBox(height: 16), _buildLabel('Password'), const SizedBox(height: 6), _buildInputField(controller: _passwordController, hint: _isSignUp ? 'At least 6 characters' : 'Enter your password', icon: Icons.lock_outline_rounded, obscureText: _obscurePassword, suffixIcon: _eyeIcon(_obscurePassword, () => setState(() => _obscurePassword = !_obscurePassword)), validator: (v) => v == null || v.isEmpty ? 'Password is required' : (v.length < 6 ? 'Password must be at least 6 characters' : null)), if (_isSignUp) ...[const SizedBox(height: 16), _buildLabel('Confirm Password'), const SizedBox(height: 6), _buildInputField(controller: _confirmPasswordController, hint: 'Repeat your password', icon: Icons.lock_outline_rounded, obscureText: _obscureConfirmPassword, suffixIcon: _eyeIcon(_obscureConfirmPassword, () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword)), validator: (v) => v == null || v.isEmpty ? 'Please confirm your password' : (v != _passwordController.text ? 'Passwords do not match' : null))], const SizedBox(height: 14), if (!_isSignUp) Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ForgotPasswordScreen(initialEmail: _emailController.text.trim()))), child: Text('Forgot password?', style: GoogleFonts.outfit(color: AppColors.primaryPurple, fontWeight: FontWeight.w600)))), const SizedBox(height: 24), if (_inlineError != null) _buildErrorBanner(_inlineError!), if (_inlineError != null) const SizedBox(height: 16), _buildPrimaryButton(), const SizedBox(height: 24), _buildSwitchModeRow()]))))]))));

  Widget _buildHeroHeader() => ClipPath(clipper: WaveClipper(), child: Container(width: double.infinity, decoration: const BoxDecoration(gradient: AppColors.heroGradient), padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 20, 20, 48), child: Column(children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [if (Navigator.of(context).canPop()) IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20), onPressed: () => Navigator.of(context).pop()) else const SizedBox(width: 40), const SizedBox(width: 40)]), const AssetLogo(size: 64, showText: true, isDarkBackground: true), const SizedBox(height: 20), Text(_isSignUp ? 'Create your account' : 'Welcome back!', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)), const SizedBox(height: 6), Text(_isSignUp ? 'Start managing your assets securely.' : AppStrings.loginSubtitle, textAlign: TextAlign.center, style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFFB3A8D2)))])));
  Widget _buildTabSwitcher() => Container(height: 48, decoration: BoxDecoration(color: AppColors.lightLavender, borderRadius: BorderRadius.circular(14)), child: Row(children: [_tabItem('Log In', !_isSignUp, () => _switchTab(false)), _tabItem('Sign Up', _isSignUp, () => _switchTab(true))]));
  Widget _tabItem(String label, bool selected, VoidCallback onTap) => Expanded(child: GestureDetector(onTap: onTap, child: AnimatedContainer(duration: const Duration(milliseconds: 220), margin: const EdgeInsets.all(4), decoration: BoxDecoration(color: selected ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(10)), child: Center(child: Text(label, style: GoogleFonts.outfit(fontSize: 15, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? AppColors.primaryPurple : AppColors.textSecondary)))));
  Widget _buildGoogleButton() => Material(color: Colors.white, borderRadius: BorderRadius.circular(14), child: InkWell(onTap: _isAnyLoading ? null : _submitGoogleAuth, child: Container(height: 52, decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2DCF3), width: 1.5)), child: _isGoogleLoading ? const Center(child: CircularProgressIndicator(color: AppColors.primaryPurple)) : Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.g_mobiledata, size: 28, color: AppColors.primaryPurple), const SizedBox(width: 8), Text('Continue with Google', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600))]))));
  Widget _buildDivider() => Row(children: [const Expanded(child: Divider()), Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Text('or', style: GoogleFonts.outfit(color: AppColors.textMuted))), const Expanded(child: Divider())]);
  Widget _buildLabel(String text) => Text(text, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary));
  Widget _buildInputField({required TextEditingController controller, required String hint, required IconData icon, TextInputType? keyboardType, bool obscureText = false, Widget? suffixIcon, String? Function(String?)? validator}) => TextFormField(controller: controller, keyboardType: keyboardType, obscureText: obscureText, validator: validator, style: GoogleFonts.outfit(fontSize: 15), decoration: InputDecoration(hintText: hint, prefixIcon: Icon(icon, size: 20, color: AppColors.textMuted), suffixIcon: suffixIcon, filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2DCF3))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2DCF3))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryPurple, width: 1.8))));
  Widget _eyeIcon(bool obscured, VoidCallback onToggle) => IconButton(icon: Icon(obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppColors.textMuted), onPressed: onToggle);
  Widget _buildErrorBanner(String message) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.error.withAlpha(15), borderRadius: BorderRadius.circular(12)), child: Text(message, style: GoogleFonts.outfit(color: AppColors.error)));
  Widget _buildPrimaryButton() => SizedBox(height: 52, child: ElevatedButton(onPressed: _isAnyLoading ? null : _submitEmailAuth, style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: _isEmailLoading ? const CircularProgressIndicator(color: Colors.white) : Text(_isSignUp ? 'Create Account' : 'Log In', style: GoogleFonts.outfit(fontWeight: FontWeight.w700))));
  Widget _buildSwitchModeRow() => Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text(_isSignUp ? 'Already have an account? ' : "Don't have an account? ", style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary)), GestureDetector(onTap: () => _switchTab(!_isSignUp), child: Text(_isSignUp ? 'Log In' : 'Sign Up', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primaryPurple)))]);
}
