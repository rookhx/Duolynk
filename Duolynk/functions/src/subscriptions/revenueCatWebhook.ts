import {onRequest} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import {FieldValue} from "firebase-admin/firestore";
import {db, Timestamp} from "../shared/firestore";
import {entitlementPath} from "../shared/paths";

export const revenueCatWebhookSecret = defineSecret("REVENUECAT_WEBHOOK_SECRET");

interface RevenueCatEvent {
  id?: string;
  app_user_id?: string;
  type?: string;
  entitlement_ids?: string[];
  expiration_at_ms?: number | null;
  purchased_at_ms?: number | null;
}

export const revenueCatWebhook = onRequest(
  {
    region: "us-central1",
    secrets: [revenueCatWebhookSecret],
  },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method not allowed");
      return;
    }
    const expected = revenueCatWebhookSecret.value();
    const provided = readBearer(req.header("authorization")) ??
      req.header("x-revenuecat-webhook-secret");
    if (!expected || provided !== expected) {
      res.status(401).send("Unauthorized");
      return;
    }

    const event = (req.body?.event ?? req.body) as RevenueCatEvent;
    const eventId = event.id;
    const uid = event.app_user_id;
    if (!eventId || !uid) {
      res.status(400).send("Missing event id or app user id");
      return;
    }

    const eventRef = db.doc(`revenueCatEvents/${eventId}`);
    await db.runTransaction(async (tx) => {
      const existing = await tx.get(eventRef);
      if (existing.exists) {
        return;
      }

      const premiumActive = isPremiumActive(event);
      const expiresAt = typeof event.expiration_at_ms === "number" ?
        Timestamp.fromMillis(event.expiration_at_ms) :
        null;
      const entitlementId = event.entitlement_ids?.[0] ?? "premium";
      const entitlement = {
        premiumActive,
        entitlementId,
        expiresAt,
        source: "revenueCatWebhook",
        updatedAt: FieldValue.serverTimestamp(),
        lastProcessedEventId: eventId,
      };
      tx.set(db.doc(entitlementPath(uid)), entitlement, {merge: true});
      tx.set(
        db.doc(`users/${uid}/subscriptions/revenuecat_premium`),
        {
          userId: uid,
          tier: premiumActive ? "premium" : "free",
          platform: "revenueCat",
          isActive: premiumActive,
          entitlementId,
          expiresAt,
          updatedAt: FieldValue.serverTimestamp(),
        },
        {merge: true},
      );
      tx.create(eventRef, {
        uid,
        type: event.type ?? "unknown",
        processedAt: FieldValue.serverTimestamp(),
      });
      tx.create(db.collection("auditLogs").doc(), {
        type: "entitlement_updated",
        uid,
        premiumActive,
        eventType: event.type ?? "unknown",
        createdAt: FieldValue.serverTimestamp(),
      });
    });

    res.status(204).send();
  },
);

function readBearer(header: string | undefined): string | undefined {
  if (!header) {
    return undefined;
  }
  const match = header.match(/^Bearer\s+(.+)$/i);
  return match?.[1];
}

function isPremiumActive(event: RevenueCatEvent): boolean {
  const inactiveTypes = new Set([
    "CANCELLATION",
    "EXPIRATION",
    "BILLING_ISSUE",
    "PRODUCT_CHANGE",
  ]);
  if (event.type && inactiveTypes.has(event.type)) {
    return false;
  }
  if (typeof event.expiration_at_ms === "number") {
    return event.expiration_at_ms > Date.now();
  }
  return (event.entitlement_ids ?? []).length > 0;
}
