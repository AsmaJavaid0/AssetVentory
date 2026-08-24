import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/asset_avatar.dart';
import '../../assets/models/asset_model.dart';
import '../../auth/models/user_model.dart';
import '../../auth/services/firestore_service.dart';
import '../models/reminder_model.dart';
import '../models/task_model.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final _service = FirestoreService();
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    if (_uid.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return StreamBuilder<UserModel?>(
      stream: _service.streamUser(_uid),
      builder: (context, userSnapshot) {
        final familyId = userSnapshot.data?.familyId;
        return Scaffold(
          backgroundColor: AppColors.scaffoldBg,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => TaskEditorSheet.show(context, familyId: familyId),
            backgroundColor: AppColors.primaryPurple,
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: Text(
              'Add Task',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          body: SafeArea(
            child: StreamBuilder<List<TaskModel>>(
              stream: _service.streamVisibleTasks(_uid, familyId: familyId),
              builder: (context, snapshot) {
                final tasks = _filtered(snapshot.data ?? [], familyId);
                return RefreshIndicator(
                  color: AppColors.primaryPurple,
                  onRefresh: () async =>
                      Future<void>.delayed(const Duration(milliseconds: 350)),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    slivers: [
                      SliverToBoxAdapter(child: _header(tasks)),
                      SliverToBoxAdapter(child: _filters(familyId)),
                      if (snapshot.hasError)
                        SliverFillRemaining(
                          child: _message(
                            Icons.cloud_off_rounded,
                            'Could not load tasks',
                            'Check your connection and try again.',
                          ),
                        )
                      else if (tasks.isEmpty)
                        SliverFillRemaining(
                          child: _message(
                            Icons.task_alt_rounded,
                            'No tasks here yet',
                            'Create a task to keep actions and due dates in one place.',
                          ),
                        )
                      else ...[
                        if (tasks.any((task) => task.status != 'completed'))
                          SliverToBoxAdapter(child: _sectionTitle('To do')),
                        SliverList.builder(
                          itemCount: tasks
                              .where((task) => task.status != 'completed')
                              .length,
                          itemBuilder: (context, index) => _taskCard(
                            tasks
                                .where((task) => task.status != 'completed')
                                .elementAt(index),
                            familyId,
                          ),
                        ),
                        if (tasks.any((task) => task.status == 'completed'))
                          SliverToBoxAdapter(child: _sectionTitle('Completed')),
                        SliverList.builder(
                          itemCount: tasks
                              .where((task) => task.status == 'completed')
                              .length,
                          itemBuilder: (context, index) => _taskCard(
                            tasks
                                .where((task) => task.status == 'completed')
                                .elementAt(index),
                            familyId,
                          ),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 92)),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  List<TaskModel> _filtered(List<TaskModel> tasks, String? familyId) =>
      tasks.where((task) {
        if (_filter == 0) {
          return task.createdBy == _uid || task.assignedTo == _uid;
        }
        if (_filter == 1) {
          return task.createdBy == _uid;
        }
        return familyId != null &&
            task.visibility == 'family' &&
            task.familyId == familyId;
      }).toList();

  Widget _header(List<TaskModel> tasks) {
    final pending = tasks.where((task) => task.status != 'completed').length;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
      decoration: const BoxDecoration(gradient: AppColors.heroGradient),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tasks',
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            pending == 0
                ? 'You are all caught up.'
                : '$pending task${pending == 1 ? '' : 's'} need your attention.',
            style: GoogleFonts.outfit(
              color: AppColors.textWhite70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filters(String? familyId) {
    final labels = [
      'My Tasks',
      'Created by Me',
      if (familyId != null && familyId.isNotEmpty) 'Family',
    ];
    if (_filter >= labels.length) {
      _filter = 0;
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(
            labels.length,
            (index) => Padding(
              padding: EdgeInsets.only(
                right: index == labels.length - 1 ? 0 : 8,
              ),
              child: ChoiceChip(
                label: Text(
                  labels[index],
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                ),
                selected: _filter == index,
                selectedColor: AppColors.primaryPurple,
                labelStyle: TextStyle(
                  color: _filter == index
                      ? Colors.white
                      : AppColors.textSecondary,
                ),
                side: BorderSide(
                  color: _filter == index
                      ? AppColors.primaryPurple
                      : AppColors.lightLavenderBorder,
                ),
                onSelected: (_) => setState(() => _filter = index),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
    child: Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
    ),
  );

  Widget _message(IconData icon, String title, String body) => Center(
    child: Padding(
      padding: const EdgeInsets.all(36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 58, color: AppColors.primaryPurple.withAlpha(150)),
          const SizedBox(height: 14),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _taskCard(TaskModel task, String? familyId) {
    final completed = task.status == 'completed';
    final overdue =
        !completed &&
        task.dueDate.isBefore(
          DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
          ),
        );
    final due =
        '${_dateText(task.dueDate)}${task.dueTime == null ? '' : ' · ${TimeOfDay.fromDateTime(task.dueTime!).format(context)}'}';
    return Dismissible(
      key: ValueKey(task.id),
      direction: task.createdBy == _uid
          ? DismissDirection.endToStart
          : DismissDirection.none,
      confirmDismiss: (_) => _confirmDelete(task),
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.lightLavenderBorder),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(6, 8, 14, 8),
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: task.createdBy == _uid || task.assignedTo == _uid
                    ? () => _service.updateTaskStatus(
                        task.id,
                        completed ? 'pending' : 'completed',
                      )
                    : null,
                icon: Icon(
                  completed
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: completed ? AppColors.success : AppColors.primaryPurple,
                ),
              ),
              AssetAvatar(
                imageUrl: task.imageUrl,
                emoji: task.emoji ?? '📋',
                size: 34,
                borderRadius: 10,
                fontSize: 18,
                defaultIcon: Icons.task_alt_rounded,
              ),
            ],
          ),
          title: Text(
            task.title,
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              decoration: completed ? TextDecoration.lineThrough : null,
              color: completed ? AppColors.textMuted : AppColors.textPrimary,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _tag(
                  Icons.event_outlined,
                  due,
                  overdue ? AppColors.error : AppColors.textSecondary,
                ),
                if (task.assetId != null)
                  _tag(
                    Icons.inventory_2_outlined,
                    'Linked asset',
                    AppColors.textSecondary,
                  ),
                if (task.reminderId != null)
                  _tag(
                    Icons.notifications_none_rounded,
                    'Reminder',
                    AppColors.primaryPurple,
                  ),
                if (task.visibility == 'family')
                  _tag(Icons.group_outlined, 'Family', AppColors.info),
              ],
            ),
          ),
          trailing: task.createdBy == _uid
              ? IconButton(
                  icon: const Icon(Icons.more_horiz_rounded),
                  onPressed: () =>
                      TaskEditorSheet.show(context, task: task, familyId: familyId),
                )
              : null,
        ),
      ),
    );
  }

  Widget _tag(IconData icon, String text, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 3),
      Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
  String _dateText(DateTime date) {
    final today = DateTime.now();
    final day = DateTime(date.year, date.month, date.day);
    final base = DateTime(today.year, today.month, today.day);
    if (day == base) return 'Today';
    if (day == base.add(const Duration(days: 1))) return 'Tomorrow';
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<bool?> _confirmDelete(TaskModel task) => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete task?'),
      content: Text('“${task.title}” and its reminder will be deleted.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            await _service.deleteTask(task);
            if (context.mounted) Navigator.pop(context, true);
          },
          child: const Text('Delete', style: TextStyle(color: AppColors.error)),
        ),
      ],
    ),
  );
}

class TaskEditorSheet extends StatefulWidget {
  final TaskModel? task;
  final String? familyId;
  const TaskEditorSheet({super.key, this.task, this.familyId});

  static Future<void> show(
    BuildContext context, {
    TaskModel? task,
    String? familyId,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TaskEditorSheet(task: task, familyId: familyId),
    );
  }

  @override
  State<TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends State<TaskEditorSheet> {
  final _service = FirestoreService();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _title = TextEditingController(
    text: widget.task?.title ?? '',
  );
  late final TextEditingController _notes = TextEditingController(
    text: widget.task?.notes ?? '',
  );
  late DateTime _dueDate = widget.task?.dueDate ?? DateTime.now();
  late TimeOfDay? _dueTime = widget.task?.dueTime == null
      ? null
      : TimeOfDay.fromDateTime(widget.task!.dueTime!);
  late String? _assetId = widget.task?.assetId;
  late bool _reminder = widget.task?.reminderId != null;
  late String _visibility = widget.task?.visibility ?? 'personal';
  late String? _assignedTo = widget.task?.assignedTo;

  // Live reminder data for edit mode
  Stream<ReminderModel?>? _reminderStream;
  ReminderModel? _liveReminder;

  AssetModel? _selectedAsset;
  bool _saving = false;
  bool _deletingReminder = false;

  @override
  void initState() {
    super.initState();
    // If editing a task that already has a reminder, start streaming it
    // so we can show live details and react to deletion.
    final reminderId = widget.task?.reminderId;
    if (reminderId != null && reminderId.isNotEmpty) {
      _reminderStream = _service.streamReminder(reminderId);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: MediaQuery.sizeOf(context).height * .85,
        padding: EdgeInsets.fromLTRB(
          20,
          14,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        decoration: const BoxDecoration(
          color: AppColors.scaffoldBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.lightLavenderBorder,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                widget.task == null ? 'Create Task' : 'Edit Task',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 20),

              _input(
                _title,
                'Task title',
                Icons.task_alt_rounded,
                required: true,
              ),
              const SizedBox(height: 14),
              StreamBuilder<List<AssetModel>>(
                stream: _service.streamUserAssets(
                  FirebaseAuth.instance.currentUser!.uid,
                ),
                builder: (context, snapshot) => _assetPicker(
                  snapshot.data ?? [],
                  snapshot.connectionState == ConnectionState.waiting,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _dateButton()),
                  const SizedBox(width: 10),
                  Expanded(child: _timeButton()),
                ],
              ),
              const SizedBox(height: 14),
              if (widget.familyId != null && widget.familyId!.isNotEmpty)
                _visibilityPicker(),
              if (_visibility == 'assigned') _assigneePicker(),
              // Reminder toggle + live card
              _buildReminderSection(),

              _input(
                _notes,
                'Notes (optional)',
                Icons.notes_rounded,
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              // GradientButton ensures vibrant purple color and instant loading state
              GradientButton(
                text: widget.task == null ? 'Create Task' : 'Save Changes',
                isLoading: _saving,
                onPressed: _save,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _input(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool required = false,
    int maxLines = 1,
  }) => TextFormField(
    controller: controller,
    maxLines: maxLines,
    validator: required
        ? (value) => value == null || value.trim().isEmpty
              ? 'A title is required'
              : null
        : null,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.inputBorder),
      ),
    ),
  );

  Widget _assetPicker(List<AssetModel> assets, bool isLoading) {
    if (isLoading && assets.isEmpty) {
      return Container(
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.inputBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.inventory_2_outlined, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Text(
              'Loading assets...',
              style: GoogleFonts.outfit(color: AppColors.textSecondary),
            ),
            const Spacer(),
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ),
      );
    }

    final validAssetIds = assets.map((a) => a.id).toSet();
    final selectedAssetId = (_assetId != null && validAssetIds.contains(_assetId)) ? _assetId : null;

    return DropdownButtonFormField<String?>(
      initialValue: selectedAssetId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Related asset (optional)',
        prefixIcon: const Icon(Icons.inventory_2_outlined),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.inputBorder),
        ),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('No linked asset')),
        ...assets.map(
          (asset) => DropdownMenuItem(
            value: asset.id,
            child: Row(
              children: [
                AssetAvatar(
                  imageUrl: asset.imageUrl,
                  emoji: asset.emoji,
                  size: 24,
                  borderRadius: 6,
                  fontSize: 14,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    asset.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      onChanged: (value) => setState(() {
        _assetId = value;
        if (value != null) {
          try {
            _selectedAsset = assets.firstWhere((a) => a.id == value);
          } catch (_) {
            _selectedAsset = null;
          }
        } else {
          _selectedAsset = null;
        }
      }),
    );
  }

  Widget _dateButton() => OutlinedButton.icon(
    onPressed: () async {
      final value = await showDatePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
        initialDate: _dueDate,
      );
      if (value != null) setState(() => _dueDate = value);
    },
    icon: const Icon(Icons.calendar_today_outlined),
    label: Text('${_dueDate.day}/${_dueDate.month}/${_dueDate.year}'),
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(0, 52),
      foregroundColor: AppColors.textPrimary,
      backgroundColor: Colors.white,
      side: const BorderSide(color: AppColors.inputBorder),
    ),
  );

  Widget _timeButton() => OutlinedButton.icon(
    onPressed: () async {
      final value = await showTimePicker(
        context: context,
        initialTime: _dueTime ?? TimeOfDay.now(),
      );
      if (value != null) setState(() => _dueTime = value);
    },
    icon: const Icon(Icons.access_time_outlined),
    label: Text(_dueTime?.format(context) ?? 'Add time'),
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(0, 52),
      foregroundColor: AppColors.textPrimary,
      backgroundColor: Colors.white,
      side: const BorderSide(color: AppColors.inputBorder),
    ),
  );

  Widget _visibilityPicker() => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: DropdownButtonFormField<String>(
      initialValue: ['personal', 'assigned', 'family'].contains(_visibility) ? _visibility : 'personal',
      decoration: InputDecoration(
        labelText: 'Visibility',
        prefixIcon: const Icon(Icons.visibility_outlined),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.inputBorder),
        ),
      ),
      items: const [
        DropdownMenuItem(value: 'personal', child: Text('Personal')),
        DropdownMenuItem(
          value: 'assigned',
          child: Text('Assign to family member'),
        ),
        DropdownMenuItem(value: 'family', child: Text('Family')),
      ],
      onChanged: (value) => setState(() {
        _visibility = value ?? 'personal';
        if (_visibility != 'assigned') _assignedTo = null;
      }),
    ),
  );

  Widget _buildReminderSection() {
    final isEditing = widget.task != null;
    final existingReminderId = widget.task?.reminderId;

    // If editing and already has a reminder, show live card via stream
    if (isEditing && existingReminderId != null && existingReminderId.isNotEmpty) {
      return StreamBuilder<ReminderModel?>(
        stream: _reminderStream,
        builder: (context, snapshot) {
          final reminder = snapshot.data;

          // Reminder was deleted remotely — sync local toggle
          if (snapshot.connectionState != ConnectionState.waiting && reminder == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _reminder) setState(() => _reminder = false);
            });
          }

          if (_reminder && reminder != null) {
            return _reminderCard(reminder, existingReminderId);
          }

          return _reminderToggle();
        },
      );
    }

    return _reminderToggle();
  }

  Widget _reminderToggle() {
    return Column(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _reminder,
          activeThumbColor: AppColors.primaryPurple,
          title: Text(
            'Add reminder',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            _reminder
                ? 'Smart notification will be scheduled for this task.'
                : 'Optional — you can complete this without one.',
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          onChanged: (value) => setState(() => _reminder = value),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _reminderCard(ReminderModel reminder, String reminderId) {
    final dateStr =
        '${reminder.reminderDate.day}/${reminder.reminderDate.month}/${reminder.reminderDate.year}';
    final timeStr = reminder.reminderTime != null
        ? TimeOfDay.fromDateTime(reminder.reminderTime!).format(context)
        : null;

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF1EDFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2D9F8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryPurple.withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.notifications_active_rounded,
                      color: AppColors.primaryPurple,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reminder set',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          timeStr != null ? '$dateStr · $timeStr' : dateStr,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed:
                      _deletingReminder ? null : () => _deleteReminder(reminderId),
                  icon: _deletingReminder
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.error,
                          ),
                        )
                      : const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: AppColors.error,
                        ),
                  label: Text(
                    'Delete Reminder',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      color: AppColors.error,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Future<void> _deleteReminder(String reminderId) async {
    final taskId = widget.task?.id;
    if (taskId == null || taskId.isEmpty) return;
    setState(() => _deletingReminder = true);
    try {
      await _service.deleteReminderOnly(reminderId, taskId);
      if (!mounted) return;
      setState(() {
        _deletingReminder = false;
        _reminder = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Reminder deleted',
            style: GoogleFonts.outfit(),
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('Error deleting reminder: $e');
      if (!mounted) return;
      setState(() => _deletingReminder = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to delete reminder. Please try again.',
            style: GoogleFonts.outfit(),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _assigneePicker() => StreamBuilder<List<UserModel>>(
    stream: _service.streamFamilyMembers(widget.familyId!),
    builder: (context, snapshot) {
      final members = snapshot.data ?? [];
      final validUids = members.map((m) => m.id).toSet();
      final selectedAssignee = (_assignedTo != null && validUids.contains(_assignedTo)) ? _assignedTo : null;

      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: DropdownButtonFormField<String>(
          initialValue: selectedAssignee,
          validator: (value) => value == null ? 'Choose an assignee' : null,
          decoration: InputDecoration(
            labelText: 'Assign to',
            prefixIcon: const Icon(Icons.person_add_alt_1_outlined),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.inputBorder),
            ),
          ),
          items: members
              .map(
                (member) => DropdownMenuItem(
                  value: member.id,
                  child: Text(member.name.isEmpty ? member.email : member.name),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => _assignedTo = value),
        ),
      );
    },
  );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    final now = DateTime.now();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final dueTime = _dueTime == null
        ? null
        : DateTime(
            _dueDate.year,
            _dueDate.month,
            _dueDate.day,
            _dueTime!.hour,
            _dueTime!.minute,
          );
    final existing = widget.task;

    final task = TaskModel(
      id: existing?.id ?? '',
      familyId: _visibility == 'personal' ? null : widget.familyId,
      createdBy: existing?.createdBy ?? uid,
      assignedTo: _visibility == 'assigned' ? _assignedTo : null,
      visibility: _visibility,
      title: _title.text.trim(),
      emoji: _selectedAsset?.emoji ?? existing?.emoji,
      imageUrl: _selectedAsset?.imageUrl ?? existing?.imageUrl,
      assetId: _assetId,
      dueDate: _dueDate,
      dueTime: dueTime,
      reminderId: existing?.reminderId,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      status: existing?.status ?? 'pending',
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    final reminder = _reminder
        ? ReminderModel(
            id: existing?.reminderId ?? '',
            ownerId: uid,
            taskId: task.id,
            title: task.title,
            reminderDate: _dueDate,
            reminderTime: dueTime,
            createdAt: now,
            updatedAt: now,
          )
        : null;

    try {
      if (existing == null) {
        await _service.createTask(task, reminder: reminder);
      } else {
        await _service.updateTask(task, reminder: reminder);
      }
      if (!mounted) return;
      setState(() => _saving = false);
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Error saving task: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save task. Please try again.'),
        ),
      );
    }
  }
}

