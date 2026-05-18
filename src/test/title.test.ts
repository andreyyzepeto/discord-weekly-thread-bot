import test from "node:test";
import assert from "node:assert/strict";

import { DateTime } from "luxon";

import { getTitleParts, renderThreadTitle } from "../title";

test("renderThreadTitle matches the agreed weekly title format", () => {
  const date = DateTime.fromISO("2026-03-23T09:00:00", { zone: "Asia/Seoul" });
  const title = renderThreadTitle(date, "피드 부스팅 신청");

  assert.equal(title, "[3월 4주차 피드 부스팅 신청(03/23~03/29)]");
});

test("getTitleParts rolls the date range into the next month", () => {
  const date = DateTime.fromISO("2026-01-29T09:00:00", { zone: "Asia/Seoul" });
  const titleParts = getTitleParts(date);

  assert.equal(titleParts.month, 1);
  assert.equal(titleParts.weekOfMonth, 5);
  assert.equal(titleParts.startDate.toFormat("MM/dd"), "01/29");
  assert.equal(titleParts.endDate.toFormat("MM/dd"), "02/04");
});
