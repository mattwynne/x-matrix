#!/usr/bin/env bash
set -euo pipefail

PLAN_PATH="${1:?plan path required}"
INDEX_PATH="docs/iterations/README.md"

if [ ! -f "$PLAN_PATH" ]; then
  echo "Plan file not found: $PLAN_PATH" >&2
  exit 1
fi

python3 - "$PLAN_PATH" "$INDEX_PATH" <<'PY'
from pathlib import Path
import re
import sys

plan_path = Path(sys.argv[1])
index_path = Path(sys.argv[2])

plan = plan_path.read_text()
if re.search(r"^Status:\s*.*$", plan, flags=re.M):
    plan = re.sub(r"^Status:\s*.*$", "Status: ready", plan, count=1, flags=re.M)
else:
    plan = plan.replace("\n## Goal\n", "\nStatus: ready\n\n## Goal\n", 1)
plan_path.write_text(plan)

if index_path.exists():
    index = index_path.read_text()
    plan_link = f"[{ 'plan' }]({plan_path.parent.as_posix().replace('docs/iterations/', '')}/plan.md)"
    lines = []
    for line in index.splitlines():
        if plan_link in line and line.startswith("|"):
            cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
            if len(cells) >= 5:
                cells[4] = "ready"
                line = "| " + " | ".join(cells) + " |"
            elif len(cells) >= 3:
                cells[2] = "ready"
                line = "| " + " | ".join(cells) + " |"
        lines.append(line)
    index_path.write_text("\n".join(lines) + ("\n" if index.endswith("\n") else ""))
PY

git add "$PLAN_PATH" "$INDEX_PATH"
if ! git diff --cached --quiet; then
  git config user.name "Fabro"
  git config user.email "fabro@users.noreply.github.com"
  git commit -m "Mark iteration plan ready"
fi

# Publish the validated run branch back to main so any automatic plan repairs and
# the ready status are visible in the canonical branch. Rebase first so we fail
# loudly on real conflicts instead of overwriting newer main work.
git pull --rebase origin main
git push origin HEAD:main
