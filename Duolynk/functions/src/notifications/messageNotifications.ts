import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {db} from "../shared/firestore";
import {createNotificationJob} from "./notificationJobs";

export const onMessageCreated = onDocumentCreated(
  {document: "conversations/{conversationId}/messages/{messageId}", region: "us-central1"},
  async (event) => {
    const message = event.data?.data();
    if (!message) {
      return;
    }
    const conversationSnap = await db.doc(`conversations/${event.params.conversationId}`).get();
    const conversation = conversationSnap.data();
    if (!conversation || !Array.isArray(conversation.memberIds)) {
      return;
    }
    const senderId = message.senderId;
    const recipientId = conversation.memberIds.find((id: string) => id !== senderId);
    if (!recipientId) {
      return;
    }
    const activation = await db
      .doc(`users/${recipientId}/conversationActivations/${conversation.pairKey}`)
      .get();
    const hasAccess = activation.exists;
    await createNotificationJob({
      userId: recipientId,
      title: "Duolynk",
      body: hasAccess ? "You have a new message." : "You have a new message from a match.",
      type: hasAccess ? "new_message" : "locked_match_message",
      data: {
        chatId: event.params.conversationId,
        matchId: conversation.matchId,
        route: "chat",
      },
    });
  },
);
