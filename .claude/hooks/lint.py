#!/usr/bin/env python3
"""The mistakes agents keep making in this repo, as checks.

    python3 .claude/hooks/lint.py                    # this checkout; added lines are those not yet in HEAD
    python3 .claude/hooks/lint.py --root DIR --base REV
    python3 .claude/hooks/lint.py --hook             # Claude Code PreToolUse: runs before `git commit`

An exception sits on the offending line:
    lint-allow(<check>): <reason>; until YYYY-MM-DD; approved by <name>
"""
import datetime
import glob
import json
import os
import re
import subprocess
import sys

ALLOW = re.compile(r"lint-allow\((\w[\w-]*)\):[^;]+;\s*until (\d{4}-\d{2}-\d{2});\s*approved by \S")
STYLE = re.compile(r"^\s*(?:font\.pixelSize|radius|spacing|duration|(?:left|right|top|bottom)?[mM]argins?|implicitWidth|implicitHeight)\s*:\s*(-?\d+(?:\.\d+)?)\s*(?://.*)?$")
I18N = re.compile(r'I18n\.t\(\s*"((?:[^"\\]|\\.)*)"')
KILL = re.compile(r"\bp(?:kill|grep)\s+-[A-Za-z]*f\b")


def git(root, *args):
    return subprocess.run(["git", "-C", root, *args], capture_output=True, text=True).stdout


def added_lines(root, base):
    """{path: set of 1-based line numbers} changed since base, untracked files whole."""
    out = {}
    path = None
    for line in git(root, "diff", base, "-U0", "--no-color", "--", "configs").splitlines():
        if line.startswith("+++ "):
            path = line[6:] if line.startswith("+++ b/") else None
        elif line.startswith("@@") and path:
            m = re.search(r"\+(\d+)(?:,(\d+))?", line)
            start, count = int(m.group(1)), int(m.group(2) or 1)
            out.setdefault(path, set()).update(range(start, start + count))
    for path in git(root, "ls-files", "--others", "--exclude-standard", "--", "configs").splitlines():
        try:
            n = sum(1 for _ in open(os.path.join(root, path), errors="replace"))
        except OSError:
            continue
        out.setdefault(path, set()).update(range(1, n + 1))
    return out


def allowed(line, check, problems, where):
    m = ALLOW.search(line)
    if not m or m.group(1) != check:
        return False
    if m.group(2) < datetime.date.today().isoformat():
        problems.append(f"{where}: the lint-allow({check}) exception expired on {m.group(2)}; fix the line or get a new approval")
    return True


def check(root, base):
    problems = []
    rel = lambda p: os.path.relpath(p, root)
    qml = sorted(glob.glob(os.path.join(root, "configs/quickshell/**/*.qml"), recursive=True))

    # One short line per comment (DOCS/CHECKLIST.md); 17 older blocks exist, so only new lines fail.
    for path, lines in added_lines(root, base).items():
        if not path.endswith(".qml"):
            continue
        try:
            text = open(os.path.join(root, path), errors="replace").read().split("\n")
        except OSError:
            continue
        is_comment = lambda i: 0 <= i < len(text) and text[i].strip().startswith("//") and not text[i].strip().startswith("//@")
        for n in sorted(lines):
            i = n - 1
            if is_comment(i) and (is_comment(i - 1) or is_comment(i + 1)) and not allowed(text[i], "comments", problems, f"{path}:{n}"):
                problems.append(f"{path}:{n}: a comment is one short line, only for a why the code cannot show (DOCS/CHECKLIST.md); fold this block into one line or delete it")

    # Every literal I18n.t() key is in every language file (.claude/rules/shell.md).
    langs = {os.path.basename(p)[:-5]: json.load(open(p)) for p in sorted(glob.glob(os.path.join(root, "configs/quickshell/i18n/*.json")))}
    for path in qml:
        for n, line in enumerate(open(path, errors="replace"), 1):
            if line.strip().startswith("//"):
                continue
            for m in I18N.finditer(line):
                key = json.loads('"' + m.group(1) + '"')
                for lang, table in langs.items():
                    if key not in table and not allowed(line, "i18n", problems, f"{rel(path)}:{n}"):
                        problems.append(f'{rel(path)}:{n}: "{key}" is missing from configs/quickshell/i18n/{lang}.json; add the key to every language file')

    # Every design value is a Theme token (.claude/rules/shell.md, Design system).
    for path in qml:
        if path.endswith("/Theme.qml"):
            continue
        for n, line in enumerate(open(path, errors="replace"), 1):
            m = STYLE.match(line)
            if m and float(m.group(1)) not in (0, 1) and not allowed(line, "tokens", problems, f"{rel(path)}:{n}"):
                problems.append(f"{rel(path)}:{n}: {line.strip()} is a magic number; use a Theme token (configs/quickshell/Theme.qml), or add one")

    # No recipe kills by a command-line pattern: it can match the agent's own shell.
    docs = glob.glob(os.path.join(root, ".claude/**/*.md"), recursive=True) + glob.glob(os.path.join(root, "DOCS/*.md")) + [os.path.join(root, "CLAUDE.md")]
    for path in sorted(docs):
        if not os.path.exists(path):
            continue
        for n, line in enumerate(open(path, errors="replace"), 1):
            if KILL.search(line) and not allowed(line, "kill", problems, f"{rel(path)}:{n}"):
                problems.append(f"{rel(path)}:{n}: kills by a command-line pattern, which can match the agent's own shell; use .claude/skills/verify-ummitos/scripts/stop.sh <name>")
    return problems


def main():
    args = sys.argv[1:]
    here = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    root = args[args.index("--root") + 1] if "--root" in args else here
    base = args[args.index("--base") + 1] if "--base" in args else "HEAD"
    if "--hook" in args:
        payload = json.load(sys.stdin)
        command = payload.get("tool_input", {}).get("command", "")
        if payload.get("tool_name") != "Bash" or not re.search(r"(^|[\s;&|(])git\s+(-C\s+\S+\s+)?commit\b", command):
            return 0
        cwd = payload.get("cwd") or os.getcwd()
        top = git(cwd, "rev-parse", "--show-toplevel").strip()
        if os.path.realpath(top) != os.path.realpath(root):
            return 0
    problems = check(root, base)
    for p in problems:
        print(p, file=sys.stderr)
    if problems:
        print(f"lint: {len(problems)} problem(s); fix them before committing (.claude/hooks/lint.py)", file=sys.stderr)
        return 2 if "--hook" in args else 1
    if "--hook" not in args:
        print("lint: ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
