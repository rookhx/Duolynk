export function pairKey(first: string, second: string): string {
  return [first, second].sort().join("_");
}

export function userPath(uid: string): string {
  return `users/${uid}`;
}

export function profileUnlockPath(uid: string, key: string): string {
  return `users/${uid}/profileUnlocks/${key}`;
}

export function conversationActivationPath(uid: string, key: string): string {
  return `users/${uid}/conversationActivations/${key}`;
}

export function weeklyAccessPath(uid: string, key: string): string {
  return `users/${uid}/weeklyAccess/${key}`;
}

export function entitlementPath(uid: string): string {
  return `entitlements/${uid}`;
}

export function matchPath(key: string): string {
  return `matches/${key}`;
}

export function conversationPath(conversationId: string): string {
  return `conversations/${conversationId}`;
}
