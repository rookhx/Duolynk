import {onCall} from "firebase-functions/v2/https";
import {FieldValue} from "firebase-admin/firestore";
import {
  MATCH_CONVERSATION_STATUSES,
  MATCH_TERMINAL_STATUSES,
  WEEKLY_CANDIDATE_LIMIT,
} from "../shared/constants";
import {requireUsableAccount, ensureNotBlocked} from "../shared/accounts";
import {db, Timestamp} from "../shared/firestore";
import {invalidArgument, permissionDenied, unauthenticated} from "../shared/errors";
import {matchPath, pairKey, weeklyAccessPath} from "../shared/paths";
import {weekKey} from "../shared/time";
import {enforceRateLimit} from "../access/rateLimit";

interface CreateIntroductionRequest {
  candidateUid?: unknown;
  compatibilityScore?: unknown;
  compatibilityReasons?: unknown;
  categoryScores?: unknown;
  categoryDataCompleteness?: unknown;
  dataCompleteness?: unknown;
  compatibilityAlgorithmVersion?: unknown;
  searchScope?: unknown;
  generatedForTier?: unknown;
}

export const createCuratedIntroduction = onCall(
  {enforceAppCheck: true, region: "us-central1"},
  async (request) => {
    if (!request.auth) {
      unauthenticated();
    }
    if (request.auth.token.admin !== true) {
      permissionDenied("Curated introduction creation is server-authoritative.");
    }
    const uid = request.auth.uid;
    const data = request.data as CreateIntroductionRequest;
    if (typeof data.candidateUid !== "string" || data.candidateUid === uid) {
      invalidArgument("A valid candidate is required.");
    }
    const score = readBoundedInt(data.compatibilityScore, 0, 100, "Compatibility score");
    const now = new Date();
    const currentWeek = weekKey(now);
    const candidateUid = data.candidateUid;
    const key = pairKey(uid, candidateUid);

    return db.runTransaction(async (tx) => {
      await requireUsableAccount(tx, uid);
      await requireUsableAccount(tx, candidateUid);
      await ensureNotBlocked(tx, uid, candidateUid);

      const weeklyRef = db.doc(weeklyAccessPath(uid, currentWeek));
      const weeklySnap = await tx.get(weeklyRef);
      const used = weeklySnap.data()?.curatedCandidateCount ?? 0;
      if (used >= WEEKLY_CANDIDATE_LIMIT) {
        return {status: "quotaReached", pairKey: key, weekKey: currentWeek};
      }

      const matchRef = db.doc(matchPath(key));
      const existingSnap = await tx.get(matchRef);
      const participantIds = [uid, candidateUid].sort();
      await enforceRateLimit(tx, uid, "curatedIntroduction", 1, now);

      if (existingSnap.exists) {
        const existing = existingSnap.data() ?? {};
        const existingStatus = String(existing.status ?? "");
        if (
          MATCH_CONVERSATION_STATUSES.has(existingStatus) ||
          MATCH_TERMINAL_STATUSES.has(existingStatus)
        ) {
          return {status: "unchanged", pairKey: key, matchId: key};
        }
        tx.set(matchRef, {
          participantIds,
          suggestedForUserIds: FieldValue.arrayUnion(uid),
          [`participantDecisions.${uid}`]: existing.participantDecisions?.[uid] ?? "pending",
          updatedAt: Timestamp.fromDate(now),
        }, {merge: true});
      } else {
        tx.set(matchRef, {
          userId: uid,
          partnerId: candidateUid,
          compatibilityScore: score,
          status: "suggested",
          compatibilityReasons: readInsightList(data.compatibilityReasons),
          categoryScores: readNumberMap(data.categoryScores, true),
          categoryDataCompleteness: readNumberMap(data.categoryDataCompleteness, false),
          dataCompleteness: readBoundedNumber(data.dataCompleteness, 0, 1, 0),
          compatibilityAlgorithmVersion: readBoundedInt(
            data.compatibilityAlgorithmVersion,
            1,
            100,
            "Algorithm version",
            1,
          ),
          createdAt: Timestamp.fromDate(now),
          expiresAt: Timestamp.fromDate(new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000)),
          pairKey: key,
          weekKey: currentWeek,
          searchScope: typeof data.searchScope === "string" ? data.searchScope : null,
          generatedForTier: typeof data.generatedForTier === "string" ? data.generatedForTier : null,
          generatedBySystem: true,
          participantIds,
          suggestedForUserIds: [uid],
          participantDecisions: Object.fromEntries(participantIds.map((id) => [id, "pending"])),
          participantDecisionAt: {},
          updatedAt: Timestamp.fromDate(now),
        });
      }

      tx.set(weeklyRef, {
        weekKey: currentWeek,
        curatedCandidateCount: FieldValue.increment(1),
        updatedAt: Timestamp.fromDate(now),
      }, {merge: true});
      tx.create(db.collection("auditLogs").doc(), {
        type: "curated_introduction_created",
        uid,
        candidateUid,
        pairKey: key,
        weekKey: currentWeek,
        createdAt: Timestamp.fromDate(now),
      });
      return {status: "created", pairKey: key, matchId: key, weekKey: currentWeek};
    });
  },
);

function readBoundedInt(
  value: unknown,
  min: number,
  max: number,
  label: string,
  fallback?: number,
): number {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    if (fallback !== undefined) {
      return fallback;
    }
    invalidArgument(`${label} is required.`);
  }
  const rounded = Math.round(value as number);
  if (rounded < min || rounded > max) {
    invalidArgument(`${label} is out of range.`);
  }
  return rounded;
}

function readBoundedNumber(value: unknown, min: number, max: number, fallback: number): number {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    return fallback;
  }
  return Math.min(max, Math.max(min, value));
}

function readNumberMap(value: unknown, round: boolean): Record<string, number> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    return {};
  }
  const result: Record<string, number> = {};
  for (const [key, raw] of Object.entries(value)) {
    if (typeof raw === "number" && Number.isFinite(raw)) {
      result[key] = round ? Math.round(raw) : raw;
    }
  }
  return result;
}

function readInsightList(value: unknown): unknown[] {
  if (!Array.isArray(value)) {
    return [];
  }
  return value
    .filter((item) => typeof item === "object" && item !== null && !Array.isArray(item))
    .slice(0, 8);
}
