import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/utils/error_formatter.dart';
import '../../auth/models/user_model.dart';
import '../models/family_model.dart';

class FamilySharePinScreen extends StatefulWidget {
  final FamilyModel family;
  final UserModel currentUser;
  final bool unlockOnly;

  const FamilySharePinScreen({
    super.key,
    required this.family,
    required this.currentUser,
    this.unlockOnly = false,
  });

  @override
  State<FamilySharePinScreen> createState() => _FamilySharePinScreenState();
}

class _FamilySharePinScreenState extends State<FamilySharePinScreen> {
  final _repository = serviceLocator.familyRepository;
  final _currentPinController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _loading = false;
  bool _obscureCurrent = true;
  bool _obscurePin = true;
  bool _obscureConfirm = true;

  bool get _isPinEnabled => _repository.isFamilyPinEnabled(widget.family.id);
  bool get _unlockOnly => widget.unlockOnly;

  @override
  void dispose() {
    _currentPinController.dispose();
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool _validPin(String pin) => RegExp(r'^\d{4,6}$').hasMatch(pin);

  Future<void> _unlock() async {
    final pin = _pinController.text.trim();
    if (!_validPin(pin)) {
      _message('Enter a 4–6 digit PIN.', error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      final valid = await _repository.verifyFamilySharePin(
        familyId: widget.family.id,
        pin: pin,
      );
      if (!mounted) return;
      if (valid) {
        Navigator.pop(context, true);
      } else {
        _message('Incorrect PIN. Please try again.', error: true);
      }
    } catch (e) {
      if (mounted) _message(ErrorFormatter.format(e), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _savePin() async {
    final pin = _pinController.text.trim();
    final confirm = _confirmController.text.trim();

    if (_isPinEnabled) {
      final current = _currentPinController.text.trim();
      if (!_validPin(current)) {
        _message('Please enter your current 4–6 digit PIN.', error: true);
        return;
      }
      setState(() => _loading = true);
      try {
        final valid = await _repository.verifyFamilySharePin(
          familyId: widget.family.id,
          pin: current,
        );
        if (!valid) {
          if (mounted) _message('Current PIN is incorrect.', error: true);
          return;
        }
      } catch (e) {
        if (mounted) _message(ErrorFormatter.format(e), error: true);
        return;
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }

    if (!_validPin(pin)) {
      _message('PIN must contain 4–6 digits.', error: true);
      return;
    }
    if (pin != confirm) {
      _message('PIN and confirmation do not match.', error: true);
      return;
    }

    setState(() => _loading = true);
    try {
      await _repository.setFamilySharePin(
        familyId: widget.family.id,
        pin: pin,
      );
      if (mounted) {
        _message(_isPinEnabled ? 'PIN updated successfully.' : 'Family Share PIN enabled.');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) _message(ErrorFormatter.format(e), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _removePin() async {
    final controller = TextEditingController();
    bool obscure = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Remove Family Share PIN?', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
          content: TextField(
            controller: controller,
            obscureText: obscure,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Current PIN',
              prefixIcon: const Icon(Icons.pin_outlined),
              suffixIcon: IconButton(
                icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setDialogState(() => obscure = !obscure),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () {
                if (_validPin(controller.text.trim())) Navigator.pop(dialogContext, true);
              },
              child: const Text('Remove PIN'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) {
      controller.dispose();
      return;
    }
    final pin = controller.text.trim();
    controller.dispose();

    setState(() => _loading = true);
    try {
      final valid = await _repository.verifyFamilySharePin(
        familyId: widget.family.id,
        pin: pin,
      );
      if (!valid) {
        if (mounted) _message('Incorrect current PIN.', error: true);
        return;
      }
      await _repository.removeFamilySharePin(widget.family.id);
      if (mounted) {
        _message('Family Share PIN removed.');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) _message(ErrorFormatter.format(e), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _lockNow() async {
    setState(() => _loading = true);
    try {
      await _repository.lockFamilyShare(widget.family.id);
      if (mounted) {
        _message('Shared assets locked.');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) _message(ErrorFormatter.format(e), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? AppColors.error : AppColors.success,
      ),
    );
  }

  Widget _pinField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback toggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: TextInputType.number,
      maxLength: 6,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.pin_outlined),
        suffixIcon: IconButton(
          onPressed: toggle,
          icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _isPinEnabled;
    final isUnlock = _unlockOnly;
    final title = isUnlock ? 'Unlock Shared Assets' : (enabled ? 'Family Share PIN' : 'Set Family Share PIN');

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryPurple))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.lightLavenderBorder),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: AppColors.primaryPurple.withAlpha(18),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isUnlock ? Icons.lock_rounded : (enabled ? Icons.verified_user_rounded : Icons.lock_outline_rounded),
                          color: AppColors.primaryPurple,
                          size: 34,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(title, style: GoogleFonts.outfit(fontSize: 21, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text(
                        isUnlock
                            ? 'Enter your 4–6 digit Family Share PIN to view and manage shared assets.'
                            : enabled
                                ? 'Family Share PIN is active. You can update your PIN, remove it, or lock assets now.'
                                : 'Protect your family\'s shared assets with a 4–6 digit PIN.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(color: AppColors.textSecondary, height: 1.4),
                      ),
                      const SizedBox(height: 24),
                      if (!isUnlock && enabled) ...[
                        _pinField(
                          controller: _currentPinController,
                          label: 'Current PIN',
                          obscure: _obscureCurrent,
                          toggle: () => setState(() => _obscureCurrent = !_obscureCurrent),
                        ),
                        const SizedBox(height: 12),
                      ],
                      _pinField(
                        controller: _pinController,
                        label: isUnlock ? 'Family PIN' : (enabled ? 'New PIN' : 'PIN (4–6 digits)'),
                        obscure: _obscurePin,
                        toggle: () => setState(() => _obscurePin = !_obscurePin),
                      ),
                      if (!isUnlock) ...[
                        const SizedBox(height: 10),
                        _pinField(
                          controller: _confirmController,
                          label: enabled ? 'Confirm New PIN' : 'Confirm PIN',
                          obscure: _obscureConfirm,
                          toggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        ),
                      ],
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          onPressed: isUnlock ? _unlock : _savePin,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primaryPurple,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text(
                            isUnlock ? 'Unlock Shared Assets' : (enabled ? 'Update PIN' : 'Enable PIN'),
                            style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      if (!isUnlock && enabled) ...[
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _lockNow,
                                icon: const Icon(Icons.lock_clock_rounded, size: 18),
                                label: const Text('Lock Now'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primaryPurple,
                                  side: const BorderSide(color: AppColors.primaryPurple),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _removePin,
                                icon: const Icon(Icons.lock_open_rounded, size: 18, color: AppColors.error),
                                label: const Text('Remove PIN', style: TextStyle(color: AppColors.error)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.error,
                                  side: const BorderSide(color: AppColors.error),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
