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

class EditTaskScreen extends StatefulWidget {
  final TaskModel task;

  const EditTaskScreen({
    super.key,
    required this.task,
  });

  static Future<void> navigateTo(BuildContext context, TaskModel task) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditTaskScreen(task: task),
      ),
    );
  }

  @override
  State<EditTaskScreen> createState() => _EditTaskScreenState();
}

class _EditTaskScreenState extends State<EditTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;

  final _taskService = serviceLocator.taskService;
  final _familyRepository = serviceLocator.familyRepository;
  final _assetRepository = serviceLocator.assetRepository;

  late TaskType _taskType;
  late TaskPriority _priority;
  late TaskStatus _status;

  LocalAsset? _selectedAsset;
  late DateTime _dueDate;
  TimeOfDay? _dueTime;
  late bool _isAllDay;

  late bool _reminderEnabled;
  late int _reminderMinutesBefore;

  late RepeatType _repeatType;

  FamilyModel? _userFamily;
  FamilyMemberModel? _assignedMember;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _titleController = TextEditingController(text: t.title);
    _descriptionController = TextEditingController(text: t.description ?? '');

    _taskType = t.taskType;
    _priority = t.priority;
    _status = t.status;

    _dueDate = t.dueDate;
    if (t.dueTime != null) {
      _dueTime = TimeOfDay.fromDateTime(t.dueTime!);
    }
    _isAllDay = t.isAllDay;

    _reminderEnabled = t.reminderEnabled;
    _reminderMinutesBefore = t.reminderMinutesBefore;

    _repeatType = t.repeatType;

    _loadInitialAsset();
    _checkFamilyMembership();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialAsset() async {
    if (widget.task.assetId != null && widget.task.assetId!.isNotEmpty) {
      try {
        final asset = await _assetRepository.getAsset(widget.task.assetId!);
        if (asset != null && mounted) {
          setState(() => _selectedAsset = asset);
        }
      } catch (_) {}
    }
  }

  Future<void> _checkFamilyMembership() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final family = await _familyRepository.getUserFamily(user.uid);
        if (mounted) {
          setState(() => _userFamily = family);
        }
      } catch (_) {}
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
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _dueTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _dueTime = picked);
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? 'local_user';
    final uname = user?.displayName ?? user?.email?.split('@').first ?? 'Local User';

    setState(() => _isSaving = true);

    try {
      DateTime? dueDateTime;
      if (_dueTime != null && !_isAllDay) {
        dueDateTime = DateTime(
          _dueDate.year,
          _dueDate.month,
          _dueDate.day,
          _dueTime!.hour,
          _dueTime!.minute,
        );
      }

      final isFamilyAssignment = _assignedMember != null && _assignedMember!.userId != uid;

      final updatedTask = widget.task.copyWith(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        taskType: isFamilyAssignment ? TaskType.familyTask : _taskType,
        priority: _priority,
        status: _status,
        assignedTo: _assignedMember?.userId ?? widget.task.assignedTo,
        assignedToName: _assignedMember?.name ?? widget.task.assignedToName ?? uname,
        assetId: _selectedAsset?.id,
        assetName: _selectedAsset?.name,
        assetEmoji: _selectedAsset?.emoji,
        dueDate: _dueDate,
        dueTime: dueDateTime,
        isAllDay: _isAllDay,
        reminderEnabled: _reminderEnabled,
        reminderMinutesBefore: _reminderMinutesBefore,
        repeatType: _repeatType,
        updatedAt: DateTime.now(),
      );

      await _taskService.updateTask(updatedTask);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task updated successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorFormatter.format(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: Text(
          'Edit Task',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          children: [
            // Title
            CustomTextField(
              controller: _titleController,
              labelText: 'Task Title *',
              hintText: 'e.g. Service bike',
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a task title' : null,
            ),
            const SizedBox(height: 16),

            // Description
            CustomTextField(
              controller: _descriptionController,
              labelText: 'Description (Optional)',
              hintText: 'Add details...',
              maxLines: 3,
            ),
            const SizedBox(height: 20),

            // Task Type Selector
            Text(
              'Task Type',
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: TaskType.values.where((t) => t != TaskType.familyTask).map((type) {
                final isSelected = type == _taskType;
                return ChoiceChip(
                  label: Text('${type.icon} ${type.label}'),
                  selected: isSelected,
                  selectedColor: AppColors.primaryPurple,
                  backgroundColor: Colors.white,
                  labelStyle: GoogleFonts.outfit(
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 13,
                  ),
                  onSelected: (_) => setState(() => _taskType = type),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Associated Asset
            Text(
              'Associated Asset',
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: () async {
                final asset = await AssetPickerSheet.show(
                  context,
                  selectedAsset: _selectedAsset,
                );
                setState(() => _selectedAsset = asset);
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.inputBorder),
                ),
                child: Row(
                  children: [
                    Text(
                      _selectedAsset?.emoji ?? widget.task.assetEmoji ?? '📦',
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedAsset?.name ?? widget.task.assetName ?? 'No asset selected',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: (_selectedAsset != null || widget.task.assetName != null)
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: (_selectedAsset != null || widget.task.assetName != null)
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Date & Time Row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Due Date *',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.inputBorder),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.primaryPurple),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  DateFormat('MMM d, yyyy').format(_dueDate),
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (!_isAllDay)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Time',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: _pickTime,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.inputBorder),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time_rounded, size: 18, color: AppColors.primaryPurple),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _dueTime != null
                                        ? _dueTime!.format(context)
                                        : 'Select time',
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            // All-day switch
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'All-day Task',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              value: _isAllDay,
              activeTrackColor: AppColors.primaryPurple,
              onChanged: (val) => setState(() => _isAllDay = val),
            ),

            const Divider(height: 24),

            // Priority
            Text(
              'Priority',
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: TaskPriority.values.map((p) {
                final isSelected = p == _priority;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: ChoiceChip(
                      label: Text(p.label),
                      selected: isSelected,
                      selectedColor: AppColors.primaryPurple,
                      backgroundColor: Colors.white,
                      labelStyle: GoogleFonts.outfit(
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        fontSize: 12,
                      ),
                      onSelected: (_) => setState(() => _priority = p),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Reminder
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Enable Reminder',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              value: _reminderEnabled,
              activeTrackColor: AppColors.primaryPurple,
              onChanged: (val) => setState(() => _reminderEnabled = val),
            ),

            if (_reminderEnabled) ...[
              DropdownButtonFormField<int>(
                initialValue: _reminderMinutesBefore,
                decoration: const InputDecoration(
                  labelText: 'Remind Me',
                  prefixIcon: Icon(Icons.notifications_active_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('At time of task')),
                  DropdownMenuItem(value: 5, child: Text('5 minutes before')),
                  DropdownMenuItem(value: 10, child: Text('10 minutes before')),
                  DropdownMenuItem(value: 15, child: Text('15 minutes before')),
                  DropdownMenuItem(value: 30, child: Text('30 minutes before')),
                  DropdownMenuItem(value: 60, child: Text('1 hour before')),
                  DropdownMenuItem(value: 1440, child: Text('1 day before')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _reminderMinutesBefore = val);
                },
              ),
              const SizedBox(height: 16),
            ],

            // Repeat
            DropdownButtonFormField<RepeatType>(
              initialValue: _repeatType,
              decoration: const InputDecoration(
                labelText: 'Repeat',
                prefixIcon: Icon(Icons.repeat_rounded),
              ),
              items: RepeatType.values.map((r) {
                return DropdownMenuItem(value: r, child: Text(r.label));
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _repeatType = val);
              },
            ),
            const SizedBox(height: 20),

            // Family Member Assignment (if user belongs to a family)
            if (_userFamily != null) ...[
              const Divider(height: 24),
              Text(
                'Family Assignment',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () async {
                  final currentUser = FirebaseAuth.instance.currentUser;
                  final member = await FamilyMemberPickerSheet.show(
                    context,
                    familyId: _userFamily!.id,
                    currentUserId: currentUser?.uid ?? '',
                    selectedUserId: _assignedMember?.userId ?? widget.task.assignedTo,
                  );
                  if (member != null) {
                    setState(() => _assignedMember = member);
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.inputBorder),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.primaryPurple,
                        child: Icon(Icons.person_rounded, size: 16, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _assignedMember != null
                              ? _assignedMember!.name
                              : widget.task.assignedToName ?? 'Myself',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ] else
              const SizedBox(height: 24),

            // Save Changes Button
            GradientButton(
              text: 'Save Changes',
              isLoading: _isSaving,
              onPressed: _saveChanges,
            ),
          ],
        ),
      ),
    );
  }
}
