import {onCall} from "firebase-functions/v2/https";
import {FieldValue} from "firebase-admin/firestore";
import {
  CONVERSATION_ACTIVATION_LIMIT_BASIC,
  CONVERSATION_ACTIVATION_LIMIT_PREMIUM,
} from "../shared/constants";
import {requireUsableAccount, ensureNotBlocked} from "../shared/accounts";
import {readTrustedEntitlement} from "../shared/entitlements";
import {db, Timestamp} from "../shared/firestore";
import {invalidArgument, unauthenticated} from "../shared/errors";
import {conversationActivationPath, weeklyAccessPath} from "../shared/paths";
import {weekKey} from "../shared/time";
import {requireMutualConversationMatch} from "../shared/matches";
import {enforceRateLimit} from "./rateLimit";

interface ActivationRequest {
  matchId?: unknown;
}

export const activateConversation = onCall(
  {enforceAppCheck: true, region: "us-central1"},
  async (request) => {
    if (!request.auth) {
      unauthenticated();
    }
    const uid = request.auth.uid;
    const data = request.data as ActivationRequest;
    if (typeof data.matchId !== "string" || data.matchId.length === 0) {
      invalidArgument("A valid match is required.");
    }

    const now = new Date();
    const currentWeek = weekKey(now);
    const result = await db.runTransaction(async (tx) => {
      await requireUsableAccount(tx, uid);
      const match = await requireMutualConversationMatch(tx, uid, data.matchId as string);
      await requireUsableAccount(tx, match.otherUid);
      await ensureNotBlocked(tx, uid, match.otherUid);

      const grantRef = db.doc(conversationActivationPath(uid, match.pairKey));
      const existingGrant = await tx.get(grantRef);
      if (existingGrant.exists) {
        return {status: "alreadyActivated", pairKey: match.pairKey};
      }

      const entitlement = await readTrustedEntitlement(tx, uid);
      const limit = entitlement.premiumActive ?
        CONVERSATION_ACTIVATION_LIMIT_PREMIUM :
        CONVERSATION_ACTIVATION_LIMIT_BASIC;
      const weeklyRef = db.doc(weeklyAccessPath(uid, currentWeek));
      const weeklySnap = await tx.get(weeklyRef);
      const used = weeklySnap.data()?.conversationActivationCount ?? 0;
      if (used >= limit) {
        return {status: "quotaReached", pairKey: match.pairKey, limit};
      }

      await enforceRateLimit(tx, uid, "conversationActivation", 2, now);
      tx.set(grantRef, {
        userId: uid,
        matchId: match.id,
        conversationId: match.data.chatId || match.pairKey,
        pairKey: match.pairKey,
        weekKey: currentWeek,
        grantType: entitlement.premiumActive ? "premiumActivation" : "basicActivation",
        createdAt: Timestamp.fromDate(now),
      });
      tx.set(
        weeklyRef,
        {
          weekKey: currentWeek,
          conversationActivationCount: FieldValue.increment(1),
          updatedAt: Timestamp.fromDate(now),
        },
        {merge: true},
      );
      tx.create(db.collection("auditLogs").doc(), {
        type: "conversation_activation_granted",
        uid,
        pairKey: match.pairKey,
        matchId: match.id,
        weekKey: currentWeek,
        createdAt: Timestamp.fromDate(now),
      });
      return {status: "activated", pairKey: match.pairKey};
    });

    return result;
  },
);
