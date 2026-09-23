import {onCall} from "firebase-functions/v2/https";
import {DocumentData} from "firebase-admin/firestore";
import {MATCH_CONVERSATION_STATUSES} from "../shared/constants";
import {requireUsableAccount, ensureNotBlocked} from "../shared/accounts";
import {db, Timestamp} from "../shared/firestore";
import {failedPrecondition, invalidArgument, unauthenticated} from "../shared/errors";
import {conversationPath, matchPath, pairKey} from "../shared/paths";

interface EnsureConversationRequest {
  matchId?: unknown;
}

export const ensureConversationForMatch = onCall(
  {enforceAppCheck: true, region: "us-central1"},
  async (request) => {
    if (!request.auth) {
      unauthenticated();
    }
    const uid = request.auth.uid;
    const data = request.data as EnsureConversationRequest;
    if (typeof data.matchId !== "string" || data.matchId.length === 0) {
      invalidArgument("A valid match is required.");
    }

    const now = new Date();
    return db.runTransaction(async (tx) => {
      await requireUsableAccount(tx, uid);
      const matchRef = db.doc(matchPath(data.matchId as string));
      const matchSnap = await tx.get(matchRef);
      if (!matchSnap.exists) {
        failedPrecondition("This connection is no longer available.");
      }
      const match = matchSnap.data() ?? {};
      const participantIds = readStringArray(match.participantIds);
      if (!participantIds.includes(uid) || participantIds.length < 2) {
        failedPrecondition("This connection is no longer available.");
      }
      if (!MATCH_CONVERSATION_STATUSES.has(String(match.status ?? ""))) {
        failedPrecondition("Only mutual connections can open a conversation.");
      }
      const otherUid = participantIds.find((id) => id !== uid);
      if (!otherUid) {
        failedPrecondition("This connection is no longer available.");
      }
      const currentUser = await requireUsableAccount(tx, uid);
      const otherUser = await requireUsableAccount(tx, otherUid);
      await ensureNotBlocked(tx, uid, otherUid);

      const key = String(match.pairKey || pairKey(participantIds[0], participantIds[1]));
      const conversationId = typeof match.chatId === "string" && match.chatId.length > 0 ?
        match.chatId :
        key;
      const conversationRef = db.doc(conversationPath(conversationId));
      const conversationSnap = await tx.get(conversationRef);
      if (!conversationSnap.exists) {
        tx.set(conversationRef, {
          matchId: matchSnap.id,
          pairKey: key,
          memberIds: participantIds,
          memberSnapshots: {
            [uid]: participantSnapshot(uid, currentUser.data),
            [otherUid]: participantSnapshot(otherUid, otherUser.data),
          },
          compatibilityScore: match.compatibilityScore ?? 0,
          compatibilityReasons: Array.isArray(match.compatibilityReasons) ?
            match.compatibilityReasons :
            [],
          lastMessage: "",
          lastMessageType: "text",
          lastMessageAt: Timestamp.fromDate(now),
          createdAt: Timestamp.fromDate(now),
          updatedAt: Timestamp.fromDate(now),
          lastReadAtByUser: {
            [uid]: Timestamp.fromDate(now),
            [otherUid]: Timestamp.fromDate(now),
          },
          typingByUser: {},
        });
      }
      if (match.chatId !== conversationId) {
        tx.set(matchRef, {
          chatId: conversationId,
          updatedAt: Timestamp.fromDate(now),
        }, {merge: true});
      }
      return {status: "ready", conversationId, matchId: matchSnap.id};
    });
  },
);

function participantSnapshot(uid: string, data: DocumentData): Record<string, unknown> {
  return {
    id: uid,
    displayName: data.displayName ?? "Duolynk Member",
    // Conversation snapshots intentionally avoid storing original profile photo
    // download URLs. Clients can resolve current profile photos through the
    // profile access path when the viewer is still authorized.
    photoUrl: null,
    country: data.country ?? null,
    age: data.age ?? null,
  };
}

function readStringArray(value: unknown): string[] {
  return Array.isArray(value) ? value.filter((item) => typeof item === "string") : [];
}
