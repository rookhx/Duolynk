import {ServerCompatibilityProfile, ServerCompatibilityResult} from "./serverMatchingTypes";

export const compatibilityAlgorithmVersion = 3;

const weights = {
  interests: 0.30,
  lifestyle: 0.25,
  relationshipGoals: 0.25,
  personality: 0.15,
  location: 0.05,
};

const neutralDifferentScore = 0.5;

export function scoreCompatibility(
  currentUser: ServerCompatibilityProfile,
  candidate: ServerCompatibilityProfile,
): ServerCompatibilityResult {
  const interests = scoreInterests(currentUser.interests, candidate.interests);
  const lifestyle = scoreAnswers(
    {
      ...currentUser.lifestyleAnswers,
      ...optionalStringAnswers(currentUser, ["financialAttitude", "pets"]),
    },
    {
      ...candidate.lifestyleAnswers,
      ...optionalStringAnswers(candidate, ["financialAttitude", "pets"]),
    },
    lifestyleKeys,
    scoreLifestyleAnswer,
  );
  const relationshipGoals = scoreRelationshipCategory(currentUser, candidate);
  const personalityBase = scoreAnswers(
    currentUser.personalityAnswers,
    candidate.personalityAnswers,
    personalityKeys,
    scorePersonalityAnswer,
  );
  const affection = scoreAffectionStyles(
    currentUser.optionalAnswers.affectionStyles,
    candidate.optionalAnswers.affectionStyles,
  );
  const personality = combineScoreResults([personalityBase, affection]);
  const location = scoreLocation(currentUser, candidate);
  const categories = {
    interests,
    lifestyle,
    relationshipGoals,
    personality,
    location: location.scoreResult,
  };

  let weightedTotal = 0;
  let activeWeightTotal = 0;
  let completenessTotal = 0;
  for (const [key, result] of Object.entries(categories)) {
    const weight = weights[key as keyof typeof weights] ?? 0;
    completenessTotal += result.completeness * weight;
    if (!result.hasSignal) continue;
    weightedTotal += result.score * 100 * weight;
    activeWeightTotal += weight;
  }

  const categoryScores = Object.fromEntries(
    Object.entries(categories).map(([key, value]) => [key, value.scorePercent]),
  );
  const categoryDataCompleteness = Object.fromEntries(
    Object.entries(categories).map(([key, value]) => [key, value.completeness]),
  );
  const compatibilityScore = activeWeightTotal === 0 ?
    0 :
    clamp(Math.round(weightedTotal / activeWeightTotal), 0, 100);

  return {
    candidate,
    compatibilityScore,
    personalizedRankingScore: compatibilityScore,
    scope: location.scope,
    categoryScores,
    categoryDataCompleteness,
    dataCompleteness: clamp(completenessTotal, 0, 1),
    strongestCategories: categoryNamesByScore(categoryScores, 75),
    weakerCategories: categoryNamesByScore(categoryScores, undefined, 55, categoryDataCompleteness),
    insights: buildSafeInsights(categoryScores, currentUser, candidate, location.scope),
    algorithmVersion: compatibilityAlgorithmVersion,
  };
}

function scoreInterests(first: string[], second: string[]): ScoreResult {
  const firstSet = stringSet(first);
  const secondSet = stringSet(second);
  if (firstSet.size === 0 || secondSet.size === 0) return ScoreResult.noSignal(1);
  const overlap = [...firstSet].filter((item) => secondSet.has(item)).length;
  const smallerList = Math.min(firstSet.size, secondSet.size);
  const union = new Set([...firstSet, ...secondSet]).size;
  const coverage = smallerList === 0 ? 0 : overlap / smallerList;
  const jaccard = union === 0 ? 0 : overlap / union;
  return new ScoreResult(clamp((coverage * 0.7) + (jaccard * 0.3), 0, 1), 1, 1);
}

function scoreAnswers(
  first: Record<string, string>,
  second: Record<string, string>,
  expectedKeys: string[],
  scorer: (key: string, first: string, second: string) => number,
): ScoreResult {
  let total = 0;
  let comparable = 0;
  for (const key of expectedKeys) {
    const firstAnswer = normalize(first[key]);
    const secondAnswer = normalize(second[key]);
    if (!firstAnswer || !secondAnswer) continue;
    total += clamp(scorer(key, firstAnswer, secondAnswer), 0, 1);
    comparable++;
  }
  if (comparable === 0) return ScoreResult.noSignal(expectedKeys.length);
  return new ScoreResult(total, comparable, expectedKeys.length);
}

function scoreRelationshipCategory(
  currentUser: ServerCompatibilityProfile,
  candidate: ServerCompatibilityProfile,
): ScoreResult {
  const base = scoreAnswers(
    {
      ...currentUser.relationshipGoalAnswers,
      ...optionalStringAnswers(currentUser, ["relocationOpenness", "culturalBackgroundImportance"]),
    },
    {
      ...candidate.relationshipGoalAnswers,
      ...optionalStringAnswers(candidate, ["relocationOpenness", "culturalBackgroundImportance"]),
    },
    relationshipGoalKeys,
    scoreRelationshipAnswer,
  );
  const firstExpectation = normalize(String(currentUser.preferenceAnswers.relationshipExpectations ?? ""));
  const secondExpectation = normalize(String(candidate.preferenceAnswers.relationshipExpectations ?? ""));
  if (!firstExpectation || !secondExpectation) {
    return new ScoreResult(base.totalScore, base.comparableCount, relationshipGoalKeys.length + 1);
  }
  return new ScoreResult(
    base.totalScore + scoreMatrixAnswer(relationshipExpectationMatrix, firstExpectation, secondExpectation),
    base.comparableCount + 1,
    relationshipGoalKeys.length + 1,
  );
}

function scoreAffectionStyles(first: unknown, second: unknown): ScoreResult {
  const firstSet = stringSet(first);
  const secondSet = stringSet(second);
  if (firstSet.size === 0 || secondSet.size === 0) return ScoreResult.noSignal(1);
  const overlap = [...firstSet].filter((item) => secondSet.has(item)).length;
  const smallerList = Math.min(firstSet.size, secondSet.size);
  const union = new Set([...firstSet, ...secondSet]).size;
  return new ScoreResult(clamp((overlap / smallerList * 0.75) + (overlap / union * 0.25), 0, 1), 1, 1);
}

function combineScoreResults(results: ScoreResult[]): ScoreResult {
  const total = results.reduce((sum, result) => sum + result.totalScore, 0);
  const comparable = results.reduce((sum, result) => sum + result.comparableCount, 0);
  const expected = results.reduce((sum, result) => sum + result.expectedCount, 0);
  if (comparable === 0) return ScoreResult.noSignal(expected);
  return new ScoreResult(total, comparable, expected);
}

function scorePersonalityAnswer(key: string, first: string, second: string): number {
  if (first === second) return 1;
  const ordinal = personalityOrdinals[key];
  if (ordinal) return scoreOrdinalSimilarity(ordinal, first, second);
  return scoreMatrixAnswer(personalityMatrices[key], first, second);
}

function scoreLifestyleAnswer(key: string, first: string, second: string): number {
  if (first === second) return 1;
  const ordinal = lifestyleOrdinals[key];
  if (ordinal) return scoreOrdinalSimilarity(ordinal, first, second);
  return scoreMatrixAnswer(lifestyleMatrices[key], first, second);
}

function scoreRelationshipAnswer(key: string, first: string, second: string): number {
  if (first === second) return 1;
  const ordinal = relationshipOrdinals[key];
  if (ordinal) return scoreOrdinalSimilarity(ordinal, first, second);
  return scoreMatrixAnswer(relationshipMatrices[key], first, second);
}

function scoreOrdinalSimilarity(orderedAnswers: string[], first: string, second: string): number {
  const firstIndex = orderedAnswers.indexOf(first);
  const secondIndex = orderedAnswers.indexOf(second);
  if (firstIndex < 0 || secondIndex < 0) return neutralDifferentScore;
  const distance = Math.abs(firstIndex - secondIndex);
  if (distance === 0) return 1;
  const maxDistance = Math.max(1, orderedAnswers.length - 1);
  return clamp(1 - ((distance / maxDistance) * 0.8), 0.2, 1);
}

function scoreMatrixAnswer(
  matrix: Record<string, Record<string, number>> | undefined,
  first: string,
  second: string,
): number {
  if (first === second) return 1;
  return matrix?.[first]?.[second] ?? matrix?.[second]?.[first] ?? neutralDifferentScore;
}

function scoreLocation(currentUser: ServerCompatibilityProfile, candidate: ServerCompatibilityProfile): {
  scoreResult: ScoreResult;
  scope: "nearby" | "country" | "region" | "worldwide";
} {
  const current = currentUser.user;
  const other = candidate.user;
  const currentCountry = normalize(current.country);
  const otherCountry = normalize(other.country);
  const currentCity = normalize(current.city);
  const otherCity = normalize(other.city);
  if (
    current.latitude !== undefined &&
    current.longitude !== undefined &&
    other.latitude !== undefined &&
    other.longitude !== undefined
  ) {
    const distanceKm = haversineKm(current.latitude, current.longitude, other.latitude, other.longitude);
    if (distanceKm <= 50) return {scoreResult: new ScoreResult(1, 1, 1), scope: "nearby"};
    if (currentCountry && currentCountry === otherCountry) return {scoreResult: new ScoreResult(0.78, 1, 1), scope: "country"};
  }
  if (currentCity && otherCity && currentCountry === otherCountry && currentCity === otherCity) {
    return {scoreResult: new ScoreResult(1, 1, 1), scope: "nearby"};
  }
  if (currentCountry && currentCountry === otherCountry) {
    return {scoreResult: new ScoreResult(0.78, 1, 1), scope: "country"};
  }
  if (!currentCountry && !otherCountry) {
    return {scoreResult: ScoreResult.noSignal(1), scope: "worldwide"};
  }
  return {scoreResult: new ScoreResult(0.30, 1, 1), scope: "worldwide"};
}

function buildSafeInsights(
  categoryScores: Record<string, number>,
  currentUser: ServerCompatibilityProfile,
  candidate: ServerCompatibilityProfile,
  scope: string,
): Array<Record<string, unknown>> {
  const insights: Array<Record<string, unknown>> = [];
  const push = (category: string, title: string, description: string, priority: number) => {
    if ((categoryScores[category] ?? 0) >= 70) {
      insights.push({category, title, description, strength: "strong", displayPriority: priority});
    }
  };
  push("relationshipGoals", "Aligned relationship goals", "You share similar ideas about the kind of relationship you are looking for.", 0);
  push("personality", "Compatible personalities", "Your communication and personality profiles show promising alignment.", 1);
  push("lifestyle", "Compatible lifestyles", "Your day-to-day lifestyle preferences align well.", 2);
  const sharedInterests = [...stringSet(currentUser.interests)].filter((item) => stringSet(candidate.interests).has(item));
  if (sharedInterests.length > 0) {
    const shown = sharedInterests.slice(0, 3).join(", ");
    const more = sharedInterests.length > 3 ? ` and ${sharedInterests.length - 3} more` : "";
    insights.push({
      category: "interests",
      title: "Shared interests",
      description: `You both enjoy ${shown}${more}.`,
      strength: "strong",
      displayPriority: 3,
    });
  }
  if (scope === "nearby" || scope === "country") {
    insights.push({
      category: "location",
      title: "Convenient location",
      description: scope === "nearby" ? "You are located near each other." : "You are based in the same country.",
      strength: "informational",
      displayPriority: 4,
    });
  }
  return insights.sort((a, b) => Number(a.displayPriority) - Number(b.displayPriority)).slice(0, 5);
}

function categoryNamesByScore(
  categoryScores: Record<string, number>,
  minScore?: number,
  maxScore?: number,
  completeness: Record<string, number> = {},
): string[] {
  return Object.entries(categoryScores)
    .filter(([key, value]) => {
      if ((completeness[key] ?? 1) === 0) return false;
      if (minScore !== undefined && value < minScore) return false;
      if (maxScore !== undefined && value > maxScore) return false;
      return true;
    })
    .sort((a, b) => b[1] - a[1])
    .slice(0, 3)
    .map(([key]) => key);
}

class ScoreResult {
  constructor(
    readonly totalScore: number,
    readonly comparableCount: number,
    readonly expectedCount: number,
  ) {}

  static noSignal(expectedCount: number): ScoreResult {
    return new ScoreResult(0, 0, expectedCount);
  }

  get hasSignal(): boolean {
    return this.comparableCount > 0;
  }

  get score(): number {
    return this.comparableCount === 0 ? 0 : this.totalScore / this.comparableCount;
  }

  get scorePercent(): number {
    return clamp(Math.round(this.score * 100), 0, 100);
  }

  get completeness(): number {
    return this.expectedCount === 0 ? 0 : clamp(this.comparableCount / this.expectedCount, 0, 1);
  }
}

function optionalStringAnswers(profile: ServerCompatibilityProfile, keys: string[]): Record<string, string> {
  const result: Record<string, string> = {};
  for (const key of keys) {
    const value = profile.optionalAnswers[key];
    if (typeof value === "string" && value.trim().length > 0) result[key] = value;
  }
  return result;
}

function stringSet(value: unknown): Set<string> {
  if (!Array.isArray(value)) return new Set();
  return new Set(value.filter((item) => typeof item === "string").map(normalize).filter(Boolean) as string[]);
}

function normalize(value?: string | null): string | null {
  if (!value || value.trim().length === 0) return null;
  return value.trim().toLowerCase();
}

function haversineKm(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const earthRadiusKm = 6371;
  const dLat = radians(lat2 - lat1);
  const dLon = radians(lon2 - lon1);
  const a = Math.sin(dLat / 2) ** 2 +
    Math.cos(radians(lat1)) * Math.cos(radians(lat2)) * Math.sin(dLon / 2) ** 2;
  return earthRadiusKm * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function radians(degrees: number): number {
  return degrees * Math.PI / 180;
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

const lifestyleKeys = [
  "smoking",
  "drinking",
  "religionImportance",
  "exerciseFrequency",
  "dietPreference",
  "sleepingSchedule",
  "socialLifestyle",
  "financialAttitude",
  "pets",
];

const personalityKeys = [
  "introvertExtrovert",
  "planningVsSpontaneous",
  "riskTaking",
  "communicationStyle",
  "communicationFrequency",
  "conflictResolution",
  "humorStyle",
];

const relationshipGoalKeys = [
  "marriage",
  "longTermRelationship",
  "casualDating",
  "children",
  "familyImportance",
  "careerPriority",
  "livingTogether",
  "relocationOpenness",
  "culturalBackgroundImportance",
];

const lifestyleOrdinals: Record<string, string[]> = {
  smoking: ["never", "occasionally", "socially", "regularly", "prefer not to say"],
  drinking: ["never", "rarely", "socially", "often", "prefer not to say"],
  religionImportance: ["not important", "somewhat important", "important", "very important"],
  exerciseFrequency: ["rarely", "1-2 times a week", "3-4 times a week", "5+ times a week"],
  socialLifestyle: ["homebody", "balanced", "social and outgoing", "very active socially"],
  financialAttitude: ["careful saver", "mostly save but enjoy spending", "balanced", "spend on experiences", "spontaneous spender"],
};

const personalityOrdinals: Record<string, string[]> = {
  introvertExtrovert: ["deep introvert", "mostly introvert", "balanced", "mostly extrovert", "high-energy extrovert"],
  planningVsSpontaneous: ["love a plan", "usually organized", "balanced", "spontaneous often", "go with the flow"],
  riskTaking: ["very cautious", "thoughtfully careful", "balanced", "comfortably adventurous", "big risk taker"],
  communicationFrequency: ["i like plenty of space", "a few meaningful check-ins", "regular communication throughout the day", "i love staying closely connected"],
};

const relationshipOrdinals: Record<string, string[]> = {
  marriage: ["definitely want it", "open to it", "unsure", "not a priority", "do not want it"],
  longTermRelationship: ["essential", "very important", "open to it", "not sure yet", "not looking for that"],
  casualDating: ["not interested", "open in the short term", "depends on the person", "comfortable with it", "prefer casual right now"],
  familyImportance: ["central to my life", "very important", "important", "somewhat important", "less important"],
  careerPriority: ["top priority right now", "very important", "balanced with personal life", "flexible", "personal life comes first"],
  livingTogether: ["only after deep commitment", "open when the relationship is serious", "comfortable if timing feels right", "prefer to keep separate homes"],
  relocationOpenness: ["no", "only locally", "within my country", "internationally", "open to possibilities"],
  culturalBackgroundImportance: ["not important", "somewhat important", "important", "very important"],
};

const lifestyleMatrices: Record<string, Record<string, Record<string, number>>> = {
  dietPreference: {
    vegetarian: {vegan: 0.75, pescatarian: 0.75, "no preference": 0.7},
    vegan: {pescatarian: 0.55, "no preference": 0.65},
    pescatarian: {"no preference": 0.7},
    halal: {kosher: 0.75, "no preference": 0.65, other: 0.55},
    kosher: {"no preference": 0.65, other: 0.55},
    other: {"no preference": 0.55},
  },
  sleepingSchedule: {
    "early bird": {balanced: 0.8, "depends on the week": 0.65, "night owl": 0.35},
    balanced: {"night owl": 0.8, "depends on the week": 0.85},
    "night owl": {"depends on the week": 0.65},
  },
  pets: {
    "have or love pets": {"would like pets": 0.85, neutral: 0.65, "prefer not to live with pets": 0.25},
    "would like pets": {neutral: 0.75, "prefer not to live with pets": 0.35},
    neutral: {"prefer not to live with pets": 0.65},
  },
};

const personalityMatrices: Record<string, Record<string, Record<string, number>>> = {
  communicationStyle: {
    "direct and clear": {"warm and reflective": 0.8, "deep and intentional": 0.75, "depends on the person": 0.65, "playful and light": 0.55},
    "warm and reflective": {"deep and intentional": 0.85, "depends on the person": 0.7, "playful and light": 0.6},
    "playful and light": {"depends on the person": 0.7, "deep and intentional": 0.55},
    "deep and intentional": {"depends on the person": 0.65},
  },
  conflictResolution: {
    "need space first": {"prefer calm reflection": 0.85, "work toward compromise": 0.7, "need emotional reassurance": 0.45, "talk it through quickly": 0.35},
    "talk it through quickly": {"work toward compromise": 0.8, "need emotional reassurance": 0.7, "prefer calm reflection": 0.55},
    "prefer calm reflection": {"work toward compromise": 0.8, "need emotional reassurance": 0.6},
    "work toward compromise": {"need emotional reassurance": 0.75},
  },
  humorStyle: {
    "dry and witty": {sarcastic: 0.85, observational: 0.8, "playful and goofy": 0.6, "warm and wholesome": 0.55},
    sarcastic: {observational: 0.75, "playful and goofy": 0.65, "warm and wholesome": 0.45},
    "playful and goofy": {observational: 0.65, "warm and wholesome": 0.8},
    observational: {"warm and wholesome": 0.65},
  },
};

const relationshipMatrices: Record<string, Record<string, Record<string, number>>> = {
  children: {
    "definitely want children": {"open to children": 0.85, unsure: 0.55, "already have children": 0.75, "do not want children": 0.15},
    "open to children": {unsure: 0.75, "already have children": 0.8, "do not want children": 0.35},
    unsure: {"already have children": 0.55, "do not want children": 0.55},
    "do not want children": {"already have children": 0.25},
  },
};

const relationshipExpectationMatrix: Record<string, Record<string, number>> = {
  "clear commitment early": {"strong long-term alignment": 0.9, "shared emotional maturity": 0.8, "consistent communication": 0.75, "take things slowly": 0.45},
  "take things slowly": {"consistent communication": 0.75, "shared emotional maturity": 0.75, "strong long-term alignment": 0.6},
  "consistent communication": {"shared emotional maturity": 0.85, "strong long-term alignment": 0.8},
  "shared emotional maturity": {"strong long-term alignment": 0.85},
};
