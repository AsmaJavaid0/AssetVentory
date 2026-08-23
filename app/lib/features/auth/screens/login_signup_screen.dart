import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/wave_clipper.dart';
import '../../../core/widgets/asset_logo.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/loading_overlay.dart';
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

class _LoginSignupScreenState extends State<LoginSignupScreen> {
  final AuthService _authService = AuthService();

  late bool _isSignUp;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _rememberMe = true;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _isSignUp = widget.initialIsSignUp;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitEmailAuth() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      if (_isSignUp) {
        await _authService.signUpWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          name: _nameController.text.trim(),
        );
      } else {
        await _authService.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(_getFirebaseAuthErrorMessage(e));
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitGoogleAuth() async {
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final credential = await _authService.signInWithGoogle();
      if (credential == null) {
        // User cancelled
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(_getFirebaseAuthErrorMessage(e));
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Google Sign-in failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getFirebaseAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found for that email address.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect password or email. Please check your credentials.';
      case 'email-already-in-use':
        return 'An account already exists for this email address.';
      case 'invalid-email':
        return 'The email address is badly formatted.';
      case 'weak-password':
        return 'The password is too weak. Must be at least 6 characters.';
      case 'network-request-failed':
        return 'Network connection error. Please check your internet.';
      default:
        return e.message ?? 'An authentication error occurred.';
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.outfit(color: Colors.white),
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBg,
        body: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            children: [
              // Hero Dark Top Area with Wave Clipper
              _buildDarkHeroHeader(),

              // Light Lavender Form Body
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Auth Mode Switcher Tabs (Log In / Sign Up)
                      _buildAuthTabs(),

                      const SizedBox(height: 24),

                      // Continue with Google Button
                      GoogleSignInButton(
                        onPressed: _submitGoogleAuth,
                      ),

                      const SizedBox(height: 20),

                      // "or" Divider
                      Row(
                        children: [
                          const Expanded(
                            child: Divider(color: Color(0xFFE2DDF0), thickness: 1.2),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              AppStrings.or,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                color: const Color(0xFF9E98AD),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const Expanded(
                            child: Divider(color: Color(0xFFE2DDF0), thickness: 1.2),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Full Name field (if Sign Up)
                      if (_isSignUp) ...[
                        CustomTextField(
                          controller: _nameController,
                          hintText: AppStrings.fullName,
                          prefixIcon: Icons.person_outline_rounded,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return AppStrings.nameRequired;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Email Field
                      CustomTextField(
                        controller: _emailController,
                        hintText: AppStrings.email,
                        prefixIcon: Icons.mail_outline_rounded,
                        keyboardType: TextInputType.emailAddress,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return AppStrings.emailRequired;
                          }
                          if (!val.contains('@') || !val.contains('.')) {
                            return AppStrings.validEmailRequired;
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 14),

                      // Password Field
                      CustomTextField(
                        controller: _passwordController,
                        hintText: AppStrings.password,
                        prefixIcon: Icons.lock_outline_rounded,
                        obscureText: _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: const Color(0xFF9E98AD),
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() => _obscurePassword = !_obscurePassword);
                          },
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return AppStrings.passwordRequired;
                          }
                          if (val.length < 6) {
                            return AppStrings.passwordMinLength;
                          }
                          return null;
                        },
                      ),

                      // Confirm Password Field (if Sign Up)
                      if (_isSignUp) ...[
                        const SizedBox(height: 14),
                        CustomTextField(
                          controller: _confirmPasswordController,
                          hintText: AppStrings.confirmPassword,
                          prefixIcon: Icons.lock_outline_rounded,
                          obscureText: _obscureConfirmPassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: const Color(0xFF9E98AD),
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() =>
                                  _obscureConfirmPassword = !_obscureConfirmPassword);
                            },
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return 'Please confirm your password';
                            }
                            if (val != _passwordController.text) {
                              return AppStrings.passwordMismatch;
                            }
                            return null;
                          },
                        ),
                      ],

                      const SizedBox(height: 14),

                      // Remember me & Forgot password row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              SizedBox(
                                width: 22,
                                height: 22,
                                child: Checkbox(
                                  value: _rememberMe,
                                  onChanged: (val) {
                                    setState(() => _rememberMe = val ?? true);
                                  },
                                  activeColor: AppColors.primaryPurple,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  side: const BorderSide(
                                    color: Color(0xFFC7C1D8),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  setState(() => _rememberMe = !_rememberMe);
                                },
                                child: Text(
                                  AppStrings.rememberMe,
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    color: const Color(0xFF655E75),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (!_isSignUp)
                            GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ForgotPasswordScreen(
                                      initialEmail: _emailController.text.trim(),
                                    ),
                                  ),
                                );
                              },
                              child: Text(
                                AppStrings.forgotPassword,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  color: AppColors.primaryPurple,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      // Action Button
                      GradientButton(
                        text: _isSignUp ? AppStrings.signUp : AppStrings.logIn,
                        onPressed: _submitEmailAuth,
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDarkHeroHeader() {
    return ClipPath(
      clipper: WaveClipper(),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppColors.heroGradient,
        ),
        padding: const EdgeInsets.fromLTRB(20, 48, 20, 44),
        child: Column(
          children: [
            // Top Bar: Back & Help
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (Navigator.of(context).canPop())
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                else
                  const SizedBox(width: 40),
                TextButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: Colors.white,
                        title: Text('AssetVentory Support', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                        content: Text(
                          'Need help signing in? You can use Google Sign-in or create a new account with your email.',
                          style: GoogleFonts.outfit(),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('Got it'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Text(
                    'Help',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textWhite70,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // AssetVentory Logo
            const AssetLogo(
              size: 68,
              showText: true,
              isDarkBackground: true,
            ),

            const SizedBox(height: 20),

            // Welcome Back Header
            Text(
              _isSignUp ? 'Create an account' : AppStrings.welcomeBack,
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _isSignUp ? AppStrings.signupSubtitle : AppStrings.loginSubtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: const Color(0xFFB3A8D2),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthTabs() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E2F0), width: 1.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () {
                if (_isSignUp) {
                  setState(() => _isSignUp = false);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: !_isSignUp ? AppColors.primaryPurple : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                child: Center(
                  child: Text(
                    AppStrings.logIn,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: !_isSignUp ? FontWeight.w700 : FontWeight.w500,
                      color: !_isSignUp ? AppColors.primaryPurple : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () {
                if (!_isSignUp) {
                  setState(() => _isSignUp = true);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: _isSignUp ? AppColors.primaryPurple : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                child: Center(
                  child: Text(
                    AppStrings.signUp,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: _isSignUp ? FontWeight.w700 : FontWeight.w500,
                      color: _isSignUp ? AppColors.primaryPurple : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
