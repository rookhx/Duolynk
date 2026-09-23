import {onCall} from "firebase-functions/v2/https";
import {DocumentData} from "firebase-admin/firestore";
import {requireUsableAccount, ensureNotBlocked} from "../shared/accounts";
import {readTrustedEntitlement} from "../shared/entitlements";
import {db, storage} from "../shared/firestore";
import {invalidArgument, unauthenticated} from "../shared/errors";
import {profileUnlockPath} from "../shared/paths";
import {isMutualOrActive, requireCandidateMatch} from "../shared/matches";

interface FullProfileRequest {
  candidateUid?: unknown;
}

export const getAuthorizedFullProfile = onCall(
  {enforceAppCheck: true, region: "us-central1"},
  async (request) => {
    if (!request.auth) {
      unauthenticated();
    }
    const uid = request.auth.uid;
    const data = request.data as FullProfileRequest;
    if (typeof data.candidateUid !== "string") {
      invalidArgument("A valid profile is required.");
    }
    const candidateUid = data.candidateUid;

    const response = await db.runTransaction(async (tx) => {
      await requireUsableAccount(tx, uid);
      await requireUsableAccount(tx, candidateUid);
      await ensureNotBlocked(tx, uid, candidateUid);

      const userSnap = await tx.get(db.doc(`users/${candidateUid}`));
      const user = userSnap.data() ?? {};
      if (uid === candidateUid) {
        return toSafeFullProfile(candidateUid, user);
      }

      const match = await requireCandidateMatch(tx, uid, candidateUid);
      if (isMutualOrActive(match.data)) {
        return toSafeFullProfile(candidateUid, user);
      }

      const grantSnap = await tx.get(db.doc(profileUnlockPath(uid, match.pairKey)));
      if (grantSnap.exists) {
        return toSafeFullProfile(candidateUid, user);
      }

      const entitlement = await readTrustedEntitlement(tx, uid);
      if (entitlement.premiumActive) {
        return toSafeFullProfile(candidateUid, user);
      }

      return {
        locked: true,
        candidateUid,
        compatibilityOnly: true,
      };
    });

    return response;
  },
);

async function toSafeFullProfile(uid: string, user: DocumentData): Promise<Record<string, unknown>> {
  const photoPaths = readStoragePaths(user.photoUrls);
  const signedPhotoUrls: string[] = [];
  for (const path of photoPaths) {
    const signed = await signedReadUrl(path);
    if (signed) {
      signedPhotoUrls.push(signed);
    }
  }
  const primaryPath = typeof user.photoUrl === "string" && isStoragePath(user.photoUrl) ?
    user.photoUrl :
    photoPaths[0];
  const signedPrimary = primaryPath ? await signedReadUrl(primaryPath) : null;
  return {
    locked: false,
    uid,
    displayName: user.displayName ?? "Duolynk Member",
    age: user.age ?? null,
    city: user.city ?? null,
    country: user.country ?? null,
    verificationStatus: user.verificationStatus ?? "unverified",
    photoUrls: signedPhotoUrls,
    photoUrl: signedPrimary,
    bio: user.bio ?? null,
    profilePrompts: Array.isArray(user.profilePrompts) ? user.profilePrompts : [],
  };
}

function readStoragePaths(value: unknown): string[] {
  if (!Array.isArray(value)) {
    return [];
  }
  return value.filter((item) => typeof item === "string" && isStoragePath(item)) as string[];
}

function isStoragePath(value: string): boolean {
  return value.startsWith("users/") && !value.startsWith("http://") && !value.startsWith("https://");
}

async function signedReadUrl(path: string): Promise<string | null> {
  try {
    const [url] = await storage.bucket().file(path).getSignedUrl({
      action: "read",
      expires: Date.now() + 15 * 60 * 1000,
    });
    return url;
  } catch (_) {
    return null;
  }
}
