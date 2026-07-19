// 릴리즈 태그 → Notion 체인지로그 DB 자동 기록
// GitHub Actions(태그 push)에서 실행된다. 외부 의존성 없음 (Node 20+ 내장 fetch 사용).
//
// 필요한 환경변수:
//   NOTION_TOKEN     : Notion 내부 인티그레이션 토큰 (GitHub Secrets)
//   NOTION_DB_ID     : 체인지로그 DB ID (GitHub Secrets 또는 Variables)
//   GITHUB_REF_NAME  : 이번 태그명 (예: v1.5.0) — Actions가 자동 주입
//   GITHUB_REPOSITORY: owner/repo — Actions가 자동 주입
//   PLATFORMS        : (선택) 콤마 구분 플랫폼. 기본 "Android,iOS"

import { execSync } from "node:child_process";

const {
  NOTION_TOKEN,
  NOTION_DB_ID,
  GITHUB_REF_NAME: TAG,
  GITHUB_REPOSITORY: REPO,
  PLATFORMS = "Android,iOS",
} = process.env;

if (!NOTION_TOKEN || !NOTION_DB_ID) {
  console.error("❌ NOTION_TOKEN / NOTION_DB_ID 환경변수가 필요합니다.");
  process.exit(1);
}
if (!TAG) {
  console.error("❌ 태그명(GITHUB_REF_NAME)이 없습니다. 태그 push 트리거에서 실행하세요.");
  process.exit(1);
}

// 커밋 프리픽스 → Notion '변경 유형' 옵션 매핑
const TYPE_MAP = {
  feat: "기능",
  fix: "버그수정",
  refactor: "리팩토링",
  perf: "성능",
  design: "디자인",
  style: "디자인",
};
// 체인지로그에서 제외할 프리픽스 (잡음)
const EXCLUDE = new Set(["chore", "docs", "ci", "test", "build"]);
const FALLBACK_TYPE = "기타";

const sh = (cmd) => execSync(cmd, { encoding: "utf8" }).trim();

// 직전 태그 찾기 (없으면 전체 히스토리)
let prevTag = null;
try {
  prevTag = sh(`git describe --tags --abbrev=0 ${TAG}^`);
} catch {
  console.log("ℹ️ 직전 태그 없음 — 전체 히스토리를 대상으로 합니다.");
}

const range = prevTag ? `${prevTag}..${TAG}` : TAG;
const rawLog = sh(`git log ${range} --no-merges --pretty=format:%s`);
const subjects = rawLog ? rawLog.split("\n") : [];

// 프리픽스 파싱: "feat: ...", "[feat] ...", "[fix]:..." 모두 처리
const parse = (subject) => {
  const m = subject.match(/^\s*\[?([a-zA-Z]+)\]?\s*:?\s*(.*)$/);
  if (!m) return { type: FALLBACK_TYPE, text: subject };
  const key = m[1].toLowerCase();
  if (EXCLUDE.has(key)) return null; // 잡음 제외
  const type = TYPE_MAP[key] ?? FALLBACK_TYPE;
  return { type, text: m[2] || subject };
};

const grouped = {}; // { 변경유형: [텍스트, ...] }
for (const s of subjects) {
  const parsed = parse(s);
  if (!parsed) continue;
  (grouped[parsed.type] ??= []).push(parsed.text);
}

const changeTypes = Object.keys(grouped);
const releaseDate = new Date().toISOString().slice(0, 10);
const platforms = PLATFORMS.split(",").map((p) => p.trim()).filter(Boolean);
const compareUrl = prevTag
  ? `https://github.com/${REPO}/compare/${prevTag}...${TAG}`
  : `https://github.com/${REPO}/releases/tag/${TAG}`;

// 상세 본문 (변경 유형별 묶음), Notion rich_text 2000자 제한 대비 컷
let detail =
  changeTypes.length === 0
    ? "분류 가능한 변경사항이 없습니다."
    : changeTypes
        .map((t) => `■ ${t}\n` + grouped[t].map((x) => `  - ${x}`).join("\n"))
        .join("\n\n");
if (detail.length > 1900) detail = detail.slice(0, 1900) + "\n…(생략)";

const body = {
  parent: { database_id: NOTION_DB_ID },
  properties: {
    버전: { title: [{ text: { content: TAG } }] },
    릴리즈일: { date: { start: releaseDate } },
    "변경 유형": { multi_select: changeTypes.map((name) => ({ name })) },
    플랫폼: { multi_select: platforms.map((name) => ({ name })) },
    "커밋/PR": { url: compareUrl },
    상세: { rich_text: [{ text: { content: detail } }] },
  },
};

const res = await fetch("https://api.notion.com/v1/pages", {
  method: "POST",
  headers: {
    Authorization: `Bearer ${NOTION_TOKEN}`,
    "Notion-Version": "2022-06-28",
    "Content-Type": "application/json",
  },
  body: JSON.stringify(body),
});

if (!res.ok) {
  console.error(`❌ Notion API 실패 (${res.status})`);
  console.error(await res.text());
  process.exit(1);
}

console.log(`✅ ${TAG} 체인지로그를 Notion에 기록했습니다.`);
console.log(`   변경 유형: ${changeTypes.join(", ") || "없음"} / 커밋 ${subjects.length}건`);
