# PR 머지 → Notion 개발 로그 자동화

master로 PR이 **머지될 때마다** GitHub Actions가 해당 PR의 커밋을 모아
Notion **🛠 개발 로그** DB에 한 줄로 기록한다.

> 릴리즈 단위로 큰 그림을 남기는 `changelog-notion-automation.md`(태그 기반)와 짝을 이룬다.
> 이쪽은 더 잦은 PR/작업 단위 기록이다.

## 구성 파일

| 파일 | 역할 |
| --- | --- |
| `.github/workflows/merge-to-notion.yml` | `pull_request: closed` + `merged == true` 트리거 |
| `scripts/merge-to-notion.mjs` | PR 커밋을 GitHub API로 조회 → 분류 → Notion row 생성 |

## 동작 흐름

1. master 대상 PR을 머지
2. 워크플로우가 실행(머지된 PR만, 단순 close는 제외)
3. 스크립트가 GitHub API로 **그 PR의 커밋 목록**을 조회 (머지/스쿼시/리베이스 전략 무관)
4. 커밋 프리픽스로 분류 후 개발 로그 DB에 row 생성:
   - **제목** = PR 제목
   - **머지일** = PR 머지일
   - **변경 유형** = 분류 결과(중복 제거)
   - **작성자** = PR 작성자(login)
   - **PR** = PR 링크
   - **커밋** = 변경 유형별 커밋 목록

분류 매핑은 릴리즈 자동화와 동일(`feat→기능`, `fix→버그수정`, … / `chore·docs·ci·test·build` 제외).

## 최초 1회 설정 (수동)

릴리즈 자동화에서 이미 만든 Notion 인티그레이션과 `NOTION_TOKEN` Secret을 재사용한다.
**추가로 해야 할 것은 딱 하나:**

- **개발 로그 DB를 인티그레이션과 공유**: 🛠 개발 로그 DB 페이지 → `...` → Connections → 기존 인티그레이션 추가.

그 외:
- `NOTION_DEVLOG_DB_ID`는 워크플로우 yml에 직접 박혀 있다(`61dba958274b460ba54696ea8746edaf`, 비밀 아님).
- `GITHUB_TOKEN`은 Actions가 자동 주입하므로 별도 설정 불필요.

## 비고

- **트리거 조건**: master를 base로 하는 PR이 머지될 때만. 직접 push는 기록되지 않는다(원하면 `push: branches: master` 트리거 추가 가능).
- 커밋 프리픽스를 일관되게 쓰면 분류가 깔끔하다. 없으면 `기타`로 들어간다.
- 워크플로우 파일은 PR의 **base 브랜치(master)** 기준으로 실행되므로, 이 워크플로우가 master에 올라가 있어야 동작한다.
