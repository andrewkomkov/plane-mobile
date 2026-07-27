#!/usr/bin/env python3
"""Fill a Plane workspace with a demo project worth screenshotting.

The screenshots in the README have to come from somewhere, and a real
workspace is the wrong somewhere: it is either empty, or it is someone's
actual work. This builds a project that exercises every screen the app has —
several states, every priority, labels, three modules, two cycles, sub-issues,
comments, a few things overdue and a few done.

It talks to Plane's *external* API (`/api/v1/`) with a plain API token, so it
needs neither the proxy nor a session. That surface is smaller than the one
the app uses, but it covers everything worth seeding.

Usage:

    export PLANE_BASE_URL=https://plane.example.com
    export PLANE_API_KEY=plane_api_...
    export PLANE_WORKSPACE_SLUG=my-workspace

    python3 tool/seed_demo.py            # create it
    python3 tool/seed_demo.py --reset    # delete the old one first
    python3 tool/seed_demo.py --dry-run  # print what it would do

Nothing here touches a project it did not create: --reset only removes a
project whose identifier matches IDENTIFIER below.
"""

from __future__ import annotations

import argparse
import json
import os
import random
import sys
import urllib.error
import urllib.request
from datetime import date, timedelta

PROJECT_NAME = "Aurora"
PROJECT_DESCRIPTION = (
    "Demo project for plane-mobile screenshots. Everything in here is invented."
)
IDENTIFIER = "AUR"

# Fixed so two runs produce the same board. A screenshot that reshuffles every
# time it is regenerated is a screenshot nobody can compare against.
SEED = 20260727

TIMEOUT = 30


class PlaneError(RuntimeError):
    pass


class Plane:
    """The slice of Plane's v1 API this script needs."""

    def __init__(self, base_url: str, token: str, slug: str, dry_run: bool = False):
        self.base = base_url.rstrip("/") + "/api/v1"
        self.token = token
        self.slug = slug
        self.dry_run = dry_run

    # Enough of a project's default state set for a dry run to walk the same
    # code path a real one does.
    _FAKE_STATES = [
        {"id": f"state-{group}", "group": group}
        for group in ("backlog", "unstarted", "started", "completed", "cancelled")
    ]

    def _call(self, method: str, path: str, body: dict | None = None) -> object:
        url = f"{self.base}/workspaces/{self.slug}{path}"
        if self.dry_run:
            # Reads are answered locally too. A dry run that still called the
            # server would need a real token to tell you what it would do.
            if method == "GET":
                return self._FAKE_STATES if path.endswith("/states/") else []
            print(f"  [dry-run] {method} {path} {json.dumps(body or {})[:120]}")
            return {"id": "00000000-0000-0000-0000-000000000000"}

        data = json.dumps(body).encode() if body is not None else None
        request = urllib.request.Request(url, data=data, method=method)
        request.add_header("X-API-Key", self.token)
        request.add_header("Content-Type", "application/json")
        try:
            with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
                raw = response.read()
                return json.loads(raw) if raw else None
        except urllib.error.HTTPError as e:
            detail = e.read().decode(errors="replace")[:400]
            raise PlaneError(f"{method} {path} -> {e.code}: {detail}") from e
        except urllib.error.URLError as e:
            raise PlaneError(f"{method} {path} -> {e.reason}") from e

    def get(self, path: str) -> object:
        return self._call("GET", path)

    def post(self, path: str, body: dict) -> dict:
        return self._call("POST", path, body)  # type: ignore[return-value]

    def patch(self, path: str, body: dict) -> object:
        return self._call("PATCH", path, body)

    def delete(self, path: str) -> None:
        self._call("DELETE", path)

    @staticmethod
    def rows(payload: object) -> list:
        """Plane paginates some collections and not others."""
        if isinstance(payload, dict):
            return payload.get("results", [])
        return payload if isinstance(payload, list) else []


# --------------------------------------------------------------------------
# The content
# --------------------------------------------------------------------------

LABELS = [
    ("bug", "#ef4444"),
    ("enhancement", "#3b82f6"),
    ("design", "#a855f7"),
    ("performance", "#f97316"),
    ("accessibility", "#10b981"),
    ("tech debt", "#64748b"),
]

MODULES = [
    (
        "Offline mode",
        "Reads from SQLite first, queues writes, drains when the network returns.",
    ),
    (
        "Board and calendar",
        "The two layouts a phone can actually show, and the drag between columns.",
    ),
    (
        "Push notifications",
        "Device registration, delivery, and what a tap on one should open.",
    ),
]

# (title, priority, label, module index or None, done, description)
WORK_ITEMS = [
    ("Cache the work item list per project", "high", "enhancement", 0, True,
     "Read from SQLite before the network answers, so opening a project is instant."),
    ("Drain the write queue on reconnect", "urgent", "enhancement", 0, True,
     "Edits made offline have to survive the app being killed."),
    ("Show which rows are stale", "medium", "design", 0, False,
     "A cached list and a fresh one currently look identical."),
    ("Conflict when the server changed first", "high", "bug", 0, False,
     "Last-write-wins loses someone's edit silently."),
    ("Purge the cache on disconnect", "low", "tech debt", 0, True, ""),

    ("Drag a card between columns", "urgent", "enhancement", 1, True,
     "Long-press to lift, drop to move. The state change is the drop."),
    ("Collapse an empty column", "low", "design", 1, False,
     "Six empty columns push the one with cards off screen."),
    ("Calendar: show more than three per day", "medium", "design", 1, False, ""),
    ("Board scrolls while dragging", "high", "bug", 1, True,
     "Dragging to the edge should scroll the board, not stop at it."),
    ("Announce the column on focus", "high", "accessibility", 1, False,
     "A card reads its title and nothing about where it is."),

    ("Register the device once per install", "medium", "bug", 2, True,
     "A token that moves between accounts followed the wrong user."),
    ("Open the work item a push refers to", "high", "enhancement", 2, True, ""),
    ("Do not notify me about my own edits", "medium", "bug", 2, True,
     "Plane already excludes the actor; the derived feed did not."),
    ("Group notifications by work item", "low", "design", 2, False, ""),

    ("Estimate points on the detail screen", "medium", "enhancement", None, True, ""),
    ("Sub-issue progress on the parent", "low", "enhancement", None, False, ""),
    ("Attachment upload shows progress", "medium", "design", None, False,
     "A large file looks like a frozen screen."),
    ("Comment edit loses the cursor", "low", "bug", None, False, ""),
    ("Search across projects", "high", "enhancement", None, True, ""),
    ("Dark theme contrast on chips", "medium", "accessibility", None, True,
     "Three chip colours fell under 4.5:1 on the dark surface."),
    ("Reduce rebuilds on the issue list", "medium", "performance", None, False,
     "The whole list rebuilt on every filter keystroke."),
    ("Retire the hand-written API handlers", "urgent", "tech debt", None, True,
     "Everything the app reads now goes through the proxy."),
    ("Spreadsheet view: freeze the first column", "low", "design", None, False, ""),
    ("Filter by label on the workspace rollup", "medium", "enhancement", None, False, ""),
    ("Empty states say what to do next", "low", "design", None, True, ""),
]

SUB_ISSUES = {
    "Drag a card between columns": [
        "Lift and shadow on long-press",
        "Auto-scroll at the board edge",
        "Announce the drop target",
    ],
    "Drain the write queue on reconnect": [
        "Retry with backoff",
        "Surface a failed write",
    ],
}

COMMENTS = {
    "Conflict when the server changed first": [
        "Plane sends updated_at on every work item — comparing it before the "
        "PATCH is enough to detect this.",
        "Agreed. Showing both versions is the part that needs a design.",
    ],
    "Reduce rebuilds on the issue list": [
        "Profiled it: the filter lives above the ListView, so every keystroke "
        "rebuilt every row.",
    ],
    "Retire the hand-written API handlers": [
        "Down to three routes, and all three mint or register something. "
        "Nothing reads Plane's tables directly any more.",
    ],
}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--reset",
        action="store_true",
        help=f"delete an existing {IDENTIFIER} project first",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="print what would be created without creating it",
    )
    args = parser.parse_args()

    base_url = os.environ.get("PLANE_BASE_URL", "")
    token = os.environ.get("PLANE_API_KEY", "")
    slug = os.environ.get("PLANE_WORKSPACE_SLUG", "")
    missing = [
        name
        for name, value in (
            ("PLANE_BASE_URL", base_url),
            ("PLANE_API_KEY", token),
            ("PLANE_WORKSPACE_SLUG", slug),
        )
        if not value
    ]
    if missing:
        print(f"Set {', '.join(missing)} first — see .env.example", file=sys.stderr)
        return 2

    random.seed(SEED)
    plane = Plane(base_url, token, slug, dry_run=args.dry_run)

    try:
        seed(plane, reset=args.reset)
    except PlaneError as e:
        print(f"\nFailed: {e}", file=sys.stderr)
        return 1
    return 0


def seed(plane: Plane, reset: bool) -> None:
    if reset:
        drop_existing(plane)

    print(f"Creating project {PROJECT_NAME} ({IDENTIFIER})…")
    project = plane.post(
        "/projects/",
        {
            "name": PROJECT_NAME,
            "identifier": IDENTIFIER,
            "description": PROJECT_DESCRIPTION,
            # Public inside the workspace, so a second account can see it.
            "network": 2,
            "module_view": True,
            "cycle_view": True,
            "issue_views_view": True,
            "page_view": True,
            "intake_view": True,
        },
    )
    pid = project["id"]
    scope = f"/projects/{pid}"

    print("  labels…")
    labels = {
        name: plane.post(f"{scope}/labels/", {"name": name, "color": color})["id"]
        for name, color in LABELS
    }

    # Plane creates a default set with the project; reuse it rather than adding
    # a parallel one that means the same thing.
    states = {}
    for state in Plane.rows(plane.get(f"{scope}/states/")):
        states.setdefault(state["group"], state["id"])
    if not states and not plane.dry_run:
        raise PlaneError("the project came back with no states")
    done_state = states.get("completed")
    started_state = states.get("started")
    backlog_state = states.get("backlog")
    unstarted_state = states.get("unstarted")

    print("  modules…")
    today = date.today()
    module_ids = []
    for index, (name, description) in enumerate(MODULES):
        module = plane.post(
            f"{scope}/modules/",
            {
                "name": name,
                "description": description,
                "start_date": iso(today - timedelta(days=30 - index * 10)),
                "target_date": iso(today + timedelta(days=15 + index * 14)),
                "status": ["completed", "in-progress", "planned"][index],
            },
        )
        module_ids.append(module["id"])

    print("  cycles…")
    # `project_id` is repeated in the body even though the URL already carries
    # it. Not belt and braces: CycleSerializer.validate reads it out of
    # `self.initial_data` — the request body — while its sibling
    # ModuleSerializer reads the same thing out of the serializer context the
    # view fills in from the URL. Post a cycle the way the route documents and
    # Plane answers 400 "Project ID is required".
    #
    # One finished, one running: the cycle screen has a different shape for
    # each, and a screenshot should show both.
    # Created still running and closed at the end, because Plane refuses to add
    # a work item to a cycle whose end date has passed — CYCLE_COMPLETED. A
    # finished sprint has to be populated first and finished second.
    past = plane.post(
        f"{scope}/cycles/",
        {
            "project_id": pid,
            "name": "Sprint 11",
            "description": "Offline reads and the write queue.",
            "start_date": iso(today - timedelta(days=28)),
            "end_date": iso(today + timedelta(days=1)),
        },
    )
    current = plane.post(
        f"{scope}/cycles/",
        {
            "project_id": pid,
            "name": "Sprint 12",
            "description": "Board interactions and accessibility.",
            "start_date": iso(today - timedelta(days=13)),
            "end_date": iso(today + timedelta(days=1)),
        },
    )

    print(f"  {len(WORK_ITEMS)} work items…")
    created: dict[str, str] = {}
    for index, (title, priority, label, module, done, body) in enumerate(WORK_ITEMS):
        state = done_state if done else pick_state(
            index, started_state, unstarted_state, backlog_state
        )
        # A handful overdue on purpose: the analytics screen counts them and
        # the list draws them differently.
        offset = [-9, -3, 2, 6, 13, 21][index % 6]
        payload = {
            "name": title,
            "priority": priority,
            "state": state,
            "target_date": iso(today + timedelta(days=offset)),
            "labels": [labels[label]] if label in labels else [],
        }
        if body:
            payload["description_html"] = f"<p>{body}</p>"
        issue = plane.post(f"{scope}/issues/", payload)
        created[title] = issue["id"]

        if module is not None:
            plane.post(
                f"{scope}/modules/{module_ids[module]}/module-issues/",
                {"issues": [issue["id"]]},
            )
        cycle = past["id"] if done and index < 12 else current["id"]
        plane.post(
            f"{scope}/cycles/{cycle}/cycle-issues/",
            {"issues": [issue["id"]]},
        )

    print("  sub-issues…")
    for parent_title, children in SUB_ISSUES.items():
        parent = created.get(parent_title)
        if not parent:
            continue
        for child in children:
            plane.post(
                f"{scope}/issues/",
                {
                    "name": child,
                    "parent": parent,
                    "priority": "medium",
                    "state": started_state or unstarted_state,
                },
            )

    print("  comments…")
    for title, bodies in COMMENTS.items():
        issue = created.get(title)
        if not issue:
            continue
        for body in bodies:
            plane.post(
                f"{scope}/issues/{issue}/comments/",
                {"comment_html": f"<p>{body}</p>"},
            )

    print("  closing the finished sprint…")
    plane.patch(
        f"{scope}/cycles/{past['id']}/",
        {"project_id": pid, "end_date": iso(today - timedelta(days=14))},
    )

    print(f"\nDone. {PROJECT_NAME} is at {plane.base.replace('/api/v1', '')}"
          f"/{plane.slug}/projects/{pid}/issues/")


def drop_existing(plane: Plane) -> None:
    """Remove a previously seeded project, and only that."""
    for project in Plane.rows(plane.get("/projects/")):
        if project.get("identifier") != IDENTIFIER:
            continue
        print(f"Removing the existing {IDENTIFIER} project…")
        plane.delete(f"/projects/{project['id']}/")


def pick_state(index: int, started, unstarted, backlog):
    """Spread the unfinished work over the three live groups."""
    return [started, unstarted, backlog][index % 3] or unstarted or backlog


def iso(value: date) -> str:
    return value.isoformat()


if __name__ == "__main__":
    sys.exit(main())
