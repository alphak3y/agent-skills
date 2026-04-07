#!/usr/bin/env python3
"""
Cleanup stale subagent sessions from OpenClaw session stores.

Usage:
  python3 cleanup.py                    # dry run, default 1 hour retention
  python3 cleanup.py --execute          # actually delete
  python3 cleanup.py --hours 24         # keep sessions from last 24 hours
  python3 cleanup.py --hours 0          # remove ALL completed subagent sessions
  python3 cleanup.py --agent developer  # only clean one agent
"""

import json
import os
import sys
import time
import glob
import argparse


def get_agents_dir():
    return os.path.expanduser("~/.openclaw/agents")


def list_agents(agents_dir):
    if not os.path.isdir(agents_dir):
        return []
    return [d for d in os.listdir(agents_dir)
            if os.path.isdir(os.path.join(agents_dir, d))]


def cleanup_agent(agent, agents_dir, cutoff_ms, dry_run=True):
    store_path = os.path.join(agents_dir, agent, "sessions", "sessions.json")
    transcripts_dir = os.path.join(agents_dir, agent, "sessions", "transcripts")

    if not os.path.isfile(store_path):
        return 0, 0

    with open(store_path) as f:
        data = json.load(f)

    keep = {}
    removed_sessions = 0
    active_session_ids = set()

    for key, session in data.items():
        # Always keep non-subagent sessions (main, cron, telegram, etc.)
        if "subagent" not in key:
            keep[key] = session
            sid = session.get("sessionId", "")
            if sid:
                active_session_ids.add(sid)
            continue

        # For subagents, check age
        updated = session.get("updatedAt", session.get("createdAt", 0))
        if updated > cutoff_ms:
            keep[key] = session
            sid = session.get("sessionId", "")
            if sid:
                active_session_ids.add(sid)
        else:
            removed_sessions += 1

    # Write cleaned store
    if not dry_run and removed_sessions > 0:
        with open(store_path, "w") as f:
            json.dump(keep, f, indent=2)

    # Clean orphaned transcript files
    removed_transcripts = 0
    if os.path.isdir(transcripts_dir):
        for transcript in glob.glob(os.path.join(transcripts_dir, "*.jsonl")):
            basename = os.path.splitext(os.path.basename(transcript))[0]
            if basename not in active_session_ids:
                removed_transcripts += 1
                if not dry_run:
                    os.remove(transcript)

    return removed_sessions, removed_transcripts


def main():
    parser = argparse.ArgumentParser(description="Cleanup stale subagent sessions")
    parser.add_argument("--execute", action="store_true", help="Actually delete (default is dry run)")
    parser.add_argument("--hours", type=float, default=1, help="Keep sessions newer than N hours (default: 1)")
    parser.add_argument("--agent", type=str, help="Only clean a specific agent")
    args = parser.parse_args()

    dry_run = not args.execute
    cutoff_ms = (time.time() - args.hours * 3600) * 1000
    agents_dir = get_agents_dir()

    if args.agent:
        agents = [args.agent]
    else:
        agents = list_agents(agents_dir)

    if dry_run:
        print("DRY RUN — pass --execute to actually delete\n")

    total_sessions = 0
    total_transcripts = 0

    for agent in sorted(agents):
        sessions, transcripts = cleanup_agent(agent, agents_dir, cutoff_ms, dry_run)
        if sessions > 0 or transcripts > 0:
            action = "would remove" if dry_run else "removed"
            print(f"  {agent}: {action} {sessions} sessions, {transcripts} transcripts")
            total_sessions += sessions
            total_transcripts += transcripts

    if total_sessions == 0 and total_transcripts == 0:
        print("Nothing to clean up.")
    else:
        action = "Would remove" if dry_run else "Removed"
        print(f"\n{action} {total_sessions} sessions + {total_transcripts} transcripts total.")


if __name__ == "__main__":
    main()
