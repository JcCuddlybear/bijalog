#!/usr/bin/env python3
"""
bijalog.py v2 - plain-text, append-only, VERSIONED decision log.

Layout (versioned keep-all): <root>/<project>/log/<project>_v###.txt
Current log = highest-numeric version. Every write copies the current highest
version, appends one line, and saves the NEXT version; older versions are never
overwritten or deleted (the recovery guarantee).

Line grammar:  timestamp | ULID | status | tags | text
Statuses: ACTIVE / PROPOSED / REJECTED / ARCHIVED   (SUPERSEDED is derived)
Current truth = newest ACTIVE line per topic, minus any id named in a supersedes: tag.

  python bijalog.py add     system "We cut Alaya." --topic core
  python bijalog.py approve system 01K...        # append ACTIVE superseding the PROPOSED
  python bijalog.py verify
  python bijalog.py state   system
  python bijalog.py watch   --inbox ./inbox
"""
import argparse, os, re, sys, time, secrets
from datetime import datetime

STATUSES = {"ACTIVE", "PROPOSED", "REJECTED", "ARCHIVED"}
TS_FMT = "%Y-%m-%d %H:%M"
CROCK = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
LINE_RE = re.compile(r"^\s*(.+?)\s*\|\s*([0-9A-Za-z]{10,32})\s*\|\s*([A-Z]+)\s*\|\s*(.*?)\s*\|\s*(.+)$")
STALE_DAYS = 30

def ulid():
    t = int(time.time() * 1000); tp = ""
    for _ in range(10):
        tp = CROCK[t & 31] + tp; t >>= 5
    return tp + "".join(secrets.choice(CROCK) for _ in range(16))

def parse_line(ln):
    m = LINE_RE.match(ln)
    if not m: return None
    return {"ts": m.group(1).strip(), "id": m.group(2).strip(),
            "status": m.group(3).strip(), "tags": m.group(4).strip(), "text": m.group(5).strip()}

def tag_val(tags, key):
    m = re.search(r"(?:^|\s)" + re.escape(key) + r":(\S+)", tags)
    return m.group(1) if m else None

def build_line(ident, status, tags, text):
    tags = tags.replace("|", "\\|").strip()
    text = text.replace("|", "\\|").replace("\r", " ").replace("\n", " ").strip()
    return datetime.now().strftime(TS_FMT) + " | " + ident + " | " + status + " | " + tags + " | " + text

def log_dir(root, project):
    return os.path.join(root, project, "log")

def _prefix(project):
    return project[8:] if project.startswith("PROJECT_") else project

def deck(root, project):
    d = log_dir(root, project)
    rx = re.compile(r"^" + re.escape(_prefix(project)) + r"_v(\d+)\.txt$")
    vs = []
    if os.path.isdir(d):
        for f in os.listdir(d):
            m = rx.match(f)
            if m: vs.append((int(m.group(1)), f))
    vs.sort()
    return d, vs

def current_file(root, project):
    d, vs = deck(root, project)
    return os.path.join(d, vs[-1][1]) if vs else None

def check_deck(root, project):
    d, vs = deck(root, project)
    errs = []
    if os.path.isfile(os.path.join(root, project, "log.txt")):
        errs.append("legacy flat log.txt present")
    if vs:
        nums = [n for n, _ in vs]
        if len(set(nums)) != len(nums): errs.append("duplicate version numbers")
        if nums != list(range(1, max(nums) + 1)): errs.append("version gaps")
    return errs

def read_lines(path):
    if not path or not os.path.isfile(path): return "", []
    txt = open(path, encoding="utf-8").read()
    return txt, [l for l in txt.splitlines() if LINE_RE.match(l)]

def _lock(lock, tries=50, delay=0.1):
    for _ in range(tries):
        try:
            fd = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY); os.close(fd); return True
        except FileExistsError:
            time.sleep(delay)
    return False

def append_version(root, project, line):
    d = log_dir(root, project); os.makedirs(d, exist_ok=True)
    errs = check_deck(root, project)
    if errs: raise RuntimeError("deck not clean: " + "; ".join(errs))
    _, vs = deck(root, project)
    n = vs[-1][0] if vs else 0
    cur = os.path.join(d, vs[-1][1]) if vs else None
    base = open(cur, encoding="utf-8").read() if cur else "# bijalog v2 | utf-8 | delimiter=| | project:" + project + "\n"
    if not base.endswith("\n"): base += "\n"
    new_path = os.path.join(d, _prefix(project) + "_v" + str(n + 1).zfill(3) + ".txt")
    lk = new_path + ".lock"
    if not _lock(lk): raise RuntimeError("could not acquire lock")
    try:
        with open(new_path, "w", encoding="utf-8") as fh:
            fh.write(base + line + "\n"); fh.flush(); os.fsync(fh.fileno())
        _, after = read_lines(new_path)
        if not after or after[-1] != line: raise RuntimeError("post-write verification failed")
    finally:
        try: os.remove(lk)
        except OSError: pass
    return new_path

def cmd_add(a):
    ident = ulid()
    tags = a.tags or ("kind:decision topic:" + a.topic)
    if a.approved:
        status = "ACTIVE"
        if "approved-by:" not in tags: tags += " approved-by:" + os.environ.get("BIJALOG_APPROVER", "admin")
    else:
        status = "PROPOSED"
    line = build_line(ident, status, tags, a.text)
    p = append_version(a.root, a.project, line)
    print("appended " + ident + " [" + status + "] -> " + a.project + "  (" + os.path.basename(p) + ")")
    print("  " + line)
    return 0

def _find(lines, arg):
    for p in (parse_line(l) for l in lines):
        if p and (p["id"] == arg or (len(arg) >= 6 and p["id"].endswith(arg))):
            return p
    return None

def cmd_approve(a):
    cur = current_file(a.root, a.project)
    _, lines = read_lines(cur)
    t = _find(lines, a.id)
    if not t: sys.exit("error: id " + a.id + " not found in '" + a.project + "'")
    if t["status"] == "ACTIVE":
        sys.exit("error: " + t["id"] + " is already ACTIVE - nothing to approve. "
                 "To change it, add a new line with --tags \"... supersedes:" + t["id"] + "\".")
    if t["status"] in ("REJECTED", "ARCHIVED"):
        sys.exit("error: " + t["id"] + " is " + t["status"] + " - approve is only for PROPOSED lines.")
    ident = ulid()
    tags = t["tags"]
    if "supersedes:" + t["id"] not in tags: tags += " supersedes:" + t["id"]
    if "approved-by:" not in tags: tags += " approved-by:" + os.environ.get("BIJALOG_APPROVER", "admin")
    line = build_line(ident, "ACTIVE", tags, t["text"])
    p = append_version(a.root, a.project, line)
    print("approved " + t["id"] + " -> new ACTIVE " + ident + "  (" + os.path.basename(p) + ")")
    print("  " + line)
    return 0

def _superseded(lines):
    s = set()
    for p in (parse_line(l) for l in lines):
        if p:
            v = tag_val(p["tags"], "supersedes")
            if v:
                for x in v.split(","): s.add(x)
    return s

def cmd_verify(a):
    root = a.root
    projs = [d for d in os.listdir(root) if os.path.isdir(os.path.join(root, d))] if os.path.isdir(root) else []
    errors = 0
    for proj in sorted(projs):
        issues = list(check_deck(root, proj))
        cur = current_file(root, proj)
        _, lines = read_lines(cur)
        ids = {}
        for l in lines:
            p = parse_line(l)
            if not p: continue
            if p["status"] not in STATUSES: issues.append(p["id"] + ": bad status " + p["status"])
            if p["id"] in ids: issues.append("duplicate id " + p["id"])
            ids[p["id"]] = p
            if p["status"] == "ACTIVE" and "kind:decision" in p["tags"] and "approved-by:" not in p["tags"]:
                issues.append(p["id"] + ": ACTIVE decision without approved-by:")
        for l in lines:
            p = parse_line(l)
            if not p: continue
            v = tag_val(p["tags"], "supersedes")
            if v:
                for x in v.split(","):
                    if x not in ids: issues.append(p["id"] + ": supersedes unknown id " + x)
        if not cur:
            print("-- " + proj + ": no versions"); continue
        if issues:
            errors += 1
            print("ERROR " + proj + " (" + os.path.basename(cur) + "):")
            for i in issues: print("   - " + i)
        else:
            print("OK: " + proj + " (" + str(len(lines)) + " lines, " + os.path.basename(cur) + ")")
    return 1 if errors else 0

def cmd_state(a):
    cur = current_file(a.root, a.project)
    _, lines = read_lines(cur)
    sup = _superseded(lines)
    by_topic = {}
    for l in lines:
        p = parse_line(l)
        if not p or p["status"] != "ACTIVE" or p["id"] in sup: continue
        by_topic[tag_val(p["tags"], "topic") or "(none)"] = p
    print("current truth for " + a.project + " (" + str(len(by_topic)) + " topics):")
    for topic, p in by_topic.items():
        print("  [" + topic + "] " + p["id"] + ": " + p["text"][:100])
    return 0

def cmd_watch(a):
    print("watching '" + a.inbox + "' -> root '" + a.root + "' (Ctrl+C to stop)")
    os.makedirs(a.inbox, exist_ok=True)
    while True:
        try:
            for fn in os.listdir(a.inbox):
                fp = os.path.join(a.inbox, fn)
                if os.path.isfile(fp):
                    c = open(fp, encoding="utf-8").read().strip()
                    if c:
                        # "project: text" routes to that project; a note with no
                        # colon goes to "general" - the note text is NEVER used
                        # as a folder name (it may hold characters that are
                        # illegal in filenames, and a mkdir failure here would
                        # retry the same note forever).
                        if ":" in c.splitlines()[0]:
                            proj, _, msg = c.partition(":")
                            proj, msg = proj.strip(), (msg.strip() or c)
                        else:
                            proj, msg = "general", c
                        if not re.fullmatch(r"[A-Za-z0-9_\-]+", proj):
                            proj = "general"; msg = c
                        append_version(a.root, proj, build_line(ulid(), "PROPOSED", "kind:decision source:inbox", msg))
                        print("ingested -> " + proj + ": " + msg)
                    os.remove(fp)
            time.sleep(2)
        except KeyboardInterrupt:
            print("\nstopped."); break
        except Exception as e:
            print("watch error: " + str(e)); time.sleep(5)
    return 0

def main():
    ap = argparse.ArgumentParser(description="Bijalog v2 decision logger")
    ap.add_argument("--root", default=os.environ.get("BIJALOG_ROOT", "./projects"))
    sub = ap.add_subparsers(dest="command", required=True)
    pa = sub.add_parser("add"); pa.add_argument("project"); pa.add_argument("text")
    pa.add_argument("--topic", default="general"); pa.add_argument("--tags"); pa.add_argument("--approved", action="store_true"); pa.set_defaults(func=cmd_add)
    pp = sub.add_parser("approve"); pp.add_argument("project"); pp.add_argument("id"); pp.set_defaults(func=cmd_approve)
    pv = sub.add_parser("verify"); pv.set_defaults(func=cmd_verify)
    ps = sub.add_parser("state"); ps.add_argument("project"); ps.set_defaults(func=cmd_state)
    pw = sub.add_parser("watch"); pw.add_argument("--inbox", default="./inbox"); pw.set_defaults(func=cmd_watch)
    args = ap.parse_args()
    sys.exit(args.func(args))

if __name__ == "__main__":
    main()
