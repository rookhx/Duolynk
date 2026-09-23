# Duolynk Security Architecture

This document records the production security model for the Firebase-backed
Duolynk app. The Flutter client is not trusted for privacy, safety, money, or
canonical relationship state.

## Trust Model

### User-editable

These fields can be written by the owning authenticated user, with validation:

- Dating profile display content: `displayName`, `bio`, prompt answers, photo URL lists.
- Compatibility questionnaire answers and dating preferences.
- Dating availability such as `datingStatus` and `datingPausedAt`.
- Notification preferences in `users/{uid}/settings/notification_preferences`.
- Personalized matching opt-in in `users/{uid}/settings/personalized_matching`.
- Own FCM device tokens in `users/{uid}/devices/{deviceId}`.
- Own block records in `users/{uid}/blocks/{blockedUid}`.

### Shared but lifecycle-controlled

These records are shared with participants, but lifecycle writes are trusted:

- `matches/{pairKey}` canonical pair records.
- Conversation documents in `conversations/{conversationId}`.
- Message documents in `conversations/{conversationId}/messages/{messageId}`.

The client may write message documents only when rules can verify the sender is
the authenticated participant, the relationship is eligible, the sender has a
trusted conversation activation grant, and the sender account can use dating
features. Canonical match
creation/transitions and conversation creation are reserved for trusted backend
or admin context.

### Private-to-user

These are readable only by the owner and trusted backend/admin context:

- DOB, email, exact coordinates and account profile data in `users/{uid}`.
- Raw questionnaire and preference answers in `users/{uid}/questionnaires`.
- Match feedback in `users/{uid}/matchFeedback`.
- Profile unlock grants in `users/{uid}/profileUnlocks`.
- Persistent conversation activation grants in
  `users/{uid}/conversationActivations`.
- Notification preferences and private settings in `users/{uid}/settings`.
- FCM tokens in `users/{uid}/devices`.
- RevenueCat entitlement mirror in `users/{uid}/subscriptions`.

### Trusted/server/moderator-controlled

Normal clients must not write:

- `moderationStatus`, moderation notes, report counters.
- `verificationStatus`.
- Photo/text moderation states.
- RevenueCat entitlement mirror documents.
- Weekly profile unlock and conversation activation grant documents.
- Report resolution/status updates.
- Notification delivery jobs.
- Canonical match lifecycle state and compatibility snapshots.
- Conversation creation.
- Derived personalized matching profile, until backend derivation exists.

## Firestore Path Access Map

| Path | Read | Create | Update | Delete |
| --- | --- | --- | --- | --- |
| `users/{uid}` | owner/admin | owner with safe defaults | owner excluding trusted fields | denied |
| `users/{uid}/devices/{deviceId}` | owner | owner | owner | owner |
| `users/{uid}/questionnaires/{id}` | owner | owner | owner | denied |
| `users/{uid}/subscriptions/{id}` | owner/admin | admin only | admin only | admin only |
| `users/{uid}/profileUnlocks/{id}` | owner/admin | admin only | admin only | admin only |
| `users/{uid}/conversationActivations/{id}` | owner/admin | admin only | admin only | admin only |
| `users/{uid}/settings/notification_preferences` | owner/admin | owner | owner | denied |
| `users/{uid}/settings/personalized_matching` | owner/admin | owner | owner | denied |
| `users/{uid}/settings/personalized_matching_profile` | owner/admin | admin only | admin only | denied |
| `users/{uid}/matchFeedback/{id}` | owner | owner | denied | denied |
| `users/{uid}/blocks/{blockedUid}` | owner | owner | owner | owner |
| `publicProfiles/{uid}` | signed-in users | admin only | admin only | admin only |
| `matches/{pairKey}` | participants/admin | admin only | admin only | admin only |
| `conversations/{id}` | members/admin | admin only | limited member metadata/admin | admin only |
| `conversations/{id}/messages/{id}` | sender, activated member, admin | activated sender only | denied | denied |
| `moderation_reports/{id}` | admin only | authenticated reporter | admin only | admin only |
| `notification_jobs/{id}` | recipient/admin | admin only | admin only | admin only |

## Locked Message Protection

Message bodies and attachment URLs live on message documents. Firestore rules
allow message reads only when the requester is:

- the sender;
- a conversation participant with a trusted persistent conversation activation
  grant;
- a legacy active-match participant retained for backward compatibility;
- privileged backend/admin context.

Unactivated recipients may read conversation metadata and see that a message
exists, but they cannot read the protected message document body or image URL
through Firestore rules.

## RevenueCat Entitlement Strategy

The Flutter client may use RevenueCat state for UI refreshes and quota copy, but
security rules only trust backend-created profile unlock and conversation
activation grant documents for protected profile/message access. RevenueCat
entitlement mirrors remain writable only by privileged backend/admin context.
`functions/src/subscriptions/revenueCatWebhook.ts` maintains the trusted
`entitlements/{uid}` mirror and `users/{uid}/subscriptions/revenuecat_premium`
document after validating the configured webhook secret.

No RevenueCat secret keys should be committed to the Flutter app.

## Trusted Functions

The repository includes a Firebase Functions v2 TypeScript backend:

- `unlockCandidateProfile`: callable, App Check enforced. Validates auth,
  curated-candidate context, block/account state, trusted entitlement, server
  week, idempotency and Basic weekly quota before creating
  `users/{uid}/profileUnlocks/{pairKey}`.
- `activateConversation`: callable, App Check enforced. Validates auth, mutual
  match state, block/account state, trusted entitlement, server week,
  idempotency and Basic/Premium activation quota before creating
  `users/{uid}/conversationActivations/{pairKey}`.
- `createCuratedIntroduction`: callable, App Check enforced. Validates auth,
  account availability, block state, canonical pair identity, server week and
  the trusted 10-candidate weekly cap before creating or updating
  `matches/{pairKey}`. The current Flutter service still computes candidate
  compatibility; this callable owns the write, quota and timestamps.
- `respondToCuratedMatch`, `expireCuratedMatch` and `unmatchPair`: callables,
  App Check enforced. Own Interested/Pass, expiration and unmatch transitions
  with server time and idempotent terminal-state handling.
- `ensureConversationForMatch`: callable, App Check enforced. Creates the
  canonical conversation document for a mutual/active match and links `chatId`
  without granting either participant message access.
- `getAuthorizedFullProfile`: callable, App Check enforced. Returns safe dating
  profile display fields only when full-profile authorization is verified.
- `revenueCatWebhook`: HTTPS endpoint that validates `REVENUECAT_WEBHOOK_SECRET`
  and updates trusted entitlement mirrors idempotently.
- `generateProfileTeaser`: Storage trigger that creates low-information
  blurred derivatives in `profileTeasers/{uid}` from owner-uploaded originals.
- notification triggers create privacy-safe notification jobs for candidate,
  mutual-match and message events.
- `migrateLegacyActiveConversations`: admin callable that grants
  `legacyMigration` conversation activations for existing active matches without
  consuming weekly quota.

Backend responsibilities still required before launch:

- port the full candidate discovery/scoring loop from the Flutter service into
  trusted Functions while preserving eligibility-first filtering, compatibility
  scoring and personalized ranking. The callable now enforces writes and the
  10-candidate cap, but the candidate selection calculation is still client-side
  input and must move server-side for a fully trusted launch path;
- move block-triggered relationship termination into a trusted callable/trigger
  if client block writes remain user-owned;
- complete protected full-profile projection/signed delivery if existing stored
  photo URLs are long-lived download URLs;
- add real emulator tests for rules and Functions in CI;
- configure RevenueCat webhook secrets and App Check providers in Firebase.

## Storage Access Map

| Path | Read | Write |
| --- | --- | --- |
| `users/{uid}/profile/{file}` | owner/admin | owner image uploads, max 8 MB |
| `profileTeasers/{uid}/{file}` | signed-in users | admin-generated teaser images only |
| `conversations/{id}/messages/{messageId}/{file}` | activated conversation members/admin | activated conversation members, image uploads only |
| `verification/{uid}/{file}` | admin only | admin only |

Clear profile photo originals are no longer broadly readable. Production needs
trusted backend projection or signed delivery for authorized full-profile
viewers, and safe low-information teaser derivatives under `profileTeasers/`
for locked Basic candidate views. Verification submissions are separate and
never publicly readable.

## App Check

No App Check dependency/configuration was found in the Flutter repo. App Check
should be enabled as defense-in-depth in Firebase Console and app platform
configuration. It is not a substitute for Auth, rules, or backend authorization.

## Account Deletion and Retention

The current client deletes owner-owned private subcollections and the user
document, but shared match/conversation/report retention needs trusted backend
policy before production. Reports and moderation evidence should not be deleted
merely because one participant deletes their account.
