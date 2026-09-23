import {ServerCompatibilityProfile} from "./serverMatchingTypes";

const europe = new Set([
  "albania",
  "andorra",
  "austria",
  "belgium",
  "bosnia and herzegovina",
  "bulgaria",
  "croatia",
  "cyprus",
  "czech republic",
  "denmark",
  "estonia",
  "finland",
  "france",
  "germany",
  "greece",
  "hungary",
  "iceland",
  "ireland",
  "italy",
  "latvia",
  "lithuania",
  "luxembourg",
  "malta",
  "moldova",
  "monaco",
  "montenegro",
  "netherlands",
  "north macedonia",
  "norway",
  "poland",
  "portugal",
  "romania",
  "serbia",
  "slovakia",
  "slovenia",
  "spain",
  "sweden",
  "switzerland",
  "ukraine",
  "united kingdom",
]);

export interface EligibilityContext {
  blockedUserIds: Set<string>;
  blockedByUserIds: Set<string>;
  activePartnerIds: Set<string>;
  excludedPairKeys: Set<string>;
}

export function isEligiblePair(
  currentUser: ServerCompatibilityProfile,
  candidate: ServerCompatibilityProfile,
  context: EligibilityContext,
): boolean {
  const currentId = currentUser.user.id;
  const candidateId = candidate.user.id;
  if (currentId === candidateId) return false;
  if (context.blockedUserIds.has(candidateId) || context.blockedByUserIds.has(candidateId)) return false;
  if (context.activePartnerIds.has(candidateId)) return false;
  if (context.excludedPairKeys.has(pairKey(currentId, candidateId))) return false;
  if (!canReceiveIntroductions(currentUser) || !canReceiveIntroductions(candidate)) return false;
  if (!mutuallyGenderCompatible(currentUser, candidate)) return false;
  if (!mutuallyAgeCompatible(currentUser, candidate)) return false;
  if (!mutuallyDistanceCompatible(currentUser, candidate)) return false;
  if (hasDealBreakerConflict(currentUser, candidate) || hasDealBreakerConflict(candidate, currentUser)) return false;
  if (!relationshipIntentionsCompatible(currentUser, candidate)) return false;
  return true;
}

export function canReceiveIntroductions(profile: ServerCompatibilityProfile): boolean {
  const data = profile.user.data;
  if (data.deletedAt || data.isDeleted === true) return false;
  if (data.isDisabled === true || data.disabled === true || data.accountDisabled === true || data.isActive === false) {
    return false;
  }
  if ((data.datingStatus ?? "active") !== "active") return false;
  if ((data.moderationStatus ?? "active") !== "active") return false;
  if (profile.user.age < 18) return false;
  if (data.isProfileComplete !== true) return false;
  if (data.participatesInMatching === false || data.matchingEnabled === false || data.matchingDisabled === true) {
    return false;
  }
  return true;
}

function mutuallyGenderCompatible(a: ServerCompatibilityProfile, b: ServerCompatibilityProfile): boolean {
  return interestsIncludeGender(a.user.interestedIn, b.user.gender) &&
    interestsIncludeGender(b.user.interestedIn, a.user.gender);
}

function interestsIncludeGender(interests: string[], gender: string): boolean {
  const normalizedGender = normalize(gender);
  if (!normalizedGender || normalizedGender === "unspecified") return true;
  if (interests.length === 0) return true;
  const normalizedInterests = interests.map(normalize).filter(Boolean) as string[];
  if (normalizedInterests.includes("everyone")) return true;
  const accepted = normalizedGender === "woman" ?
    new Set(["women", "woman"]) :
    normalizedGender === "man" ?
      new Set(["men", "man"]) :
      normalizedGender === "non-binary" || normalizedGender === "nonbinary" ?
        new Set(["non-binary people", "nonbinary people", "non-binary", "nonbinary"]) :
        new Set([normalizedGender]);
  return normalizedInterests.some((item) => accepted.has(item));
}

function mutuallyAgeCompatible(a: ServerCompatibilityProfile, b: ServerCompatibilityProfile): boolean {
  return ageAllowedByPreference(b.user.age, a.preferenceAnswers.ageRange) &&
    ageAllowedByPreference(a.user.age, b.preferenceAnswers.ageRange);
}

function ageAllowedByPreference(age: number, rawRange: unknown): boolean {
  if (typeof rawRange !== "string" || rawRange.trim().length === 0) return true;
  const value = rawRange.trim();
  if (value.endsWith("+")) {
    const min = Number.parseInt(value.slice(0, -1), 10);
    return Number.isFinite(min) ? age >= min : true;
  }
  const [rawMin, rawMax] = value.split("-");
  const min = Number.parseInt(rawMin?.trim() ?? "", 10);
  const max = Number.parseInt(rawMax?.trim() ?? "", 10);
  if (!Number.isFinite(min) || !Number.isFinite(max)) return true;
  return age >= min && age <= max;
}

function mutuallyDistanceCompatible(a: ServerCompatibilityProfile, b: ServerCompatibilityProfile): boolean {
  return distanceAllowedByPreference(a, b, a.preferenceAnswers.distancePreference) &&
    distanceAllowedByPreference(b, a, b.preferenceAnswers.distancePreference);
}

function distanceAllowedByPreference(
  owner: ServerCompatibilityProfile,
  other: ServerCompatibilityProfile,
  preference: unknown,
): boolean {
  const normalizedPreference = normalize(typeof preference === "string" ? preference : undefined);
  if (!normalizedPreference || normalizedPreference === "worldwide") return true;
  const ownerCountry = normalize(owner.user.country);
  const otherCountry = normalize(other.user.country);
  const ownerCity = normalize(owner.user.city);
  const otherCity = normalize(other.user.city);
  if (
    owner.user.latitude !== undefined &&
    owner.user.longitude !== undefined &&
    other.user.latitude !== undefined &&
    other.user.longitude !== undefined
  ) {
    const distanceKm = haversineKm(owner.user.latitude, owner.user.longitude, other.user.latitude, other.user.longitude);
    if (normalizedPreference === "same city") return distanceKm <= 50;
    if (normalizedPreference === "same country") return !ownerCountry || !otherCountry || ownerCountry === otherCountry;
    if (normalizedPreference === "europe") return europe.has(ownerCountry ?? "") && europe.has(otherCountry ?? "");
  }
  if (normalizedPreference === "same city") {
    if (!ownerCountry || !otherCountry || !ownerCity || !otherCity) return true;
    return ownerCountry === otherCountry && ownerCity === otherCity;
  }
  if (normalizedPreference === "same country") {
    if (!ownerCountry || !otherCountry) return true;
    return ownerCountry === otherCountry;
  }
  if (normalizedPreference === "europe") {
    if (!ownerCountry || !otherCountry) return true;
    return europe.has(ownerCountry) && europe.has(otherCountry);
  }
  return true;
}

function hasDealBreakerConflict(owner: ServerCompatibilityProfile, other: ServerCompatibilityProfile): boolean {
  const dealBreakers = stringList(owner.preferenceAnswers.dealBreakers).map(normalize).filter(Boolean) as string[];
  const lifestyle = normalizeRecord(other.lifestyleAnswers);
  const goals = normalizeRecord(other.relationshipGoalAnswers);
  if (dealBreakers.includes("smoking") && ["occasionally", "socially", "regularly"].includes(lifestyle.smoking)) return true;
  if (dealBreakers.includes("heavy drinking") && lifestyle.drinking === "often") return true;
  if (
    dealBreakers.includes("not wanting commitment") &&
    (goals.longTermRelationship === "not looking for that" || goals.casualDating === "prefer casual right now")
  ) return true;
  if (dealBreakers.includes("different family values") && goals.familyImportance === "less important") return true;
  if (dealBreakers.includes("no interest in children") && goals.children === "do not want children") return true;
  return false;
}

function relationshipIntentionsCompatible(a: ServerCompatibilityProfile, b: ServerCompatibilityProfile): boolean {
  const first = relationshipIntent(a.relationshipGoalAnswers);
  const second = relationshipIntent(b.relationshipGoalAnswers);
  if (!first || !second) return true;
  return compatibleIntentions[first].has(second);
}

function relationshipIntent(answers: Record<string, string>): "committed" | "flexible" | "casualOnly" | null {
  const marriage = normalize(answers.marriage);
  const longTerm = normalize(answers.longTermRelationship);
  const casual = normalize(answers.casualDating);
  if (marriage === "definitely want it" || longTerm === "essential" || longTerm === "very important") return "committed";
  if (
    marriage === "do not want it" &&
    longTerm === "not looking for that" &&
    (casual === "comfortable with it" || casual === "prefer casual right now")
  ) return "casualOnly";
  if (longTerm === "not looking for that" && casual === "prefer casual right now") return "casualOnly";
  if (
    longTerm === "open to it" ||
    longTerm === "not sure yet" ||
    casual === "depends on the person" ||
    casual === "open in the short term" ||
    marriage === "open to it" ||
    marriage === "unsure" ||
    marriage === "not a priority"
  ) return "flexible";
  return null;
}

const compatibleIntentions = {
  committed: new Set(["committed", "flexible"]),
  flexible: new Set(["committed", "flexible", "casualOnly"]),
  casualOnly: new Set(["flexible", "casualOnly"]),
};

export function pairKey(first: string, second: string): string {
  return [first, second].sort().join("_");
}

function normalize(value?: string | null): string | null {
  if (!value || value.trim().length === 0) return null;
  return value.trim().toLowerCase();
}

function normalizeRecord(value: Record<string, string>): Record<string, string> {
  return Object.fromEntries(Object.entries(value).map(([key, raw]) => [key, normalize(raw) ?? ""]));
}

function stringList(value: unknown): string[] {
  return Array.isArray(value) ? value.filter((item) => typeof item === "string") : [];
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
