import {onCall} from "firebase-functions/v2/https";
import {FieldValue} from "firebase-admin/firestore";
import {
  GRANT_TYPE_EXPLICIT_BASIC,
  PROFILE_UNLOCK_LIMIT_BASIC,
} from "../shared/constants";
import {requireUsableAccount, ensureNotBlocked} from "../shared/accounts";
import {readTrustedEntitlement} from "../shared/entitlements";
import {db, Timestamp} from "../shared/firestore";
import {invalidArgument, unauthenticated} from "../shared/errors";
import {
  profileUnlockPath,
  weeklyAccessPath,
} from "../shared/paths";
import {weekKey} from "../shared/time";
import {
  isMutualOrActive,
  requireCandidateMatch,
} from "../shared/matches";
import {enforceRateLimit} from "./rateLimit";

interface UnlockRequest {
  candidateUid?: unknown;
}

export const unlockCandidateProfile = onCall(
  {enforceAppCheck: true, region: "us-central1"},
  async (request) => {
    if (!request.auth) {
      unauthenticated();
    }
    const uid = request.auth.uid;
    const data = request.data as UnlockRequest;
    if (typeof data.candidateUid !== "string" || data.candidateUid === uid) {
      invalidArgument("A valid candidate is required.");
    }

    const now = new Date();
    const currentWeek = weekKey(now);
    const candidateUid = data.candidateUid;
    const result = await db.runTransaction(async (tx) => {
      await requireUsableAccount(tx, uid);
      await requireUsableAccount(tx, candidateUid);
      await ensureNotBlocked(tx, uid, candidateUid);

      const match = await requireCandidateMatch(tx, uid, candidateUid);
      if (isMutualOrActive(match.data)) {
        return {status: "mutualAccess", pairKey: match.pairKey};
      }

      const grantRef = db.doc(profileUnlockPath(uid, match.pairKey));
      const existingGrant = await tx.get(grantRef);
      if (existingGrant.exists) {
        return {status: "alreadyUnlocked", pairKey: match.pairKey};
      }

      const entitlement = await readTrustedEntitlement(tx, uid);
      if (entitlement.premiumActive) {
        return {status: "premiumAccess", pairKey: match.pairKey};
      }

      const weeklyRef = db.doc(weeklyAccessPath(uid, currentWeek));
      const weeklySnap = await tx.get(weeklyRef);
      const used = weeklySnap.data()?.explicitProfileUnlockCount ?? 0;
      if (used >= PROFILE_UNLOCK_LIMIT_BASIC) {
        return {status: "quotaReached", pairKey: match.pairKey};
      }

      await enforceRateLimit(tx, uid, "profileUnlock", 2, now);
      tx.set(grantRef, {
        viewerUid: uid,
        targetUid: candidateUid,
        pairKey: match.pairKey,
        weekKey: currentWeek,
        grantType: GRANT_TYPE_EXPLICIT_BASIC,
        createdAt: Timestamp.fromDate(now),
      });
      tx.set(
        weeklyRef,
        {
          weekKey: currentWeek,
          explicitProfileUnlockCount: FieldValue.increment(1),
          updatedAt: Timestamp.fromDate(now),
        },
        {merge: true},
      );
      tx.create(db.collection("auditLogs").doc(), {
        type: "profile_unlock_granted",
        uid,
        targetUid: candidateUid,
        pairKey: match.pairKey,
        weekKey: currentWeek,
        createdAt: Timestamp.fromDate(now),
      });
      return {status: "unlocked", pairKey: match.pairKey};
    });

    return result;
  },
);
