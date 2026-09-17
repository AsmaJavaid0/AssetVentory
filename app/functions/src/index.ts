import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { randomBytes, scryptSync, timingSafeEqual } from 'crypto';

admin.initializeApp();
const db = admin.firestore();

async function getFamily(familyId: string) {
  const snap = await db.collection('families').doc(familyId).get();
  if (!snap.exists) throw new functions.https.HttpsError('not-found', 'Family not found.');
  return snap;
}

async function assertOwner(familyId: string, uid: string) {
  const family = await getFamily(familyId);
  if (family.data()?.ownerId !== uid) {
    throw new functions.https.HttpsError('permission-denied', 'Only the family owner can manage the PIN.');
  }
  return family;
}

async function hasCurrentAccess(familyId: string, uid: string, family: FirebaseFirestore.DocumentSnapshot) {
  const access = await db.collection('family_access').doc(`${familyId}_${uid}`).get();
  return access.exists && access.data()?.userId === uid && Number(access.data()?.pinVersion ?? 0) === Number(family.data()?.pinVersion ?? 0);
}

async function verifyPinValue(familyId: string, pin: string, familySnap?: FirebaseFirestore.DocumentSnapshot) {
  const family = familySnap ?? await getFamily(familyId);
  const data = family.data() ?? {};
  if (data.pinEnabled !== true) return true;

  const secretSnap = await db.collection('family_pin_secrets').doc(familyId).get();
  if (!secretSnap.exists) throw new functions.https.HttpsError('failed-precondition', 'Family PIN is not configured correctly.');

  const secret = secretSnap.data()!;
  const actual = scryptSync(pin, String(secret.salt), 64);
  const expected = Buffer.from(String(secret.hash), 'hex');
  return expected.length === actual.length && timingSafeEqual(actual, expected);
}

export const setFamilySharePin = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Sign in first.');
  const familyId = String(data?.familyId ?? '').trim();
  const pin = String(data?.pin ?? '');
  const currentPin = String(data?.currentPin ?? '');
  if (!familyId || !/^\d{4,6}$/.test(pin)) throw new functions.https.HttpsError('invalid-argument', 'PIN must contain 4 to 6 digits.');

  const familySnap = await assertOwner(familyId, context.auth.uid);
  const family = familySnap.data() ?? {};

  if (family.pinEnabled === true) {
    const accessValid = await hasCurrentAccess(familyId, context.auth.uid, familySnap);
    const pinValid = /^\d{4,6}$/.test(currentPin) && await verifyPinValue(familyId, currentPin, familySnap);
    if (!accessValid && !pinValid) throw new functions.https.HttpsError('permission-denied', 'Current PIN is required.');
  }

  const salt = randomBytes(16).toString('hex');
  const hash = scryptSync(pin, salt, 64).toString('hex');
  const version = Number(family.pinVersion ?? 0) + 1;

  await db.collection('family_pin_secrets').doc(familyId).set({
    familyId,
    salt,
    hash,
    version,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await db.collection('families').doc(familyId).update({
    pinEnabled: true,
    pinVersion: version,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await revokeFamilyAccess(familyId);
  await db.collection('family_access').doc(`${familyId}_${context.auth.uid}`).set({
    familyId,
    userId: context.auth.uid,
    pinVersion: version,
    grantedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true, pinVersion: version };
});

export const removeFamilySharePin = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Sign in first.');
  const familyId = String(data?.familyId ?? '').trim();
  const currentPin = String(data?.currentPin ?? '');
  if (!familyId) throw new functions.https.HttpsError('invalid-argument', 'Family id is required.');

  const familySnap = await assertOwner(familyId, context.auth.uid);
  const accessValid = await hasCurrentAccess(familyId, context.auth.uid, familySnap);
  const pinValid = /^\d{4,6}$/.test(currentPin) && await verifyPinValue(familyId, currentPin, familySnap);
  if (!accessValid && !pinValid) throw new functions.https.HttpsError('permission-denied', 'Current PIN is required.');

  await db.collection('family_pin_secrets').doc(familyId).delete();
  await db.collection('families').doc(familyId).update({
    pinEnabled: false,
    pinVersion: admin.firestore.FieldValue.increment(1),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  await revokeFamilyAccess(familyId);
  return { success: true };
});

export const verifyFamilySharePin = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Sign in first.');
  const familyId = String(data?.familyId ?? '').trim();
  const pin = String(data?.pin ?? '');
  if (!familyId || !/^\d{4,6}$/.test(pin)) throw new functions.https.HttpsError('invalid-argument', 'Enter a valid PIN.');

  const familySnap = await getFamily(familyId);
  const family = familySnap.data()!;
  const memberSnap = await db.collection('family_members').doc(`${familyId}_${context.auth.uid}`).get();
  if (!memberSnap.exists) throw new functions.https.HttpsError('permission-denied', 'You are not a member of this family.');

  if (family.pinEnabled !== true) return { success: true };
  if (!(await verifyPinValue(familyId, pin, familySnap))) throw new functions.https.HttpsError('permission-denied', 'Incorrect family PIN.');

  const version = Number(family.pinVersion ?? 0);
  await db.collection('family_access').doc(`${familyId}_${context.auth.uid}`).set({
    familyId,
    userId: context.auth.uid,
    pinVersion: version,
    grantedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  return { success: true, pinVersion: version };
});

export const lockFamilyShare = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Sign in first.');
  const familyId = String(data?.familyId ?? '').trim();
  if (!familyId) throw new functions.https.HttpsError('invalid-argument', 'Family id is required.');
  await getFamily(familyId);
  const memberSnap = await db.collection('family_members').doc(`${familyId}_${context.auth.uid}`).get();
  if (!memberSnap.exists) throw new functions.https.HttpsError('permission-denied', 'You are not a member of this family.');
  await db.collection('family_access').doc(`${familyId}_${context.auth.uid}`).delete();
  return { success: true };
});

async function revokeFamilyAccess(familyId: string) {
  const snapshot = await db.collection('family_access').where('familyId', '==', familyId).get();
  if (snapshot.empty) return;
  const batch = db.batch();
  snapshot.docs.forEach((doc) => batch.delete(doc.ref));
  await batch.commit();
}

export const onTaskCreated = functions.firestore.document('tasks/{taskId}').onCreate(async (snapshot, context) => {
  const task = snapshot.data();
  if (!task) return;
  const assignedTo = task.assignedTo;
  const createdBy = task.createdBy;
  if (assignedTo && assignedTo !== createdBy) await sendFcmNotification(assignedTo, 'New Task Assigned', `${task.createdByName || 'A family member'} assigned you a task: "${task.title}"`, { taskId: context.params.taskId, type: 'task_assigned' });
});

export const onTaskUpdated = functions.firestore.document('tasks/{taskId}').onUpdate(async (change, context) => {
  const before = change.before.data();
  const after = change.after.data();
  if (!before || !after) return;
  if (before.status !== 'completed' && after.status === 'completed' && after.createdBy && after.completedBy && after.createdBy !== after.completedBy) await sendFcmNotification(after.createdBy, 'Task Completed', `${after.completedByName || 'A family member'} completed: "${after.title}"`, { taskId: context.params.taskId, type: 'task_completed' });
});

async function sendFcmNotification(userId: string, title: string, body: string, data: Record<string, string>) {
  try {
    const devicesSnapshot = await db.collection('users').doc(userId).collection('devices').get();
    const tokens: string[] = [];
    devicesSnapshot.forEach((doc) => { if (doc.data().token) tokens.push(doc.data().token); });
    if (!tokens.length) return;
    const response = await admin.messaging().sendEachForMulticast({ tokens, notification: { title, body }, data });
    response.responses.forEach((resp, idx) => {
      if (!resp.success && resp.error && ['messaging/invalid-registration-token', 'messaging/registration-token-not-registered'].includes(resp.error.code)) void db.collection('users').doc(userId).collection('devices').doc(tokens[idx]).delete();
    });
  } catch (error) {
    console.error('Error sending FCM push notification:', error);
  }
}
