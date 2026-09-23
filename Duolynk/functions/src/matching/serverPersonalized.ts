import {db} from "../shared/firestore";
import {PersonalizedProfile, ServerCompatibilityResult} from "./serverMatchingTypes";

const baseWeights: Record<string, number> = {
  interests: 0.30,
  lifestyle: 0.25,
  relationshipGoals: 0.25,
  personality: 0.15,
  location: 0.05,
};

const maxRankingPointAdjustment = 5;
const minFeedbackSignals = 3;

export async function readPersonalizedProfile(uid: string): Promise<PersonalizedProfile> {
  const snap = await db.doc(`users/${uid}/settings/personalized_matching_profile`).get();
  const data = snap.data() ?? {};
  return {
    enabled: data.enabled === true,
    feedbackSignalCount: typeof data.feedbackSignalCount === "number" ?
      Math.round(data.feedbackSignalCount) :
      0,
    categoryWeightAdjustments: readNumberMap(data.categoryWeightAdjustments),
  };
}

export function balancedPairRankingScore(
  result: ServerCompatibilityResult,
  currentUserProfile: PersonalizedProfile,
  candidateProfile: PersonalizedProfile,
): number {
  const current = personalizedScoreFor(result, currentUserProfile);
  const candidate = personalizedScoreFor(result, candidateProfile);
  return clamp(((current * 0.55) + (candidate * 0.45)), 0, 100);
}

function personalizedScoreFor(
  result: ServerCompatibilityResult,
  profile: PersonalizedProfile,
): number {
  if (!profile.enabled || profile.feedbackSignalCount < minFeedbackSignals) {
    return result.compatibilityScore;
  }

  let adjustedWeightedTotal = 0;
  let adjustedWeightTotal = 0;
  let baseWeightedTotal = 0;
  let baseWeightTotal = 0;

  for (const [category, baseWeight] of Object.entries(baseWeights)) {
    const completeness = result.categoryDataCompleteness[category] ?? 0;
    if (completeness <= 0) continue;

    const score = result.categoryScores[category] ?? 0;
    const adjustedWeight = clamp(
      baseWeight + (profile.categoryWeightAdjustments[category] ?? 0),
      Math.max(0.01, baseWeight - 0.05),
      baseWeight + 0.05,
    );

    adjustedWeightedTotal += score * adjustedWeight;
    adjustedWeightTotal += adjustedWeight;
    baseWeightedTotal += score * baseWeight;
    baseWeightTotal += baseWeight;
  }

  if (adjustedWeightTotal <= 0 || baseWeightTotal <= 0) {
    return result.compatibilityScore;
  }

  const adjusted = adjustedWeightedTotal / adjustedWeightTotal;
  const base = baseWeightedTotal / baseWeightTotal;
  const delta = clamp(adjusted - base, -maxRankingPointAdjustment, maxRankingPointAdjustment);
  return clamp(result.compatibilityScore + delta, 0, 100);
}

function readNumberMap(value: unknown): Record<string, number> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    return {};
  }
  const result: Record<string, number> = {};
  for (const [key, raw] of Object.entries(value)) {
    if (typeof raw === "number" && Number.isFinite(raw)) {
      result[key] = clamp(raw, -0.05, 0.05);
    }
  }
  return result;
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}
