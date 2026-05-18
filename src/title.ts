import { DateTime } from "luxon";

export interface TitleParts {
  startDate: DateTime;
  endDate: DateTime;
  weekOfMonth: number;
  month: number;
}

export function getTitleParts(date: DateTime): TitleParts {
  const startDate = date.startOf("day");
  const endDate = startDate.plus({ days: 6 });
  const weekOfMonth = Math.floor((startDate.day - 1) / 7) + 1;

  return {
    startDate,
    endDate,
    weekOfMonth,
    month: startDate.month,
  };
}

export function renderThreadTitle(date: DateTime, titleSuffix: string): string {
  const { startDate, endDate, weekOfMonth, month } = getTitleParts(date);
  return `[${month}월 ${weekOfMonth}주차 ${titleSuffix}(${startDate.toFormat("MM/dd")}~${endDate.toFormat("MM/dd")})]`;
}
