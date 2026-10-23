// Pure helpers that turn the fetcher cache into bar text.
function parse(text) {
  try { var d = JSON.parse(text); return d && d.games ? d : null } catch (e) { return null }
}
function line(g) {
  if (g.status === 1) return g.away + " @ " + g.home + " " + g.start
  return g.away + " " + g.awayScore + "–" + g.homeScore + " " + g.home + " " + g.statusText
}
function barText(d, idx) {
  if (!d) return "NBA"
  var live = d.games.filter(function (g) { return g.status === 2 })
  if (live.length) return line(live[idx % live.length])
  var next = d.games.filter(function (g) { return g.status === 1 })
  if (next.length) return "Next " + next[0].away + "@" + next[0].home + " " + next[0].start
  if (d.games.length) return line(d.games[idx % d.games.length])
  if (d.upcoming && d.upcoming.length) return "Next " + d.upcoming[0].start
  return "No games"
}
function leaderText(g) {
  if (!g.leaders) return ""
  function f(arr) { return (arr || []).map(function (p) { return p.name + " " + p.pts + "p " + p.reb + "r " + p.ast + "a" }).join(" · ") }
  return g.away + ": " + f(g.leaders.awayTeam) + "\n" + g.home + ": " + f(g.leaders.homeTeam)
}
