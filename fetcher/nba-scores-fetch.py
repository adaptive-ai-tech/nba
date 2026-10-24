#!/usr/bin/env python3
"""NBA Scores fetcher (Adaptive AI Technologies, MIT).
Polls the public NBA data feed (cdn.nba.com, falling back to NBA's S3 origin) and writes ~/.cache/nba-scores/scores.json
for the Omarchy bar widget. No keys, no login, no telemetry."""
import json, os, sys, time, subprocess, urllib.request
from datetime import datetime, timezone, timedelta

LOCAL_TZ = datetime.now().astimezone().tzinfo
CACHE = os.path.expanduser(os.environ.get("XDG_CACHE_HOME", "~/.cache") + "/nba-scores")
CONF = os.path.expanduser(os.environ.get("XDG_CONFIG_HOME", "~/.config") + "/nba-scores/config.json")
SB = "https://cdn.nba.com/static/json/liveData/scoreboard/todaysScoreboard_00.json"
BOX = "https://cdn.nba.com/static/json/liveData/boxscore/boxscore_{}.json"
SCHED = "https://cdn.nba.com/static/json/staticData/scheduleLeagueV2.json"
DEFAULT = {"favourites": [], "notify": True, "liveInterval": 30, "idleInterval": 600,
           "scheduleHours": 12,
           "donateUrl": "upi://pay?ver=01&mode=01&purpose=00&mc=0000&qrMedium=02&pa=9629734560@hdfc&pn=PRADEEP%20CHANDAR%20T"}

def conf():
    c = dict(DEFAULT)
    try:
        with open(CONF) as f:
            c.update(json.load(f))
    except FileNotFoundError:
        os.makedirs(os.path.dirname(CONF), exist_ok=True)
        with open(CONF, "w") as f:
            json.dump(DEFAULT, f, indent=2)
    except Exception:
        pass
    return c

# cdn.nba.com sits behind a CDN that returns 403 in some regions; the same official
# files are served by NBA's own S3 origin, used as a fallback.
def log(msg):
    """One line to stdout; systemd stores it in journald (journalctl --user -u nba-scores)."""
    print(msg, file=sys.stdout, flush=True)

ORIGIN = "https://nba-prod-us-east-1-mediaops-stats.s3.amazonaws.com/NBA"

def get(url, timeout=15):
    name = url.rsplit("/", 1)[-1]
    t0 = time.monotonic()
    try:
        d = _get(url, timeout)
        src = "cdn"
    except Exception as e1:
        try:
            d = _get(url.replace("https://cdn.nba.com/static/json", ORIGIN), timeout)
            src = "s3"
        except Exception as e2:
            log(f"fetch-error {name} cdn={str(e1)[:80]} s3={str(e2)[:80]} ms={int((time.monotonic()-t0)*1000)}")
            raise
    log(f"fetch {name} src={src} ms={int((time.monotonic()-t0)*1000)}")
    return d

def _get(url, timeout):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 omarchy-nba-scores", "Referer": "https://www.nba.com/"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.load(r)

def write(name, data):
    os.makedirs(CACHE, exist_ok=True)
    tmp = os.path.join(CACHE, name + ".tmp")
    with open(tmp, "w") as f:
        json.dump(data, f)
    os.replace(tmp, os.path.join(CACHE, name))

def local(utc):
    try:
        return datetime.fromisoformat(utc.replace("Z", "+00:00")).astimezone(LOCAL_TZ)
    except Exception:
        return None

def tz(t):
    return t.strftime("%Z") if t else ""

def clock(s):  # PT03M12.00S -> 3:12
    try:
        m, sec = s.replace("PT", "").replace("S", "").split("M")
        return f"{int(m)}:{int(float(sec)):02d}"
    except Exception:
        return ""

def leaders(gid):
    try:
        g = get(BOX.format(gid))["game"]
        out = {}
        for side in ("homeTeam", "awayTeam"):
            ps = [p for p in g[side].get("players", []) if p.get("played") == "1"]
            ps.sort(key=lambda p: p["statistics"].get("points", 0), reverse=True)
            out[side] = [{"name": p.get("nameI", p.get("name")), "pts": p["statistics"].get("points", 0),
                          "reb": p["statistics"].get("reboundsTotal", 0), "ast": p["statistics"].get("assists", 0)} for p in ps[:3]]
        return out
    except Exception:
        return None

def notify(title, body):
    try:
        subprocess.run(["notify-send", "-a", "NBA Scores", title, body], timeout=5)
    except Exception:
        pass

def upcoming(c, cache):
    if time.time() - cache.get("t", 0) < float(c["scheduleHours"]) * 3600:
        return cache
    try:
        now = datetime.now(timezone.utc)
        up = []
        for d in get(SCHED, 60)["leagueSchedule"]["gameDates"]:
            for g in d["games"]:
                t = local(g.get("gameDateTimeUTC", ""))
                if t and t > now:
                    up.append({"gameId": g["gameId"], "away": g["awayTeam"]["teamTricode"], "home": g["homeTeam"]["teamTricode"],
                               "start": t.strftime("%a %d %b %H:%M ") + tz(t), "ts": t.timestamp()})
        up.sort(key=lambda x: x["ts"])
        return {"t": time.time(), "upcoming": up[:10]}
    except Exception:
        return cache

def main():
    state, sched, box, seen, boxAt, finals = {}, {}, {}, {}, {}, {}
    log("start")
    while True:
        c = conf()
        live = False
        try:
            sb = get(SB)["scoreboard"]
            fav = set(str(x).upper() for x in c["favourites"])
            games = []
            for g in sb["games"]:
                st, gid = g["gameStatus"], g["gameId"]  # 1 scheduled, 2 live, 3 final
                a, h = g["awayTeam"], g["homeTeam"]
                t = local(g.get("gameTimeUTC", ""))
                if st == 2:
                    live = True
                if st == 3 and seen.get(gid) == 2:
                    finals[gid] = int(time.time())  # only finals we watched happen get a FINAL flash
                if seen.get(gid) != st:
                    log(f"state {a['teamTricode']}@{h['teamTricode']} {gid} {seen.get(gid)}->{st} {a['score']}-{h['score']}")
                    seen[gid] = st
                # Box scores are the slow part (one request per game): refresh live ones at most every 2 min.
                if (st == 2 and time.time() - boxAt.get(gid, 0) >= 120) or (st == 3 and gid not in box):
                    lb = leaders(gid)
                    boxAt[gid] = time.time()
                    if lb:
                        box[gid] = lb
                gst = g.get("gameStatusText", "").strip()
                gc = clock(g.get("gameClock", ""))
                if st == 2:
                    # Breaks (halftime, end of quarter) report a 0:00 clock; NBA's own text ("Half", "End Q2") is clearer.
                    status = f"Q{g['period']} {gc}" if gc and gc != "0:00" else (gst or f"Q{g['period']}")
                elif st == 1:
                    status = (t.strftime("%H:%M ") + tz(t)) if t else gst
                else:
                    status = gst
                games.append({"gameId": gid, "status": st, "statusText": status,
                              "away": a["teamTricode"], "home": h["teamTricode"],
                              "awayScore": a["score"], "homeScore": h["score"],
                              "start": (t.strftime("%H:%M ") + tz(t)) if t else "",
                              "url": f"https://www.nba.com/game/{gid}", "leaders": box.get(gid),
                              "finalAt": finals.get(gid)})
                if c["notify"] and fav & {a["teamTricode"], h["teamTricode"]}:
                    if state.get(gid) is not None and state[gid] != st:
                        if st == 2:
                            notify("Tip-off", f"{a['teamTricode']} @ {h['teamTricode']}")
                        elif st == 3:
                            notify("Final", f"{a['teamTricode']} {a['score']}–{h['score']} {h['teamTricode']}")
                    state[gid] = st
            if not games or all(x["status"] == 3 for x in games):
                sched = upcoming(c, sched)
            write("scores.json", {"ok": True, "gameDate": sb.get("gameDate"),
                                  "updated": datetime.now(LOCAL_TZ).strftime("%H:%M:%S %Z"),
                                  "live": live, "games": games, "upcoming": sched.get("upcoming", []),
                                  "donateUrl": str(c.get("donateUrl") or "")})
        except Exception as e:
            log(f"error {type(e).__name__}: {str(e)[:200]}")
            try:
                with open(os.path.join(CACHE, "scores.json")) as f:
                    old = json.load(f)
            except Exception:
                old = {"games": [], "upcoming": []}
            old.update({"ok": False, "error": str(e)[:200], "donateUrl": str(c.get("donateUrl") or "")})
            write("scores.json", old)
        time.sleep(max(10, int(c["liveInterval"] if live else c["idleInterval"])))

if __name__ == "__main__":
    main()
