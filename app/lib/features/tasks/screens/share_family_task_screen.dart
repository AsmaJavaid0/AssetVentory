import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../family/models/family_member_model.dart';
import '../../family/models/family_model.dart';
import '../models/task_model.dart';

class ShareFamilyTaskScreen extends StatefulWidget {
  const ShareFamilyTaskScreen({super.key});

  static Future<void> navigateTo(BuildContext context) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ShareFamilyTaskScreen()),
      );

  @override
  State<ShareFamilyTaskScreen> createState() => _ShareFamilyTaskScreenState();
}

class _ShareFamilyTaskScreenState extends State<ShareFamilyTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _familyRepository = serviceLocator.familyRepository;
  final _taskService = serviceLocator.taskService;

  FamilyModel? _family;
  List<FamilyMemberModel> _members = [];
  FamilyMemberModel? _selectedMember;
  DateTime _dueDate = DateTime.now();
  TimeOfDay _dueTime = TimeOfDay.now();
  bool _reminderEnabled = true;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadFamily();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadFamily() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final family = await _familyRepository.getUserFamily(uid);
      if (family != null) {
        final members = await _familyRepository.getFamilyMembers(family.id);
        members.removeWhere((m) => m.userId == uid);
        if (mounted) {
          setState(() {
            _family = family;
            _members = members;
            _selectedMember = members.isNotEmpty ? members.first : null;
          });
        }
      }
    } catch (_) {
      // The screen remains usable with a clear offline/error message.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() => _dueDate = DateTime(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _dueTime);
    if (picked != null) setState(() => _dueTime = picked);
  }

  Future<void> _assign() async {
    if (!_formKey.currentState!.validate() || _selectedMember == null || _family == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final due = DateTime(
        _dueDate.year,
        _dueDate.month,
        _dueDate.day,
        _dueTime.hour,
        _dueTime.minute,
      );
      final name = user.displayName ?? user.email?.split('@').first ?? 'Family member';
      final task = TaskModel(
        id: '',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        taskType: TaskType.familyTask,
        priority: TaskPriority.medium,
        status: TaskStatus.pending,
        ownerId: user.uid,
        createdBy: user.uid,
        createdByName: name,
        assignedTo: _selectedMember!.userId,
        assignedToName: _selectedMember!.name,
        familyId: _family!.id,
        visibility: 'family',
        dueDate: _dueDate,
        dueTime: due,
        reminderEnabled: _reminderEnabled,
        reminderMinutesBefore: 15,
        repeatType: RepeatType.none,
        createdAt: now,
        updatedAt: now,
      );

      await _taskService.createTask(task);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Task assigned to ${_selectedMember!.name}.'), backgroundColor: AppColors.success),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorFormatter.format(e)), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: Text('Share with Family', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _family == null
              ? _emptyFamilyState()
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                    children: [
                      _infoCard(),
                      const SizedBox(height: 20),
                      CustomTextField(
                        controller: _titleController,
                        labelText: 'Task Title *',
                        hintText: 'e.g. Check the car documents',
                        validator: (v) => v == null || v.trim().isEmpty ? 'Please enter a task title' : null,
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _descriptionController,
                        labelText: 'Instructions (Optional)',
                        hintText: 'Add details for the family member...',
                        maxLines: 3,
                      ),
                      const SizedBox(height: 20),
                      Text('Assign To', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedMember?.userId,
                        decoration: const InputDecoration(prefixIcon: Icon(Icons.person_outline), labelText: 'Family member'),
                        items: _members.map((member) => DropdownMenuItem(value: member.userId, child: Text(member.name))).toList(),
                        onChanged: (id) => setState(() => _selectedMember = _members.firstWhere((m) => m.userId == id)),
                        validator: (_) => _selectedMember == null ? 'Select a family member' : null,
                      ),
                      const SizedBox(height: 20),
                      Row(children: [Expanded(child: _dateField()), const SizedBox(width: 12), Expanded(child: _timeField())]),
                      const SizedBox(height: 20),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Reminder on assignee phone', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                        subtitle: Text('The family task remains a remote task; the assigned member can receive its local reminder.', style: GoogleFonts.outfit(fontSize: 12)),
                        value: _reminderEnabled,
                        onChanged: (v) => setState(() => _reminderEnabled = v),
                      ),
                      const SizedBox(height: 24),
                      GradientButton(text: _saving ? 'Assigning...' : 'Assign to Family', onPressed: _saving ? null : _assign, isLoading: _saving),
                    ],
                  ),
                ),
    );
  }

  Widget _infoCard() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.lightLavender, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          const Icon(Icons.groups_rounded, color: AppColors.primaryPurple),
          const SizedBox(width: 12),
          Expanded(child: Text('This task will be assigned in ${_family!.name}. Personal tasks stay on this device.', style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textPrimary))),
        ]),
      );

  Widget _dateField() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Due Date', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        InkWell(onTap: _pickDate, child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.inputBorder)), child: Row(children: [const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.primaryPurple), const SizedBox(width: 8), Expanded(child: Text(DateFormat('MMM d, yyyy').format(_dueDate), style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600)))]))),
      ]);

  Widget _timeField() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Device Time', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        InkWell(onTap: _pickTime, child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.inputBorder)), child: Row(children: [const Icon(Icons.schedule_rounded, size: 18, color: AppColors.primaryPurple), const SizedBox(width: 8), Expanded(child: Text(_dueTime.format(context), style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600)))]))),
      ]);

  Widget _emptyFamilyState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.group_off_rounded, size: 56, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text('Family sharing is unavailable', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('You need to be connected to your family space to assign a task. Your personal tasks still work offline.', textAlign: TextAlign.center, style: GoogleFonts.outfit(color: AppColors.textSecondary)),
          ]),
        ),
      );
}
