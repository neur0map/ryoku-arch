.pragma library

// Fuzzy, field-weighted ranking for the Control Center's settings search.
// Ported from Shibumi-Shell's SearchEngine.js: an ordered-subsequence fuzzy
// match with per-field weights, direct-match-first then a fuzzy fallback for
// tokens of two or more characters. `ranked(entries, query, limit)` returns the
// best-matching entries; `ghostText(query, target)` builds the type-ahead hint.
//
// Entry shape (see ControlCenter.qml): { id, name, route, category, searchTags,
// description }. Missing fields simply never match — the scorer skips them.

function normalize(value) {
  return String(value || "").trim().toLocaleLowerCase()
}

function words(value) {
  return normalize(value).split(/[^a-z0-9@._+-]+/).filter(Boolean)
}

function fuzzyScore(queryValue, candidateValue) {
  const query = normalize(queryValue)
  const candidate = normalize(candidateValue)
  if (query === "" || candidate === "") return Number.POSITIVE_INFINITY
  const contiguous = candidate.indexOf(query)
  if (contiguous >= 0) return contiguous
  let previous = -1
  let gaps = 0
  for (let index = 0; index < query.length; index++) {
    const position = candidate.indexOf(query.charAt(index), previous + 1)
    if (position < 0) return Number.POSITIVE_INFINITY
    if (previous >= 0) gaps += position - previous - 1
    previous = position
  }
  return 100 + gaps
}

function uniqueStrings(values) {
  const result = []
  for (let index = 0; index < values.length; index++) {
    const value = String(values[index] || "").trim()
    if (value !== "" && result.indexOf(value) < 0) result.push(value)
  }
  return result
}

function entryTags(entry) {
  const tags = Array.isArray(entry.searchTags) ? entry.searchTags : []
  return uniqueStrings(tags.concat(
    Array.isArray(entry.kinds) ? entry.kinds : []))
}

function primaryEntryFields(entry) {
  return [
    { value: entry.name, weight: 0 },
    { value: entry.id, weight: 7 },
    { value: entry.provider, weight: 12 },
    { value: entry.author, weight: 15 },
    { value: entry.category, weight: 17 },
    { value: entryTags(entry).join(" "), weight: 20 }
  ]
}

function entryFields(entry, includeDescription) {
  const fields = primaryEntryFields(entry)
  if (includeDescription === true)
    fields.push({ value: entry.description, weight: 28 })
  return fields
}

function directTokenScore(token, candidateValue) {
  const candidate = normalize(candidateValue)
  if (candidate === "") return Number.POSITIVE_INFINITY
  const position = candidate.indexOf(token)
  if (position >= 0) return position
  if (token.length > 1) return Number.POSITIVE_INFINITY
  const candidates = words(candidate)
  for (let index = 0; index < candidates.length; index++) {
    if (candidates[index].startsWith(token)) return index
  }
  return Number.POSITIVE_INFINITY
}

function directEntryScore(entry, queryValue, includeDescription) {
  const tokens = words(queryValue)
  if (tokens.length === 0) return 0
  const fields = entryFields(entry, includeDescription)
  let total = 0
  for (let tokenIndex = 0; tokenIndex < tokens.length; tokenIndex++) {
    let best = Number.POSITIVE_INFINITY
    for (let fieldIndex = 0; fieldIndex < fields.length; fieldIndex++) {
      const score = directTokenScore(
        tokens[tokenIndex], fields[fieldIndex].value)
      best = Math.min(best, score + fields[fieldIndex].weight)
    }
    if (!Number.isFinite(best)) return Number.POSITIVE_INFINITY
    total += best
  }
  const query = normalize(queryValue)
  const name = normalize(entry.name)
  if (name === query) total -= 30
  else if (name.startsWith(query)) total -= 12
  return total
}

function fuzzyEntryScore(entry, queryValue, includeDescription) {
  const tokens = words(queryValue)
  if (tokens.length === 0) return 0
  const fields = entryFields(entry, includeDescription)
  let total = 0
  for (let tokenIndex = 0; tokenIndex < tokens.length; tokenIndex++) {
    if (tokens[tokenIndex].length < 2) return Number.POSITIVE_INFINITY
    let best = Number.POSITIVE_INFINITY
    for (let fieldIndex = 0; fieldIndex < fields.length; fieldIndex++) {
      const score = fuzzyScore(tokens[tokenIndex], fields[fieldIndex].value)
      best = Math.min(best, score + fields[fieldIndex].weight)
    }
    if (!Number.isFinite(best)) return Number.POSITIVE_INFINITY
    total += best
  }
  return total
}

function sortMatches(matches) {
  return matches.sort(function(left, right) {
    return left.score - right.score
      || String(left.entry.name || left.entry.id || "").localeCompare(
        String(right.entry.name || right.entry.id || ""))
  })
}

function collectMatches(source, query, scorer, includeDescription) {
  const matches = []
  for (let index = 0; index < source.length; index++) {
    const score = scorer(source[index], query, includeDescription)
    if (Number.isFinite(score))
      matches.push({ entry: source[index], score: score })
  }
  return matches
}

function unwrap(matches) {
  return sortMatches(matches).map(function(match) {
    return match.entry
  })
}

function filterAndRank(entries, queryValue) {
  const source = Array.isArray(entries) ? entries : []
  const query = normalize(queryValue)
  if (query === "") return source.slice()
  // Prefer intentional catalog metadata (name/id/tags/category). Free-form
  // descriptions remain a fallback so relational wording does not pollute a
  // direct search for a specific control.
  const primaryDirect = collectMatches(source, query, directEntryScore, false)
  if (primaryDirect.length > 0) return unwrap(primaryDirect)
  const expandedDirect = collectMatches(source, query, directEntryScore, true)
  if (expandedDirect.length > 0) return unwrap(expandedDirect)
  const primaryFuzzy = collectMatches(source, query, fuzzyEntryScore, false)
  if (primaryFuzzy.length > 0) return unwrap(primaryFuzzy)
  const expandedFuzzy = collectMatches(source, query, fuzzyEntryScore, true)
  return unwrap(expandedFuzzy)
}

// Public: best-matching entries for `query`, capped at `limit` (0/absent = all).
function ranked(entries, queryValue, limitValue) {
  const ordered = filterAndRank(entries, queryValue)
  const limit = Math.floor(Number(limitValue))
  if (Number.isFinite(limit) && limit > 0 && ordered.length > limit)
    return ordered.slice(0, limit)
  return ordered
}

function completionTarget(target) {
  if (!target) return ""
  return String(target.value || target.label || target.name || target)
}

// Type-ahead hint: if the target begins with what was typed, show the whole
// target (grey completion behind the caret); otherwise show `query → target`.
function ghostText(queryValue, target) {
  const query = String(queryValue || "")
  const goal = completionTarget(target)
  if (query === "" || goal === "") return ""
  const queryLower = query.toLocaleLowerCase()
  const goalLower = goal.toLocaleLowerCase()
  return goalLower.startsWith(queryLower) ? goal : query + "  \u2192 " + goal
}
