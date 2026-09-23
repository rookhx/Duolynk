import {DocumentData, Transaction} from "firebase-admin/firestore";
import {
  ACTIVE_DATING_STATUS,
  ACTIVE_MODERATION_STATUS,
} from "./constants";
import {db} from "./firestore";
import {failedPrecondition} from "./errors";
import {userPath} from "./paths";

export interface AccountState {
  uid: string;
  data: DocumentData;
}

export async function requireUsableAccount(
  tx: Transaction,
  uid: string,
): Promise<AccountState> {
  const ref = db.doc(userPath(uid));
  const snap = await tx.get(ref);
  if (!snap.exists) {
    failedPrecondition("This account is not available.");
  }
  const data = snap.data() ?? {};
  if (data.deletedAt || data.isDeleted === true || data.disabled === true) {
    failedPrecondition("This account is not available.");
  }
  if ((data.moderationStatus ?? ACTIVE_MODERATION_STATUS) !== ACTIVE_MODERATION_STATUS) {
    failedPrecondition("This account cannot use dating features right now.");
  }
  if ((data.datingStatus ?? ACTIVE_DATING_STATUS) !== ACTIVE_DATING_STATUS) {
    failedPrecondition("Dating is paused.");
  }
  if (isKnownUnderage(data)) {
    failedPrecondition("Duolynk is only available to people aged 18 or older.");
  }
  return {uid, data};
}

export async function ensureNotBlocked(
  tx: Transaction,
  firstUid: string,
  secondUid: string,
): Promise<void> {
  const [firstBlock, secondBlock] = await Promise.all([
    tx.get(db.doc(`users/${firstUid}/blocks/${secondUid}`)),
    tx.get(db.doc(`users/${secondUid}/blocks/${firstUid}`)),
  ]);
  if (firstBlock.exists || secondBlock.exists) {
    failedPrecondition("This connection is no longer available.");
  }
}

function isKnownUnderage(data: DocumentData): boolean {
  const dob = data.dateOfBirth;
  if (!dob?.toDate) {
    return false;
  }
  const birthDate: Date = dob.toDate();
  const today = new Date();
  const eighteenth = new Date(Date.UTC(
    birthDate.getUTCFullYear() + 18,
    birthDate.getUTCMonth(),
    birthDate.getUTCDate(),
  ));
  return today.getTime() < eighteenth.getTime();
}
