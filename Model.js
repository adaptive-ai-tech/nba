// Pure helpers that turn the fetcher cache into bar text.
function parse(text) {
  try { var d = JSON.parse(text); return d && d.games ? d : null } catch (e) { return null }
}
function line(g) {
  return stripLine(g)
}
function barText(d, idx) {
  if (!d) return "NBA"
  var live = d.games.filter(function (g) { return g.status === 2 })
  if (live.length) return line(live[idx % live.length])
  // Upcoming tip-off times live in the tooltip/dropdown only, to keep the bar narrow.
  return ""
}
// Games for the left "strip" instance: every live game, plus games that went final in the last `finalSecs`.
function stripGames(d, nowSecs, finalSecs) {
  if (!d || !d.games) return []
  return d.games.filter(function (g) {
    return g.status === 2 || (g.status === 3 && g.finalAt && nowSecs - g.finalAt < finalSecs)
  })
}
// Tiny period tag for the bar: "Q3", "OT", "HT", "F". Never the clock, tip-off time or date.
function period(g) {
  if (g.status === 3) return "F"
  var t = String(g.statusText || "")
  if (/half/i.test(t)) return "HT"
  var m = t.match(/\b(Q[1-4]|\d?OT\d?)\b/i)
  return m ? m[1].toUpperCase() : ""
}
function stripLine(g) {
  var p = period(g)
  return g.away + " " + g.awayScore + "-" + g.homeScore + " " + g.home + (p ? " " + p : "")
}
// Full details (clock, status, IST start times) for the tooltip only.
function tooltipText(d) {
  if (!d || !d.games) return "NBA scores: waiting for nba-scores.service"
  var rows = d.games.map(function (g) {
    if (g.status === 1) return g.away + " @ " + g.home + "  " + g.start
    return g.away + " " + g.awayScore + "-" + g.homeScore + " " + g.home + "  " + g.statusText + "  (" + g.start + ")"
  })
  return "NBA scores · updated " + (d.updated || "") + (rows.length ? "\n" + rows.join("\n") : "\nNo games today")
}
// All games at once when they fit (<= perPage), otherwise rotate pages of perPage.
function stripText(games, idx, perPage) {
  if (!games.length) return ""
  var pages = Math.ceil(games.length / perPage)
  var p = idx % pages
  return games.slice(p * perPage, p * perPage + perPage).map(stripLine).join(" · ")
}
function leaderText(g) {
  if (!g.leaders) return ""
  function f(arr) { return (arr || []).map(function (p) { return p.name + " " + p.pts + "p " + p.reb + "r " + p.ast + "a" }).join(" · ") }
  return g.away + ": " + f(g.leaders.awayTeam) + "\n" + g.home + ": " + f(g.leaders.homeTeam)
}
