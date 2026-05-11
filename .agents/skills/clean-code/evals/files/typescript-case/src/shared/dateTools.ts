export function formatIsoDate(input: string): string {
  return new Date(input).toISOString().slice(0, 10);
}
