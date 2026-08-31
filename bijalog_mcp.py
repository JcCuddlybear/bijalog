#!/usr/bin/env python3
"""
bijalog_mcp.py - minimal, dependency-free MCP stdio server for Bijalog v2.
Lets any MCP-capable AI PROPOSE decision lines into your spines, hands-free.
Tools: bijalog_list_projects, bijalog_context, bijalog_propose.
Config via env: BIJALOG_CANON (optional shared spine folder), BIJALOG_STAGING
(root for everything else; defaults to ~/Bijalog/projects).
Every append is PROPOSED (never ACTIVE) - the human gate stays. Versioned keep-all, ULID ids.
"""
import os, sys, json, re, time, secrets
from datetime import datetime

# Optional: point BIJALOG_CANON at a shared/synced folder holding project
# spines. Left unset, everything resolves under BIJALOG_STAGING below.
CANON = os.environ.get("BIJALOG_CANON", "")
STAGING = os.environ.get("BIJALOG_STAGING", os.path.join(os.path.expanduser("~"), "Bijalog", "projects"))
CROCK = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
TS_FMT = "%Y-%m-%d %H:%M"
VER_RE = re.compile(r"^(.+?)_v(\d+)\.txt$")

def ulid():
    t = int(time.time() * 1000); tp = ""
    for _ in range(10):
        tp = CROCK[t & 31] + tp; t >>= 5
    return tp + "".join(secrets.choice(CROCK) for _ in range(16))

def _scan_logdirs(root):
    out = {}
    if not os.path.isdir(root):
        return out
    for dp, dirs, files in os.walk(root):
        if os.path.basename(dp) != "log":
            continue
        vers = {}
        for f in files:
            m = VER_RE.match(f)
            if m:
                vers.setdefault(m.group(1), []).append((int(m.group(2)), f))
        for prefix, vs in vers.items():
            vs.sort()
            out[prefix.lower()] = (prefix, dp, vs)
    return out

def resolve(name):
    hit = _scan_logdirs(CANON).get(name.lower())
    if hit:
        return hit
    logdir = os.path.join(STAGING, name, "log")
    vs = []
    if os.path.isdir(logdir):
        for f in os.listdir(logdir):
            m = VER_RE.match(f)
            if m and m.group(1) == name:
                vs.append((int(m.group(2)), f))
        vs.sort()
    return (name, logdir, vs)

def list_projects():
    return sorted(v[0] for v in _scan_logdirs(CANON).values())

def context(name, last=15):
    prefix, logdir, vs = resolve(name)
    if not vs:
        return "(no spine for %s)" % name
    cur = os.path.join(logdir, vs[-1][1])
    lines = [l for l in open(cur, encoding="utf-8").read().splitlines() if " | " in l]
    return "\n".join(lines[-last:])

def propose(name, text, topic="general"):
    prefix, logdir, vs = resolve(name)
    os.makedirs(logdir, exist_ok=True)
    nums = sorted(v for v, _ in vs)
    if nums:
        if len(set(nums)) != len(nums):
            raise RuntimeError("duplicate version numbers in " + logdir)
        missing = sorted(set(range(1, max(nums) + 1)) - set(nums))
        if missing:
            # Gaps are REPORTED, not fatal - matching bijalog_ingest.py, which
            # continues on a gap because Varta has one its own spine records as
            # deliberate. Refusing to write is the wrong answer to a gap the
            # human already knows about. The note goes to STDERR because stdout
            # is the JSON-RPC channel and must carry nothing but protocol.
            print("bijalog_mcp: version gap(s) in %s: %s - continuing"
                  % (logdir, ", ".join("v%03d" % m for m in missing)), file=sys.stderr)
    lock = os.path.join(logdir, ".lock")
    got = False
    for _ in range(25):
        try:
            fd = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
            os.close(fd); got = True; break
        except FileExistsError:
            time.sleep(0.2)
    if not got:
        raise RuntimeError("could not take lock: " + lock)
    try:
        n = vs[-1][0] if vs else 0
        cur = os.path.join(logdir, vs[-1][1]) if vs else None
        base = open(cur, encoding="utf-8").read() if cur else "# bijalog v2 | utf-8 | delimiter=| | project:" + prefix + "\n"
        if not base.endswith("\n"):
            base += "\n"
        text = text.replace("|", "\\|").replace("\r", " ").replace("\n", " ").strip()
        ident = ulid()
        line = datetime.now().strftime(TS_FMT) + " | " + ident + " | PROPOSED | kind:decision topic:" + topic + " source:mcp | " + text
        newp = os.path.join(logdir, prefix + "_v" + str(n + 1).zfill(3) + ".txt")
        if os.path.exists(newp):
            raise RuntimeError("refusing to overwrite existing " + newp)
        with open(newp, "w", encoding="utf-8") as fh:
            fh.write(base + line + "\n"); fh.flush(); os.fsync(fh.fileno())
        check = open(newp, encoding="utf-8").read()
        if ident not in check:
            raise RuntimeError("post-write verification failed for " + newp)
        if len(check) < len(base):
            raise RuntimeError("new version shorter than its source - aborted: " + newp)
    finally:
        try:
            os.remove(lock)
        except OSError:
            pass
    return {"id": ident, "file": newp, "line": line}

TOOLS = [
    {"name": "bijalog_list_projects", "description": "List all Bijalog project names.",
     "inputSchema": {"type": "object", "properties": {}}},
    {"name": "bijalog_context", "description": "Read the most recent decision lines for a project.",
     "inputSchema": {"type": "object", "properties": {"project": {"type": "string"}, "last": {"type": "integer"}}, "required": ["project"]}},
    {"name": "bijalog_propose", "description": "Append a PROPOSED decision line to a project's spine. The human ratifies later; this never writes ACTIVE.",
     "inputSchema": {"type": "object", "properties": {"project": {"type": "string"}, "text": {"type": "string"}, "topic": {"type": "string"}}, "required": ["project", "text"]}},
]

def _send(obj):
    sys.stdout.write(json.dumps(obj) + "\n"); sys.stdout.flush()

def _call(name, args):
    if name == "bijalog_list_projects":
        return {"content": [{"type": "text", "text": "\n".join(list_projects())}]}
    if name == "bijalog_context":
        return {"content": [{"type": "text", "text": context(args["project"], int(args.get("last", 15)))}]}
    if name == "bijalog_propose":
        r = propose(args["project"], args["text"], args.get("topic", "general"))
        return {"content": [{"type": "text", "text": "PROPOSED " + r["id"] + " -> " + os.path.basename(r["file"]) + "\n" + r["line"]}]}
    return {"content": [{"type": "text", "text": "unknown tool " + str(name)}], "isError": True}

def serve():
    for raw in sys.stdin:
        raw = raw.strip()
        if not raw:
            continue
        try:
            msg = json.loads(raw)
        except Exception:
            continue
        mid = msg.get("id"); method = msg.get("method")
        if method == "initialize":
            _send({"jsonrpc": "2.0", "id": mid, "result": {"protocolVersion": "2024-11-05",
                   "capabilities": {"tools": {}}, "serverInfo": {"name": "bijalog", "version": "2.0"}}})
        elif method == "tools/list":
            _send({"jsonrpc": "2.0", "id": mid, "result": {"tools": TOOLS}})
        elif method == "tools/call":
            p = msg.get("params", {})
            try:
                res = _call(p.get("name"), p.get("arguments", {}))
            except Exception as e:
                res = {"content": [{"type": "text", "text": str(e)}], "isError": True}
            _send({"jsonrpc": "2.0", "id": mid, "result": res})
        elif method and method.startswith("notifications/"):
            pass
        elif mid is not None:
            _send({"jsonrpc": "2.0", "id": mid, "error": {"code": -32601, "message": "method not found"}})

if __name__ == "__main__":
    serve()
