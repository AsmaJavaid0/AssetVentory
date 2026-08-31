import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

admin.initializeApp();

/**
 * Cloud Function triggered when a new task is created.
 * Sends FCM push notification to assigned family member if assignedTo != createdBy.
 */
export const onTaskCreated = functions.firestore
  .document('tasks/{taskId}')
  .onCreate(async (snapshot, context) => {
    const task = snapshot.data();
    if (!task) return;

    const assignedTo = task.assignedTo;
    const createdBy = task.createdBy;

    // Send push notification if assigned to another family member
    if (assignedTo && assignedTo !== createdBy) {
      const title = 'New Task Assigned';
      const body = `${task.createdByName || 'A family member'} assigned you a task: "${task.title}"`;
      await sendFcmNotification(assignedTo, title, body, {
        taskId: context.params.taskId,
        type: 'task_assigned',
      });
    }
  });

/**
 * Cloud Function triggered when a task is updated.
 * Notifies assigned member if completed or updated by creator.
 */
export const onTaskUpdated = functions.firestore
  .document('tasks/{taskId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    if (!before || !after) return;

    // Completion notification to task creator
    if (before.status !== 'completed' && after.status === 'completed') {
      if (after.createdBy && after.completedBy && after.createdBy !== after.completedBy) {
        const title = 'Task Completed';
        const body = `${after.completedByName || 'A family member'} completed: "${after.title}"`;
        await sendFcmNotification(after.createdBy, title, body, {
          taskId: context.params.taskId,
          type: 'task_completed',
        });
      }
    }
  });

/**
 * Helper function to query FCM tokens for a target user and dispatch Multicast FCM message.
 */
async function sendFcmNotification(
  userId: string,
  title: string,
  body: string,
  data: Record<string, string>
) {
  try {
    const devicesSnapshot = await admin
      .firestore()
      .collection('users')
      .doc(userId)
      .collection('devices')
      .get();

    if (devicesSnapshot.empty) return;

    const tokens: string[] = [];
    devicesSnapshot.forEach((doc) => {
      const tokenData = doc.data();
      if (tokenData.token) tokens.push(tokenData.token);
    });

    if (tokens.length === 0) return;

    const message: admin.messaging.MulticastMessage = {
      tokens,
      notification: {
        title,
        body,
      },
      data,
    };

    const response = await admin.messaging().sendEachForMulticast(message);

    // Clean up stale invalid tokens
    response.responses.forEach((resp, idx) => {
      if (!resp.success && resp.error) {
        const errCode = resp.error.code;
        if (
          errCode === 'messaging/invalid-registration-token' ||
          errCode === 'messaging/registration-token-not-registered'
        ) {
          const badToken = tokens[idx];
          admin.firestore().collection('users').doc(userId).collection('devices').doc(badToken).delete();
        }
      }
    });
  } catch (error) {
    console.error('Error sending FCM push notification:', error);
  }
}
