export const PROFILE_UNLOCK_LIMIT_BASIC = 1;
export const WEEKLY_CANDIDATE_LIMIT = 10;
export const CONVERSATION_ACTIVATION_LIMIT_BASIC = 1;
export const CONVERSATION_ACTIVATION_LIMIT_PREMIUM = 3;

export const GRANT_TYPE_EXPLICIT_BASIC = "explicitBasic";
export const GRANT_TYPE_LEGACY_MIGRATION = "legacyMigration";

export const MATCH_CONVERSATION_STATUSES = new Set(["mutual", "active"]);
export const MATCH_CANDIDATE_STATUSES = new Set([
  "suggested",
  "interested",
  "mutual",
  "active",
]);
export const MATCH_TERMINAL_STATUSES = new Set([
  "passed",
  "expired",
  "unmatched",
  "blocked",
  "archived",
]);

export const ACTIVE_MODERATION_STATUS = "active";
export const ACTIVE_DATING_STATUS = "active";
