// Run with `node test-api.js`; pure boundary-model smoke tests for request URLs and choice serialization.
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
function configForChoice(serverUrl, key, choice) {
  var config = { serverUrl: serverUrl }
  if (choice === "plaintext") config.apiKey = key
  return JSON.stringify(config)
}
function demo() {
  if (apiUrl("https://media.example/seerr/", "/auth/me") !== "https://media.example/seerr/api/v1/auth/me") throw new Error("reverse proxy path")
  if (apiUrl("https://media.example/seerr/api/v1", "/request") !== "https://media.example/seerr/api/v1/request") throw new Error("explicit API path")
  if (apiUrl("http://localhost:5055", "/search?query=The%20Office") !== "http://localhost:5055/api/v1/search?query=The%20Office") throw new Error("default server URL")
  var rejected = false
  try { normalizeBase("not-a-url") } catch (e) { rejected = true }
  if (!rejected) throw new Error("invalid URL accepted")

  var keyring = JSON.parse(configForChoice("https://media.example", "key", "keyring"))
  var session = JSON.parse(configForChoice("https://media.example", "key", "none"))
  var plaintext = JSON.parse(configForChoice("https://media.example", "key", "plaintext"))
  if ("apiKey" in keyring || "apiKey" in session) throw new Error("non-plaintext choice stored key")
  if (plaintext.apiKey !== "key") throw new Error("plaintext choice missing key")
}
demo()
