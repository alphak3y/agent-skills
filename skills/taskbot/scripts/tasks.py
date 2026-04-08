#!/usr/bin/env python3
"""Taskbot — lightweight persistent task manager with reminders."""

import argparse
import json
import os
import random
import string
import sys
from datetime import datetime, timedelta, timezone

TASKS_FILE = os.path.expanduser("~/.openclaw/workspace/tasks.json")


def load_tasks():
    if not os.path.exists(TASKS_FILE):
        return []
    with open(TASKS_FILE, "r") as f:
        return json.load(f)


def save_tasks(tasks):
    os.makedirs(os.path.dirname(TASKS_FILE), exist_ok=True)
    with open(TASKS_FILE, "w") as f:
        json.dump(tasks, f, indent=2)


def gen_id():
    return "".join(random.choices(string.ascii_lowercase + string.digits, k=6))


def parse_due(due_str):
    """Parse a due date string into UTC ISO format."""
    if not due_str:
        return None
    # Try full datetime first
    for fmt in ("%Y-%m-%d %H:%M", "%Y-%m-%dT%H:%M", "%Y-%m-%d %H:%M:%S"):
        try:
            dt = datetime.strptime(due_str, fmt)
            return dt.isoformat() + "Z"
        except ValueError:
            continue
    # Date only — default to 09:00 MDT (UTC-6) = 15:00 UTC
    try:
        dt = datetime.strptime(due_str, "%Y-%m-%d")
        dt = dt.replace(hour=15, minute=0)  # 9am MDT in UTC
        return dt.isoformat() + "Z"
    except ValueError:
        print(f"Error: Could not parse date '{due_str}'", file=sys.stderr)
        sys.exit(1)


def fmt_time(iso_str):
    """Format UTC ISO string to readable MDT (UTC-6) time."""
    if not iso_str:
        return "no due date"
    dt = datetime.fromisoformat(iso_str.replace("Z", "+00:00"))
    # MDT = UTC-6 (Mar-Nov), MST = UTC-7 (Nov-Mar)
    # Simple approach: use -6 during DST period
    mdt = timezone(timedelta(hours=-6))
    local = dt.astimezone(mdt)
    return local.strftime("%a %b %d, %I:%M %p MDT")


def cmd_add(args):
    tasks = load_tasks()
    task = {
        "id": gen_id(),
        "text": args.text,
        "status": "open",
        "priority": args.priority or "medium",
        "tags": [t.strip() for t in args.tags.split(",")] if args.tags else [],
        "due": parse_due(args.due),
        "created": datetime.now(timezone.utc).isoformat(),
        "snoozed_until": None,
    }
    tasks.append(task)
    save_tasks(tasks)
    due_info = f" — due {fmt_time(task['due'])}" if task["due"] else ""
    print(f"✅ Added [{task['id']}] {task['text']}{due_info}")


def cmd_list(args):
    tasks = load_tasks()
    status_filter = args.status or "open"

    filtered = tasks
    if status_filter != "all":
        filtered = [t for t in filtered if t["status"] == status_filter]
    if args.tag:
        filtered = [t for t in filtered if args.tag in t.get("tags", [])]
    if args.priority:
        filtered = [t for t in filtered if t.get("priority") == args.priority]

    if not filtered:
        print("No tasks found.")
        return

    # Sort: high priority first, then by due date
    priority_order = {"high": 0, "medium": 1, "low": 2}
    filtered.sort(key=lambda t: (
        priority_order.get(t.get("priority", "medium"), 1),
        t.get("due") or "9999",
    ))

    for t in filtered:
        pri = {"high": "🔴", "medium": "🟡", "low": "🟢"}.get(t.get("priority", "medium"), "⚪")
        status = "✅" if t["status"] == "done" else "⬜"
        due = f" — due {fmt_time(t['due'])}" if t.get("due") else ""
        tags = f" [{', '.join(t['tags'])}]" if t.get("tags") else ""
        print(f"{status} {pri} [{t['id']}] {t['text']}{due}{tags}")


def cmd_done(args):
    tasks = load_tasks()
    for t in tasks:
        if t["id"] == args.task_id:
            t["status"] = "done"
            t["completed"] = datetime.now(timezone.utc).isoformat()
            save_tasks(tasks)
            print(f"✅ Completed [{t['id']}] {t['text']}")
            return
    print(f"Error: Task '{args.task_id}' not found.", file=sys.stderr)
    sys.exit(1)


def cmd_delete(args):
    tasks = load_tasks()
    original_len = len(tasks)
    tasks = [t for t in tasks if t["id"] != args.task_id]
    if len(tasks) == original_len:
        print(f"Error: Task '{args.task_id}' not found.", file=sys.stderr)
        sys.exit(1)
    save_tasks(tasks)
    print(f"🗑️ Deleted task {args.task_id}")


def cmd_due(args):
    tasks = load_tasks()
    now = datetime.now(timezone.utc)
    window = timedelta(minutes=args.window or 60)

    due_tasks = []
    for t in tasks:
        if t["status"] != "open" or not t.get("due"):
            continue
        # Check snooze
        if t.get("snoozed_until"):
            snooze_end = datetime.fromisoformat(t["snoozed_until"].replace("Z", "+00:00"))
            if now < snooze_end:
                continue
        due_dt = datetime.fromisoformat(t["due"].replace("Z", "+00:00"))
        if due_dt <= now + window:
            due_tasks.append(t)

    if not due_tasks:
        print("No tasks due.")
        return

    due_tasks.sort(key=lambda t: t["due"])
    for t in due_tasks:
        pri = {"high": "🔴", "medium": "🟡", "low": "🟢"}.get(t.get("priority", "medium"), "⚪")
        overdue = ""
        due_dt = datetime.fromisoformat(t["due"].replace("Z", "+00:00"))
        if due_dt <= now:
            overdue = " ⏰ OVERDUE"
        print(f"{pri} [{t['id']}] {t['text']} — due {fmt_time(t['due'])}{overdue}")


def cmd_snooze(args):
    tasks = load_tasks()
    for t in tasks:
        if t["id"] == args.task_id:
            snooze_until = datetime.now(timezone.utc) + timedelta(minutes=int(args.minutes))
            t["snoozed_until"] = snooze_until.isoformat() + "Z"
            save_tasks(tasks)
            print(f"😴 Snoozed [{t['id']}] until {fmt_time(t['snoozed_until'])}")
            return
    print(f"Error: Task '{args.task_id}' not found.", file=sys.stderr)
    sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description="Taskbot — task manager")
    sub = parser.add_subparsers(dest="command")

    p_add = sub.add_parser("add")
    p_add.add_argument("text")
    p_add.add_argument("--due")
    p_add.add_argument("--priority", choices=["high", "medium", "low"])
    p_add.add_argument("--tags")

    p_list = sub.add_parser("list")
    p_list.add_argument("--status", choices=["open", "done", "all"])
    p_list.add_argument("--tag")
    p_list.add_argument("--priority", choices=["high", "medium", "low"])

    p_done = sub.add_parser("done")
    p_done.add_argument("task_id")

    p_del = sub.add_parser("delete")
    p_del.add_argument("task_id")

    p_due = sub.add_parser("due")
    p_due.add_argument("--window", type=int, default=60)

    p_snooze = sub.add_parser("snooze")
    p_snooze.add_argument("task_id")
    p_snooze.add_argument("minutes")

    args = parser.parse_args()
    if not args.command:
        parser.print_help()
        sys.exit(1)

    cmds = {
        "add": cmd_add,
        "list": cmd_list,
        "done": cmd_done,
        "delete": cmd_delete,
        "due": cmd_due,
        "snooze": cmd_snooze,
    }
    cmds[args.command](args)


if __name__ == "__main__":
    main()
