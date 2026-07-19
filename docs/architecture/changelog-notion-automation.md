# 릴리즈 체인지로그 → Notion 자동화

릴리즈 태그(`vX.Y.Z`)를 push하면 GitHub Actions가 직전 태그~이번 태그 사이 커밋을 모아
Notion **🚀 릴리즈 · 체인지로그** DB에 한 줄로 기록한다.

## 구성 파일

| 파일 | 역할 |
| --- | --- |
| `.github/workflows/changelog-to-notion.yml` | 태그 push(`v*`) 트리거 워크플로우 |
| `scripts/changelog-to-notion.mjs` | 커밋 파싱 → Notion API row 생성 (외부 의존성 없음) |

## 동작 흐름

1. `git tag v1.5.0 && git push origin v1.5.0`
2. 워크플로우가 전체 히스토리 checkout → 직전 태그 탐색
3. `직전태그..이번태그` 범위 커밋 수집 (merge 제외)
4. 커밋 프리픽스로 분류 후 Notion row 생성:
   - **버전** = 태그명, **릴리즈일** = 실행일
   - **변경 유형** = 아래 매핑 결과(중복 제거)
   - **플랫폼** = Android, iOS (워크플로우 env `PLATFORMS`에서 조정)
   - **커밋/PR** = GitHub compare 링크
   - **상세** = 변경 유형별 커밋 목록

## 커밋 프리픽스 매핑

`feat:` 와 `[feat]` 표기 모두 인식한다.

| 커밋 프리픽스 | 변경 유형 |
| --- | --- |
| feat | 기능 |
| fix | 버그수정 |
| refactor | 리팩토링 |
| perf | 성능 |
| design, style | 디자인 |
| 프리픽스 없음/기타 | 기타 |
| chore, docs, ci, test, build | **체인지로그에서 제외** |

매핑을 바꾸려면 `scripts/changelog-to-notion.mjs` 상단의 `TYPE_MAP` / `EXCLUDE`를 수정한다.

## 최초 1회 설정 (수동)

1. **Notion 인티그레이션 생성**: https://www.notion.so/profile/integrations → New integration(Internal) → 토큰(`secret_...`) 복사.
2. **DB 공유**: 체인지로그 DB 페이지 → 우측 상단 `...` → Connections → 위 인티그레이션 추가.
3. **DB ID 확인**: 체인지로그 DB URL의 32자리 = `8c5d12c7e77247a1b12ed95c50f2765e`.
4. **GitHub Secrets 등록**: 레포 → Settings → Secrets and variables → Actions →
   - `NOTION_TOKEN` = 1번 토큰
   - `NOTION_DB_ID` = 3번 ID

설정 후 `git tag v1.x.x && git push origin v1.x.x` 하면 Actions 탭에서 결과를 확인할 수 있다.

## 비고

- 프리픽스 없는 커밋(`Update ...` 등)은 `기타`로 분류되므로, 깔끔한 체인지로그를 위해 커밋 프리픽스(`feat:`/`fix:` 등)를 일관되게 쓰는 게 좋다.
- 백엔드(unimal-server)는 모듈별 상시 배포라 앱 버전과 1:1로 맞지 않아 이 자동화 범위에서 제외했다.
