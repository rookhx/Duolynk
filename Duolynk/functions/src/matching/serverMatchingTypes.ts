import {DocumentData} from "firebase-admin/firestore";

export interface ServerUser {
  id: string;
  data: DocumentData;
  age: number;
  gender: string;
  interestedIn: string[];
  country?: string;
  city?: string;
  latitude?: number;
  longitude?: number;
}

export interface ServerCompatibilityProfile {
  user: ServerUser;
  interests: string[];
  lifestyleAnswers: Record<string, string>;
  relationshipGoalAnswers: Record<string, string>;
  personalityAnswers: Record<string, string>;
  preferenceAnswers: Record<string, unknown>;
  optionalAnswers: Record<string, unknown>;
}

export interface ServerCompatibilityResult {
  candidate: ServerCompatibilityProfile;
  compatibilityScore: number;
  personalizedRankingScore: number;
  scope: "nearby" | "country" | "region" | "worldwide";
  categoryScores: Record<string, number>;
  categoryDataCompleteness: Record<string, number>;
  dataCompleteness: number;
  strongestCategories: string[];
  weakerCategories: string[];
  insights: Array<Record<string, unknown>>;
  algorithmVersion: number;
}

export interface PersonalizedProfile {
  enabled: boolean;
  feedbackSignalCount: number;
  categoryWeightAdjustments: Record<string, number>;
}
