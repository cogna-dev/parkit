import {
  type RawUser,
  type ReportRow,
  buildUserCsvLines,
  createUserReport,
  normalizeUserName,
} from "../../../features/reports/userReportService";

export async function exportActiveUsers(users: RawUser[]): Promise<string> {
  const names = users.map(normalizeUserName).join(", ");
  const csv = await createUserReport(users, false);

  return `${names}\n${csv}`;
}

export function previewUserCsv(users: RawUser[]): string {
  const previewRows: ReportRow[] = users.map((user) => ({
    label: normalizeUserName(user),
    joinedDate: "preview",
    tier: "preview",
    spend: user.totalSpend,
  }));

  return buildUserCsvLines(previewRows).join("\n");
}
