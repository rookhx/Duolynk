# Duolynk Production Security Checklist

Repository changes alone are not deployment. Complete these steps before
shipping a production Firebase project.

- Deploy Firestore rules: `firebase deploy --only firestore:rules`.
- Deploy Storage rules: `firebase deploy --only storage`.
- Deploy Firestore indexes: `firebase deploy --only firestore:indexes`.
- Install and build Functions dependencies: `cd functions && npm install &&
  npm run build`.
- Deploy Cloud Functions: `firebase deploy --only functions`.
- Port the full weekly candidate discovery/scoring loop to trusted Functions
  before production launch. The current backend owns match writes/lifecycle
  transitions and the 10-candidate cap, but Flutter still supplies the selected
  candidate snapshot.
- Store backend secrets using Firebase/Google secret configuration. Do not put
  RevenueCat secret keys or service account keys in Flutter source.
- Configure Firebase secret `REVENUECAT_WEBHOOK_SECRET` and RevenueCat webhook
  endpoint for `revenueCatWebhook`.
- Verify callable `unlockCandidateProfile` creates at most one Basic profile
  unlock per server week and is idempotent for an existing pair.
- Verify callable `activateConversation` creates at most one Basic or three
  Premium activations per server week and is idempotent for an existing pair.
- Verify callable `createCuratedIntroduction` uses server week, canonical pair
  IDs, block/account checks and the 10-candidate cap.
- Verify callables `respondToCuratedMatch`, `expireCuratedMatch` and
  `unmatchPair` reject stale/terminal transitions and are idempotent.
- Verify callable `ensureConversationForMatch` creates only one conversation
  and does not grant message access.
- Enable and configure Firebase App Check for Android, iOS, and debug/dev
  providers. Do not commit debug secrets.
- Verify Firebase Auth providers and authorized domains.
- Run Firestore Rules emulator tests.
- Run Storage Rules emulator tests.
- Run Cloud Functions emulator tests for curated-introduction creation,
  lifecycle transitions, conversation creation, unlock, activation, entitlement
  webhook and teaser generation.
- Test Premium purchase and restore in App Store/Play sandbox.
- Test locked-message access against production-like rules using conversation
  activation grants, not current Premium state alone.
- Verify DOB is not readable by another authenticated user.
- Verify raw questionnaires and deal breakers are owner-only.
- Verify report documents are not readable by reported users.
- Verify normal clients cannot set `verificationStatus = verified`.
- Verify normal clients cannot set `moderationStatus = active` after a ban.
- Verify normal clients cannot create fake mutual matches.
- Verify notification jobs cannot be created by ordinary clients.
- Verify profile photo uploads enforce owner path, image type, and size limits.
- Verify `generateProfileTeaser` creates safe low-information images into
  `profileTeasers/` after profile uploads.
- Implement trusted clear-photo delivery/projection for Premium, explicit
  profile unlock, and mutual-match profile viewers.
- Verify chat attachments are inaccessible to unactivated recipients.
- Verify account deletion preserves reports/moderation evidence as required.
- Monitor Functions logs/errors and Firebase denied-rule metrics after launch.
