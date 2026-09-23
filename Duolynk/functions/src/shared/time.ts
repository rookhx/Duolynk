export function weekKey(date = new Date()): string {
  const utcMidnight = Date.UTC(
    date.getUTCFullYear(),
    date.getUTCMonth(),
    date.getUTCDate(),
  );
  const normalized = new Date(utcMidnight);
  const weekday = normalized.getUTCDay() === 0 ? 7 : normalized.getUTCDay();
  const startMs = utcMidnight - (weekday - 1) * 24 * 60 * 60 * 1000;
  const endMs = startMs + 6 * 24 * 60 * 60 * 1000;
  return `${formatDate(new Date(startMs))}_${formatDate(new Date(endMs))}`;
}

function formatDate(date: Date): string {
  return [
    date.getUTCFullYear().toString().padStart(4, "0"),
    (date.getUTCMonth() + 1).toString().padStart(2, "0"),
    date.getUTCDate().toString().padStart(2, "0"),
  ].join("-");
}
