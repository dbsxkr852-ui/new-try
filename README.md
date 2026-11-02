# 생각의 갈림길 · AI 윤리 설문

Vite + JavaScript / Supabase / GitHub → Vercel용 프로젝트입니다. 계정·실제 DB 연결·배포는 사용자가 설정해야 합니다. 실시간 AI 호출은 없으며 관리자가 작성한 딜레마에 응답합니다.

## 1. 파일 구조

```text
ai-ethics-survey/
├── index.html
├── package.json
├── package-lock.json        # 의존성 설치 후 생성
├── .env.example
├── .gitignore
├── src/
│   ├── main.js              # 기본 정보 → 딜레마 3개 → 완료, 관리자 통계
│   ├── api.js               # Supabase REST/Auth 호출
│   ├── stats.js             # 집계 및 HTML 안전 출력
│   ├── stats.test.js
│   └── style.css
└── supabase/
    ├── 01_schema.sql        # 테이블, RLS, 제출/통계 함수
    └── 02_seed.sql          # 처음 사용할 예시 문항 3개
```

## 2. 테이블 SQL부터 설정

새 Supabase 프로젝트를 만들고 SQL Editor → New query에서 `supabase/01_schema.sql` 전체를 붙여넣어 Run 합니다. 이어서 `02_seed.sql`을 실행합니다. RLS를 끄지 마세요. 코드의 전체 SQL은 이 두 파일에 있습니다.

| 테이블 | 저장 내용 | 브라우저 권한 |
| --- | --- | --- |
| ethics_questions | 순서, 제목, 상황, 선택지 A/B, 수정 시각 | 모든 방문자 읽기 |
| ethics_submissions | 응답 UUID, 만 나이, 성별, 서버 응답 시각 | 관리자만 읽기 |
| ethics_answers | 문항별 선택/이유, 응답 당시 문항 | 관리자만 읽기 |

방문자는 테이블에 직접 쓰지 못하고 `submit_ethics` 함수로 3문항을 한꺼번에 저장합니다. 함수가 선택·이유·연령·성별·문항 버전을 검사합니다. UUID 기반 재시도는 중복 저장하지 않습니다. 모든 시각은 서버에서 생성합니다.

## 3. 로컬 실행

Node.js 22.12 이상을 설치합니다. ZIP을 푼 폴더를 VS Code로 열고 터미널에서 다음 순서로 실행합니다.

```bash
npm install
```

`.env.example`을 복사해 `.env` 파일을 만듭니다. Supabase 프로젝트 설정의 Project URL과 API Keys의 Publishable key를 넣습니다. 기존 anon JWT 키도 지원합니다.

```dotenv
VITE_SUPABASE_URL=https://실제프로젝트.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=실제공개용키
```

```bash
npm run dev
```

터미널의 Local 주소를 엽니다. `.env`를 변경했다면 개발 서버를 재시작합니다. 이름은 받지 않으며 연령은 만 6~120세, 성별은 여성/남성/기타/응답하지 않음입니다. 응답 이유는 필수이며 1~2,000자입니다.

**VITE_ 변수는 빌드 결과와 브라우저에 공개됩니다.** `.env`는 Git 유출을 막는 용도이며 키를 브라우저에서 숨기는 기능이 아닙니다. Publishable/anon 키만 사용하고 `service_role`, `sb_secret_...`, DB 비밀번호는 절대 넣지 마세요. 실제 데이터 접근은 RLS와 함수 권한으로 제한합니다.

## 4. 문항 수정

Supabase → Table Editor → `ethics_questions`에서 `title`, `scenario`, `option_a`, `option_b`를 수정하고 저장합니다. 순서 `position`은 1, 2, 3을 유지합니다. 문항 3개가 모두 있어야 시작/제출할 수 있습니다. 문항 ID는 변경하거나 삭제하지 마세요. 문항 수정 직전에 열어 둔 응답은 제출 시 거부되므로 안내에 따라 새로 시작합니다. 기존 응답은 당시 문항과 선택지를 보관하며, 문항/선택지 내용이 다른 버전은 통계에서 분리합니다.

## 5. 관리자 계정과 통계

1. Supabase → Authentication → Users → Add user에서 관리자 이메일과 비밀번호로 사용자를 만듭니다. Auto Confirm 옵션이 있으면 켜거나 이메일 확인을 완료합니다. 사이트에는 회원가입 기능이 없습니다.
2. SQL Editor에서 아래 이메일을 본인 관리자 이메일로 바꾼 다음 실행합니다. 관리자 권한은 사용자 편집 가능한 user_metadata가 아닌 app_metadata로 관리합니다.

```sql
update auth.users
set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb)
  || '{"ethics_admin": true}'::jsonb
where email = '본인관리자이메일@example.com';
```

3. 사이트 상단 **관리자** 링크(`#admin`)에서 로그인합니다. 최소·최대 연령과 성별을 조합해 조회합니다. 기본값은 전체 연령/성별입니다.
4. 완료 응답 수, 문항 버전별 A/B 인원·비율, 최근 이유 최대 200개를 확인합니다. 집계는 DB 전체를 대상으로 하므로 API 기본 행 수 제한에 잘리지 않습니다. 응답이 없으면 빈 상태가 표시됩니다. 시간 표시는 한국 시간입니다.

관리자 토큰은 메모리에만 보관하며 새로고침/화면 이동 시 다시 로그인합니다. 만료 시에도 재로그인합니다. 문항 편집은 Supabase 대시보드에서 수행합니다.

## 6. GitHub 업로드

GitHub에서 빈 저장소를 만들고 **프로젝트 폴더 안**에서 실행합니다. 아래 URL은 본인 저장소 주소로 바꿉니다.

```bash
git init
git add .
git commit -m "Create AI ethics survey"
git branch -M main
git remote add origin https://github.com/YOUR_ACCOUNT/ai-ethics-survey.git
git push -u origin main
```

`.env`, `node_modules`, `dist`는 업로드하지 않습니다. GitHub 웹 업로드를 사용한다면 `.env.example`, `.gitignore`도 포함하고 `.env`는 제외하세요.

## 7. Vercel 배포

1. Vercel → Add New → Project → GitHub 저장소 선택.
2. Framework Preset: **Vite**, Build Command: `npm run build`, Output Directory: `dist`, Node.js: **22.x 이상**.
3. Environment Variables에 `.env`와 같은 두 변수 이름/값을 넣습니다. Production과 필요한 Preview 환경에 각각 설정합니다.
4. Deploy를 누릅니다. 이후 GitHub main에 push하면 다시 배포됩니다. 환경변수를 바꾸면 Redeploy합니다.

## 8. 확인 순서

- 방문자: 기본 정보와 동의 없이 진행 불가 → A/B 및 이유 모두 필수 → 이전 버튼으로 수정 → 마지막에 3문항을 함께 제출 → 완료 화면.
- 대시보드: 응답 1건과 답변 3건이 생기는지 확인. 새로 제출한 응답이 관리자 통계에 포함되는지 확인.
- 관리자: 연령 범위/성별을 바꿔 수와 비율, 빈 결과 확인.
- 권한: 일반 사용자는 응답 테이블 조회가 거부되거나 빈 결과, 통계 함수는 거부되어야 합니다. 관리자만 조회되어야 합니다.
- 문항 수정: 새 방문에 수정 내용 반영, 열어 둔 이전 버전 제출 거부, 과거 응답 보존 확인.
- 제출 실패: 입력 내용 유지. 같은 화면에서 재시도하면 UUID가 유지되어 중복 저장되지 않습니다. 새로고침 후 재응답은 별도 제출입니다.

```bash
npm test
npm run build
```

자동 테스트는 통계 버전 분리/A·B 합산/안전한 HTML 출력을 확인했으며 Vite 프로덕션 빌드가 통과했습니다. 별도 PGlite(PostgreSQL 호환) 테스트 환경에서는 SQL 재실행, 원자적 저장, 중복 방지, 빈 이유 및 누락 문항 거부, anon 직접 조회/쓰기 차단, 비관리자 통계 차단, 관리자 통계 및 연령 필터, 문항 수정 후 이전 버전 제출 거부를 확인했습니다. 이 환경에서는 auth.jwt()와 API 역할을 모의 구성했습니다. 실제 Supabase Auth/PostgREST와 브라우저 연결, Vercel 배포는 본인 프로젝트에서 위 순서로 확인해야 합니다.

익명 설문이므로 한 사람의 여러 차례 응답을 막거나 봇을 판별하지 않습니다. 공개 설문 대규모 운영 시에는 서버 측 속도 제한 및 CAPTCHA를 추가해야 합니다. 응답자 인증은 구현하지 않았습니다. 운영 전 보관 기간과 이용 목적을 정하고 시작 안내를 실제 운영 기준에 맞게 조정하세요.

## 공식 참고 자료

- https://vite.dev/guide/env-and-mode
- https://supabase.com/docs/guides/getting-started/api-keys
- https://supabase.com/docs/guides/database/postgres/row-level-security
