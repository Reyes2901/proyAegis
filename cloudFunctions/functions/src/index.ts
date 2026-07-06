import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();

/**
 * Sends FCM when parent creates a notification.
 *
 * Flutter writes to `users/{parentUid}/notifications/{notificationId}` with
 * `{ id: childId, title, message, ... }`. Matches `APIPath.notificationsStream`.
 */
export const sendNotificationToChild = functions.firestore
  .document("users/{parentUid}/notifications/{notificationId}")
  .onCreate(async (snapshot, context) => {
    const parentUid = context.params.parentUid as string;
    const notificationId = context.params.notificationId as string;
    const newData = snapshot.data();

    if (!newData) {
      console.log("No notification data");
      return;
    }

    const childId = newData.id as string | undefined;
    if (!childId) {
      console.log("No child id on notification document");
      return;
    }

    const tokens = await resolveChildFcmTokens(parentUid, childId);
    if (tokens.length === 0) {
      console.log("No FCM tokens for child", childId);
      return;
    }

    const title =
      (newData.title as string | undefined) ?? "Hey New notification";
    const body =
      (newData.message as string | undefined) ??
      (newData.body as string | undefined) ??
      "";

    const extraData = newData.data as Record<string, string> | undefined;
    const data: Record<string, string> = {
      click_action: "FLUTTER_NOTIFICATION_CLICK",
      screen: "notifications",
      notificationId,
      childId,
      message: body,
      ...(extraData ?? {}),
    };

    const message: admin.messaging.MulticastMessage = {
      tokens,
      notification: { title, body },
      data,
      android: { priority: "high" },
    };

    try {
      const response = await admin.messaging().sendEachForMulticast(message);
      console.log(
        "Notification sent",
        response.successCount,
        "of",
        tokens.length,
      );

      response.responses.forEach((result, index) => {
        if (result.success) return;
        const code = result.error?.code;
        console.log(
          "FCM failed for token index",
          index,
          code,
          result.error?.message,
        );
        if (
          code === "messaging/invalid-registration-token" ||
          code === "messaging/registration-token-not-registered"
        ) {
          // ponytail: stale tokens logged only; prune via scheduled job if needed
        }
      });
    } catch (err) {
      console.log("FCM send error (non-fatal):", err);
    }
  });

/** @deprecated Use sendNotificationToChild — kept for existing deploy aliases. */
export const sendNotification = sendNotificationToChild;

/**
 * Notifies linked child device when parent blocks/unblocks an app.
 * Flutter writes `users/{parentUid}/child/{childId}/blockedApps/{packageName}`.
 */
export const sendBlockedAppToChild = functions.firestore
  .document("users/{parentUid}/child/{childId}/blockedApps/{packageName}")
  .onWrite(async (change, context) => {
    const parentUid = context.params.parentUid as string;
    const childId = context.params.childId as string;
    const packageName = context.params.packageName as string;
    const after = change.after.exists ? change.after.data() : null;
    const blocked = (after?.blocked as boolean | undefined) ?? false;

    const tokens = await resolveChildFcmTokens(parentUid, childId);
    if (tokens.length === 0) {
      console.log("No FCM tokens for blocked app sync", childId);
      return;
    }

    const message: admin.messaging.MulticastMessage = {
      tokens,
      data: {
        type: "blocked_apps",
        packageName,
        blocked: blocked ? "true" : "false",
        childId,
      },
      android: { priority: "high" },
    };

    try {
      const response = await admin.messaging().sendEachForMulticast(message);
      console.log(
        "Blocked app FCM",
        packageName,
        blocked,
        response.successCount,
        "of",
        tokens.length,
      );
    } catch (err) {
      console.log("Blocked app FCM error (non-fatal):", err);
    }
  });

async function resolveChildFcmTokens(
  parentUid: string,
  childId: string,
): Promise<string[]> {
  const tokens: string[] = [];

  const deviceTokens = await admin
    .firestore()
    .collection("DeviceTokens")
    .where("childId", "==", childId)
    .get();

  deviceTokens.docs.forEach((doc) => {
    const token = doc.data().device_token as string | undefined;
    if (token) tokens.push(token);
  });

  if (tokens.length === 0) {
    const childDoc = await admin
      .firestore()
      .doc(`users/${parentUid}/child/${childId}`)
      .get();
    const childToken = childDoc.data()?.token as string | undefined;
    if (childToken) tokens.push(childToken);
  }

  return tokens;
}
