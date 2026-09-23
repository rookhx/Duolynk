import {DocumentData, Transaction} from "firebase-admin/firestore";
import {
  MATCH_CANDIDATE_STATUSES,
  MATCH_CONVERSATION_STATUSES,
} from "./constants";
import {db} from "./firestore";
import {failedPrecondition} from "./errors";
import {pairKey} from "./paths";

export interface MatchState {
  id: string;
  refPath: string;
  data: DocumentData;
  otherUid: string;
  pairKey: string;
}

export async function requireCandidateMatch(
  tx: Transaction,
  viewerUid: string,
  candidateUid: string,
): Promise<MatchState> {
  const key = pairKey(viewerUid, candidateUid);
  const ref = db.doc(`matches/${key}`);
  const snap = await tx.get(ref);
  if (!snap.exists) {
    failedPrecondition("This curated candidate is no longer available.");
  }
  const data = snap.data() ?? {};
  const participantIds = readStringArray(data.participantIds);
  const suggestedFor = readStringArray(data.suggestedForUserIds);
  if (!participantIds.includes(viewerUid) || !participantIds.includes(candidateUid)) {
    failedPrecondition("This curated candidate is no longer available.");
  }
  if (!suggestedFor.includes(viewerUid) && !MATCH_CONVERSATION_STATUSES.has(data.status)) {
    failedPrecondition("This curated candidate is no longer available.");
  }
  if (!MATCH_CANDIDATE_STATUSES.has(data.status)) {
    failedPrecondition("This curated candidate is no longer available.");
  }
  return {
    id: snap.id,
    refPath: ref.path,
    data,
    otherUid: candidateUid,
    pairKey: key,
  };
}

export async function requireMutualConversationMatch(
  tx: Transaction,
  uid: string,
  matchId: string,
): Promise<MatchState> {
  const ref = db.doc(`matches/${matchId}`);
  const snap = await tx.get(ref);
  if (!snap.exists) {
    failedPrecondition("This connection is no longer available.");
  }
  const data = snap.data() ?? {};
  const participantIds = readStringArray(data.participantIds);
  if (!participantIds.includes(uid)) {
    failedPrecondition("This connection is no longer available.");
  }
  if (!MATCH_CONVERSATION_STATUSES.has(data.status)) {
    failedPrecondition("This connection is not mutual yet.");
  }
  const otherUid = participantIds.find((id) => id !== uid);
  if (!otherUid) {
    failedPrecondition("This connection is no longer available.");
  }
  return {
    id: snap.id,
    refPath: ref.path,
    data,
    otherUid,
    pairKey: data.pairKey || pairKey(participantIds[0], participantIds[1]),
  };
}

export function isMutualOrActive(data: DocumentData): boolean {
  return MATCH_CONVERSATION_STATUSES.has(data.status);
}

function readStringArray(value: unknown): string[] {
  return Array.isArray(value) ? value.filter((item) => typeof item === "string") : [];
}
