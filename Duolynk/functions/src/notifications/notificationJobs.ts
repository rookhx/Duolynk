import {FieldValue} from "firebase-admin/firestore";
import {db} from "../shared/firestore";

export async function createNotificationJob(params: {
  userId: string;
  title: string;
  body: string;
  type: string;
  data: Record<string, string | null | undefined>;
  dedupeKey?: string;
}): Promise<void> {
  const id = params.dedupeKey ?? db.collection("notification_jobs").doc().id;
  const ref = db.doc(`notification_jobs/${id}`);
  await ref.set(
    {
      userId: params.userId,
      title: params.title,
      body: params.body,
      type: params.type,
      data: params.data,
      dedupeKey: params.dedupeKey ?? null,
      createdAt: FieldValue.serverTimestamp(),
      status: "queued",
    },
    {merge: false},
  );
}
