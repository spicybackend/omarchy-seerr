// Run with `node test-api.js`; kept as the client URL regression check.
function normalizeBase(value) {
  var url = String(value || "").trim().replace(/\/+$/, "")
  if (!/^https?:\/\//i.test(url)) throw new Error("invalid URL")
  var apiPath = url.indexOf("/api/v1")
  if (apiPath >= 0 && apiPath + 7 === url.length) url = url.substring(0, apiPath)
  return url
}
function apiUrl(baseValue, path) {
  var base = normalizeBase(baseValue)
  return base + (path.indexOf("/api/v1/") === 0 ? path.substring(7) : "/api/v1" + path)
}
function demo() {
  if (apiUrl("https://media.example/seerr/", "/auth/me") !== "https://media.example/seerr/api/v1/auth/me") throw new Error("reverse proxy path")
  if (apiUrl("https://media.example/seerr/api/v1", "/request") !== "https://media.example/seerr/api/v1/request") throw new Error("explicit API path")
  if (apiUrl("http://localhost:5055", "/search?query=The%20Office") !== "http://localhost:5055/api/v1/search?query=The%20Office") throw new Error("default server URL")
  var rejected = false
  try { normalizeBase("not-a-url") } catch (e) { rejected = true }
  if (!rejected) throw new Error("invalid URL accepted")
}
demo()
