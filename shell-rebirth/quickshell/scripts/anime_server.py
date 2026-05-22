"""
ani-cli Python API
Exposes ani-cli scraping logic as HTTP endpoints.
Run: pip install flask requests && python ani_api.py
"""

import base64
import hashlib
import json
import re
import subprocess
import threading
import time
import urllib.parse
from concurrent.futures import ThreadPoolExecutor, as_completed

import requests
from flask import Flask, jsonify, request

app = Flask(__name__)

AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/121.0"
ALLANIME_REFR = "https://allmanga.to"
ALLANIME_BASE = "allanime.day"
ALLANIME_API = f"https://api.{ALLANIME_BASE}"
# SHA-256 of the hardcoded passphrase, used for AES-256-CTR decryption of "tobeparsed" blobs.
# Mirrors: printf '%s' 'Xot36i3lK3:v1' | openssl dgst -sha256 -binary | od -A n -t x1 | tr -d ' \n'
ALLANIME_KEY = hashlib.sha256(b"Xot36i3lK3:v1").hexdigest()

HEADERS = {
    "User-Agent": AGENT,
    "Referer": ALLANIME_REFR,
}

# Headers specifically for GraphQL POST requests (need Content-Type)
GQL_HEADERS = {
    "User-Agent": AGENT,
    "Referer": ALLANIME_REFR,
    "Content-Type": "application/json",
}

HEX_MAP = {
    "79": "A", "7a": "B", "7b": "C", "7c": "D", "7d": "E", "7e": "F", "7f": "G",
    "70": "H", "71": "I", "72": "J", "73": "K", "74": "L", "75": "M", "76": "N",
    "77": "O", "68": "P", "69": "Q", "6a": "R", "6b": "S", "6c": "T", "6d": "U",
    "6e": "V", "6f": "W", "60": "X", "61": "Y", "62": "Z",
    "59": "a", "5a": "b", "5b": "c", "5c": "d", "5d": "e", "5e": "f", "5f": "g",
    "50": "h", "51": "i", "52": "j", "53": "k", "54": "l", "55": "m", "56": "n",
    "57": "o", "48": "p", "49": "q", "4a": "r", "4b": "s", "4c": "t", "4d": "u",
    "4e": "v", "4f": "w", "40": "x", "41": "y", "42": "z",
    "08": "0", "09": "1", "0a": "2", "0b": "3", "0c": "4", "0d": "5",
    "0e": "6", "0f": "7", "00": "8", "01": "9",
    "15": "-", "16": ".", "67": "_", "46": "~", "02": ":", "17": "/",
    "07": "?", "1b": "#", "63": "[", "65": "]", "78": "@", "19": "!",
    "1c": "$", "1e": "&", "10": "(", "11": ")", "12": "*", "13": "+",
    "14": ",", "03": ";", "05": "=", "1d": "%",
}


def decode_provider_url(encoded: str) -> str:
    """
    Decode the hex-encoded provider URL produced by the shell script's
    `provider_init` sed chain. Each pair of hex chars maps to a character
    via HEX_MAP; anything not in the map is passed through as-is.
    """
    pairs = [encoded[i:i+2] for i in range(0, len(encoded), 2)]
    result = "".join(HEX_MAP.get(p, p) for p in pairs)
    # allanime clock path fix
    result = result.replace("/clock", "/clock.json")
    return result


def gql_post(variables: dict, query: str) -> str:
    """Fire a GraphQL POST request against the allanime API and return raw text.

    The upstream site now requires POST with a JSON body (matching the bash
    script's ``curl -X POST --data '...'`` calls).  The old GET-with-params
    approach no longer works after the Cloudflare / rules change.
    """
    payload = json.dumps({
        "variables": variables,
        "query": query,
    })
    resp = requests.post(
        f"{ALLANIME_API}/api",
        data=payload,
        headers=GQL_HEADERS,
        timeout=15,
    )
    resp.raise_for_status()
    return resp.text


SEARCH_GQL = (
    "query( $search: SearchInput $limit: Int $page: Int "
    "$translationType: VaildTranslationTypeEnumType "
    "$countryOrigin: VaildCountryOriginEnumType ) { "
    "shows( search: $search limit: $limit page: $page "
    "translationType: $translationType countryOrigin: $countryOrigin ) "
    "{ edges { _id name englishName nativeName thumbnail score "
    "availableEpisodes episodeCount __typename } }}"
)


def search_anime(query: str, mode: str = "sub") -> list[dict]:
    """Return list of show dicts including thumbnail, score, and episode counts."""
    variables = {
        "search": {
            "allowAdult": False,
            "allowUnknown": False,
            "query": query,
        },
        "limit": 40,
        "page": 1,
        "translationType": mode,
        "countryOrigin": "ALL",
    }

    payload = json.dumps({
        "variables": variables,
        "query": SEARCH_GQL,
    })
    resp = requests.post(
        f"{ALLANIME_API}/api",
        data=payload,
        headers=GQL_HEADERS,
        timeout=15,
    )
    resp.raise_for_status()

    data = resp.json()
    edges = data.get("data", {}).get("shows", {}).get("edges", [])

    results = []
    seen = set()
    for edge in edges:
        show_id = edge.get("_id")
        if not show_id or show_id in seen:
            continue
        seen.add(show_id)
        available = edge.get("availableEpisodes") or {}
        results.append({
            "id": show_id,
            "name": edge.get("name"),
            "english_name": edge.get("englishName"),
            "native_name": edge.get("nativeName"),
            "thumbnail": edge.get("thumbnail"),
            "score": edge.get("score"),
            "episode_count": edge.get("episodeCount"),
            "available_episodes": {
                "sub": available.get("sub", 0),
                "dub": available.get("dub", 0),
                "raw": available.get("raw", 0),
            },
        })
    return results

EPISODES_LIST_GQL = (
    "query ($showId: String!) { show( _id: $showId ) { _id availableEpisodesDetail }}"
)


def episodes_list(show_id: str, mode: str = "sub") -> list[str]:
    """Return sorted list of available episode strings for a show."""
    payload = json.dumps({
        "variables": {"showId": show_id},
        "query": EPISODES_LIST_GQL,
    })
    resp = requests.post(
        f"{ALLANIME_API}/api",
        data=payload,
        headers=GQL_HEADERS,
        timeout=15,
    )
    resp.raise_for_status()
    raw = resp.text
    m = re.search(r'"' + mode + r'\":\[([0-9.\",]*)\]', raw)
    if not m:
        return []
    eps_raw = m.group(1)
    eps = [e.strip('"') for e in eps_raw.split(",") if e.strip('"')]
    try:
        eps.sort(key=lambda x: float(x))
    except ValueError:
        eps.sort()
    return eps


# ---------------------------------------------------------------------------
# Provider / link extraction
# ---------------------------------------------------------------------------
EPISODE_EMBED_GQL = (
    "query ($showId: String!, $translationType: VaildTranslationTypeEnumType!, "
    "$episodeString: String!) { episode( showId: $showId translationType: $translationType "
    "episodeString: $episodeString ) { episodeString sourceUrls }}"
)

PROVIDER_PATTERNS = {
    "wixmp":      r"Default\s*:([^\n]+)",
    "youtube":    r"Yt-mp4\s*:([^\n]+)",
    "sharepoint": r"S-mp4\s*:([^\n]+)",
    "filemoon":   r"Fm-mp4\s*:([^\n]+)",
    "hianime":    r"Luf-Mp4\s*:([^\n]+)",
}


def _extract_provider_id(resp_normalized: str, pattern: str) -> str | None:
    m = re.search(pattern, resp_normalized)
    if not m:
        return None
    encoded = m.group(1).strip()
    return decode_provider_url(encoded)


def b64url_to_hex(s: str) -> str:
    """Convert a base64url-encoded string to hex, adding padding as needed."""
    pad = {2: "==", 3: "=", 0: "", 1: ""}
    padded = s + pad[len(s) % 4]
    padded = padded.replace("-", "+").replace("_", "/")
    return base64.b64decode(padded).hex()


def get_filemoon_links(path: str) -> list[dict]:
    """
    Fetch and decrypt filemoon provider links.
    Mirrors the shell script's get_filemoon_links() function.
    """
    url = f"https://{ALLANIME_BASE}{path}"
    try:
        resp = requests.get(url, headers=HEADERS, timeout=15)
        resp.raise_for_status()
        raw = resp.text
    except Exception as e:
        return [{"error": str(e), "url": url}]

    try:
        data = json.loads(raw)

        iv = data.get("iv", "")
        payload = data.get("payload", "")
        key_parts = data.get("key_parts", [])

        if len(key_parts) < 2 or not iv or not payload:
            return [{"error": "Missing filemoon decryption fields"}]

        kp1_hex = b64url_to_hex(key_parts[0])
        kp2_hex = b64url_to_hex(key_parts[1])
        key_hex = kp1_hex + kp2_hex
        iv_hex = b64url_to_hex(iv) + "00000002"

        # Decode payload from base64url
        payload_pad = {2: "==", 3: "=", 0: "", 1: ""}
        payload_padded = payload + payload_pad[len(payload) % 4]
        payload_padded = payload_padded.replace("-", "+").replace("_", "/")
        payload_bytes = base64.b64decode(payload_padded)

        # Strip last 16 bytes (auth tag)
        ct_bytes = payload_bytes[:-16]

        result = subprocess.run(
            [
                "openssl", "enc", "-d", "-aes-256-ctr",
                "-K", key_hex,
                "-iv", iv_hex,
                "-nosalt", "-nopad",
            ],
            input=ct_bytes,
            capture_output=True,
            timeout=10,
        )
        plain = result.stdout.decode("utf-8", errors="replace")

        # Parse url/height pairs from decrypted JSON
        links = []
        for chunk in re.split(r"[{}\[\]]", plain):
            # Match either "url":"...","height":N or "height":N,"url":"..."
            m = re.search(r'"url":"([^"]*)".*?"height":(\d+)', chunk)
            if not m:
                m = re.search(r'"height":(\d+).*?"url":"([^"]*)"', chunk)
                if m:
                    height, stream_url = m.group(1), m.group(2)
                else:
                    continue
            else:
                stream_url, height = m.group(1), m.group(2)

            # Unescape unicode sequences
            stream_url = stream_url.replace("\\u0026", "&").replace("\\u003D", "=")
            links.append({"quality": f"{height}p", "url": stream_url, "type": "mp4"})

        links.sort(key=lambda x: int(re.match(r"(\d+)", x.get("quality", "0")).group(1)) if re.match(r"(\d+)", x.get("quality", "0")) else 0, reverse=True)
        return links

    except Exception as e:
        return [{"error": f"Filemoon decryption failed: {e}"}]


def _get_links_from_url(path: str) -> list[dict]:
    """
    Fetch the embed URL and parse out video links.
    Returns list of {quality, url, type} dicts.
    """
    # Don't prepend base domain for absolute URLs
    url = path if path.startswith("http") else f"https://{ALLANIME_BASE}{path}"
    try:
        resp = requests.get(url, headers=HEADERS, timeout=15)
        resp.raise_for_status()
        raw = resp.text
    except Exception as e:
        return [{"error": str(e), "url": url}]

    links = []

    if "repackager.wixmp.com" in raw:
        for m in re.finditer(r'"link":"([^"]*repackager\.wixmp\.com[^"]*)".*?"resolutionStr":"([^"]*)"', raw):
            links.append({"quality": m.group(2), "url": m.group(1), "type": "mp4"})
        return links

    if "master.m3u8" in raw:
        m_url = re.search(r'"url":"([^"]*master\.m3u8[^"]*)"', raw)
        m_refr = re.search(r'"Referer":"([^"]*)"', raw)
        subtitle_m = re.search(r'"subtitles":\[.*?"lang":"en".*?"src":"([^"]*)"', raw)
        referer = m_refr.group(1) if m_refr else ALLANIME_REFR
        subtitle = subtitle_m.group(1) if subtitle_m else None
        if m_url:
            m3u8_url = m_url.group(1)
            try:
                m3u8_resp = requests.get(m3u8_url, headers={**HEADERS, "Referer": referer}, timeout=15)
                m3u8_text = m3u8_resp.text
                base = m3u8_url.rsplit("/", 1)[0] + "/"
                stream_re = re.compile(r'#EXT-X-STREAM-INF[^\n]*RESOLUTION=\d+x(\d+)[^\n]*\n([^\n]+)')
                for sm in stream_re.finditer(m3u8_text):
                    height = sm.group(1)
                    stream_path = sm.group(2).strip()
                    stream_url = stream_path if stream_path.startswith("http") else base + stream_path
                    links.append({
                        "quality": f"{height}p",
                        "url": stream_url,
                        "type": "m3u8",
                        "referer": referer,
                        **({"subtitle": subtitle} if subtitle else {}),
                    })
                if not links:
                    links.append({"quality": "best", "url": m3u8_url, "type": "m3u8", "referer": referer})
            except Exception as e:
                links.append({"quality": "best", "url": m3u8_url, "type": "m3u8",
                               "referer": referer, "parse_error": str(e)})
        return links

    for m in re.finditer(r'"link":"([^"]*)".*?"resolutionStr":"([^"]*)"', raw):
        links.append({"quality": m.group(2), "url": m.group(1), "type": "mp4"})

    # Shell: printf "%s" "$*" | grep -q "tools.fast4speed.rsvp" && printf "Yt >$*"
    # Check the path itself (not the response) for fast4speed/YouTube links
    if "tools.fast4speed.rsvp" in path:
        links.append({"quality": "best", "url": url, "type": "yt", "referer": ALLANIME_REFR})

    return links


def decode_tobeparsed(blob: str) -> dict[str, str]:
    """
    Decrypt the 'tobeparsed' AES-256-CTR blob returned by the allanime API.

    Mirrors the shell script's decode_tobeparsed():
      1. base64-decode the blob
      2. first 12 bytes are the nonce/IV
      3. counter = nonce + b'\\x00\\x00\\x00\\x02'  (matches shell: ctr="${iv}00000002")
      4. decrypt with AES-256-CTR using ALLANIME_KEY
      5. parse the plaintext for sourceUrl / sourceName pairs

    Returns dict of {provider_name: hex-encoded-path} (paths still need
    decode_provider_url() to become usable URLs, exactly like the non-tobeparsed path).
    """
    try:
        data = base64.b64decode(blob)
    except Exception:
        return {}

    # Shell: skip=1 count=12 for IV, skip=13 for ciphertext, exclude last 16 bytes (auth tag)
    iv_bytes = data[1:13]
    ciphertext = data[13:-16]
    ctr_hex = iv_bytes.hex() + "00000002"  # 12-byte nonce + 4-byte counter = 16-byte AES block

    try:
        result = subprocess.run(
            [
                "openssl", "enc", "-d", "-aes-256-ctr",
                "-K", ALLANIME_KEY,
                "-iv", ctr_hex,
                "-nosalt", "-nopad",
            ],
            input=ciphertext,
            capture_output=True,
            timeout=10,
        )
        plain = result.stdout.decode("utf-8", errors="replace")
    except Exception:
        return {}

    # tr '{}' '\n' | sed -nE 's|.*"sourceUrl":"--([^"]*)".*"sourceName":"([^"]*)".*|\2 :\1|p'
    sources: dict[str, str] = {}
    for chunk in re.split(r"[{}]", plain):
        m = re.search(r'"sourceUrl":"--([^"]*)".*"sourceName":"([^"]*)"', chunk)
        if m:
            enc_path, name = m.group(1), m.group(2)
            sources[name] = enc_path  # decoded by decode_provider_url below
    return sources


EPISODE_QUERY_HASH = "d405d0edd690624b66baba3068e0edc3ac90f1597d898a1ec8db4e5c43c00fec"


def get_episode_links(show_id: str, ep_no: str, mode: str = "sub") -> dict:
    """
    Full equivalent of get_episode_url() in the shell script.
    Returns {providers: {name: [links]}, all_links: [...]}
    """
    # Step 1: Try GET with persisted query hash first (mirrors shell's first attempt)
    query_vars = json.dumps({
        "showId": show_id,
        "translationType": mode,
        "episodeString": ep_no,
    })
    query_ext = json.dumps({
        "persistedQuery": {
            "version": 1,
            "sha256Hash": EPISODE_QUERY_HASH,
        }
    })
    get_headers = {
        "User-Agent": AGENT,
        "Referer": "https://youtu-chan.com",
        "Origin": "https://youtu-chan.com",
    }
    try:
        get_resp = requests.get(
            f"{ALLANIME_API}/api",
            params={"variables": query_vars, "extensions": query_ext},
            headers=get_headers,
            timeout=15,
        )
        get_resp.raise_for_status()
        raw = get_resp.text
    except Exception:
        raw = ""

    # Step 2: Fall back to POST if GET response is empty or missing "tobeparsed"
    if not raw or "tobeparsed" not in raw:
        payload = json.dumps({
            "variables": {
                "showId": show_id,
                "translationType": mode,
                "episodeString": ep_no,
            },
            "query": EPISODE_EMBED_GQL,
        })
        resp = requests.post(
            f"{ALLANIME_API}/api",
            data=payload,
            headers=GQL_HEADERS,
            timeout=15,
        )
        resp.raise_for_status()
        raw = resp.text

    # Mirror the shell script's two-branch logic:
    #   if response contains "tobeparsed" → decrypt AES-256-CTR blob
    #   else → parse sourceUrl/sourceName pairs directly from the JSON text
    if '"tobeparsed"' in raw:
        blob_m = re.search(r'"tobeparsed":"([^"]*)"', raw)
        if blob_m:
            enc_sources = decode_tobeparsed(blob_m.group(1))
            sources = {name: decode_provider_url(enc) for name, enc in enc_sources.items()}
        else:
            sources = {}
    else:
        raw_norm = raw.replace("\\u002F", "/").replace("\\|", "")
        source_re = re.compile(r'sourceUrl":"--([^"]+)"[^}]*sourceName":"([^"]+)"')
        sources = {}
        for m in source_re.finditer(raw_norm):
            encoded_url, name = m.group(1), m.group(2)
            sources[name] = decode_provider_url(encoded_url)

    if not sources:
        return {"error": "No sources found for this episode", "raw_snippet": raw[:500]}

    provider_results = {}

    def fetch_provider(name, path):
        # Route filemoon sources to dedicated handler
        if name.lower() in ("fm-mp4", "filemoon") or "Fm-mp4" in name:
            return name, get_filemoon_links(path)
        return name, _get_links_from_url(path)

    with ThreadPoolExecutor(max_workers=6) as pool:
        futures = {pool.submit(fetch_provider, n, p): n for n, p in sources.items()}
        for future in as_completed(futures):
            name, links = future.result()
            provider_results[name] = links

    all_links = []
    for name, links in provider_results.items():
        for link in links:
            # FIX: Only include links that have no "error" key
            if "error" not in link:
                all_links.append({**link, "provider": name})

    def quality_key(x):
        q = x.get("quality", "")
        m = re.match(r"(\d+)", q)
        return int(m.group(1)) if m else 0

    all_links.sort(key=quality_key, reverse=True)

    return {
        "show_id": show_id,
        "episode": ep_no,
        "mode": mode,
        "providers": provider_results,
        "all_links": all_links,
    }


LATEST_QUERY_HASH = "a24c500a1b765c68ae1d8dd85174931f661c71369c89b92b88b75a725afc471c"


def _parse_latest_show(edge: dict) -> dict:
    """
    Normalise a single edge from the latest shows response into a clean dict.
    All fields are optional-safe so partial data never raises KeyError.
    """
    last_ep_info = edge.get("lastEpisodeInfo", {})
    last_ep_date = edge.get("lastEpisodeDate", {})
    available = edge.get("availableEpisodes", {})
    season = edge.get("season") or {}
    aired = edge.get("airedStart") or {}

    def ep_str(mode: str) -> str | None:
        info = last_ep_info.get(mode)
        return info.get("episodeString") if info else None

    def ep_date(mode: str) -> dict | None:
        d = last_ep_date.get(mode)
        return d if d else None

    return {
        "id": edge.get("_id"),
        "name": edge.get("name"),
        "english_name": edge.get("englishName"),
        "native_name": edge.get("nativeName"),
        "type": edge.get("type"),
        "thumbnail": edge.get("thumbnail"),
        "score": edge.get("score"),
        "episode_count": edge.get("episodeCount"),
        "episode_duration_ms": edge.get("episodeDuration"),
        "available_episodes": {
            "sub": available.get("sub", 0),
            "dub": available.get("dub", 0),
            "raw": available.get("raw", 0),
        },
        "last_episode": {
            "sub": ep_str("sub"),
            "dub": ep_str("dub"),
        },
        "last_episode_date": {
            "sub": ep_date("sub"),
            "dub": ep_date("dub"),
        },
        "season": {
            "quarter": season.get("quarter"),
            "year": season.get("year"),
        },
        "aired_start": aired if aired else None,
        "last_update": edge.get("lastUpdateEnd"),
    }


def latest_shows(
    limit: int = 26,
    page: int = 1,
    mode: str = "sub",
    country: str = "ALL",
    search: dict | None = None,
) -> dict:
    """
    Fetch recently-updated shows using the persisted query on the allanime API.

    Parameters
    ----------
    limit   : number of results per page (max ~50 before the API ignores extras)
    page    : page number (1-based)
    mode    : "sub" | "dub" | "raw"
    country : "ALL" | "JP" | "CN" | "KR" etc.
    search  : optional extra search fields (e.g. {"query": "one piece"})

    Returns
    -------
    {
        "page": int,
        "limit": int,
        "total": int,          # total shows in the DB matching the filter
        "count": int,          # number of shows in this response
        "shows": [ ... ]
    }
    """
    variables = {
        "search": search or {},
        "limit": limit,
        "page": page,
        "translationType": mode,
        "countryOrigin": country,
    }

    # Persisted queries still use GET with extensions param (hash-based, no query body)
    params = {
        "variables": json.dumps(variables),
        "extensions": json.dumps({
            "persistedQuery": {
                "version": 1,
                "sha256Hash": LATEST_QUERY_HASH,
            }
        }),
    }

    resp = requests.get(
        f"{ALLANIME_API}/api",
        params=params,
        headers=HEADERS,
        timeout=15,
    )
    resp.raise_for_status()

    data = resp.json()

    shows_data = (
        data.get("data", {}).get("shows", {})
        if isinstance(data, dict)
        else {}
    )

    total = shows_data.get("pageInfo", {}).get("total", 0)
    edges = shows_data.get("edges", [])

    return {
        "page": page,
        "limit": limit,
        "total": total,
        "count": len(edges),
        "shows": [_parse_latest_show(e) for e in edges],
    }

POPULAR_QUERY_HASH = "60f50b84bb545fa25ee7f7c8c0adbf8f5cea40f7b1ef8501cbbff70e38589489"


def _parse_popular_show(rec: dict) -> dict:
    """
    Normalise a single recommendation entry from the popular shows response.
    Each entry has an `anyCard` (show details) and a `pageStatus` (view stats).
    """
    card = rec.get("anyCard") or {}
    status = rec.get("pageStatus") or {}

    last_ep_date = card.get("lastEpisodeDate") or {}
    available = card.get("availableEpisodes") or {}
    aired = card.get("airedStart") or {}

    def ep_date(mode: str) -> dict | None:
        d = last_ep_date.get(mode)
        return d if d else None

    return {
        "id": card.get("_id"),
        "name": card.get("name"),
        "english_name": card.get("englishName"),
        "native_name": card.get("nativeName"),
        "thumbnail": card.get("thumbnail"),
        "score": card.get("score"),
        "available_episodes": {
            "sub": available.get("sub", 0),
            "dub": available.get("dub", 0),
            "raw": available.get("raw", 0),
        },
        "last_episode_date": {
            "sub": ep_date("sub"),
            "dub": ep_date("dub"),
        },
        "aired_start": aired if aired else None,
        "views": {
            "total": status.get("views"),
            "range": status.get("rangeViews"),
        },
        "is_manga": status.get("isManga"),
    }


def popular_shows(
    size: int = 20,
    page: int = 1,
    date_range: int = 1,
    allow_adult: bool = False,
    allow_unknown: bool = False,
) -> dict:
    """
    Fetch currently popular anime using the queryPopular persisted query.

    Parameters
    ----------
    size          : results per page (default 20)
    page          : page number, 1-based (default 1)
    date_range    : view-count window in days (default 1 = last 24 h)
    allow_adult   : include adult titles (default False)
    allow_unknown : include unknown-status titles (default False)

    Returns
    -------
    {
        "page": int,
        "size": int,
        "date_range": int,
        "total": int,
        "count": int,
        "shows": [ ... ]
    }
    """
    variables = {
        "type": "anime",
        "size": size,
        "dateRange": date_range,
        "page": page,
        "allowAdult": allow_adult,
        "allowUnknown": allow_unknown,
    }

    # Persisted queries still use GET with extensions param (hash-based, no query body)
    params = {
        "variables": json.dumps(variables),
        "extensions": json.dumps({
            "persistedQuery": {
                "version": 1,
                "sha256Hash": POPULAR_QUERY_HASH,
            }
        }),
    }

    resp = requests.get(
        f"{ALLANIME_API}/api",
        params=params,
        headers=HEADERS,
        timeout=15,
    )
    resp.raise_for_status()

    data = resp.json() if isinstance(resp.json(), dict) else {}
    popular_data = data.get("data", {}).get("queryPopular", {})

    total = popular_data.get("total", 0)
    recommendations = popular_data.get("recommendations", [])

    return {
        "page": page,
        "size": size,
        "date_range": date_range,
        "total": total,
        "count": len(recommendations),
        "shows": [_parse_popular_show(r) for r in recommendations],
    }

def next_ep_countdown(query: str) -> list[dict]:
    """Fetch next episode countdown data from animeschedule.net."""
    base = "https://animeschedule.net"
    q = query.replace(" ", "+")
    try:
        r = requests.get(f"{base}/api/v3/anime", params={"q": q}, headers=HEADERS, timeout=15)
        r.raise_for_status()
        raw = r.text
    except Exception as e:
        return [{"error": str(e)}]

    routes = re.findall(r'"route":"([^"]+)"', raw)
    results = []
    for route in routes:
        try:
            page = requests.get(f"{base}/anime/{route}", headers=HEADERS, timeout=15)
            text = page.text
            next_raw = re.search(r'countdown-time-raw"[^>]*datetime="([^"]*)"', text)
            next_sub = re.search(r'countdown-time"[^>]*datetime="([^"]*)"', text)
            eng_title = re.search(r'english-title">([^<]*)<', text)
            jp_title = re.search(r'main-title"[^>]*>([^<]*)<', text)
            results.append({
                "route": route,
                "english_title": eng_title.group(1) if eng_title else None,
                "japanese_title": jp_title.group(1) if jp_title else None,
                "next_raw_release": next_raw.group(1) if next_raw else None,
                "next_sub_release": next_sub.group(1) if next_sub else None,
                "status": "Ongoing" if next_raw else "Finished",
            })
        except Exception as e:
            results.append({"route": route, "error": str(e)})
    return results


@app.route("/")
def index():
    return jsonify({
        "name": "ani-cli API",
        "endpoints": {
            "GET /search":  "Search for anime. Params: q (required), mode (sub|dub, default sub)",
            "GET /episodes": "List episodes for a show. Params: id (required), mode (sub|dub, default sub)",
            "GET /links":   "Get stream links for an episode. Params: id, ep, mode. Optional: quality (e.g. 1080p, 720p, best, worst)",
            "GET /latest":  (
                "Recently-updated shows. Params: "
                "limit (int, default 26), page (int, default 1), "
                "mode (sub|dub|raw, default sub), "
                "country (ALL|JP|CN|KR…, default ALL), "
                "q (optional search query string)"
            ),
            "GET /popular": (
                "Currently popular anime ranked by views. Params: "
                "size (int, default 20), page (int, default 1), "
                "date_range (int days, default 1), "
                "allow_adult (bool, default false), allow_unknown (bool, default false)"
            ),
            "GET /nextep":  "Next episode countdown. Params: q (required)",
            "GET /health":  "Health check",
        },
        "examples": {
            "search":           "/search?q=blue+lock&mode=sub",
            "episodes":         "/episodes?id=<show_id>&mode=sub",
            "links":            "/links?id=<show_id>&ep=1&mode=sub",
            "links_quality":    "/links?id=<show_id>&ep=5&mode=sub&quality=720p",
            "latest":           "/latest?limit=26&page=1&mode=sub",
            "latest_dub":       "/latest?mode=dub&limit=10",
            "latest_search":    "/latest?q=one+piece",
            "latest_kr":        "/latest?country=KR&limit=20",
            "popular":          "/popular",
            "popular_weekly":   "/popular?date_range=7&size=50",
            "popular_page2":    "/popular?page=2",
            "nextep":           "/nextep?q=one+piece",
        },
    })


@app.route("/health")
def health():
    return jsonify({"status": "ok"})


@app.route("/search")
def search_route():
    """
    GET /search?q=<query>&mode=sub|dub
    Returns list of matching anime with id, title, episode count.
    """
    q = request.args.get("q", "").strip()
    mode = request.args.get("mode", "sub").strip()
    if not q:
        return jsonify({"error": "Missing required param: q"}), 400
    if mode not in ("sub", "dub"):
        return jsonify({"error": "mode must be 'sub' or 'dub'"}), 400
    try:
        results = search_anime(q, mode)
    except Exception as e:
        return jsonify({"error": str(e)}), 500
    return jsonify({"query": q, "mode": mode, "count": len(results), "results": results})


@app.route("/episodes")
def episodes_route():
    """
    GET /episodes?id=<show_id>&mode=sub|dub
    Returns sorted list of available episodes.
    """
    show_id = request.args.get("id", "").strip()
    mode = request.args.get("mode", "sub").strip()
    if not show_id:
        return jsonify({"error": "Missing required param: id"}), 400
    try:
        eps = episodes_list(show_id, mode)
    except Exception as e:
        return jsonify({"error": str(e)}), 500
    return jsonify({"id": show_id, "mode": mode, "count": len(eps), "episodes": eps})


@app.route("/links")
def links_route():
    """
    GET /links?id=<show_id>&ep=<episode>&mode=sub|dub&quality=best
    Returns stream links. quality can be: best, worst, 1080p, 720p, 480p, 360p,
    or any string to grep for.
    """
    show_id = request.args.get("id", "").strip()
    ep_no = request.args.get("ep", "").strip()
    mode = request.args.get("mode", "sub").strip()
    quality = request.args.get("quality", "best").strip()

    if not show_id:
        return jsonify({"error": "Missing required param: id"}), 400
    if not ep_no:
        return jsonify({"error": "Missing required param: ep"}), 400

    try:
        data = get_episode_links(show_id, ep_no, mode)
    except Exception as e:
        return jsonify({"error": str(e)}), 500

    if "error" in data:
        return jsonify(data), 404

    all_links = data.get("all_links", [])
    if quality == "best":
        selected = all_links[0] if all_links else None
    elif quality == "worst":
        numeric = [l for l in all_links if re.match(r"\d+", l.get("quality", ""))]
        selected = numeric[-1] if numeric else (all_links[-1] if all_links else None)
    else:
        matched = [l for l in all_links if quality in l.get("quality", "")]
        selected = matched[0] if matched else (all_links[0] if all_links else None)

    # FIX: If selected has an error (shouldn't happen after filtering, but guard anyway)
    if selected and "error" in selected:
        selected = None

    data["selected"] = selected
    data["requested_quality"] = quality
    return jsonify(data)


@app.route("/latest")
def latest_route():
    """
    GET /latest
    Query params:
      limit   (int, default 26)   — results per page
      page    (int, default 1)    — page number
      mode    (str, default sub)  — sub | dub | raw
      country (str, default ALL)  — ALL | JP | CN | KR | …
      q       (str, optional)     — filter by title query
    """
    try:
        limit = int(request.args.get("limit", 26))
        page  = int(request.args.get("page",  1))
    except ValueError:
        return jsonify({"error": "limit and page must be integers"}), 400

    mode    = request.args.get("mode",    "sub").strip()
    country = request.args.get("country", "ALL").strip()
    q       = request.args.get("q",       "").strip()

    if mode not in ("sub", "dub", "raw"):
        return jsonify({"error": "mode must be 'sub', 'dub', or 'raw'"}), 400

    if limit < 1 or limit > 100:
        return jsonify({"error": "limit must be between 1 and 100"}), 400

    if page < 1:
        return jsonify({"error": "page must be >= 1"}), 400

    # Build optional search dict only if a query was supplied
    search_dict = {"query": q} if q else {}

    try:
        result = latest_shows(
            limit=limit,
            page=page,
            mode=mode,
            country=country,
            search=search_dict if search_dict else None,
        )
    except requests.HTTPError as e:
        return jsonify({"error": f"Upstream API error: {e}"}), 502
    except Exception as e:
        return jsonify({"error": str(e)}), 500

    return jsonify(result)


@app.route("/popular")
def popular_route():
    """
    GET /popular
    Query params:
      size          (int,  default 20)    — results per page
      page          (int,  default 1)     — page number
      date_range    (int,  default 1)     — view-count window in days (1=24h, 7=week, 30=month)
      allow_adult   (bool, default false) — include adult titles
      allow_unknown (bool, default false) — include unknown-status titles
    """
    try:
        size       = int(request.args.get("size",       20))
        page       = int(request.args.get("page",        1))
        date_range = int(request.args.get("date_range",  1))
    except ValueError:
        return jsonify({"error": "size, page, and date_range must be integers"}), 400

    def _bool(param: str, default: bool = False) -> bool:
        v = request.args.get(param, "").lower()
        if v in ("1", "true", "yes"):
            return True
        if v in ("0", "false", "no"):
            return False
        return default

    allow_adult   = _bool("allow_adult",   False)
    allow_unknown = _bool("allow_unknown", False)

    if size < 1 or size > 100:
        return jsonify({"error": "size must be between 1 and 100"}), 400
    if page < 1:
        return jsonify({"error": "page must be >= 1"}), 400
    if date_range < 1:
        return jsonify({"error": "date_range must be >= 1"}), 400

    try:
        result = popular_shows(
            size=size,
            page=page,
            date_range=date_range,
            allow_adult=allow_adult,
            allow_unknown=allow_unknown,
        )
    except requests.HTTPError as e:
        return jsonify({"error": f"Upstream API error: {e}"}), 502
    except Exception as e:
        return jsonify({"error": str(e)}), 500

    return jsonify(result)


@app.route("/nextep")
def nextep_route():
    """
    GET /nextep?q=<anime name>
    Returns countdown data for the next episode.
    """
    q = request.args.get("q", "").strip()
    if not q:
        return jsonify({"error": "Missing required param: q"}), 400
    try:
        results = next_ep_countdown(q)
    except Exception as e:
        return jsonify({"error": str(e)}), 500
    return jsonify({"query": q, "results": results})


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="ani-cli Python API server")
    parser.add_argument("--host", default="0.0.0.0", help="Host to bind (default: 0.0.0.0)")
    parser.add_argument("--port", type=int, default=5050, help="Port to listen on (default: 5050)")
    parser.add_argument("--debug", action="store_true", help="Enable Flask debug mode")
    args = parser.parse_args()

    print(f"""
  ┌─────────────────────────────────────────┐
  │          ani-cli Python API             │
  │  http://{args.host}:{args.port}              │
  ├─────────────────────────────────────────┤
  │  GET /search?q=blue+lock               │
  │  GET /episodes?id=<id>                 │
  │  GET /links?id=<id>&ep=1              │
  │  GET /latest                           │
  │  GET /latest?mode=dub&country=JP       │
  │  GET /popular                          │
  │  GET /popular?date_range=7&size=50     │
  │  GET /nextep?q=one+piece              │
  │  GET /                (docs)           │
  └─────────────────────────────────────────┘
""")
    app.run(host=args.host, port=args.port, debug=args.debug)