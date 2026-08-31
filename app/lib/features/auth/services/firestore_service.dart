import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/utils/result.dart';
import '../models/user_model.dart';
import '../../assets/models/asset_model.dart';
import '../../assets/models/category_model.dart';
import '../../assets/models/document_model.dart';
import '../../tasks/models/task_model.dart';
import '../../tasks/models/reminder_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersCollection => _firestore.collection('users');
  CollectionReference<Map<String, dynamic>> get _assetsCollection => _firestore.collection('assets');
  CollectionReference<Map<String, dynamic>> get _categoriesCollection => _firestore.collection('categories');
  CollectionReference<Map<String, dynamic>> get _documentsCollection => _firestore.collection('documents');
  CollectionReference<Map<String, dynamic>> get _remindersCollection => _firestore.collection('reminders');
  CollectionReference<Map<String, dynamic>> get _tasksCollection => _firestore.collection('tasks');

  Future<void> createOrUpdateUser({required String uid, required String name, required String email, String? photoUrl, String? familyId}) async {
    try {
      final userDocRef = _usersCollection.doc(uid);
      final now = DateTime.now();
      final updateData = <String, dynamic>{
        'name': name.isNotEmpty ? name : email.split('@').first,
        'email': email,
        'updatedAt': Timestamp.fromDate(now),
      };
      if (photoUrl != null && photoUrl.isNotEmpty) updateData['photoUrl'] = photoUrl;
      if (familyId != null) updateData['familyId'] = familyId;
      await userDocRef.set(updateData, SetOptions(merge: true));
    } catch (e) {
      // Non-fatal for profile synchronization.
    }
  }

  Future<Result<UserModel>> getUser(String uid) async {
    try {
      final doc = await _usersCollection.doc(uid).get();
      if (doc.exists) return Result.success(UserModel.fromFirestore(doc));
      return Result.failure(StorageException('User not found'));
    } catch (e) {
      return Result.failure(StorageException(e.toString()));
    }
  }

  Stream<UserModel?> streamUser(String uid) => _usersCollection.doc(uid).snapshots().map((doc) => doc.exists ? UserModel.fromFirestore(doc) : null);

  Stream<List<AssetModel>> streamUserAssets(String ownerId) => _assetsCollection.where('ownerId', isEqualTo: ownerId).orderBy('createdAt', descending: true).snapshots().map((snapshot) => snapshot.docs.map((doc) => AssetModel.fromFirestore(doc)).toList());

  Stream<List<AssetModel>> streamRecentAssets(String ownerId, {int limit = 5}) => _assetsCollection.where('ownerId', isEqualTo: ownerId).orderBy('createdAt', descending: true).limit(limit).snapshots().map((snapshot) => snapshot.docs.map((doc) => AssetModel.fromFirestore(doc)).toList());

  Stream<List<ReminderModel>> streamUpcomingReminders(String ownerId, {int limit = 5}) {
    return _remindersCollection.where('ownerId', isEqualTo: ownerId).snapshots().map((snapshot) {
      final list = snapshot.docs.map((doc) => ReminderModel.fromFirestore(doc)).where((r) => r.status == 'active').toList();
      list.sort((a, b) => a.reminderDate.compareTo(b.reminderDate));
      return list.take(limit).toList();
    });
  }

  Stream<List<TaskModel>> streamPendingTasks(String uid, {String? familyId}) {
    return _tasksCollection.where('assignedTo', isEqualTo: uid).snapshots().map((snapshot) {
      final list = snapshot.docs.map((doc) => TaskModel.fromFirestore(doc)).where((task) => task.status == TaskStatus.pending).toList();
      list.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      return list;
    });
  }

  /// Streams tasks visible to the current user from two independent queries:
  /// tasks assigned to the user and family tasks created by the user.
  ///
  /// Keeping these as separate queries avoids a broad family query and avoids
  /// relying on a composite OR query/index. Results are merged by document ID.
  Stream<List<TaskModel>> streamVisibleTasks(String uid, {String? familyId}) {
    final assignedStream = _tasksCollection
        .where('assignedTo', isEqualTo: uid)
        .snapshots();
    final createdStream = _tasksCollection
        .where('createdBy', isEqualTo: uid)
        .snapshots();

    return Stream.multi((controller) {
      var assignedDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      var createdDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

      void emit() {
        final byId = <String, TaskModel>{};
        for (final doc in [...assignedDocs, ...createdDocs]) {
          final task = TaskModel.fromFirestore(doc);
          if (task.assignedTo == uid || task.createdBy == uid) {
            // A task with a familyId is family-shared. Personal tasks are also
            // allowed here because the existing personal-task compatibility
            // path may mirror them into Firestore.
            byId[task.id] = task;
          }
        }
        final tasks = byId.values.toList()
          ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
        controller.add(tasks);
      }

      final assignedSub = assignedStream.listen(
        (snapshot) {
          assignedDocs = snapshot.docs;
          emit();
        },
        onError: controller.addError,
      );
      final createdSub = createdStream.listen(
        (snapshot) {
          createdDocs = snapshot.docs;
          emit();
        },
        onError: controller.addError,
      );

      controller.onCancel = () async {
        await assignedSub.cancel();
        await createdSub.cancel();
      };
    });
  }

  Future<TaskModel?> getTask(String taskId) async {
    try {
      final doc = await _tasksCollection.doc(taskId).get();
      if (!doc.exists) return null;
      return TaskModel.fromFirestore(doc);
    } catch (_) {
      return null;
    }
  }

  Future<String> addTask(TaskModel task) async => (await _tasksCollection.add(task.toFirestore())).id;

  /// Creates a task and only returns after Firestore has accepted the write.
  Future<String> createTask(TaskModel task) async {
    final docRef = task.id.isNotEmpty ? _tasksCollection.doc(task.id) : _tasksCollection.doc();
    final taskData = task.copyWith(id: docRef.id).toFirestore();
    await docRef.set(taskData, SetOptions(merge: true));
    return docRef.id;
  }

  Future<void> updateTask(TaskModel task) async {
    await _tasksCollection.doc(task.id).update({
      ...task.toFirestore(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> completeTask(String taskId, {required String completedBy, String? completedByName}) async {
    final now = DateTime.now();
    await _tasksCollection.doc(taskId).update({
      'status': TaskStatus.completed.toFirestore(),
      'completedBy': completedBy,
      'completedByName': completedByName,
      'completedAt': Timestamp.fromDate(now),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> snoozeTask(String taskId, DateTime snoozeUntil) async {
    await _tasksCollection.doc(taskId).update({
      'snoozedUntil': Timestamp.fromDate(snoozeUntil),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteTask(String taskId) async {
    await _tasksCollection.doc(taskId).delete();
  }
}
