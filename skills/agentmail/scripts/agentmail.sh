#!/usr/bin/env bash
# AgentMail helper — create inboxes, list/wait for messages
set -euo pipefail

API="https://api.agentmail.to/v0"
KEY=$(cat ~/.openclaw/.env.agentmail 2>/dev/null || true)

if [[ -z "$KEY" ]]; then
  echo "Error: No API key found at ~/.openclaw/.env.agentmail" >&2
  exit 1
fi

auth() { echo "Authorization: Bearer $KEY"; }

cmd="${1:-help}"
shift || true

case "$cmd" in
  create)
    username="${1:-}"
    if [[ -n "$username" ]]; then
      result=$(curl -s -X POST -H "$(auth)" -H "Content-Type: application/json" \
        "$API/inboxes" -d "{\"username\": \"$username\", \"domain\": \"agentmail.to\"}")
    else
      result=$(curl -s -X POST -H "$(auth)" -H "Content-Type: application/json" \
        "$API/inboxes" -d '{}')
    fi
    email=$(echo "$result" | jq -r '.email // empty')
    if [[ -n "$email" ]]; then
      echo "$email"
    else
      echo "Error creating inbox:" >&2
      echo "$result" >&2
      exit 1
    fi
    ;;

  messages|msgs)
    inbox="${1:?Usage: agentmail.sh messages <inbox-email>}"
    curl -s -H "$(auth)" "$API/inboxes/$inbox/messages" | jq '.'
    ;;

  wait)
    inbox="${1:?Usage: agentmail.sh wait <inbox-email> [timeout-seconds]}"
    timeout="${2:-60}"
    elapsed=0
    interval=5
    while [[ $elapsed -lt $timeout ]]; do
      count=$(curl -s -H "$(auth)" "$API/inboxes/$inbox/messages" | jq '.count // 0')
      if [[ "$count" -gt 0 ]]; then
        echo "✅ $count message(s) received"
        curl -s -H "$(auth)" "$API/inboxes/$inbox/messages" | jq '.messages[] | {subject, from: .from_address, snippet: (.extracted_text // .text // "" | .[0:300])}'
        exit 0
      fi
      sleep $interval
      elapsed=$((elapsed + interval))
      echo "⏳ Waiting... ($elapsed/${timeout}s)"
    done
    echo "❌ No messages after ${timeout}s" >&2
    exit 1
    ;;

  list)
    curl -s -H "$(auth)" "$API/inboxes" | jq '.inboxes[] | {email, created_at}'
    ;;

  *)
    echo "Usage: agentmail.sh <command> [args]"
    echo ""
    echo "Commands:"
    echo "  create [username]         Create an inbox (random or named)"
    echo "  messages <inbox-email>    List messages in an inbox"
    echo "  wait <inbox-email> [sec]  Poll until a message arrives (default 60s)"
    echo "  list                      List all inboxes"
    ;;
esac
