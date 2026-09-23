import {onDocumentCreated, onDocumentUpdated} from "firebase-functions/v2/firestore";
import {createNotificationJob} from "./notificationJobs";

export const onCandidateCreated = onDocumentCreated(
  {document: "matches/{matchId}", region: "us-central1"},
  async (event) => {
    const match = event.data?.data();
    if (!match || match.generatedBySystem !== true) {
      return;
    }
    const recipients = Array.isArray(match.suggestedForUserIds) ?
      match.suggestedForUserIds :
      [];
    await Promise.all(
      recipients.map((userId: string) =>
        createNotificationJob({
          userId,
          title: "Duolynk found new people for you",
          body: "Your curated candidates are ready.",
          type: "curated_introduction",
          dedupeKey: `candidate_ready_${event.params.matchId}_${userId}`,
          data: {
            matchId: event.params.matchId,
            pairKey: match.pairKey ?? event.params.matchId,
            route: "match",
          },
        }),
      ),
    );
  },
);

export const onMutualMatchCreated = onDocumentUpdated(
  {document: "matches/{matchId}", region: "us-central1"},
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after || before.status === after.status || after.status !== "mutual") {
      return;
    }
    const recipients = Array.isArray(after.participantIds) ? after.participantIds : [];
    await Promise.all(
      recipients.map((userId: string) =>
        createNotificationJob({
          userId,
          title: "It's mutual!",
          body: "You both want to connect.",
          type: "mutual_match",
          dedupeKey: `mutual_${event.params.matchId}_${userId}`,
          data: {
            matchId: event.params.matchId,
            pairKey: after.pairKey ?? event.params.matchId,
            route: "match",
          },
        }),
      ),
    );
  },
);
