// ryoku-canvas: relays the current track's Spotify Canvas to the Ryoku shell.
//
// Spotify's token endpoint is bot-gated, so the shell daemon (ipc/music.go)
// cannot resolve Canvas itself. This extension runs inside the (spicetified)
// Spotify client, where a valid session token exists, resolves the Canvas from
// the same `canvaz-cache` endpoint the desktop client uses, and POSTs the url
// to the daemon's loopback relay. The desktop music widget, with Backdrop set
// to "Spotify Canvas", then plays that loop per song. The flatpak client shares
// the host network namespace, so 127.0.0.1 reaches the daemon.
//
// Notes learned the hard way:
//   * the token is Spicetify.Platform.Session.accessToken (the AuthorizationAPI
//     `_tokenProvider` key is not callable);
//   * the relay POST must be a CORS-"simple" request (no-cors + text/plain);
//   * at cold start the session token is briefly empty, so a fetch is only
//     cached once it actually succeeds and the relay is (re)sent every poll --
//     that survives a warming token and a daemon restart both;
//   * the request is a hand-encoded protobuf so nothing loads from a CDN, and
//     the url is scraped from the protobuf response by pattern.
(function ryokuCanvas() {
  const RELAY = "http://127.0.0.1:47615/canvas";

  function varint(n) {
    const out = [];
    for (;;) {
      let b = n & 0x7f;
      n >>>= 7;
      out.push(n ? b | 0x80 : b);
      if (!n) break;
    }
    return out;
  }
  // EntityCanvazRequest { entities = 1 : [ Entity { entityUri = 1 } ] }
  function encodeRequest(uri) {
    const u = Array.from(new TextEncoder().encode(uri));
    const entity = [0x0a, ...varint(u.length), ...u];
    const req = [0x0a, ...varint(entity.length), ...entity];
    return new Uint8Array(req);
  }

  let spclient = "";
  async function host() {
    if (spclient) return spclient;
    try {
      const r = await fetch("https://apresolve.spotify.com/?type=spclient").then((x) => x.json());
      spclient = (r.spclient && r.spclient[0]) || "";
    } catch (e) {}
    return spclient || "gew1-spclient.spotify.com:443";
  }
  function token() {
    return (Spicetify.Platform.Session && Spicetify.Platform.Session.accessToken) || "";
  }
  // returns the canvas url, "" for a track with none, or null on a transient
  // error (no token yet, network) so the caller retries instead of caching it.
  async function canvasFor(uri) {
    const t = token();
    if (!t) return null;
    try {
      const res = await fetch("https://" + (await host()) + "/canvaz-cache/v0/canvases", {
        method: "POST",
        headers: { Authorization: "Bearer " + t, "Content-Type": "application/x-protobuf" },
        body: encodeRequest(uri),
      });
      if (!res.ok) return null;
      const buf = new Uint8Array(await res.arrayBuffer());
      let s = "";
      for (let i = 0; i < buf.length; i++) s += String.fromCharCode(buf[i]);
      const m = s.match(/https?:\/\/[\x21-\x7e]+?\.(mp4|gif|jpg|jpeg|png)/);
      return m ? m[0] : "";
    } catch (e) {
      return null;
    }
  }

  const cache = {}; // uri -> confirmed canvas url ("" = confirmed none)
  async function report() {
    const item = Spicetify.Player && Spicetify.Player.data && Spicetify.Player.data.item;
    const uri = item && item.uri;
    if (!uri) return;
    if (!(uri in cache)) {
      const r = await canvasFor(uri);
      if (r !== null) cache[uri] = r; // cache only confirmed results
    }
    try {
      // no-cors + text/plain keeps this a "simple" request; re-sent each poll so
      // it also repopulates the daemon after a shell restart.
      await fetch(RELAY, {
        method: "POST",
        mode: "no-cors",
        headers: { "Content-Type": "text/plain" },
        body: JSON.stringify({ uri: uri, url: cache[uri] || "" }),
      });
    } catch (e) {}
  }

  function boot() {
    if (!(window.Spicetify && Spicetify.Player && Spicetify.Player.addEventListener &&
          Spicetify.Platform && Spicetify.Platform.Session)) {
      setTimeout(boot, 500);
      return;
    }
    Spicetify.Player.addEventListener("songchange", report);
    setInterval(report, 3000);
    report();
  }
  boot();
})();
