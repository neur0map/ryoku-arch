function nameForPath(path) {
  return String(path || "").split("/").pop().replace(/\.[^/.]+$/, "")
}
function labelForPath(path) {
  return nameForPath(path).replace(/[-_]+/g, " ").replace(/\b\w/g, function(m) { return m.toUpperCase() })
}
function loadRows(rows) {
  var images = [], seen = {}, paths = String(rows || "").split("\n")
  for (var i = 0; i < paths.length; i++) {
    var row = paths[i]; if (!row) continue
    var columns = row.split("\t"), path = columns[0]; if (!path) continue
    var fileName = path.split("/").pop(); if (seen[fileName]) continue
    seen[fileName] = true
    images.push({
      filePath: path,
      fileName: fileName,
      thumbnailPath: columns[1] || path,
      // optional 3rd column (theme scan only): the theme directory, used to
      // lazily fetch author/palette for the focused theme without slowing the scan
      dir: columns[2] || ""
    })
  }
  return images
}
function itemMatches(images, index, filterText) {
  if (!Array.isArray(images) || index < 0 || index >= images.length) return false
  var needle = String(filterText || "").toLowerCase(); if (!needle) return true
  var path = String(images[index].filePath || "")
  return nameForPath(path).toLowerCase().indexOf(needle) !== -1
      || labelForPath(path).toLowerCase().indexOf(needle) !== -1
}
function matchCount(images, filterText) {
  if (!Array.isArray(images)) return 0
  if (!String(filterText || "")) return images.length
  var c = 0
  for (var i = 0; i < images.length; i++) if (itemMatches(images, i, filterText)) c++
  return c
}
function firstMatchingIndex(images, filterText) {
  for (var i = 0; i < images.length; i++) if (itemMatches(images, i, filterText)) return i
  return -1
}
function filteredPosition(images, index, filterText) {
  if (!filterText) return index
  var pos = 0
  for (var i = 0; i < index; i++) if (itemMatches(images, i, filterText)) pos++
  return pos
}
function selectedFilteredPosition(images, selectedIndex, filterText) {
  if (!filterText) return selectedIndex
  return itemMatches(images, selectedIndex, filterText) ? filteredPosition(images, selectedIndex, filterText) : 0
}
function indexForSelectedImage(images, selectedImage) {
  for (var i = 0; i < images.length; i++) if (images[i].filePath === selectedImage) return i
  return 0
}
function nextSelectedIndexForFilter(images, selectedIndex, filterText) {
  if (itemMatches(images, selectedIndex, filterText)) return selectedIndex
  return firstMatchingIndex(images, filterText)
}
