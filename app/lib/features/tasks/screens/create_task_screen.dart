import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../assets/models/local_asset.dart';
import '../../family/models/family_member_model.dart';
import '../../family/models/family_model.dart';
import '../models/task_model.dart';
import '../widgets/asset_picker_sheet.dart';
import '../widgets/family_member_picker.dart';

class CreateTaskScreen extends StatefulWidget {
  final LocalAsset? preselectedAsset;
  const CreateTaskScreen({super.key, this.preselectedAsset});
  static Future<void> navigateTo(BuildContext context, {LocalAsset? preselectedAsset}) => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateTaskScreen(preselectedAsset: preselectedAsset)));
  @override State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _taskService = serviceLocator.taskService;
  final _familyRepository = serviceLocator.familyRepository;
  TaskType _taskType = TaskType.generalTask;
  TaskPriority _priority = TaskPriority.medium;
  LocalAsset? _selectedAsset;
  DateTime _dueDate = DateTime.now();
  TimeOfDay _dueTime = TimeOfDay.now();
  bool _isAllDay = false;
  bool _reminderEnabled = true;
  int _reminderMinutesBefore = 15;
  RepeatType _repeatType = RepeatType.none;
  FamilyModel? _userFamily;
  FamilyMemberModel? _assignedMember;
  bool _isLoadingFamily = true;
  bool _isSaving = false;

  @override void initState() { super.initState(); _selectedAsset = widget.preselectedAsset; _reminderMinutesBefore = serviceLocator.preferences.defaultReminderMinutes; _reminderEnabled = serviceLocator.preferences.taskRemindersEnabled; _checkFamilyMembership(); }
  @override void dispose() { _titleController.dispose(); _descriptionController.dispose(); super.dispose(); }

  Future<void> _checkFamilyMembership() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) { try { final family = await _familyRepository.getUserFamily(user.uid); if (mounted) setState(() { _userFamily = family; _isLoadingFamily = false; }); } catch (_) { if (mounted) setState(() => _isLoadingFamily = false); } }
    else if (mounted) setState(() => _isLoadingFamily = false);
  }
  Future<void> _pickDate() async { final now = DateTime.now(); final picked = await showDatePicker(context: context, initialDate: _dueDate, firstDate: now.subtract(const Duration(days: 365)), lastDate: now.add(const Duration(days: 365 * 5))); if (picked != null) setState(() => _dueDate = DateTime(picked.year, picked.month, picked.day)); }
  Future<void> _pickTime() async { final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now()); if (picked != null) setState(() => _dueTime = picked); }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? 'local_user';
    final uname = user?.displayName ?? user?.email?.split('@').first ?? 'Local User';
    setState(() => _isSaving = true);
    try {
      final now = DateTime.now();
      final dueDateTime = !_isAllDay ? DateTime(_dueDate.year, _dueDate.month, _dueDate.day, _dueTime.hour, _dueTime.minute) : null;
      final isFamilyAssignment = _assignedMember != null && _assignedMember!.userId != uid;
      final task = TaskModel(id: '', title: _titleController.text.trim(), description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(), taskType: isFamilyAssignment ? TaskType.familyTask : _taskType, priority: _priority, status: TaskStatus.pending, ownerId: uid, createdBy: uid, createdByName: uname, assignedTo: _assignedMember?.userId ?? uid, assignedToName: _assignedMember?.name ?? uname, familyId: _userFamily?.id, visibility: isFamilyAssignment ? 'family' : 'personal', assetId: _selectedAsset?.id, assetName: _selectedAsset?.name, assetEmoji: _selectedAsset?.emoji, dueDate: _dueDate, dueTime: dueDateTime, isAllDay: _isAllDay, reminderEnabled: _reminderEnabled, reminderMinutesBefore: _reminderMinutesBefore, repeatType: _repeatType, createdAt: now, updatedAt: now);
      await _taskService.createTask(task);
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task created successfully!'), backgroundColor: AppColors.success)); Navigator.pop(context); }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ErrorFormatter.format(e)), backgroundColor: AppColors.error)); }
    finally { if (mounted) setState(() => _isSaving = false); }
  }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.scaffoldBg,
    appBar: AppBar(title: Text('Create Task', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppColors.textPrimary)), backgroundColor: Colors.white, elevation: 0, leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary), onPressed: () => Navigator.pop(context))),
    body: Form(key: _formKey, child: ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 40), children: [
      CustomTextField(controller: _titleController, labelText: 'Task Title *', hintText: 'e.g. Oil change for bike', validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a task title' : null),
      const SizedBox(height: 16),
      CustomTextField(controller: _descriptionController, labelText: 'Description (Optional)', hintText: 'Add details, notes or instructions...', maxLines: 3),
      const SizedBox(height: 20),
      Text('Task Type', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)), const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: TaskType.values.where((t) => t != TaskType.familyTask).map((type) { final selected = type == _taskType; return ChoiceChip(label: Text('${type.icon} ${type.label}'), selected: selected, selectedColor: AppColors.primaryPurple, backgroundColor: Colors.white, labelStyle: GoogleFonts.outfit(color: selected ? Colors.white : AppColors.textPrimary, fontWeight: selected ? FontWeight.w600 : FontWeight.normal, fontSize: 13), onSelected: (_) => setState(() => _taskType = type)); }).toList()),
      const SizedBox(height: 20),
      Text('Associated Asset', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)), const SizedBox(height: 6),
      InkWell(onTap: () async { final asset = await AssetPickerSheet.show(context, selectedAsset: _selectedAsset); if (mounted) setState(() => _selectedAsset = asset); }, borderRadius: BorderRadius.circular(16), child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.inputBorder)), child: Row(children: [Text(_selectedAsset?.emoji ?? '📦', style: const TextStyle(fontSize: 20)), const SizedBox(width: 12), Expanded(child: Text(_selectedAsset?.name ?? 'No asset selected', style: GoogleFonts.outfit(fontSize: 15, fontWeight: _selectedAsset != null ? FontWeight.w600 : FontWeight.normal, color: _selectedAsset != null ? AppColors.textPrimary : AppColors.textMuted))), const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted)]))),
      const SizedBox(height: 20),
      Row(children: [Expanded(child: _dateField()), const SizedBox(width: 12), Expanded(child: _timeField())]),
      const SizedBox(height: 20),
      SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, title: Text('Reminder', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)), subtitle: Text('Use this phone\'s local time for the alarm', style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)), value: _reminderEnabled, activeColor: AppColors.primaryPurple, onChanged: (v) => setState(() => _reminderEnabled = v)),
      if (_reminderEnabled) ...[const SizedBox(height: 8), DropdownButtonFormField<int>(value: _reminderMinutesBefore, decoration: const InputDecoration(labelText: 'Remind me before'), items: const [5, 10, 15, 30, 60, 120].map((m) => DropdownMenuItem(value: m, child: Text('$m minutes before'))).toList(), onChanged: (v) { if (v != null) setState(() => _reminderMinutesBefore = v); })],
      const SizedBox(height: 24),
      GradientButton(text: _isSaving ? 'Saving...' : 'Save Task', onPressed: _isSaving ? null : _saveTask, isLoading: _isSaving),
    ]),),
  );

  Widget _dateField() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Due Date *', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)), const SizedBox(height: 6), InkWell(onTap: _pickDate, borderRadius: BorderRadius.circular(16), child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.inputBorder)), child: Row(children: [const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.primaryPurple), const SizedBox(width: 8), Expanded(child: Text(DateFormat('MMM d, yyyy').format(_dueDate), style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600)))]))) ]);
  Widget _timeField() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Device Time', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)), const SizedBox(height: 6), InkWell(onTap: _pickTime, borderRadius: BorderRadius.circular(16), child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.inputBorder)), child: Row(children: [const Icon(Icons.schedule_rounded, size: 19, color: AppColors.primaryPurple), const SizedBox(width: 8), Expanded(child: Text(_dueTime.format(context), style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600)))]))) ]);
}
