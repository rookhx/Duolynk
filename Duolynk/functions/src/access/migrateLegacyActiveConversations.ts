import {onCall} from "firebase-functions/v2/https";
import {db, Timestamp} from "../shared/firestore";
import {GRANT_TYPE_LEGACY_MIGRATION} from "../shared/constants";
import {unauthenticated, permissionDenied} from "../shared/errors";

export const migrateLegacyActiveConversations = onCall(
  {enforceAppCheck: true, region: "us-central1"},
  async (request) => {
    if (!request.auth) {
      unauthenticated();
    }
    if (request.auth.token.admin !== true) {
      permissionDenied("Admin access is required.");
    }

    const now = new Date();
    const snapshot = await db
      .collection("matches")
      .where("status", "==", "active")
      .get();

    let grantCount = 0;
    const batch = db.batch();
    for (const doc of snapshot.docs) {
      const data = doc.data();
      const participantIds = Array.isArray(data.participantIds) && data.participantIds.length >= 2 ?
        data.participantIds as string[] :
        [data.userId, data.partnerId].filter((id) => typeof id === "string");
      const pairKey = data.pairKey ?? doc.id;
      const conversationId = data.chatId ?? pairKey;
      for (const uid of participantIds) {
        const ref = db.doc(`users/${uid}/conversationActivations/${pairKey}`);
        batch.set(
          ref,
          {
            userId: uid,
            matchId: doc.id,
            conversationId,
            pairKey,
            grantType: GRANT_TYPE_LEGACY_MIGRATION,
            createdAt: Timestamp.fromDate(now),
            migratedAt: Timestamp.fromDate(now),
          },
          {merge: true},
        );
        grantCount++;
      }
    }
    await batch.commit();
    return {migratedMatches: snapshot.size, grantCount};
  },
);
