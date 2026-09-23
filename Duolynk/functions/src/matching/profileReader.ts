import {DocumentData} from "firebase-admin/firestore";
import {db} from "../shared/firestore";
import {ServerCompatibilityProfile, ServerUser} from "./serverMatchingTypes";

const questionnaireIds = {
  interests: "questionnaire_one_interests",
  lifestyle: "questionnaire_two_lifestyle",
  personality: "questionnaire_three_personality",
  relationshipGoals: "questionnaire_four_relationship_goals",
  preferences: "questionnaire_five_preferences_deal_breakers",
  optionalCompatibility: "questionnaire_six_optional_compatibility",
};

export async function buildCompatibilityProfile(
  userId: string,
  fallback?: DocumentData,
): Promise<ServerCompatibilityProfile | null> {
  const userData = fallback ?? (await db.doc(`users/${userId}`).get()).data();
  if (!userData) {
    return null;
  }
  const [interests, lifestyle, relationshipGoals, personality, preferences, optional] =
    await Promise.all([
      readInterestSelections(userId),
      readStringAnswers(userId, questionnaireIds.lifestyle, [
        "smoking",
        "drinking",
        "religionImportance",
        "exerciseFrequency",
        "dietPreference",
        "sleepingSchedule",
        "socialLifestyle",
      ]),
      readStringAnswers(userId, questionnaireIds.relationshipGoals, [
        "marriage",
        "longTermRelationship",
        "casualDating",
        "children",
        "familyImportance",
        "careerPriority",
        "livingTogether",
      ]),
      readStringAnswers(userId, questionnaireIds.personality, [
        "introvertExtrovert",
        "planningVsSpontaneous",
        "riskTaking",
        "communicationStyle",
        "communicationFrequency",
        "conflictResolution",
        "humorStyle",
      ]),
      readDynamicAnswers(userId, questionnaireIds.preferences, [
        "ageRange",
        "distancePreference",
        "dealBreakers",
        "relationshipExpectations",
      ]),
      readDynamicAnswers(userId, questionnaireIds.optionalCompatibility, [
        "affectionStyles",
        "financialAttitude",
        "pets",
        "relocationOpenness",
        "culturalBackgroundImportance",
        "politicalViewsImportance",
      ]),
    ]);

  return {
    user: toServerUser(userId, userData),
    interests,
    lifestyleAnswers: lifestyle,
    relationshipGoalAnswers: relationshipGoals,
    personalityAnswers: personality,
    preferenceAnswers: preferences,
    optionalAnswers: optional,
  };
}

export function toServerUser(userId: string, data: DocumentData): ServerUser {
  return {
    id: userId,
    data,
    age: displayAge(data),
    gender: typeof data.gender === "string" ? data.gender : "unspecified",
    interestedIn: readStringArray(data.interestedIn),
    country: typeof data.country === "string" ? data.country : undefined,
    city: typeof data.city === "string" ? data.city : undefined,
    latitude: readNumber(data.latitude ?? data.lat ?? data.location?.latitude ?? data.location?.lat),
    longitude: readNumber(data.longitude ?? data.lng ?? data.location?.longitude ?? data.location?.lng),
  };
}

function displayAge(data: DocumentData): number {
  const dob = toDate(data.dateOfBirth ?? data.dob);
  if (!dob) {
    return typeof data.age === "number" ? Math.round(data.age) : 18;
  }
  const now = new Date();
  let age = now.getUTCFullYear() - dob.getUTCFullYear();
  const birthdayThisYear = Date.UTC(now.getUTCFullYear(), dob.getUTCMonth(), dob.getUTCDate());
  const today = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate());
  if (today < birthdayThisYear) {
    age--;
  }
  return age;
}

async function readInterestSelections(userId: string): Promise<string[]> {
  const data = await readQuestionnaireAnswers(userId, questionnaireIds.interests);
  return readStringArray(data.selectedInterests);
}

async function readStringAnswers(
  userId: string,
  questionnaireId: string,
  keys: string[],
): Promise<Record<string, string>> {
  const answers = await readQuestionnaireAnswers(userId, questionnaireId);
  const result: Record<string, string> = {};
  for (const key of keys) {
    if (typeof answers[key] === "string" && answers[key].trim().length > 0) {
      result[key] = answers[key];
    }
  }
  return result;
}

async function readDynamicAnswers(
  userId: string,
  questionnaireId: string,
  keys: string[],
): Promise<Record<string, unknown>> {
  const answers = await readQuestionnaireAnswers(userId, questionnaireId);
  const result: Record<string, unknown> = {};
  for (const key of keys) {
    if (Object.prototype.hasOwnProperty.call(answers, key)) {
      result[key] = answers[key];
    }
  }
  return result;
}

async function readQuestionnaireAnswers(userId: string, questionnaireId: string): Promise<DocumentData> {
  const snap = await db.doc(`users/${userId}/questionnaires/${questionnaireId}`).get();
  const data = snap.data();
  return data?.answers && typeof data.answers === "object" ? data.answers : {};
}

function readStringArray(value: unknown): string[] {
  return Array.isArray(value) ? value.filter((item) => typeof item === "string") : [];
}

function readNumber(value: unknown): number | undefined {
  return typeof value === "number" && Number.isFinite(value) ? value : undefined;
}

function toDate(value: unknown): Date | null {
  if (value && typeof value === "object" && "toDate" in value) {
    return (value as {toDate: () => Date}).toDate();
  }
  if (value instanceof Date) {
    return value;
  }
  return null;
}
