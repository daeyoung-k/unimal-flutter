// PR 머지(master) → Notion 개발 로그 DB 자동 기록
// GitHub Actions(pull_request closed & merged)에서 실행. 외부 의존성 없음 (Node 20+ fetch).
//
// 필요한 환경변수:
//   NOTION_TOKEN         : Notion 내부 인티그레이션 토큰 (Secrets)
//   NOTION_DEVLOG_DB_ID  : 개발 로그 DB ID (워크플로우 env, 비밀 아님)
//   GH_TOKEN             : GitHub 토큰 (Actions의 GITHUB_TOKEN 자동 주입)
//   GITHUB_REPOSITORY    : owner/repo (Actions 자동 주입)
//   PR_NUMBER, PR_TITLE, PR_URL, PR_AUTHOR, PR_MERGED_AT : PR 이벤트 정보

const {
  NOTION_TOKEN,
  NOTION_DEVLOG_DB_ID,
  GH_TOKEN,
  GITHUB_REPOSITORY: REPO,
  PR_NUMBER,
  PR_TITLE,
  PR_URL,
  PR_AUTHOR,
  PR_MERGED_AT,
} = process.env;

if (!NOTION_TOKEN || !NOTION_DEVLOG_DB_ID) {
  console.error("❌ NOTION_TOKEN / NOTION_DEVLOG_DB_ID 가 필요합니다.");
  process.exit(1);
}
if (!PR_NUMBER) {
  console.error("❌ PR 정보가 없습니다. pull_request 트리거에서 실행하세요.");
  process.exit(1);
}

const TYPE_MAP = {
  feat: "기능",
  fix: "버그수정",
  refactor: "리팩토링",
  perf: "성능",
  design: "디자인",
  style: "디자인",
};
const EXCLUDE = new Set(["chore", "docs", "ci", "test", "build"]);
const FALLBACK_TYPE = "기타";

// PR에 포함된 커밋을 GitHub API로 조회 (머지 전략과 무관하게 동작)
const ghRes = await fetch(
  `https://api.github.com/repos/${REPO}/pulls/${PR_NUMBER}/commits?per_page=100`,
  {
    headers: {
      Authorization: `Bearer ${GH_TOKEN}`,
      Accept: "application/vnd.github+json",
      "User-Agent": "changelog-bot",
    },
  }
);
if (!ghRes.ok) {
  console.error(`❌ GitHub API 실패 (${ghRes.status})`);
  console.error(await ghRes.text());
  process.exit(1);
}
const commits = await ghRes.json();
const subjects = commits.map((c) => (c.commit?.message || "").split("\n")[0]).filter(Boolean);

const parse = (subject) => {
  const m = subject.match(/^\s*\[?([a-zA-Z]+)\]?\s*:?\s*(.*)$/);
  if (!m) return { type: FALLBACK_TYPE, text: subject };
  const key = m[1].toLowerCase();
  if (EXCLUDE.has(key)) return null;
  return { type: TYPE_MAP[key] ?? FALLBACK_TYPE, text: m[2] || subject };
};

const grouped = {};
for (const s of subjects) {
  const p = parse(s);
  if (!p) continue;
  (grouped[p.type] ??= []).push(p.text);
}

const changeTypes = Object.keys(grouped);
const mergeDate = (PR_MERGED_AT || new Date().toISOString()).slice(0, 10);
const title = PR_TITLE || `PR #${PR_NUMBER}`;

let detail =
  changeTypes.length === 0
    ? "분류 가능한 커밋이 없습니다."
    : changeTypes
        .map((t) => `■ ${t}\n` + grouped[t].map((x) => `  - ${x}`).join("\n"))
        .join("\n\n");
if (detail.length > 1900) detail = detail.slice(0, 1900) + "\n…(생략)";

const body = {
  parent: { database_id: NOTION_DEVLOG_DB_ID },
  properties: {
    제목: { title: [{ text: { content: title } }] },
    머지일: { date: { start: mergeDate } },
    "변경 유형": { multi_select: changeTypes.map((name) => ({ name })) },
    작성자: { rich_text: [{ text: { content: PR_AUTHOR || "" } }] },
    PR: { url: PR_URL || null },
    커밋: { rich_text: [{ text: { content: detail } }] },
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

console.log(`✅ PR #${PR_NUMBER} "${title}" 를 개발 로그에 기록했습니다.`);
console.log(`   커밋 ${subjects.length}건 / 변경 유형: ${changeTypes.join(", ") || "없음"}`);
