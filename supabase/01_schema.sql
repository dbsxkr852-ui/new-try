-- 새 Supabase 프로젝트의 SQL Editor에서 전체 실행. 기존 다른 프로젝트와 분리 권장.
begin;
create table if not exists public.ethics_questions (
 id uuid primary key default gen_random_uuid(), position integer not null unique check(position between 1 and 3),
 title text not null check(length(title) between 1 and 200), scenario text not null check(length(scenario) between 1 and 5000),
 option_a text not null check(length(option_a) between 1 and 1000), option_b text not null check(length(option_b) between 1 and 1000),
 updated_at timestamptz not null default now()
);
create or replace function public.ethics_touch() returns trigger language plpgsql set search_path='' as $$
begin new.updated_at=clock_timestamp(); return new; end $$;
drop trigger if exists ethics_question_touch on public.ethics_questions;
create trigger ethics_question_touch before update on public.ethics_questions for each row execute function public.ethics_touch();
create table if not exists public.ethics_submissions (
 id uuid primary key, age integer not null check(age between 6 and 120),
 gender text not null check(gender in ('여성','남성','기타','응답하지 않음')),
 created_at timestamptz not null default now()
);
create table if not exists public.ethics_answers (
 submission_id uuid not null references public.ethics_submissions(id) on delete cascade,
 question_id uuid not null references public.ethics_questions(id),
 question_snapshot jsonb not null, choice text not null check(choice in ('A','B')),
 reason text not null check(length(btrim(reason)) between 1 and 2000),
 primary key(submission_id,question_id)
);
alter table public.ethics_questions enable row level security;
alter table public.ethics_submissions enable row level security;
alter table public.ethics_answers enable row level security;
revoke all on public.ethics_questions,public.ethics_submissions,public.ethics_answers from anon,authenticated;
grant select on public.ethics_questions to anon,authenticated;
grant select on public.ethics_submissions,public.ethics_answers to authenticated;
drop policy if exists ethics_question_read on public.ethics_questions;
create policy ethics_question_read on public.ethics_questions for select to anon,authenticated using(true);
drop policy if exists ethics_submission_admin on public.ethics_submissions;
create policy ethics_submission_admin on public.ethics_submissions for select to authenticated using((auth.jwt()->'app_metadata'->>'ethics_admin')='true');
drop policy if exists ethics_answer_admin on public.ethics_answers;
create policy ethics_answer_admin on public.ethics_answers for select to authenticated using((auth.jwt()->'app_metadata'->>'ethics_admin')='true');
-- 제출은 이 함수만 허용. 3문항 검증, 서버 시각, 원자적 저장, 재시도 중복 방지.
create or replace function public.submit_ethics(p_id uuid,p_age integer,p_gender text,p_answers jsonb)
returns uuid language plpgsql security definer set search_path='' as $$
declare q public.ethics_questions; a jsonb; n integer;
begin
 if p_age is null or p_age not between 6 and 120 or p_gender is null or p_gender not in ('여성','남성','기타','응답하지 않음') then raise exception '기본 정보를 확인해 주세요.'; end if;
 if jsonb_typeof(p_answers) is distinct from 'array' or jsonb_array_length(p_answers)<>3 then raise exception '세 문항 모두 응답해 주세요.'; end if;
 -- 동일 요청 ID가 이미 완료되었다면 응답 내용을 노출하지 않고 성공 처리.
 insert into public.ethics_submissions(id,age,gender) values(p_id,p_age,p_gender) on conflict(id) do nothing;
 get diagnostics n=row_count;
 if n=0 then return p_id; end if;
 if (select count(*) from public.ethics_questions)<>3 then raise exception '관리자가 세 문항을 설정해야 합니다.'; end if;
 for q in select * from public.ethics_questions order by position for share loop
  select count(*) into n from jsonb_array_elements(p_answers) e where e->>'id'=q.id::text;
  if n<>1 then raise exception '문항 구성이 변경되었습니다. 처음부터 다시 시작해 주세요.'; end if;
  select e into a from jsonb_array_elements(p_answers) e where e->>'id'=q.id::text;
  if a->>'updated_at' is distinct from q.updated_at::text and (a->>'updated_at')::timestamptz is distinct from q.updated_at then raise exception '문항이 수정되었습니다. 처음부터 다시 시작해 주세요.'; end if;
  if a->>'choice' is null or a->>'choice' not in ('A','B') or a->>'reason' is null or length(btrim(a->>'reason')) not between 1 and 2000 then raise exception '선택과 이유를 확인해 주세요.'; end if;
  insert into public.ethics_answers values(p_id,q.id,to_jsonb(q),a->>'choice',btrim(a->>'reason'));
 end loop;
 return p_id;
end $$;
revoke all on function public.submit_ethics(uuid,integer,text,jsonb) from public;
grant execute on function public.submit_ethics(uuid,integer,text,jsonb) to anon,authenticated;
-- 통계는 전체 데이터 집계. 이유는 최근 200개만 표시.
create or replace function public.ethics_report(p_min integer default 6,p_max integer default 120,p_gender text default null)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare result jsonb;
begin
 if (auth.jwt()->'app_metadata'->>'ethics_admin') is distinct from 'true' then raise exception '관리자 권한이 필요합니다.'; end if;
 with selected as (select * from public.ethics_submissions where age between p_min and p_max and (p_gender is null or gender=p_gender)),
 counts as (select a.question_id,a.question_snapshot->>'title' title,a.question_snapshot->>'option_a' option_a,a.question_snapshot->>'option_b' option_b,a.choice,count(*) total from public.ethics_answers a join selected s on s.id=a.submission_id group by 1,2,3,4,5),
 recent as (select s.age,s.gender,s.created_at,a.question_snapshot->>'title' title,a.choice,a.reason from public.ethics_answers a join selected s on s.id=a.submission_id order by s.created_at desc,a.question_id limit 200)
 select jsonb_build_object('respondents',(select count(*) from selected),'counts',coalesce((select jsonb_agg(to_jsonb(c)) from counts c),'[]'::jsonb),'recent',coalesce((select jsonb_agg(to_jsonb(r)) from recent r),'[]'::jsonb)) into result;
 return result;
end $$;
revoke all on function public.ethics_report(integer,integer,text) from public;
grant execute on function public.ethics_report(integer,integer,text) to authenticated;
commit;
