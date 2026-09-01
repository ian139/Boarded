#!/usr/bin/env python3
"""Exercise the disposable local Supabase social/session security boundary.

The harness uses two ordinary password-authenticated users and an anonymous
client. Postgres is used only for deterministic fixture setup/cleanup; every
assertion of RLS, triggers, RPCs, and storage policies goes through local HTTP.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import threading
import uuid
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from http.client import HTTPResponse
from urllib.error import HTTPError, URLError
from urllib.parse import quote, urlparse
from urllib.request import Request, urlopen


LOCAL_URL_ENV = "BOARDED_LOCAL_SUPABASE_URL"
DEFAULT_LOCAL_URL = "http://127.0.0.1:54321"
DB_CONTAINER_ENV = "BOARDED_LOCAL_DB_CONTAINER"
DEFAULT_DB_CONTAINER = "supabase_db_boarded-supabase"
PASSWORD = "BoardedHarness-2026!"
INSTANCE_ID = "00000000-0000-0000-0000-000000000000"

OWNER_ID = "2c6f6f39-3b0e-4d8b-8b8d-2c8a9f6b4c11"
OTHER_ID = "7a4e2d80-6c35-49d2-8d2e-51ec2dd09322"
# A fixture-only profile fills a capacity slot; it never authenticates.
FILLER_ID = "8f4d2e10-4c68-44af-90c5-11d7b8e3aa19"
OWNER_EMAIL = "boarded-rls-harness-owner@local.invalid"
OTHER_EMAIL = "boarded-rls-harness-other@local.invalid"
FILLER_EMAIL = "boarded-rls-harness-filler@local.invalid"

OWNER_ROUTE_ID = "b5f0d878-5d47-4db8-90a5-3c5bc73f7c31"
OWNER_SESSION_ID = "a5f0d878-5d47-4db8-90a5-3c5bc73f7c31"
OTHER_SESSION_ID = "a6f0d878-5d47-4db8-90a5-3c5bc73f7c31"
OWNER_SENT_ATTEMPT_ID = "a7f0d878-5d47-4db8-90a5-3c5bc73f7c31"
OWNER_FELL_ATTEMPT_ID = "a8f0d878-5d47-4db8-90a5-3c5bc73f7c31"
OTHER_SENT_ATTEMPT_ID = "a9f0d878-5d47-4db8-90a5-3c5bc73f7c31"
UNPOSTED_ATTEMPT_ID = "aa0d8780-5d47-4db8-90a5-3c5bc73f7c31"
OWNER_POST_ID = "ab0d8780-5d47-4db8-90a5-3c5bc73f7c31"
OTHER_POST_ID = "ac0d8780-5d47-4db8-90a5-3c5bc73f7c31"
OWNER_MEETUP_ID = "ad0d8780-5d47-4db8-90a5-3c5bc73f7c31"
OTHER_MEETUP_ID = "ae0d8780-5d47-4db8-90a5-3c5bc73f7c31"
CANCELLED_MEETUP_ID = "af0d8780-5d47-4db8-90a5-3c5bc73f7c31"
FILLER_MEETUP_ID = "b00d8780-5d47-4db8-90a5-3c5bc73f7c31"
RACE_MEETUP_ID = "b10d8780-5d47-4db8-90a5-3c5bc73f7c31"
PAST_MEETUP_ID = "b20d8780-5d47-4db8-90a5-3c5bc73f7c31"


ROUTE_MARKER = "__boarded_rls_harness__"
SECRET_NOTES = "__boarded_private_attempt_notes__"


class HarnessError(RuntimeError):
    pass


@dataclass(frozen=True)
class User:
    id: str
    email: str


@dataclass
class ApiResult:
    status: int
    body: object


def fail(message: str) -> None:
    raise HarnessError(message)


def sql_quote(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def run_psql(sql: str) -> str:
    container = os.environ.get(DB_CONTAINER_ENV, DEFAULT_DB_CONTAINER)
    if not container.startswith("supabase_db_"):
        fail(f"refusing database container {container!r}; expected disposable supabase_db_*")
    try:
        completed = subprocess.run(
            [
                "docker", "exec", container, "psql", "-v", "ON_ERROR_STOP=1",
                "-U", "postgres", "-d", "postgres", "-Atqc", sql,
            ],
            check=False,
            capture_output=True,
            text=True,
            timeout=15,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        fail(f"local disposable database unavailable: {exc}")
    if completed.returncode != 0:
        fail(f"local disposable database unavailable or SQL failed: {(completed.stderr or completed.stdout).strip()}")
    return completed.stdout.strip()


def expect_api_result(result: ApiResult | object, description: str) -> ApiResult:
    if not isinstance(result, ApiResult):
        fail(f"{description}: expected HTTP result, got {result!r}")
    return result


def decode_response(response: HTTPResponse) -> ApiResult:
    raw = response.read().decode("utf-8", errors="replace")
    if not raw:
        return ApiResult(response.status, None)
    try:
        return ApiResult(response.status, json.loads(raw))
    except json.JSONDecodeError:
        return ApiResult(response.status, raw)


def request_json(
    method: str,
    url: str,
    token: str | None = None,
    payload: object | None = None,
) -> ApiResult | object:
    headers = {"Accept": "application/json"}
    if method in {"POST", "PATCH", "DELETE"}:
        headers["Prefer"] = "return=representation"
    data = None
    if payload is not None:
        headers["Content-Type"] = "application/json"
        data = json.dumps(payload).encode("utf-8")
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = Request(url, data=data, headers=headers, method=method)
    try:
        with urlopen(request, timeout=15) as response:
            return decode_response(response)
    except HTTPError as exc:
        raw = exc.read().decode("utf-8", errors="replace")
        try:
            body: object = json.loads(raw) if raw else None
        except json.JSONDecodeError:
            body = raw
        return ApiResult(exc.code, body)
    except (URLError, TimeoutError, OSError) as exc:
        fail(f"HTTP {method} {url} failed: {exc}")


def request_storage(
    method: str,
    base: str,
    key: str,
    token: str | None = None,
    payload: bytes | None = None,
) -> ApiResult | object:
    headers = {"Accept": "application/json"}
    if payload is not None:
        headers["Content-Type"] = "image/jpeg"
    if token:
        headers["Authorization"] = f"Bearer {token}"
    url = f"{base}/storage/v1/object/social-media/{quote(key, safe='/')}"
    request = Request(url, data=payload, headers=headers, method=method)
    try:
        with urlopen(request, timeout=15) as response:
            return decode_response(response)
    except HTTPError as exc:
        raw = exc.read().decode("utf-8", errors="replace")
        try:
            body: object = json.loads(raw) if raw else None
        except json.JSONDecodeError:
            body = raw
        return ApiResult(exc.code, body)
    except (URLError, TimeoutError, OSError) as exc:
        fail(f"Storage HTTP {method} failed: {exc}")


def ensure_backend(base: str) -> None:
    parsed = urlparse(base)
    if parsed.scheme != "http" or parsed.hostname not in {"127.0.0.1", "localhost", "::1"}:
        fail(f"refusing non-loopback Supabase URL {base!r}")
    health = expect_api_result(request_json("GET", f"{base}/auth/v1/health"), "local Auth health")
    if health.status != 200 or not isinstance(health.body, dict) or health.body.get("name") != "GoTrue":
        fail(f"unexpected local Auth health: HTTP {health.status} {health.body!r}")
    rest = expect_api_result(request_json("GET", f"{base}/rest/v1/routes?select=id&limit=1"), "local PostgREST health")
    if rest.status != 200:
        fail(f"unexpected local PostgREST health: HTTP {rest.status} {rest.body!r}")


def login(base: str, user: User) -> str:
    result = expect_api_result(
        request_json(
            "POST", f"{base}/auth/v1/token?grant_type=password",
            payload={"email": user.email, "password": PASSWORD},
        ),
        f"login for {user.email}",
    )
    if result.status != 200 or not isinstance(result.body, dict) or not result.body.get("access_token"):
        fail(f"login for {user.email} failed: HTTP {result.status} {result.body!r}")
    if result.body.get("user", {}).get("id") != user.id:
        fail(f"login returned wrong user ID: {result.body!r}")
    return str(result.body["access_token"])


def setup_fixtures() -> None:
    users = ((OWNER_ID, OWNER_EMAIL), (OTHER_ID, OTHER_EMAIL), (FILLER_ID, FILLER_EMAIL))
    user_ids = ", ".join(sql_quote(item[0]) for item in users)
    social_ids = ", ".join(
        sql_quote(item)
        for item in (
            OWNER_POST_ID, OTHER_POST_ID, OWNER_SENT_ATTEMPT_ID, OWNER_FELL_ATTEMPT_ID,
            OTHER_SENT_ATTEMPT_ID, UNPOSTED_ATTEMPT_ID, OWNER_SESSION_ID, OTHER_SESSION_ID,
        )
    )
    metadata = sql_quote(json.dumps({"provider": "email", "providers": ["email"]}, separators=(",", ":")))
    raw_metadata = {
        OWNER_ID: sql_quote(json.dumps({"sub": OWNER_ID, "email": OWNER_EMAIL, "email_verified": True}, separators=(",", ":"))),
        OTHER_ID: sql_quote(json.dumps({"sub": OTHER_ID, "email": OTHER_EMAIL, "email_verified": True}, separators=(",", ":"))),
        FILLER_ID: sql_quote(json.dumps({"sub": FILLER_ID, "email": FILLER_EMAIL, "email_verified": True}, separators=(",", ":"))),
    }
    emails = (OWNER_EMAIL, OTHER_EMAIL, FILLER_EMAIL)
    sql = f"""
BEGIN;
DELETE FROM public.send_post_comments WHERE post_id IN ({sql_quote(OWNER_POST_ID)}, {sql_quote(OTHER_POST_ID)});
DELETE FROM public.send_post_likes WHERE post_id IN ({sql_quote(OWNER_POST_ID)}, {sql_quote(OTHER_POST_ID)});
DELETE FROM public.send_posts WHERE id IN ({social_ids});
DELETE FROM public.meetup_comments WHERE meetup_id IN ({sql_quote(OWNER_MEETUP_ID)}, {sql_quote(OTHER_MEETUP_ID)}, {sql_quote(CANCELLED_MEETUP_ID)}, {sql_quote(FILLER_MEETUP_ID)}, {sql_quote(RACE_MEETUP_ID)}, {sql_quote(PAST_MEETUP_ID)});
DELETE FROM public.meetup_attendees WHERE meetup_id IN ({sql_quote(OWNER_MEETUP_ID)}, {sql_quote(OTHER_MEETUP_ID)}, {sql_quote(CANCELLED_MEETUP_ID)}, {sql_quote(FILLER_MEETUP_ID)}, {sql_quote(RACE_MEETUP_ID)}, {sql_quote(PAST_MEETUP_ID)});
DELETE FROM public.meetups WHERE id IN ({sql_quote(OWNER_MEETUP_ID)}, {sql_quote(OTHER_MEETUP_ID)}, {sql_quote(CANCELLED_MEETUP_ID)}, {sql_quote(FILLER_MEETUP_ID)}, {sql_quote(RACE_MEETUP_ID)}, {sql_quote(PAST_MEETUP_ID)});

DELETE FROM public.climb_attempts WHERE id IN ({sql_quote(OWNER_SENT_ATTEMPT_ID)}, {sql_quote(OWNER_FELL_ATTEMPT_ID)}, {sql_quote(OTHER_SENT_ATTEMPT_ID)}, {sql_quote(UNPOSTED_ATTEMPT_ID)});
DELETE FROM public.climbing_sessions WHERE id IN ({sql_quote(OWNER_SESSION_ID)}, {sql_quote(OTHER_SESSION_ID)});
DELETE FROM public.routes WHERE id = {sql_quote(OWNER_ROUTE_ID)};
DELETE FROM auth.users WHERE id IN ({user_ids});
INSERT INTO auth.users (instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,confirmation_token,recovery_token,email_change_token_new,email_change,email_change_token_current,phone_change,raw_app_meta_data,raw_user_meta_data,is_super_admin,created_at,updated_at,is_anonymous)
VALUES
 ({sql_quote(INSTANCE_ID)},{sql_quote(OWNER_ID)},'authenticated','authenticated',{sql_quote(OWNER_EMAIL)},crypt({sql_quote(PASSWORD)},gen_salt('bf')),now(),'','','','','','',{metadata}::jsonb,{raw_metadata[OWNER_ID]}::jsonb,false,now(),now(),false),
 ({sql_quote(INSTANCE_ID)},{sql_quote(OTHER_ID)},'authenticated','authenticated',{sql_quote(OTHER_EMAIL)},crypt({sql_quote(PASSWORD)},gen_salt('bf')),now(),'','','','','','',{metadata}::jsonb,{raw_metadata[OTHER_ID]}::jsonb,false,now(),now(),false),
 ({sql_quote(INSTANCE_ID)},{sql_quote(FILLER_ID)},'authenticated','authenticated',{sql_quote(FILLER_EMAIL)},crypt({sql_quote(PASSWORD)},gen_salt('bf')),now(),'','','','','','',{metadata}::jsonb,{raw_metadata[FILLER_ID]}::jsonb,false,now(),now(),false);
INSERT INTO auth.identities (provider_id,user_id,identity_data,provider,last_sign_in_at,created_at,updated_at)
VALUES
 ({sql_quote(OWNER_ID)},{sql_quote(OWNER_ID)},jsonb_build_object('sub',{sql_quote(OWNER_ID)},'email',{sql_quote(OWNER_EMAIL)}),'email',now(),now(),now()),
 ({sql_quote(OTHER_ID)},{sql_quote(OTHER_ID)},jsonb_build_object('sub',{sql_quote(OTHER_ID)},'email',{sql_quote(OTHER_EMAIL)}),'email',now(),now(),now()),
 ({sql_quote(FILLER_ID)},{sql_quote(FILLER_ID)},jsonb_build_object('sub',{sql_quote(FILLER_ID)},'email',{sql_quote(FILLER_EMAIL)}),'email',now(),now(),now());
INSERT INTO public.profiles (id,username,home_area) VALUES
 ({sql_quote(OWNER_ID)},'rls-harness-owner','Boulder'),
 ({sql_quote(OTHER_ID)},'rls-harness-other','Golden'),
 ({sql_quote(FILLER_ID)},'rls-harness-filler','Denver');
INSERT INTO public.routes (id,user_id,wall_id,name,grade_v,holds,is_public,created_at)
VALUES ({sql_quote(OWNER_ROUTE_ID)},{sql_quote(OWNER_ID)},'rls-harness-wall',{sql_quote(ROUTE_MARKER + 'route')},'V3','[]'::jsonb,true,now());
INSERT INTO public.climbing_sessions (id,user_id,venue_name,started_at,ended_at)
VALUES
 ({sql_quote(OWNER_SESSION_ID)},{sql_quote(OWNER_ID)},'Owner Gym',now()-interval '1 hour',now()),
 ({sql_quote(OTHER_SESSION_ID)},{sql_quote(OTHER_ID)},'Other Gym',now()-interval '1 hour',now());
INSERT INTO public.climb_attempts (id,session_id,user_id,board_route_id,route_name,discipline,grade_system,grade_label,outcome,attempt_number,notes,occurred_at)
VALUES
 ({sql_quote(OWNER_SENT_ATTEMPT_ID)},{sql_quote(OWNER_SESSION_ID)},{sql_quote(OWNER_ID)},{sql_quote(OWNER_ROUTE_ID)},'Harness Send','board','v_scale','V3','sent',1,'owner public-safe note',now()),
 ({sql_quote(OWNER_FELL_ATTEMPT_ID)},{sql_quote(OWNER_SESSION_ID)},{sql_quote(OWNER_ID)},NULL,'Harness Fell','boulder','v_scale','V4','fell',1,{sql_quote(SECRET_NOTES)},now()),
 ({sql_quote(OTHER_SENT_ATTEMPT_ID)},{sql_quote(OTHER_SESSION_ID)},{sql_quote(OTHER_ID)},NULL,'Other Send','sport','yds','5.10a','sent',1,'other private note',now()),
 ({sql_quote(UNPOSTED_ATTEMPT_ID)},{sql_quote(OWNER_SESSION_ID)},{sql_quote(OWNER_ID)},NULL,'Unposted Secret','board','v_scale','V5','sent',2,{sql_quote(SECRET_NOTES)},now());
INSERT INTO public.send_posts (id,user_id,attempt_id,caption,image_alt)
VALUES
 ({sql_quote(OWNER_POST_ID)},{sql_quote(OWNER_ID)},{sql_quote(OWNER_SENT_ATTEMPT_ID)},'Owner send','Owner send image alt'),
 ({sql_quote(OTHER_POST_ID)},{sql_quote(OTHER_ID)},{sql_quote(OTHER_SENT_ATTEMPT_ID)},'Other send','Other send image alt');
INSERT INTO public.meetups (id,organizer_id,title,description,venue_name,area,starts_at,ends_at,capacity,status)
VALUES
 ({sql_quote(OWNER_MEETUP_ID)},{sql_quote(OWNER_ID)},'Owner meetup','A public owner meetup','Owner Gym','Boulder',now()+interval '2 days',now()+interval '2 days 2 hours',2,'scheduled'),
 ({sql_quote(OTHER_MEETUP_ID)},{sql_quote(OTHER_ID)},'Other meetup','A public other meetup','Other Gym','Golden',now()+interval '3 days',now()+interval '3 days 2 hours',2,'scheduled'),
 ({sql_quote(CANCELLED_MEETUP_ID)},{sql_quote(OWNER_ID)},'Cancelled meetup','A public cancelled meetup','Owner Gym','Boulder',now()+interval '4 days',now()+interval '4 days 2 hours',2,'cancelled'),
 ({sql_quote(FILLER_MEETUP_ID)},{sql_quote(FILLER_ID)},'Filler meetup','A public capacity fixture','Filler Gym','Denver',now()+interval '5 days',now()+interval '5 days 2 hours',2,'scheduled'),
 ({sql_quote(RACE_MEETUP_ID)},{sql_quote(FILLER_ID)},'Race meetup','A concurrent capacity fixture','Filler Gym','Denver',now()+interval '6 days',now()+interval '6 days 2 hours',2,'scheduled'),
 ({sql_quote(PAST_MEETUP_ID)},{sql_quote(FILLER_ID)},'Past meetup','A past capacity fixture','Filler Gym','Denver',now()-interval '2 days',now()-interval '1 day',2,'scheduled');
COMMIT;
"""
    run_psql(sql)


def cleanup_fixtures() -> None:
    user_ids = ", ".join(sql_quote(item) for item in (OWNER_ID, OTHER_ID, FILLER_ID))
    run_psql(
        f"DELETE FROM storage.objects WHERE bucket_id = 'social-media' AND name LIKE {sql_quote(OWNER_ID + '/rls-harness-%')};"
        f" DELETE FROM storage.objects WHERE bucket_id = 'social-media' AND name LIKE {sql_quote(OTHER_ID + '/rls-harness-%')};"
        f" DELETE FROM public.routes WHERE id = {sql_quote(OWNER_ROUTE_ID)};"
        f" DELETE FROM auth.users WHERE id IN ({user_ids});"
    )
    remaining = run_psql(f"SELECT count(*) FROM auth.users WHERE id IN ({user_ids});")
    if remaining != "0":
        fail(f"fixture cleanup incomplete; remaining users: {remaining!r}")


def rows(result: ApiResult, description: str) -> list[dict]:
    if result.status != 200 or not isinstance(result.body, list):
        fail(f"{description} failed: HTTP {result.status} {result.body!r}")
    return [item for item in result.body if isinstance(item, dict)]


def assert_rejected(result: ApiResult, description: str) -> None:
    if 200 <= result.status < 300:
        fail(f"{description} unexpectedly succeeded: HTTP {result.status} {result.body!r}")

def assert_no_rows(result: ApiResult, description: str) -> None:
    if result.status != 200 or result.body != []:
        fail(f"{description} changed a row or returned an error: HTTP {result.status} {result.body!r}")



def assert_route_ownership(base: str, owner_token: str, other_token: str) -> None:
    owner_patch = expect_api_result(
        request_json("PATCH", f"{base}/rest/v1/routes?id=eq.{OWNER_ROUTE_ID}", owner_token, {"name": ROUTE_MARKER + "route-updated"}),
        "route owner update",
    )
    if owner_patch.status != 200:
        fail(f"route owner update failed: HTTP {owner_patch.status} {owner_patch.body!r}")
    other_patch = expect_api_result(
        request_json("PATCH", f"{base}/rest/v1/routes?id=eq.{OWNER_ROUTE_ID}", other_token, {"name": ROUTE_MARKER + "cross-update"}),
        "route cross-user update",
    )
    if other_patch.status != 200 or other_patch.body:
        fail(f"route cross-user update changed a row: HTTP {other_patch.status} {other_patch.body!r}")
    public_read = expect_api_result(
        request_json("GET", f"{base}/rest/v1/routes?id=eq.{OWNER_ROUTE_ID}&select=id,name"),
        "anonymous route read",
    )
    if not rows(public_read, "anonymous route read"):
        fail("anonymous route read did not return the public route")
    print("PASS: existing Boarded route owner and cross-user RLS remained intact")
def assert_public_profiles_and_feed(base: str) -> None:
    profile = expect_api_result(
        request_json("GET", f"{base}/rest/v1/profiles?id=eq.{OWNER_ID}&select=id,username,home_area"),
        "anonymous public profile read",
    )
    profile_rows = rows(profile, "anonymous public profile read")
    if len(profile_rows) != 1 or profile_rows[0].get("home_area") != "Boulder":
        fail(f"public profile/home_area read was wrong: {profile_rows!r}")
    feed = rows(rpc(base, "get_send_feed", payload={"page_size": 50}), "anonymous send feed")
    post_ids = [item.get("id") for item in feed]
    if OWNER_POST_ID not in post_ids or OTHER_POST_ID not in post_ids:
        fail(f"anonymous feed missed public posts: {post_ids!r}")
    serialized = json.dumps(feed, sort_keys=True)
    if UNPOSTED_ATTEMPT_ID in serialized or SECRET_NOTES in serialized:
        fail(f"feed leaked unposted/private attempt data: {serialized}")
    for item in feed:
        if "notes" in item or "session_id" in item or "venue_name" in item:
            fail(f"feed exposed owner-only field: {item!r}")
        attempt = item.get("attempt")
        if not isinstance(item.get("author"), dict) or not isinstance(attempt, dict):
            fail(f"feed omitted nested author/attempt: {item!r}")
        if any(key in attempt for key in ("notes", "session_id", "venue_name")):
            fail(f"feed exposed private nested attempt field: {item!r}")
        if "like_count" not in item or "comment_count" not in item or "is_liked" not in item:
            fail(f"feed omitted engagement fields: {item!r}")
    owner_feed = rows(rpc(base, "get_send_feed", payload={"author_filter": OWNER_ID, "page_size": 1}), "filtered send feed")
    if len(owner_feed) != 1 or owner_feed[0].get("user_id") != OWNER_ID:
        fail(f"author-filtered feed was wrong: {owner_feed!r}")
    print("PASS: anonymous public profile/feed, nested author/attempt, pagination fields, and non-leakage verified")


def assert_private_sessions_and_attempts(base: str, owner_token: str, other_token: str) -> None:
    owner_sessions = rows(
        expect_api_result(request_json("GET", f"{base}/rest/v1/climbing_sessions?id=eq.{OWNER_SESSION_ID}&select=*", owner_token), "owner session read"),
        "owner session read",
    )
    if len(owner_sessions) != 1:
        fail(f"owner could not read own session: {owner_sessions!r}")
    other_session = rows(
        expect_api_result(request_json("GET", f"{base}/rest/v1/climbing_sessions?id=eq.{OWNER_SESSION_ID}&select=*", other_token), "other session read"),
        "other session read",
    )
    if other_session:
        fail(f"other user read owner session: {other_session!r}")
    anon = expect_api_result(request_json("GET", f"{base}/rest/v1/climbing_sessions?id=eq.{OWNER_SESSION_ID}&select=*"), "anonymous session read")
    if anon.status not in {200, 401, 403} or (anon.status == 200 and anon.body):
        fail(f"anonymous session read leaked private data: HTTP {anon.status} {anon.body!r}")
    owner_attempts = rows(
        expect_api_result(request_json("GET", f"{base}/rest/v1/climb_attempts?session_id=eq.{OWNER_SESSION_ID}&select=*", owner_token), "owner attempt read"),
        "owner attempt read",
    )
    if not any(item.get("id") == OWNER_FELL_ATTEMPT_ID and item.get("notes") == SECRET_NOTES for item in owner_attempts):
        fail(f"owner could not read private attempt notes: {owner_attempts!r}")
    other_attempts = rows(
        expect_api_result(request_json("GET", f"{base}/rest/v1/climb_attempts?session_id=eq.{OWNER_SESSION_ID}&select=*", other_token), "other attempt read"),
        "other attempt read",
    )
    if other_attempts:
        fail(f"other user read owner attempts: {other_attempts!r}")
    print("PASS: sessions and attempts are owner-only while public send projection stays safe")


def assert_social_mutations(base: str, owner_token: str, other_token: str) -> None:
    def post(table: str, token: str | None, body: object, description: str) -> ApiResult:
        return expect_api_result(request_json("POST", f"{base}/rest/v1/{table}", token, body), description)

    def patch(table: str, query: str, token: str, body: object, description: str) -> ApiResult:
        return expect_api_result(request_json("PATCH", f"{base}/rest/v1/{table}?{query}", token, body), description)

    assert_rejected(post("climbing_sessions", other_token, {"user_id": OWNER_ID, "venue_name": "cross", "started_at": "2030-01-01T00:00:00Z"}, "cross-user session insert"), "cross-user session insert")
    assert_no_rows(patch("climbing_sessions", f"id=eq.{OWNER_SESSION_ID}", other_token, {"venue_name": "cross"}, "cross-user session update"), "cross-user session update")
    assert_rejected(patch("climbing_sessions", f"id=eq.{OWNER_SESSION_ID}", owner_token, {"user_id": OTHER_ID}, "owner session user mutation"), "owner session user mutation")
    assert_rejected(post("climb_attempts", owner_token, {"session_id": OTHER_SESSION_ID, "user_id": OWNER_ID, "route_name": "cross", "discipline": "board", "grade_system": "v_scale", "grade_label": "V1", "outcome": "fell", "attempt_number": 1, "occurred_at": "2030-01-01T00:00:00Z"}, "attempt in another session"), "attempt in another session")
    assert_rejected(patch("climb_attempts", f"id=eq.{OWNER_SENT_ATTEMPT_ID}", owner_token, {"user_id": OTHER_ID}, "owner attempt user mutation"), "owner attempt user mutation")
    assert_rejected(patch("climb_attempts", f"id=eq.{OWNER_SENT_ATTEMPT_ID}", owner_token, {"session_id": OTHER_SESSION_ID}, "owner attempt session mutation"), "owner attempt session mutation")
    assert_rejected(patch("climb_attempts", f"id=eq.{OWNER_SENT_ATTEMPT_ID}", owner_token, {"board_route_id": None}, "owner attempt board route mutation"), "owner attempt board route mutation")
    assert_no_rows(patch("climb_attempts", f"id=eq.{OWNER_SENT_ATTEMPT_ID}", other_token, {"notes": "cross"}, "cross-user attempt update"), "cross-user attempt update")
    assert_rejected(post("send_posts", owner_token, {"user_id": OWNER_ID, "attempt_id": OWNER_FELL_ATTEMPT_ID, "caption": "fell post", "image_alt": "alt"}, "unsent post trigger"), "unsent post trigger")
    assert_rejected(patch("climb_attempts", f"id=eq.{OWNER_SENT_ATTEMPT_ID}", owner_token, {"outcome": "fell"}, "published attempt outcome downgrade"), "published attempt outcome downgrade")
    assert_rejected(patch("send_posts", f"id=eq.{OWNER_POST_ID}", owner_token, {"user_id": OTHER_ID}, "owner post user mutation"), "owner post user mutation")
    assert_rejected(patch("send_posts", f"id=eq.{OWNER_POST_ID}", owner_token, {"attempt_id": OTHER_SENT_ATTEMPT_ID}, "owner post attempt mutation"), "owner post attempt mutation")
    assert_no_rows(patch("send_posts", f"id=eq.{OWNER_POST_ID}", other_token, {"caption": "cross"}, "cross-user post update"), "cross-user post update")
    assert_no_rows(expect_api_result(request_json("DELETE", f"{base}/rest/v1/send_posts?id=eq.{OWNER_POST_ID}", other_token), "cross-user post delete"), "cross-user post delete")

    canonical_path = f"{OWNER_ID}/{OWNER_POST_ID}.jpg"
    canonical_update = patch("send_posts", f"id=eq.{OWNER_POST_ID}", owner_token, {"image_path": canonical_path}, "canonical image path")
    if canonical_update.status != 200:
        fail(f"canonical image path was rejected: HTTP {canonical_update.status} {canonical_update.body!r}")
    for foreign_path, description in (
        (f"{OTHER_ID}/{OWNER_POST_ID}.jpg", "foreign image owner prefix"),
        (f"{OWNER_ID}/{OTHER_POST_ID}.jpg", "foreign image post reference"),
    ):
        assert_rejected(
            patch("send_posts", f"id=eq.{OWNER_POST_ID}", owner_token, {"image_path": foreign_path}, description),
            description,
        )

    assert_rejected(post("send_post_likes", other_token, {"post_id": OWNER_POST_ID, "user_id": OWNER_ID}, "cross-user like insert"), "cross-user like insert")
    owner_like = post("send_post_likes", owner_token, {"post_id": OWNER_POST_ID, "user_id": OWNER_ID}, "owner like insert")
    if owner_like.status not in {200, 201}:
        fail(f"owner like insert failed: HTTP {owner_like.status} {owner_like.body!r}")
    other_like = post("send_post_likes", other_token, {"post_id": OWNER_POST_ID, "user_id": OTHER_ID}, "other-user like insert")
    if other_like.status not in {200, 201}:
        fail(f"other-user like insert failed: HTTP {other_like.status} {other_like.body!r}")
    liked_feed = rows(rpc(base, "get_send_feed", owner_token, {"author_filter": OWNER_ID, "page_size": 1}), "authenticated liked feed")
    if len(liked_feed) != 1 or liked_feed[0].get("id") != OWNER_POST_ID or liked_feed[0].get("is_liked") is not True:
        fail(f"authenticated viewer did not see is_liked=true: {liked_feed!r}")
    assert_rejected(patch("send_post_likes", f"post_id=eq.{OWNER_POST_ID}&user_id=eq.{OWNER_ID}", owner_token, {"post_id": OTHER_POST_ID}, "owner like parent mutation"), "owner like parent mutation")
    assert_rejected(patch("send_post_likes", f"post_id=eq.{OWNER_POST_ID}&user_id=eq.{OWNER_ID}", owner_token, {"user_id": OTHER_ID}, "owner like user mutation"), "owner like user mutation")
    assert_no_rows(expect_api_result(request_json("DELETE", f"{base}/rest/v1/send_post_likes?post_id=eq.{OWNER_POST_ID}&user_id=eq.{OWNER_ID}", other_token), "cross-user like delete"), "cross-user like delete")

    post_comment = post("send_post_comments", owner_token, {"post_id": OWNER_POST_ID, "user_id": OWNER_ID, "content": "owner comment"}, "owner post comment")
    comment_rows = rows(post_comment, "owner post comment")
    if len(comment_rows) != 1:
        fail(f"owner post comment did not return one row: {comment_rows!r}")
    comment_id = comment_rows[0]["id"]
    other_comment = post("send_post_comments", other_token, {"post_id": OWNER_POST_ID, "user_id": OTHER_ID, "content": "other comment"}, "other-user post comment")
    if other_comment.status not in {200, 201}:
        fail(f"other-user post comment failed: HTTP {other_comment.status} {other_comment.body!r}")
    assert_rejected(patch("send_post_comments", f"id=eq.{comment_id}", owner_token, {"post_id": OTHER_POST_ID}, "owner comment parent mutation"), "owner comment parent mutation")
    assert_rejected(patch("send_post_comments", f"id=eq.{comment_id}", owner_token, {"user_id": OTHER_ID}, "owner comment user mutation"), "owner comment user mutation")
    assert_rejected(post("send_post_comments", other_token, {"post_id": OWNER_POST_ID, "user_id": OWNER_ID, "content": "cross comment"}, "cross-user post comment"), "cross-user post comment")
    assert_no_rows(patch("send_post_comments", f"id=eq.{comment_id}", other_token, {"content": "cross"}, "cross-user comment update"), "cross-user comment update")
    assert_no_rows(expect_api_result(request_json("DELETE", f"{base}/rest/v1/send_post_comments?id=eq.{comment_id}", other_token), "cross-user comment delete"), "cross-user comment delete")

    assert_rejected(post("meetups", other_token, {"organizer_id": OWNER_ID, "title": "cross", "description": "cross", "venue_name": "venue", "area": "area", "starts_at": "2030-01-01T00:00:00Z"}, "cross-user meetup insert"), "cross-user meetup insert")
    assert_no_rows(patch("meetups", f"id=eq.{OWNER_MEETUP_ID}", other_token, {"title": "cross"}, "cross-user meetup update"), "cross-user meetup update")
    assert_no_rows(expect_api_result(request_json("DELETE", f"{base}/rest/v1/meetups?id=eq.{OWNER_MEETUP_ID}", other_token), "cross-user meetup delete"), "cross-user meetup delete")
    assert_rejected(patch("meetups", f"id=eq.{OWNER_MEETUP_ID}", owner_token, {"organizer_id": OTHER_ID}, "owner meetup organizer mutation"), "owner meetup organizer mutation")
    assert_rejected(post("meetup_attendees", other_token, {"meetup_id": OWNER_MEETUP_ID, "user_id": OTHER_ID}, "direct attendee insert"), "direct attendee insert")
    meetup_comment = post("meetup_comments", owner_token, {"meetup_id": OWNER_MEETUP_ID, "user_id": OWNER_ID, "content": "owner meetup comment"}, "owner meetup comment")
    meetup_comment_rows = rows(meetup_comment, "owner meetup comment")
    comment_id = meetup_comment_rows[0]["id"]
    assert_rejected(patch("meetup_comments", f"id=eq.{comment_id}", owner_token, {"meetup_id": OTHER_MEETUP_ID}, "owner meetup comment parent mutation"), "owner meetup comment parent mutation")
    assert_rejected(patch("meetup_comments", f"id=eq.{comment_id}", owner_token, {"user_id": OTHER_ID}, "owner meetup comment user mutation"), "owner meetup comment user mutation")
    assert_rejected(post("meetup_comments", other_token, {"meetup_id": OWNER_MEETUP_ID, "user_id": OWNER_ID, "content": "cross meetup comment"}, "cross-user meetup comment"), "cross-user meetup comment")
    assert_no_rows(patch("meetup_comments", f"id=eq.{comment_id}", other_token, {"content": "cross"}, "cross-user meetup comment update"), "cross-user meetup comment update")
    assert_no_rows(expect_api_result(request_json("DELETE", f"{base}/rest/v1/meetup_comments?id=eq.{comment_id}", other_token), "cross-user meetup comment delete"), "cross-user meetup comment delete")
    print("PASS: owner matching, canonical images, immutable parents, engagement, and cross-user social mutations verified")


def rpc(base: str, function: str, token: str | None = None, payload: object | None = None) -> ApiResult:
    return expect_api_result(
        request_json("POST", f"{base}/rest/v1/rpc/{function}", token, payload if payload is not None else {}),
        f"rpc {function}",
    )


def assert_public_meetups_and_joins(base: str, owner_token: str, other_token: str) -> None:
    public = rows(
        expect_api_result(request_json("GET", f"{base}/rest/v1/meetups?id=in.({OWNER_MEETUP_ID},{CANCELLED_MEETUP_ID})&select=id,status"), "anonymous meetup read"),
        "anonymous meetup read",
    )
    if {item.get("id") for item in public} != {OWNER_MEETUP_ID, CANCELLED_MEETUP_ID}:
        fail(f"public meetup read omitted status variants: {public!r}")
    assert_rejected(rpc(base, "join_meetup", owner_token, {"meetup_id": OWNER_MEETUP_ID}), "organizer join")
    first = rpc(base, "join_meetup", other_token, {"meetup_id": OWNER_MEETUP_ID})
    if first.status != 200:
        fail(f"first meetup join failed: HTTP {first.status} {first.body!r}")
    second = rpc(base, "join_meetup", other_token, {"meetup_id": OWNER_MEETUP_ID})
    if second.status != 200 or second.body != first.body:
        fail(f"meetup join was not idempotent: first={first.body!r} second={second.body!r}")
    assert_rejected(rpc(base, "join_meetup", payload={"meetup_id": OWNER_MEETUP_ID}), "anonymous meetup join")
    owner_other = rpc(base, "join_meetup", owner_token, {"meetup_id": OTHER_MEETUP_ID})
    if owner_other.status != 200:
        fail(f"owner join of other meetup failed: HTTP {owner_other.status} {owner_other.body!r}")
    assert_rejected(
        expect_api_result(
            request_json(
                "PATCH",
                f"{base}/rest/v1/meetup_attendees?meetup_id=eq.{OTHER_MEETUP_ID}&user_id=eq.{OWNER_ID}",
                owner_token,
                {"meetup_id": OWNER_MEETUP_ID},
            ),
            "owner attendee parent mutation",
        ),
        "owner attendee parent mutation",
    )
    assert_rejected(
        expect_api_result(
            request_json(
                "PATCH",
                f"{base}/rest/v1/meetup_attendees?meetup_id=eq.{OTHER_MEETUP_ID}&user_id=eq.{OWNER_ID}",
                owner_token,
                {"user_id": OTHER_ID},
            ),
            "owner attendee user mutation",
        ),
        "owner attendee user mutation",
    )
    leave = expect_api_result(
        request_json(
            "DELETE",
            f"{base}/rest/v1/meetup_attendees?meetup_id=eq.{OTHER_MEETUP_ID}&user_id=eq.{OWNER_ID}",
            owner_token,
        ),
        "attendee leave",
    )
    if leave.status != 200:
        fail(f"attendee leave failed: HTTP {leave.status} {leave.body!r}")
    if rows(
        expect_api_result(
            request_json(
                "GET",
                f"{base}/rest/v1/meetup_attendees?meetup_id=eq.{OTHER_MEETUP_ID}&user_id=eq.{OWNER_ID}&select=user_id",
            ),
            "attendee leave verification",
        ),
        "attendee leave verification",
    ):
        fail("attendee leave left an attendance row")
    if rpc(base, "join_meetup", owner_token, {"meetup_id": OTHER_MEETUP_ID}).status != 200:
        fail("attendee could not rejoin after leaving")
    owner_filler = rpc(base, "join_meetup", owner_token, {"meetup_id": FILLER_MEETUP_ID})
    if owner_filler.status != 200:
        fail(f"owner join of filler meetup failed: HTTP {owner_filler.status} {owner_filler.body!r}")
    assert_rejected(rpc(base, "join_meetup", other_token, {"meetup_id": FILLER_MEETUP_ID}), "full meetup join")
    assert_rejected(rpc(base, "join_meetup", other_token, {"meetup_id": CANCELLED_MEETUP_ID}), "cancelled meetup join")
    assert_rejected(rpc(base, "join_meetup", other_token, {"meetup_id": PAST_MEETUP_ID}), "past meetup join")

    barrier = threading.Barrier(2)

    def synchronized_join(token: str) -> ApiResult:
        barrier.wait(timeout=15)
        return rpc(base, "join_meetup", token, {"meetup_id": RACE_MEETUP_ID})

    with ThreadPoolExecutor(max_workers=2) as executor:
        futures = [executor.submit(synchronized_join, token) for token in (owner_token, other_token)]
        race_results = [future.result() for future in futures]
    successes = [result for result in race_results if 200 <= result.status < 300]
    full_results = [result for result in race_results if not 200 <= result.status < 300]
    if len(successes) != 1 or len(full_results) != 1:
        fail(f"concurrent final-slot contention was not one success/full result: {race_results!r}")
    assert_rejected(full_results[0], "concurrent full meetup join")
    race_attendees = rows(
        expect_api_result(
            request_json(
                "GET",
                f"{base}/rest/v1/meetup_attendees?meetup_id=eq.{RACE_MEETUP_ID}&select=user_id",
            ),
            "concurrent attendee count",
        ),
        "concurrent attendee count",
    )
    if len(race_attendees) != 1 or race_attendees[0].get("user_id") not in {OWNER_ID, OTHER_ID}:
        fail(f"concurrent capacity admitted the wrong attendee count: {race_attendees!r}")

    cancelled_update = expect_api_result(request_json("PATCH", f"{base}/rest/v1/meetups?id=eq.{OWNER_MEETUP_ID}", owner_token, {"status": "cancelled"}), "organizer cancellation")
    if cancelled_update.status != 200:
        fail(f"organizer cancellation failed: HTTP {cancelled_update.status} {cancelled_update.body!r}")
    # Existing attendance remains idempotent after cancellation.
    if rpc(base, "join_meetup", other_token, {"meetup_id": OWNER_MEETUP_ID}).status != 200:
        fail("existing attendee lost idempotence after cancellation")
    print("PASS: public reads, organizer authority, attendee leave, past rejection, idempotence, and synchronized locked capacity verified")


def assert_storage_ownership(base: str, owner_token: str, other_token: str) -> None:
    marker = f"rls-harness-{uuid.uuid4().hex}"
    owner_key = f"{OWNER_ID}/{marker}/owner.jpg"
    cross_key = f"{OWNER_ID}/{marker}/cross.jpg"
    legacy_key = f"{marker}/legacy.jpg"
    upload = b"boarded-social-storage-harness"
    owner_upload = expect_api_result(request_storage("POST", base, owner_key, owner_token, upload), "owner social-media upload")
    if owner_upload.status not in {200, 201}:
        fail(f"owner social-media upload failed: HTTP {owner_upload.status} {owner_upload.body!r}")
    try:
        public_read = expect_api_result(request_storage("GET", base, owner_key), "public social-media read")
        if public_read.status != 200:
            fail(f"public social-media read failed: HTTP {public_read.status} {public_read.body!r}")
        assert_rejected(expect_api_result(request_storage("POST", base, cross_key, other_token, upload), "cross-prefix upload"), "cross-prefix upload")
        assert_rejected(expect_api_result(request_storage("POST", base, legacy_key, owner_token, upload), "legacy-prefix upload"), "legacy-prefix upload")
        assert_rejected(expect_api_result(request_storage("POST", base, cross_key, payload=upload), "anonymous upload"), "anonymous upload")
    finally:
        deleted = expect_api_result(request_storage("DELETE", base, owner_key, owner_token), "owner social-media cleanup")
        if deleted.status not in {200, 204}:
            fail(f"owner social-media cleanup failed: HTTP {deleted.status} {deleted.body!r}")
    print("PASS: social-media public read and first-path authenticated ownership verified")


def run() -> None:
    base = os.environ.get(LOCAL_URL_ENV, DEFAULT_LOCAL_URL).rstrip("/")
    ensure_backend(base)
    run_psql("SELECT 1;")
    try:
        setup_fixtures()
        owner_token = login(base, User(OWNER_ID, OWNER_EMAIL))
        other_token = login(base, User(OTHER_ID, OTHER_EMAIL))
        assert_route_ownership(base, owner_token, other_token)
        assert_public_profiles_and_feed(base)
        assert_private_sessions_and_attempts(base, owner_token, other_token)
        assert_social_mutations(base, owner_token, other_token)
        assert_public_meetups_and_joins(base, owner_token, other_token)
        assert_storage_ownership(base, owner_token, other_token)
    finally:
        cleanup_fixtures()
        print("PASS: fixed UUID auth and social fixtures cleaned up")


def main() -> int:
    try:
        run()
    except HarnessError as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1
    except Exception as exc:
        print(f"FAIL: unexpected harness error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
