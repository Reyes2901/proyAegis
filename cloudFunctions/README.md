# Cloud Functions — FCM push notifications

## Trigger

`sendNotificationToChild` fires on **create** at:

```
users/{parentUid}/notifications/{notificationId}
```

This matches the Flutter client path (`APIPath.notificationsStream`). Each document must include `id` (childId), `title`, and `message`/`body`.

FCM tokens are resolved from:

1. `DeviceTokens/` where `childId` matches
2. Fallback: `users/{parentUid}/child/{childId}.token`

Invalid or missing tokens are logged and skipped (no unhandled throw).

## Deploy (do not run in CI without credentials)

```bash
cd cloudFunctions/functions
npm install
npm run build
cd ..
firebase deploy --only functions,firestore:rules
```

Project default: `aegis-kids-parentshield` (see `.firebaserc`). Legacy alias: `times-up-flutter-dev`.

## Firestore security rules

Rules for `locationHistory`, `appUsageDaily`, `DeviceTokens`, and core collections live in [`firestore.rules`](firestore.rules). Config: [`firebase.json`](firebase.json).

Child devices must have `linkedChildUid` on `users/{parentUid}/child/{childId}` (set at link time in Flutter) so background writes pass `isLinkedChild`.

### Deploy rules (CLI)

Requires [Firebase CLI](https://firebase.google.com/docs/cli) logged in (`firebase login`).

```bash
cd cloudFunctions
firebase deploy --only firestore:rules --project times-up-flutter-dev
```

Project alias: `times-up-flutter-dev` (see [`.firebaserc`](.firebaserc)).

### Deploy rules (Firebase Console — manual fallback)

1. Open [Firebase Console](https://console.firebase.google.com/) → project **times-up-flutter-dev**
2. **Firestore Database** → **Rules**
3. Copy the full contents of [`firestore.rules`](firestore.rules) from this repo
4. Click **Publish**

If child linking still returns `permission-denied`, confirm the published rules match the repo (stale rules in the console are a common cause).

**Recent rule fixes (child registration):**

- `DeviceTokens/{tokenId}`: doc ID and field `id` must match `request.auth.uid` (client writes `id`, not `ownerUid`).
- Initial link: authenticated users may read/update unlinked child docs when setting `linkedChildUid` to their own UID (invite-key model).

**Indexes:** queries on `locationHistory` use `where('capturedAt', …).orderBy('capturedAt')` — single-field index only; no composite index required. Daily usage reads use document IDs `YYYY-MM-DD`.

## Local build check

```bash
cd cloudFunctions/functions
npm install
npm run build
```
