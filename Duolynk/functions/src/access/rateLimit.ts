import {Transaction} from "firebase-admin/firestore";
import {db, Timestamp} from "../shared/firestore";
import {failedPrecondition} from "../shared/errors";

export async function enforceRateLimit(
  tx: Transaction,
  uid: string,
  key: string,
  minIntervalSeconds: number,
  now: Date,
): Promise<void> {
  const ref = db.doc(`users/${uid}/rateLimits/${key}`);
  const snap = await tx.get(ref);
  const lastAt = snap.data()?.lastAt?.toDate?.() as Date | undefined;
  if (lastAt && now.getTime() - lastAt.getTime() < minIntervalSeconds * 1000) {
    failedPrecondition("Please wait a moment and try again.");
  }
  tx.set(ref, {lastAt: Timestamp.fromDate(now)}, {merge: true});
}
