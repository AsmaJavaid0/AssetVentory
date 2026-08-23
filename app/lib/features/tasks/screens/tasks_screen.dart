import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
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
            onPressed: () => _openEditor(context, familyId: familyId),
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
          contentPadding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
          leading: IconButton(
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
                      _openEditor(context, task: task, familyId: familyId),
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

  Future<void> _openEditor(
    BuildContext context, {
    TaskModel? task,
    String? familyId,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TaskEditor(task: task, familyId: familyId),
    );
  }
}

class _TaskEditor extends StatefulWidget {
  final TaskModel? task;
  final String? familyId;
  const _TaskEditor({this.task, this.familyId});
  @override
  State<_TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<_TaskEditor> {
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
  bool _saving = false;
  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      height: MediaQuery.sizeOf(context).height * .88,
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
              builder: (context, snapshot) => _assetPicker(snapshot.data ?? []),
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
            _input(
              _notes,
              'Notes (optional)',
              Icons.notes_rounded,
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      widget.task == null ? 'Create Task' : 'Save Changes',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w800),
                    ),
            ),
          ],
        ),
      ),
    ),
  );

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
  Widget _assetPicker(List<AssetModel> assets) =>
      DropdownButtonFormField<String?>(
        initialValue: _assetId,
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
              child: Text(
                '${asset.emoji ?? '📦'} ${asset.name}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
        onChanged: (value) => setState(() => _assetId = value),
      );
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
      initialValue: _visibility,
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

  Widget _assigneePicker() => StreamBuilder<List<UserModel>>(
    stream: _service.streamFamilyMembers(widget.familyId!),
    builder: (context, snapshot) {
      final members = snapshot.data ?? [];
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: DropdownButtonFormField<String>(
          initialValue: _assignedTo,
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
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save task. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
