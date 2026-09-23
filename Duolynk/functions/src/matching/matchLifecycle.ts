import {onCall} from "firebase-functions/v2/https";
import {DocumentData, FieldValue} from "firebase-admin/firestore";
import {
  MATCH_CONVERSATION_STATUSES,
  MATCH_TERMINAL_STATUSES,
} from "../shared/constants";
import {requireUsableAccount, ensureNotBlocked} from "../shared/accounts";
import {db, Timestamp} from "../shared/firestore";
import {failedPrecondition, invalidArgument, unauthenticated} from "../shared/errors";
import {matchPath} from "../shared/paths";

const passCooldownMs = 90 * 24 * 60 * 60 * 1000;
const expiredNoInterestCooldownMs = 60 * 24 * 60 * 60 * 1000;
const expiredWithInterestCooldownMs = 90 * 24 * 60 * 60 * 1000;

interface DecisionRequest {
  matchId?: unknown;
  action?: unknown;
}

export const respondToCuratedMatch = onCall(
  {enforceAppCheck: true, region: "us-central1"},
  async (request) => {
    if (!request.auth) {
      unauthenticated();
    }
    const uid = request.auth.uid;
    const data = request.data as DecisionRequest;
    const action = data.action;
    if (typeof data.matchId !== "string" || data.matchId.length === 0) {
      invalidArgument("A valid match is required.");
    }
    if (action !== "interested" && action !== "pass") {
      invalidArgument("A valid response is required.");
    }

    const now = new Date();
    const result = await db.runTransaction(async (tx) => {
      await requireUsableAccount(tx, uid);
      const ref = db.doc(matchPath(data.matchId as string));
      const snap = await tx.get(ref);
      if (!snap.exists) {
        failedPrecondition("This introduction is no longer available.");
      }
      const match = snap.data() ?? {};
      const participantIds = readStringArray(match.participantIds);
      if (!participantIds.includes(uid)) {
        failedPrecondition("This introduction is no longer available.");
      }
      const otherUid = participantIds.find((id) => id !== uid);
      if (!otherUid) {
        failedPrecondition("This introduction is no longer available.");
      }
      await requireUsableAccount(tx, otherUid);
      await ensureNotBlocked(tx, uid, otherUid);

      const currentStatus = String(match.status ?? "");
      if (MATCH_CONVERSATION_STATUSES.has(currentStatus)) {
        return {status: currentStatus, matchId: snap.id, createdMutual: false};
      }
      if (MATCH_TERMINAL_STATUSES.has(currentStatus)) {
        failedPrecondition("This introduction is no longer available.");
      }
      if (isExpired(match.expiresAt, now)) {
        const reintro = expiredReintroductionAt(match, now);
        tx.set(ref, {
          status: "expired",
          expiredAt: Timestamp.fromDate(now),
          eligibleForReintroductionAt: Timestamp.fromDate(reintro),
          updatedAt: Timestamp.fromDate(now),
        }, {merge: true});
        return {status: "expired", matchId: snap.id, createdMutual: false};
      }

      const decisions = readDecisionMap(match.participantDecisions, participantIds);
      const decisionAt = readDateMap(match.participantDecisionAt);
      if (decisions[uid] === "passed") {
        failedPrecondition("This introduction is no longer available.");
      }
      if (action === "pass") {
        decisions[uid] = "passed";
        decisionAt[uid] = Timestamp.fromDate(now);
        tx.set(ref, {
          status: "passed",
          participantDecisions: decisions,
          participantDecisionAt: decisionAt,
          passedAt: Timestamp.fromDate(now),
          eligibleForReintroductionAt: Timestamp.fromDate(
            new Date(now.getTime() + passCooldownMs),
          ),
          updatedAt: Timestamp.fromDate(now),
        }, {merge: true});
        return {status: "passed", matchId: snap.id, createdMutual: false};
      }

      decisions[uid] = "interested";
      decisionAt[uid] = decisionAt[uid] ?? Timestamp.fromDate(now);
      const allInterested = participantIds.every((id) => decisions[id] === "interested");
      const createdMutual = allInterested && currentStatus !== "mutual";
      tx.set(ref, {
        status: allInterested ? "mutual" : "interested",
        participantDecisions: decisions,
        participantDecisionAt: decisionAt,
        suggestedForUserIds: FieldValue.arrayUnion(uid),
        ...(createdMutual ? {mutualAt: Timestamp.fromDate(now)} : {}),
        updatedAt: Timestamp.fromDate(now),
      }, {merge: true});
      return {
        status: allInterested ? "mutual" : "interested",
        matchId: snap.id,
        createdMutual,
      };
    });

    return result;
  },
);

export const expireCuratedMatch = onCall(
  {enforceAppCheck: true, region: "us-central1"},
  async (request) => {
    if (!request.auth) {
      unauthenticated();
    }
    const uid = request.auth.uid;
    const data = request.data as {matchId?: unknown};
    if (typeof data.matchId !== "string" || data.matchId.length === 0) {
      invalidArgument("A valid match is required.");
    }
    const now = new Date();
    return db.runTransaction(async (tx) => {
      await requireUsableAccount(tx, uid);
      const ref = db.doc(matchPath(data.matchId as string));
      const snap = await tx.get(ref);
      if (!snap.exists) {
        failedPrecondition("This introduction is no longer available.");
      }
      const match = snap.data() ?? {};
      const participantIds = readStringArray(match.participantIds);
      if (!participantIds.includes(uid)) {
        failedPrecondition("This introduction is no longer available.");
      }
      const status = String(match.status ?? "");
      if (MATCH_CONVERSATION_STATUSES.has(status) || MATCH_TERMINAL_STATUSES.has(status)) {
        return {status, matchId: snap.id};
      }
      if (!isExpired(match.expiresAt, now)) {
        return {status, matchId: snap.id};
      }
      tx.set(ref, {
        status: "expired",
        expiredAt: Timestamp.fromDate(now),
        eligibleForReintroductionAt: Timestamp.fromDate(expiredReintroductionAt(match, now)),
        updatedAt: Timestamp.fromDate(now),
      }, {merge: true});
      return {status: "expired", matchId: snap.id};
    });
  },
);

export const unmatchPair = onCall(
  {enforceAppCheck: true, region: "us-central1"},
  async (request) => {
    if (!request.auth) {
      unauthenticated();
    }
    const uid = request.auth.uid;
    const data = request.data as {matchId?: unknown};
    if (typeof data.matchId !== "string" || data.matchId.length === 0) {
      invalidArgument("A valid match is required.");
    }
    const now = new Date();
    return db.runTransaction(async (tx) => {
      await requireUsableAccount(tx, uid);
      const ref = db.doc(matchPath(data.matchId as string));
      const snap = await tx.get(ref);
      if (!snap.exists) {
        failedPrecondition("This connection is no longer available.");
      }
      const match = snap.data() ?? {};
      const participantIds = readStringArray(match.participantIds);
      if (!participantIds.includes(uid)) {
        failedPrecondition("This connection is no longer available.");
      }
      const status = String(match.status ?? "");
      if (status === "unmatched") {
        return {status: "unmatched", matchId: snap.id};
      }
      if (!MATCH_CONVERSATION_STATUSES.has(status)) {
        failedPrecondition("Only mutual connections can be unmatched.");
      }
      tx.set(ref, {
        status: "unmatched",
        unmatchedAt: match.unmatchedAt ?? Timestamp.fromDate(now),
        unmatchedBy: match.unmatchedBy ?? uid,
        updatedAt: Timestamp.fromDate(now),
      }, {merge: true});
      return {status: "unmatched", matchId: snap.id};
    });
  },
);

function isExpired(rawExpiresAt: unknown, now: Date): boolean {
  const expiresAt = toDate(rawExpiresAt);
  return !!expiresAt && now.getTime() >= expiresAt.getTime();
}

function expiredReintroductionAt(match: DocumentData, expiredAt: Date): Date {
  const decisions = readDecisionMap(match.participantDecisions, readStringArray(match.participantIds));
  const hasInterest = Object.values(decisions).includes("interested");
  const cooldown = hasInterest ? expiredWithInterestCooldownMs : expiredNoInterestCooldownMs;
  return new Date(expiredAt.getTime() + cooldown);
}

function readStringArray(value: unknown): string[] {
  return Array.isArray(value) ? value.filter((item) => typeof item === "string") : [];
}

function readDecisionMap(value: unknown, participantIds: string[]): Record<string, string> {
  const raw = typeof value === "object" && value !== null ? value as Record<string, unknown> : {};
  return Object.fromEntries(
    participantIds.map((id) => {
      const decision = raw[id];
      return [id, typeof decision === "string" ? decision : "pending"];
    }),
  );
}

function readDateMap(value: unknown): Record<string, unknown> {
  return typeof value === "object" && value !== null ? {...value as Record<string, unknown>} : {};
}

function toDate(value: unknown): Date | null {
  if (value instanceof Timestamp) {
    return value.toDate();
  }
  if (value && typeof value === "object" && "toDate" in value) {
    return (value as {toDate: () => Date}).toDate();
  }
  return null;
}
