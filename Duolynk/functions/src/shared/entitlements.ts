import {Transaction} from "firebase-admin/firestore";
import {db} from "./firestore";
import {entitlementPath} from "./paths";

export interface TrustedEntitlement {
  premiumActive: boolean;
  entitlementId?: string;
  expiresAt?: Date | null;
}

export async function readTrustedEntitlement(
  tx: Transaction,
  uid: string,
): Promise<TrustedEntitlement> {
  const snap = await tx.get(db.doc(entitlementPath(uid)));
  const data = snap.data();
  if (!data) {
    return {premiumActive: false};
  }
  const expiresAt = data.expiresAt?.toDate?.() as Date | undefined;
  const activeByExpiry = !expiresAt || expiresAt.getTime() > Date.now();
  return {
    premiumActive: data.premiumActive === true && activeByExpiry,
    entitlementId: data.entitlementId,
    expiresAt: expiresAt ?? null,
  };
}
