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

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _assetsCollection =>
      _firestore.collection('assets');

  CollectionReference<Map<String, dynamic>> get _categoriesCollection =>
      _firestore.collection('categories');

  CollectionReference<Map<String, dynamic>> get _documentsCollection =>
      _firestore.collection('documents');

  CollectionReference<Map<String, dynamic>> get _remindersCollection =>
      _firestore.collection('reminders');

  CollectionReference<Map<String, dynamic>> get _tasksCollection =>
      _firestore.collection('tasks');

  /// Creates or updates a user document in users/{userId}
  Future<void> createOrUpdateUser({
    required String uid,
    required String name,
    required String email,
    String? photoUrl,
    String? familyId,
  }) async {
    try {
      final userDocRef = _usersCollection.doc(uid);
      final now = DateTime.now();

      final updateData = <String, dynamic>{
        'name': name.isNotEmpty ? name : email.split('@').first,
        'email': email,
        'updatedAt': Timestamp.fromDate(now),
      };

      if (photoUrl != null && photoUrl.isNotEmpty) {
        updateData['photoUrl'] = photoUrl;
      }
      if (familyId != null) {
        updateData['familyId'] = familyId;
      }

      // set with merge doesn't require a blocking get() call
      await userDocRef.set(updateData, SetOptions(merge: true));
    } catch (e) {
      // Non-fatal: offline client will sync when connection is established
    }
  }

  /// Fetches the user profile by UID
  Future<Result<UserModel>> getUser(String uid) async {
    try {
      final doc = await _usersCollection.doc(uid).get();
      if (doc.exists) {
        return Result.success(UserModel.fromFirestore(doc));
      }
      return Result.failure(StorageException('User not found'));
    } catch (e) {
      return Result.failure(StorageException(e.toString()));
    }
  }

  /// Stream of user profile updates
  Stream<UserModel?> streamUser(String uid) {
    return _usersCollection.doc(uid).snapshots().map((doc) {
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    });
  }

  /// Stream all assets owned by user
  Stream<List<AssetModel>> streamUserAssets(String ownerId) {
    return _assetsCollection
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => AssetModel.fromFirestore(doc))
              .toList();
        });
  }

  /// Stream top N recent assets
  Stream<List<AssetModel>> streamRecentAssets(String ownerId, {int limit = 5}) {
    return _assetsCollection
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => AssetModel.fromFirestore(doc))
              .toList();
        });
  }

  /// Stream active upcoming reminders for user
  Stream<List<ReminderModel>> streamUpcomingReminders(
    String ownerId, {
    int limit = 5,
  }) {
    return _remindersCollection
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => ReminderModel.fromFirestore(doc))
              .where((r) => r.status == 'active')
              .toList();
          list.sort((a, b) => a.reminderDate.compareTo(b.reminderDate));
          return list.take(limit).toList();
        });
  }

  /// Stream pending tasks for user.
  ///
  /// IMPORTANT: this used to be `_tasksCollection.snapshots()` with no
  /// `.where()` at all, meaning it downloaded and listened to every task
  /// belonging to every user of the app, then filtered client-side. That is
  /// the main source of the app-wide lag: it re-downloads the whole
  /// collection every time this stream is (re)subscribed to. This version
  /// filters on the server using `Filter.or`, so only the documents the
  /// user is actually allowed to see are ever transferred.
  Stream<List<TaskModel>> streamPendingTasks(String uid, {String? familyId}) {
    final hasFamily = familyId != null && familyId.isNotEmpty;

    final filter = hasFamily
        ? Filter.or(
            Filter('createdBy', isEqualTo: uid),
            Filter('assignedTo', isEqualTo: uid),
            Filter('familyId', isEqualTo: familyId),
          )
        : Filter.or(
            Filter('createdBy', isEqualTo: uid),
            Filter('assignedTo', isEqualTo: uid),
          );

    return _tasksCollection.where(filter).snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => TaskModel.fromFirestore(doc))
          .where((task) => task.status == TaskStatus.pending)
          .toList();
      list.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      return list;
    });
  }

  /// Stream all tasks visible to user (created by user, assigned to user, or family tasks).
  Stream<List<TaskModel>> streamVisibleTasks(String uid, {String? familyId}) {
    final hasFamily = familyId != null && familyId.isNotEmpty;
    final filter = hasFamily
        ? Filter.or(
            Filter('createdBy', isEqualTo: uid),
            Filter('assignedTo', isEqualTo: uid),
            Filter('familyId', isEqualTo: familyId),
          )
        : Filter.or(
            Filter('createdBy', isEqualTo: uid),
            Filter('assignedTo', isEqualTo: uid),
          );

    return _tasksCollection.where(filter).snapshots().map((snapshot) {
      final tasks = snapshot.docs
          .map((doc) => TaskModel.fromFirestore(doc))
          .where(
            (task) =>
                task.createdBy == uid ||
                task.assignedTo == uid ||
                (hasFamily &&
                    task.visibility == 'family' &&
                    task.familyId == familyId),
          )
          .toList();
      tasks.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      return tasks;
    });
  }

  /// Get single task by ID
  Future<TaskModel?> getTask(String taskId) async {
    try {
      final doc = await _tasksCollection.doc(taskId).get();
      if (!doc.exists) return null;
      return TaskModel.fromFirestore(doc);
    } catch (_) {
      return null;
    }
  }

  /// Add a new task document
  Future<String> addTask(TaskModel task) async {
    final docRef = await _tasksCollection.add(task.toFirestore());
    return docRef.id;
  }

  /// Set task with explicit document ID or generated ID
  Future<String> createTask(TaskModel task) async {
    final docRef = task.id.isNotEmpty
        ? _tasksCollection.doc(task.id)
        : _tasksCollection.doc();
    
    final taskData = task.copyWith(id: docRef.id).toFirestore();
    try {
      await docRef
          .set(taskData, SetOptions(merge: true))
          .timeout(const Duration(seconds: 6));
    } on TimeoutException {
      // Queued in Firestore offline cache
    }
    return docRef.id;
  }

  /// Update an existing task
  Future<void> updateTask(TaskModel task) async {
    try {
      await _tasksCollection
          .doc(task.id)
          .update({
            ...task.toFirestore(),
            'updatedAt': FieldValue.serverTimestamp(),
          })
          .timeout(const Duration(seconds: 6));
    } on TimeoutException {
      // Queued in Firestore offline cache
    }
  }

  /// Complete a task
  Future<void> completeTask(
    String taskId, {
    required String completedBy,
    String? completedByName,
  }) async {
    final now = DateTime.now();
    final data = <String, dynamic>{
      'status': TaskStatus.completed.toFirestore(),
      'completedAt': Timestamp.fromDate(now),
      'completedBy': completedBy,
      'updatedAt': Timestamp.fromDate(now),
    };
    if (completedByName != null) {
      data['completedByName'] = completedByName;
    }
    try {
      await _tasksCollection
          .doc(taskId)
          .update(data)
          .timeout(const Duration(seconds: 6));
    } on TimeoutException {
      // Queued in Firestore offline cache
    }
  }

  /// Snooze a task
  Future<void> snoozeTask(String taskId, DateTime snoozeUntil) async {
    final now = DateTime.now();
    try {
      await _tasksCollection
          .doc(taskId)
          .update({
            'snoozedUntil': Timestamp.fromDate(snoozeUntil),
            'updatedAt': Timestamp.fromDate(now),
          })
          .timeout(const Duration(seconds: 6));
    } on TimeoutException {
      // Queued in Firestore offline cache
    }
  }

  /// Delete a task
  Future<void> deleteTask(String taskId) async {
    try {
      await _tasksCollection
          .doc(taskId)
          .delete()
          .timeout(const Duration(seconds: 6));
    } on TimeoutException {
      // Queued in Firestore offline cache
    }
  }

  /// Delete an asset
  Future<void> deleteAsset(String assetId) async {
    await _assetsCollection.doc(assetId).delete();
  }

  /// Stream categories for a specific user
  Stream<List<CategoryModel>> streamUserCategories(String ownerId) {
    return _categoriesCollection
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => CategoryModel.fromFirestore(doc))
              .toList();
          list.sort((a, b) => a.name.compareTo(b.name));
          return list;
        });
  }

  /// Add a new category, reusing an existing one with the same name
  /// (case-insensitive, trimmed) if the user already has one.
  ///
  /// Previously this always inserted a new document, so tapping "Create"
  /// for a name that already existed (e.g. from both the Assets screen and
  /// the Add Asset screen) silently produced duplicate categories. That's
  /// why you can end up with two "Electronics" folders that both show 0
  /// items: assets are filtered by the *exact* category document id, and
  /// only one of the duplicates (if either) actually matches.
  Future<String> addCategory(CategoryModel category) async {
    final normalizedName = category.name.trim().toLowerCase();
    final existing = await _categoriesCollection
        .where('ownerId', isEqualTo: category.ownerId)
        .get();
    for (final doc in existing.docs) {
      final data = doc.data();
      final existingName = (data['name'] as String? ?? '').trim().toLowerCase();
      if (existingName == normalizedName) {
        return doc.id; // Reuse the existing category instead of duplicating.
      }
    }
    final docRef = await _categoriesCollection.add(category.toFirestore());
    return docRef.id;
  }

  /// Update an existing category. The id is deliberately kept out of the
  /// Firestore payload; it is the document reference, not a stored field.
  Future<void> updateCategory(CategoryModel category) async {
    await _categoriesCollection.doc(category.id).update(category.toFirestore());
  }

  /// Delete a category AND unlink it from any assets that reference it.
  ///
  /// Previously deleting a category left `assets.categoryId` pointing at a
  /// document that no longer existed, which silently orphans those assets:
  /// they disappear from every category filter (including a
  /// newly-recreated category with the same name) while still counting
  /// toward "All Assets". This clears the reference so the assets fall
  /// back to "Uncategorized" instead of vanishing from every filter.
  Future<void> deleteCategory(String categoryId) async {
    final batch = _firestore.batch();
    final affectedAssets = await _assetsCollection
        .where('categoryId', isEqualTo: categoryId)
        .get();
    for (final doc in affectedAssets.docs) {
      batch.update(doc.reference, {'categoryId': null});
    }
    batch.delete(_categoriesCollection.doc(categoryId));
    await batch.commit();
  }

  /// Stream documents associated with an asset
  Stream<List<DocumentModel>> streamAssetDocuments(String assetId) {
    return _documentsCollection
        .where('assetId', isEqualTo: assetId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => DocumentModel.fromFirestore(doc))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  /// Add a new document metadata record
  Future<String> addDocument(DocumentModel document) async {
    final docRef = await _documentsCollection.add(document.toFirestore());
    return docRef.id;
  }

  /// Delete a document metadata record
  Future<void> deleteDocument(String documentId) async {
    await _documentsCollection.doc(documentId).delete();
  }
}
