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
  const FamilySharePinScreen({super.key, required this.family, required this.currentUser, this.unlockOnly = false});
  @override
  State<FamilySharePinScreen> createState() => _FamilySharePinScreenState();
}

class _FamilySharePinScreenState extends State<FamilySharePinScreen> {
  final _repository = serviceLocator.familyRepository;
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  bool get _isOwner => widget.family.ownerId == widget.currentUser.id;
  bool get _unlockOnly => widget.unlockOnly || (!_isOwner && widget.family.pinEnabled);

  @override
  void dispose() { _pinController.dispose(); _confirmController.dispose(); super.dispose(); }

  Future<void> _verify() async {
    final pin = _pinController.text.trim();
    if (!RegExp(r'^\d{4,6}$').hasMatch(pin)) { _message('Enter a 4–6 digit PIN.', error: true); return; }
    setState(() => _loading = true);
    try {
      final ok = await _repository.verifyFamilySharePin(familyId: widget.family.id, pin: pin);
      if (!mounted) return;
      if (ok) Navigator.pop(context, true); else _message('Incorrect PIN.', error: true);
    } catch (e) { if (mounted) _message(ErrorFormatter.format(e), error: true); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _savePin() async {
    if (!_isOwner) { _message('Only the family owner can change the Family Share PIN.', error: true); return; }
    final pin = _pinController.text.trim();
    final confirm = _confirmController.text.trim();
    if (!RegExp(r'^\d{4,6}$').hasMatch(pin)) { _message('PIN must contain 4–6 digits.', error: true); return; }
    if (pin != confirm) { _message('PINs do not match.', error: true); return; }
    setState(() => _loading = true);
    try { await _repository.setFamilySharePin(familyId: widget.family.id, pin: pin); if (mounted) Navigator.pop(context, true); }
    catch (e) { if (mounted) _message(ErrorFormatter.format(e), error: true); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _removePin() async {
    if (!_isOwner) return;
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Remove Family Share PIN?'), content: const Text('Shared assets will no longer require the family PIN.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove PIN'))]));
    if (confirmed != true) return;
    setState(() => _loading = true);
    try { await _repository.removeFamilySharePin(widget.family.id); if (mounted) Navigator.pop(context, true); }
    catch (e) { if (mounted) _message(ErrorFormatter.format(e), error: true); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  void _message(String text, {bool error = false}) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), backgroundColor: error ? AppColors.error : AppColors.success));

  @override
  Widget build(BuildContext context) {
    final enabled = widget.family.pinEnabled;
    final title = _unlockOnly ? 'Unlock Shared Assets' : 'Family Share PIN';
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(title: Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.w700)), backgroundColor: Colors.white, elevation: 0),
      body: _loading ? const Center(child: CircularProgressIndicator(color: AppColors.primaryPurple)) : ListView(padding: const EdgeInsets.all(20), children: [
        Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.lightLavenderBorder)), child: Column(children: [
          Container(width: 70, height: 70, decoration: BoxDecoration(color: AppColors.primaryPurple.withAlpha(18), shape: BoxShape.circle), child: const Icon(Icons.lock_outline_rounded, color: AppColors.primaryPurple, size: 34)),
          const SizedBox(height: 16), Text(title, style: GoogleFonts.outfit(fontSize: 21, fontWeight: FontWeight.w700)), const SizedBox(height: 8),
          Text(_unlockOnly ? 'Enter the PIN set by the family owner to view and manage shared assets.' : 'Protect your family\'s shared assets with a separate 4–6 digit PIN. The PIN is stored securely as a salted hash.', textAlign: TextAlign.center, style: GoogleFonts.outfit(color: AppColors.textSecondary, height: 1.4)),
          const SizedBox(height: 24),
          TextField(controller: _pinController, obscureText: _obscure, keyboardType: TextInputType.number, maxLength: 6, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: InputDecoration(labelText: _unlockOnly ? 'Family PIN' : 'New PIN', prefixIcon: const Icon(Icons.pin_outlined), suffixIcon: IconButton(onPressed: () => setState(() => _obscure = !_obscure), icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)))),
          if (!_unlockOnly) ...[const SizedBox(height: 10), TextField(controller: _confirmController, obscureText: true, keyboardType: TextInputType.number, maxLength: 6, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: InputDecoration(labelText: 'Confirm PIN', prefixIcon: const Icon(Icons.verified_user_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))))],
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, height: 52, child: FilledButton(onPressed: _unlockOnly ? _verify : _savePin, style: FilledButton.styleFrom(backgroundColor: AppColors.primaryPurple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: Text(_unlockOnly ? 'Unlock Shared Assets' : (enabled ? 'Update PIN' : 'Enable PIN')))),
          if (!_unlockOnly && enabled && _isOwner) ...[const SizedBox(height: 10), TextButton.icon(onPressed: _removePin, icon: const Icon(Icons.lock_open_rounded, color: AppColors.error), label: const Text('Remove PIN', style: TextStyle(color: AppColors.error)))],
        ])),
      ]),
    );
  }
}
