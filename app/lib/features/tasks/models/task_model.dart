import 'package:cloud_firestore/cloud_firestore.dart';

// TaskModel keeps scheduled date/time as a device-local wall-clock value.
// Firestore stores the instant, while the notification service reconstructs
// the local device timezone before scheduling the alarm.
