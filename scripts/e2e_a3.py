#!/usr/bin/env python3
"""A3 API-level E2E against a running core-backend (+ ai-service for draft/escalate).

Covers mobile/README.md checklist at the HTTP layer.
Android emulator/device UI taps are out of scope in this cloud VM (no Android SDK).
"""
from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request

BASE = os.environ.get("CORE_API_BASE", "http://127.0.0.1:8080")
ADMIN = os.environ.get("ADMIN_API_TOKEN", "dev-admin-token")

passed = 0
failed = 0


def ok(msg: str) -> None:
    global passed
    passed += 1
    print(f"  OK: {msg}")


def fail(msg: str) -> None:
    global failed
    failed += 1
    print(f"  FAIL: {msg}")


def step(msg: str) -> None:
    print(f"\n==> {msg}")


def req(method: str, path: str, body=None, token: str | None = None, admin: bool = False):
    data = None if body is None else json.dumps(body).encode()
    headers = {"Content-Type": "application/json"}
    if admin:
        headers["Authorization"] = f"Bearer {ADMIN}"
    elif token:
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(BASE + path, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request) as resp:
            raw = resp.read().decode()
            return resp.status, json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try:
            payload = json.loads(raw) if raw else {}
        except json.JSONDecodeError:
            payload = {"raw": raw}
        return e.code, payload


def main() -> int:
    step("health")
    code, body = req("GET", "/health")
    ok("core health") if code == 200 else fail(f"health {code} {body}")

    step("1) invite + signup (two users)")
    _, ia = req("POST", "/invites", {}, admin=True)
    _, ib = req("POST", "/invites", {}, admin=True)
    code_a, sa = req("POST", "/auth/signup", {"invite_code": ia["code"], "display_name": "E2E Alice"})
    code_b, sb = req("POST", "/auth/signup", {"invite_code": ib["code"], "display_name": "E2E Bob"})
    if code_a == 200 and code_b == 200 and sa.get("token") and sb.get("token"):
        ok(f"signup tokens for #{sa['id']} and #{sb['id']}")
    else:
        fail(f"signup a={code_a} b={code_b}")
        return 1
    token_a, token_b = sa["token"], sb["token"]
    id_a, id_b = sa["id"], sb["id"]

    step("2) contact + conversation create")
    _, contact = req(
        "POST",
        f"/users/{id_a}/contacts",
        {"display_name": "Bob", "contact_user_id": id_b, "relationship_note": "e2e"},
        token=token_a,
    )
    contact_id = contact["id"]
    _, conv = req(
        "POST",
        "/conversations",
        {"user_ids": [id_a, id_b], "contact_id": contact_id},
        token=token_a,
    )
    conv_id = conv["id"]
    ok(f"conversation #{conv_id} via contact #{contact_id}")
    _, clist = req("GET", "/conversations", token=token_a)
    ids = [c["id"] for c in clist.get("conversations", [])]
    ok("conversation list includes room") if conv_id in ids else fail(f"list missing room: {ids}")

    step("3) human message + history")
    _, msg = req(
        "POST",
        f"/conversations/{conv_id}/messages",
        {"sender_id": id_a, "text": "안녕 Bob", "sender_mode": "human"},
        token=token_a,
    )
    msg_id = msg["id"]
    _, hist = req("GET", f"/conversations/{conv_id}/messages", token=token_a)
    hist_ids = [m["id"] for m in hist.get("messages", [])]
    ok(f"history retains message #{msg_id}") if msg_id in hist_ids else fail("history")

    step("4) draft + L1 approved twin send")
    dcode, draft = req(
        "POST",
        f"/conversations/{conv_id}/draft",
        {"context_lines": ["상대: 오늘 뭐해?"], "style_examples": ["ㅇㅇ 알겠음", "ㅋㅋ 그래"]},
        token=token_a,
    )
    if dcode == 200 and draft.get("status") in {"ok", "no_key", "escalate"}:
        ok(f"draft status={draft.get('status')}")
    else:
        fail(f"draft {dcode} {draft}")
    req("PATCH", f"/users/{id_a}/twin-settings", {"autonomy_level": "L1"}, token=token_a)
    twin_text = "ㅇㅇ 알겠음 나중에"
    if draft.get("status") == "ok" and draft.get("text"):
        twin_text = draft["text"]
    tcode, twin = req(
        "POST",
        f"/conversations/{conv_id}/messages",
        {"sender_id": id_a, "text": twin_text, "sender_mode": "twin", "approved": True},
        token=token_a,
    )
    twin_id = twin.get("id")
    if tcode == 200 and twin_id:
        ok(f"L1 approved twin message #{twin_id}")
    else:
        fail(f"twin send {tcode} {twin}")
        return 1

    step("5) escalation path + inbox logs")
    ecode, _ = req(
        "POST",
        f"/conversations/{conv_id}/messages",
        {
            "sender_id": id_a,
            "text": "계좌로 돈 보내줄게 계좌번호 알려줘",
            "sender_mode": "twin",
            "approved": True,
        },
        token=token_a,
    )
    if ecode != 200:
        ok(f"escalating twin blocked (HTTP {ecode})")
    else:
        fail("escalating twin unexpectedly accepted")
    _, logs = req("GET", f"/users/{id_a}/escalation-logs", token=token_a)
    if "escalation_logs" in logs:
        ok(f"escalation-logs count={len(logs['escalation_logs'])}")
    else:
        fail("escalation-logs shape")

    step("6) retract twin + veto")
    rcode, _ = req("POST", f"/messages/{twin_id}/retract", token=token_a)
    ok(f"retract HTTP {rcode}") if rcode == 200 else fail(f"retract {rcode}")
    vcode, _ = req("POST", f"/conversations/{conv_id}/veto", token=token_b)
    ok(f"peer veto HTTP {vcode}") if vcode == 200 else fail(f"veto {vcode}")
    bcode, _ = req(
        "POST",
        f"/conversations/{conv_id}/messages",
        {"sender_id": id_a, "text": "veto 이후", "sender_mode": "twin", "approved": True},
        token=token_a,
    )
    ok(f"twin blocked after veto (HTTP {bcode})") if bcode != 200 else fail("twin allowed after veto")

    step("7) whitelist CRUD + autonomy")
    _, wl = req(
        "POST",
        f"/users/{id_a}/whitelist-rules",
        {"topic_keyword": "날씨"},
        token=token_a,
    )
    _, wlist = req("GET", f"/users/{id_a}/whitelist-rules", token=token_a)
    rules = wlist.get("whitelist_rules", [])
    ok("whitelist add/list") if any(r.get("topic_keyword") == "날씨" for r in rules) else fail("whitelist")
    dcode, _ = req("DELETE", f"/users/{id_a}/whitelist-rules/{wl['id']}", token=token_a)
    ok("whitelist delete") if dcode == 200 else fail(f"whitelist delete {dcode}")
    acode, _ = req("PATCH", f"/users/{id_a}/twin-settings", {"autonomy_level": "L0"}, token=token_a)
    ok("autonomy L0 reset") if acode == 200 else fail(f"autonomy {acode}")

    step("8) contacts list")
    _, contacts = req("GET", f"/users/{id_a}/contacts", token=token_a)
    cids = [c["id"] for c in contacts.get("contacts", [])]
    ok("contacts list") if contact_id in cids else fail("contacts list")

    print(f"\n==== E2E RESULT: {passed} passed, {failed} failed ====")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
