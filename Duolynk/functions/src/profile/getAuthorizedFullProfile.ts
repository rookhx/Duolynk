import {onCall} from "firebase-functions/v2/https";
import {DocumentData, Transaction} from "firebase-admin/firestore";
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
      const relationshipGoals = await readStringAnswers(
        tx,
        candidateUid,
        RELATIONSHIP_GOALS_QUESTIONNAIRE,
        ["marriage", "longTermRelationship", "casualDating"],
      );
      if (uid === candidateUid) {
        return toSafeFullProfile(tx, candidateUid, user, relationshipGoals);
      }

      const match = await requireCandidateMatch(tx, uid, candidateUid);
      if (isMutualOrActive(match.data)) {
        return toSafeFullProfile(tx, candidateUid, user, relationshipGoals);
      }

      const grantSnap = await tx.get(db.doc(profileUnlockPath(uid, match.pairKey)));
      if (grantSnap.exists) {
        return toSafeFullProfile(tx, candidateUid, user, relationshipGoals);
      }

      const entitlement = await readTrustedEntitlement(tx, uid);
      if (entitlement.premiumActive) {
        return toSafeFullProfile(tx, candidateUid, user, relationshipGoals);
      }

      // Teaser-level fields only: the locked card shows location,
      // verification and relationship intention, never name/photos/bio.
      return {
        locked: true,
        candidateUid,
        compatibilityOnly: true,
        city: user.city ?? null,
        country: user.country ?? null,
        verificationStatus: user.verificationStatus ?? "unverified",
        relationshipGoals,
      };
    });

    return response;
  },
);

const INTERESTS_QUESTIONNAIRE = "questionnaire_one_interests";
const RELATIONSHIP_GOALS_QUESTIONNAIRE = "questionnaire_four_relationship_goals";

async function readQuestionnaireAnswers(
  tx: Transaction,
  uid: string,
  questionnaireId: string,
): Promise<Record<string, unknown>> {
  const snap = await tx.get(db.doc(`users/${uid}/questionnaires/${questionnaireId}`));
  const answers = snap.data()?.answers;
  return answers && typeof answers === "object" ? answers as Record<string, unknown> : {};
}

async function readStringAnswers(
  tx: Transaction,
  uid: string,
  questionnaireId: string,
  keys: string[],
): Promise<Record<string, string>> {
  const answers = await readQuestionnaireAnswers(tx, uid, questionnaireId);
  const result: Record<string, string> = {};
  for (const key of keys) {
    const value = answers[key];
    if (typeof value === "string" && value.length > 0) {
      result[key] = value;
    }
  }
  return result;
}

async function toSafeFullProfile(
  tx: Transaction,
  uid: string,
  user: DocumentData,
  relationshipGoals: Record<string, string>,
): Promise<Record<string, unknown>> {
  const interestAnswers = await readQuestionnaireAnswers(tx, uid, INTERESTS_QUESTIONNAIRE);
  const interests = Array.isArray(interestAnswers.selectedInterests) ?
    interestAnswers.selectedInterests.filter((item) => typeof item === "string") :
    [];

  const photoPaths = readStoragePaths(user.photoUrls);
  const photoUrls: string[] = [];
  for (const path of photoPaths) {
    photoUrls.push(await readableUrl(path));
  }
  const primaryPath = typeof user.photoUrl === "string" && isStoragePath(user.photoUrl) ?
    user.photoUrl :
    photoPaths[0];
  const primaryUrl = primaryPath ? await readableUrl(primaryPath) : null;
  return {
    locked: false,
    uid,
    displayName: user.displayName ?? "Duolynk Member",
    age: user.age ?? null,
    gender: user.gender ?? null,
    city: user.city ?? null,
    country: user.country ?? null,
    verificationStatus: user.verificationStatus ?? "unverified",
    photoUrls,
    photoUrl: primaryUrl,
    bio: user.bio ?? null,
    profilePrompts: Array.isArray(user.profilePrompts) ? user.profilePrompts : [],
    interests,
    relationshipGoals,
  };
}

// Prefer a short-lived signed URL. Signing needs the function's service
// account to hold iam.serviceAccounts.signBlob; without it, fall back to the
// storage path, which the client resolves through storage.rules.
async function readableUrl(path: string): Promise<string> {
  return (await signedReadUrl(path)) ?? path;
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
