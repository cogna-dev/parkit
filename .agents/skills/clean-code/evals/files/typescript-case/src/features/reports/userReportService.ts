import { formatIsoDate } from "../../shared/dateTools";

export type RawUser = {
  id: string;
  firstName: string;
  lastName: string;
  joinedAt: string;
  active: boolean;
  totalSpend: number;
};

export type ReportRow = {
  label: string;
  joinedDate: string;
  tier: string;
  spend: number;
};

export function normalizeUserName(user: RawUser): string {
  return `${user.firstName.trim()} ${user.lastName.trim()}`.replace(
    /\s+/g,
    " ",
  );
}

export function isEligibleForReport(
  user: RawUser,
  includeInactive: boolean,
): boolean {
  return includeInactive || user.active;
}

export function buildUserCsvLines(rows: ReportRow[]): string[] {
  return [
    "label,joinedDate,tier,spend",
    ...rows.map(
      (row) =>
        `${row.label},${row.joinedDate},${row.tier},${row.spend.toFixed(2)}`,
    ),
  ];
}

function determineTier(totalSpend: number): string {
  if (totalSpend >= 1000) {
    return "platinum";
  }

  if (totalSpend >= 500) {
    return "gold";
  }

  return "standard";
}

export async function createUserReport(
  users: RawUser[],
  includeInactive: boolean,
): Promise<string> {
  const rows: ReportRow[] = [];

  for (const user of users) {
    if (!isEligibleForReport(user, includeInactive)) {
      continue;
    }

    rows.push({
      label: normalizeUserName(user),
      joinedDate: formatIsoDate(user.joinedAt),
      tier: determineTier(user.totalSpend),
      spend: user.totalSpend,
    });
  }

  return buildUserCsvLines(rows).join("\n");
}
