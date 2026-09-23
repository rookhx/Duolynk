import {onCall} from "firebase-functions/v2/https";
import {
  DocumentData,
  DocumentSnapshot,
  FieldValue,
  QueryDocumentSnapshot,
} from "firebase-admin/firestore";
import {WEEKLY_CANDIDATE_LIMIT} from "../shared/constants";
import {readTrustedEntitlement} from "../shared/entitlements";
import {db, Timestamp} from "../shared/firestore";
import {failedPrecondition, invalidArgument, unauthenticated} from "../shared/errors";
import {matchPath, pairKey, weeklyAccessPath} from "../shared/paths";
import {weekKey} from "../shared/time";
import {buildCompatibilityProfile} from "./profileReader";
import {isEligiblePair} from "./serverEligibility";
import {scoreCompatibility} from "./serverCompatibility";
import {balancedPairRankingScore, readPersonalizedProfile} from "./serverPersonalized";
import {ServerCompatibilityProfile, ServerCompatibilityResult} from "./serverMatchingTypes";

const candidatePoolLimit = 250;
const suggestionLifetimeMs = 7 * 24 * 60 * 60 * 1000;

interface GenerateWeeklyCandidatesRequest {
  candidateUid?: unknown;
}

interface PairHistoryContext {
  excludedPairKeys: Set<string>;
  activePartnerIds: Set<string>;
}

export const generateWeeklyCuratedCandidates = onCall(
  {enforceAppCheck: true, region: "us-central1"},
  async (request) => {
    if (!request.auth) {
      unauthenticated();
    }
    const uid = request.auth.uid;
    const data = (request.data ?? {}) as GenerateWeeklyCandidatesRequest;
    if (data.candidateUid !== undefined) {
      invalidArgument("Candidate selection is server-authoritative.");
    }

    const now = new Date();
    const currentWeek = weekKey(now);
    const existing = await readExistingGeneratedMatches(uid, currentWeek);
    if (existing.length > 0) {
      return {
        status: existing.length >= WEEKLY_CANDIDATE_LIMIT ? "quotaReached" : "alreadyGenerated",
        generatedCount: 0,
        matchIds: existing.map((doc) => doc.id),
        weekKey: currentWeek,
        limit: WEEKLY_CANDIDATE_LIMIT,
      };
    }

    const currentProfile = await buildCompatibilityProfile(uid);
    if (!currentProfile) {
      failedPrecondition("This account is not available.");
    }
    if (!isCandidateReceivable(currentProfile)) {
      return {
        status: "notEligible",
        generatedCount: 0,
        matchIds: [],
        weekKey: currentWeek,
        limit: WEEKLY_CANDIDATE_LIMIT,
      };
    }

    const [blockedUserIds, pairHistory, currentPersonalizedProfile] = await Promise.all([
      readBlockedUserIds(uid),
      readPairHistory(uid, now),
      readPersonalizedProfile(uid),
    ]);
    const candidatesSnapshot = await db.collection("users").limit(candidatePoolLimit).get();
    const ranked: ServerCompatibilityResult[] = [];

    for (const doc of candidatesSnapshot.docs) {
      if (doc.id === uid) continue;
      const blockedByCandidate = await db.doc(`users/${doc.id}/blocks/${uid}`).get();
      const candidate = await buildCompatibilityProfile(doc.id, doc.data());
      if (!candidate) continue;
      const eligible = isEligiblePair(currentProfile, candidate, {
        blockedUserIds,
        blockedByUserIds: blockedByCandidate.exists ? new Set([doc.id]) : new Set(),
        activePartnerIds: pairHistory.activePartnerIds,
        excludedPairKeys: pairHistory.excludedPairKeys,
      });
      if (!eligible) continue;

      const result = scoreCompatibility(currentProfile, candidate);
      const candidatePersonalizedProfile = await readPersonalizedProfile(doc.id);
      result.personalizedRankingScore = balancedPairRankingScore(
        result,
        currentPersonalizedProfile,
        candidatePersonalizedProfile,
      );
      ranked.push(result);
    }

    ranked.sort((a, b) => {
      const rank = b.personalizedRankingScore - a.personalizedRankingScore;
      if (rank !== 0) return rank;
      const completeness = b.dataCompleteness - a.dataCompleteness;
      if (completeness !== 0) return completeness;
      const base = b.compatibilityScore - a.compatibilityScore;
      if (base !== 0) return base;
      return a.candidate.user.id.localeCompare(b.candidate.user.id);
    });

    const selected = ranked.slice(0, WEEKLY_CANDIDATE_LIMIT);
    if (selected.length === 0) {
      return {
        status: "noEligibleCandidates",
        generatedCount: 0,
        matchIds: [],
        weekKey: currentWeek,
        limit: WEEKLY_CANDIDATE_LIMIT,
      };
    }

    return db.runTransaction(async (tx) => {
      const weeklyRef = db.doc(weeklyAccessPath(uid, currentWeek));
      const weeklySnap = await tx.get(weeklyRef);
      const used = Number(weeklySnap.data()?.curatedCandidateCount ?? 0);
      if (used >= WEEKLY_CANDIDATE_LIMIT) {
        return {
          status: "quotaReached",
          generatedCount: 0,
          matchIds: [],
          weekKey: currentWeek,
          limit: WEEKLY_CANDIDATE_LIMIT,
        };
      }

      const entitlement = await readTrustedEntitlement(tx, uid);
      const slots = Math.max(0, WEEKLY_CANDIDATE_LIMIT - used);
      const eligibleSelection = selected.slice(0, slots);
      const matchRefs = eligibleSelection.map((result) =>
        db.doc(matchPath(pairKey(uid, result.candidate.user.id))),
      );
      const existingMatchSnaps: Array<DocumentSnapshot<DocumentData>> = [];
      for (const ref of matchRefs) {
        existingMatchSnaps.push(await tx.get(ref));
      }

      const createdMatchIds: string[] = [];
      for (let index = 0; index < eligibleSelection.length; index++) {
        const result = eligibleSelection[index];
        const candidateUid = result.candidate.user.id;
        const key = pairKey(uid, candidateUid);
        const existingMatch = existingMatchSnaps[index];
        if (existingMatch.exists && !canReuseExistingPair(existingMatch.data() ?? {}, now)) {
          continue;
        }

        tx.set(db.doc(matchPath(key)), {
          userId: uid,
          partnerId: candidateUid,
          compatibilityScore: result.compatibilityScore,
          personalizedRankingScore: result.personalizedRankingScore,
          status: "suggested",
          compatibilityReasons: result.insights,
          categoryScores: result.categoryScores,
          categoryDataCompleteness: result.categoryDataCompleteness,
          dataCompleteness: result.dataCompleteness,
          strongestCategories: result.strongestCategories,
          weakerCategories: result.weakerCategories,
          compatibilityAlgorithmVersion: result.algorithmVersion,
          createdAt: Timestamp.fromDate(now),
          expiresAt: Timestamp.fromDate(new Date(now.getTime() + suggestionLifetimeMs)),
          pairKey: key,
          weekKey: currentWeek,
          searchScope: result.scope,
          generatedForTier: entitlement.premiumActive ? "premium" : "basic",
          generatedBySystem: true,
          generatedByTrustedBackend: true,
          participantIds: [uid, candidateUid].sort(),
          suggestedForUserIds: FieldValue.arrayUnion(uid),
          participantDecisions: {
            [uid]: "pending",
            [candidateUid]: "pending",
          },
          participantDecisionAt: {},
          updatedAt: Timestamp.fromDate(now),
        }, {merge: true});
        tx.create(db.collection("auditLogs").doc(), {
          type: "trusted_curated_candidate_created",
          uid,
          candidateUid,
          pairKey: key,
          weekKey: currentWeek,
          createdAt: Timestamp.fromDate(now),
        });
        createdMatchIds.push(key);
      }

      if (createdMatchIds.length > 0) {
        tx.set(weeklyRef, {
          weekKey: currentWeek,
          curatedCandidateCount: FieldValue.increment(createdMatchIds.length),
          updatedAt: Timestamp.fromDate(now),
        }, {merge: true});
      }

      return {
        status: createdMatchIds.length > 0 ? "created" : "unchanged",
        generatedCount: createdMatchIds.length,
        matchIds: createdMatchIds,
        weekKey: currentWeek,
        limit: WEEKLY_CANDIDATE_LIMIT,
      };
    });
  },
);

async function readExistingGeneratedMatches(
  uid: string,
  currentWeek: string,
): Promise<QueryDocumentSnapshot<DocumentData>[]> {
  const snapshot = await db.collection("matches")
    .where("suggestedForUserIds", "array-contains", uid)
    .where("weekKey", "==", currentWeek)
    .where("generatedBySystem", "==", true)
    .get();
  return snapshot.docs;
}

async function readBlockedUserIds(uid: string): Promise<Set<string>> {
  const snapshot = await db.collection(`users/${uid}/blocks`).get();
  return new Set(snapshot.docs.map((doc) => doc.id));
}

async function readPairHistory(uid: string, now: Date): Promise<PairHistoryContext> {
  const snapshot = await db.collection("matches")
    .where("participantIds", "array-contains", uid)
    .get();
  const excludedPairKeys = new Set<string>();
  const activePartnerIds = new Set<string>();
  for (const doc of snapshot.docs) {
    const data = doc.data();
    const key = String(data.pairKey || doc.id);
    const participantIds = readStringArray(data.participantIds);
    const otherUid = participantIds.find((id) => id !== uid);
    if (otherUid && isActiveConversationStatus(String(data.status ?? ""))) {
      activePartnerIds.add(otherUid);
    }
    if (excludesFromRecommendations(data, now)) {
      excludedPairKeys.add(key);
    }
  }
  return {excludedPairKeys, activePartnerIds};
}

function excludesFromRecommendations(data: DocumentData, now: Date): boolean {
  const status = String(data.status ?? "");
  if (["suggested", "interested", "mutual", "active", "unmatched", "blocked", "archived"].includes(status)) {
    return true;
  }
  const reintro = data.eligibleForReintroductionAt?.toDate?.() as Date | undefined;
  if (reintro) {
    return now.getTime() < reintro.getTime();
  }
  if (status === "passed") {
    const passedAt = data.passedAt?.toDate?.() as Date | undefined;
    if (!passedAt) return true;
    return now.getTime() < passedAt.getTime() + 90 * 24 * 60 * 60 * 1000;
  }
  if (status === "expired") {
    const expiredAt = data.expiredAt?.toDate?.() as Date | undefined;
    if (!expiredAt) return true;
    const decisions = (typeof data.participantDecisions === "object" && data.participantDecisions !== null) ?
      data.participantDecisions as Record<string, unknown> :
      {};
    const hadInterest = Object.values(decisions).includes("interested");
    const cooldownDays = hadInterest ? 90 : 60;
    return now.getTime() < expiredAt.getTime() + cooldownDays * 24 * 60 * 60 * 1000;
  }
  return false;
}

function canReuseExistingPair(data: DocumentData, now: Date): boolean {
  return !excludesFromRecommendations(data, now);
}

function isCandidateReceivable(profile: ServerCompatibilityProfile): boolean {
  const data = profile.user.data;
  return !data.deletedAt &&
    data.isDeleted !== true &&
    data.disabled !== true &&
    data.isDisabled !== true &&
    data.accountDisabled !== true &&
    data.isActive !== false &&
    (data.datingStatus ?? "active") === "active" &&
    (data.moderationStatus ?? "active") === "active" &&
    profile.user.age >= 18 &&
    data.isProfileComplete === true;
}

function isActiveConversationStatus(status: string): boolean {
  return status === "mutual" || status === "active";
}

function readStringArray(value: unknown): string[] {
  return Array.isArray(value) ? value.filter((item) => typeof item === "string") : [];
}
