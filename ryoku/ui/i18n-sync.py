#!/usr/bin/env python3
"""Ryoku i18n sync: keep the per-language translation files current from English.

A developer only ever writes English (wrapped in `I18n.tr("...")`, or as a hub
schema label/desc/group). This tool does the rest:

  extract  scan the tree for every English UI string -> translations/en.json
  sync     for each target language, translate ONLY the strings it is missing
           (keeping what is already translated and any human overrides), so a
           normal update translates a handful of new strings, never the file.

Backend is Google's keyless endpoint, so this runs in CI or locally with no
secret. Placeholders (%1, %2, ...) are shielded so they survive translation, and
overrides/<lang>.json always wins, so a human fix is never overwritten.

  python3 i18n-sync.py extract
  python3 i18n-sync.py sync            # all targets
  python3 i18n-sync.py sync es fr      # a subset
"""

import json
import os
import re
import sys
import time
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
TRANS = os.path.join(HERE, "translations")
OVERRIDES = os.path.join(TRANS, "overrides")

# file name -> Google target code. "pt" is Brazilian on the endpoint and "pt-PT"
# is European, so the generic "pt" file takes European and "pt_BR" Brazilian.
TARGETS = {"es": "es", "fr": "fr", "pt": "pt-PT", "pt_BR": "pt"}

QML_ROOT = os.path.join(REPO, "ryoku")
SCHEMA_DIR = os.path.join(REPO, "ryoku", "hub", "quickshell", "schema")

TR_CALL = re.compile(r"""I18n\.tr\(\s*(["'])((?:\\.|(?!\1).)*)\1""")
SCHEMA_FIELD = re.compile(r'"(?:tab|label|desc|group)"\s*:\s*"((?:\\.|[^"\\])*)"')

# shield %1..%9 as private-use codepoints so the translator leaves them intact.
PU_BASE = 0xE000


def _unescape(lit):
    """Turn a source string literal body into its runtime value (\\n, \\" ...)."""
    try:
        return json.loads('"' + lit.replace('"', '\\"') + '"')
    except Exception:
        return lit


# schema .js for full-bleed pages is documentation, not rendered copy: its
# label/desc/group hold engineering notes, not UI. These markers drop that noise
# so only real, displayed strings become translation keys.
NOISE = ("SettingSection", "PluginPlacementEditor", "disclosure)", "readout)",
         "Repeater", "bespoke", "transient page state", "(no ", "(none", "(header",
         "(action", "(install", "(bottom", "(plugin", "(embedded", "(field")


def _noise(s):
    return s.startswith("(") or any(n in s for n in NOISE)


def _brand(s):
    return any(ord(c) >= 0x3000 for c in s)          # CJK / kana / kanji

OPTS_ARR = re.compile(r'"opts"\s*:\s*\[([^\]]*)\]', re.S)
PAGE_OPTS = re.compile(r'\boptions\s*:\s*\[([^\]]*)\]', re.S)   # inline page option arrays
STR_LIT = re.compile(r'"((?:\\.|[^"\\])*)"')
# data-model display fields, key quoted ("label":) or not (label:).
MODEL_LABEL = re.compile(r'\b(?:label|name|desc|altLabel)"?\s*:\s*"((?:\\.|[^"\\])*)"')


def extract_keys():
    keys = set()
    for root, _, files in os.walk(QML_ROOT):
        for f in files:
            if not f.endswith(".qml"):
                continue
            text = open(os.path.join(root, f), encoding="utf-8", errors="ignore").read()
            for _, body in TR_CALL.findall(text):
                s = _unescape(body).strip()
                if s:
                    keys.add(s)          # explicit tr() calls are always kept
    if os.path.isdir(SCHEMA_DIR):
        for f in os.listdir(SCHEMA_DIR):
            if not f.endswith(".js"):
                continue
            text = open(os.path.join(SCHEMA_DIR, f), encoding="utf-8", errors="ignore").read()
            for body in SCHEMA_FIELD.findall(text):
                s = _unescape(body).strip()
                if s and not _noise(s):
                    keys.add(s)
            # seg/chips option values (the controls translate their display)
            for arr in OPTS_ARR.findall(text):
                for body in STR_LIT.findall(arr):
                    s = _unescape(body).strip()
                    if s and not _noise(s) and not _brand(s):
                        keys.add(s)
    # the Hub rail's nav + group names are data-driven, so I18n.tr() wraps them by
    # variable, not literal; pull them from Hub.qml's groups array (unquoted
    # `name: "..."`, so the quoted-key kanji jpName map is not matched).
    hub = os.path.join(REPO, "ryoku", "hub", "quickshell", "Hub.qml")
    if os.path.isfile(hub):
        text = open(hub, encoding="utf-8", errors="ignore").read()
        for body in re.findall(r'\bname:\s*"([^"]+)"', text):
            s = body.strip()
            if s and not _noise(s):
                keys.add(s)
    # each page declares its title/eyebrow/blurb as string properties, wrapped by
    # variable at render, so pull the literals from the page files.
    pages = os.path.join(REPO, "ryoku", "hub", "quickshell", "pages")
    if os.path.isdir(pages):
        for f in os.listdir(pages):
            if not f.endswith(".qml"):
                continue
            text = open(os.path.join(pages, f), encoding="utf-8", errors="ignore").read()
            for body in re.findall(r'\bp(?:Title|Eyebrow|Blurb)\s*:\s*"((?:\\.|[^"\\])*)"', text):
                s = _unescape(body).strip()
                if s and not _noise(s):
                    keys.add(s)
            # data-model display labels ({key, label} arrays, FnCard names, ...);
            # the controls / render sites translate them, brand kana excluded.
            for body in MODEL_LABEL.findall(text):
                s = _unescape(body).strip()
                if s and not _noise(s) and not _brand(s):
                    keys.add(s)
            # inline option arrays in a page (options: ["FOLLOW","LIGHT",...]);
            # a control translates the display, the value stays the source string.
            for arr in PAGE_OPTS.findall(text):
                for body in STR_LIT.findall(arr):
                    s = _unescape(body).strip()
                    if s and not _noise(s) and not _brand(s):
                        keys.add(s)
    return keys


def load_json(path):
    try:
        return json.load(open(path, encoding="utf-8"))
    except Exception:
        return {}


def write_json(path, obj):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(dict(sorted(obj.items())), fh, ensure_ascii=False, indent=2)
        fh.write("\n")


def cmd_extract():
    keys = extract_keys()
    write_json(os.path.join(TRANS, "en.json"), {k: k for k in keys})
    print(f"extract: {len(keys)} strings -> translations/en.json")


def shield(s):
    return re.sub(r"%(\d)", lambda m: chr(PU_BASE + int(m.group(1))), s)


def unshield(s):
    out = []
    for c in s:
        o = ord(c)
        out.append("%" + str(o - PU_BASE) if PU_BASE <= o <= PU_BASE + 9 else c)
    return "".join(out)


def google_translate(text, tl, tries=3):
    q = shield(text)
    url = "https://translate.googleapis.com/translate_a/single?" + urllib.parse.urlencode(
        {"client": "gtx", "sl": "en", "tl": tl, "dt": "t", "q": q})
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    for attempt in range(tries):
        try:
            with urllib.request.urlopen(req, timeout=15) as resp:
                data = json.loads(resp.read().decode("utf-8"))
            out = "".join(seg[0] for seg in data[0] if seg and seg[0])
            return unshield(out)
        except Exception as e:
            if attempt == tries - 1:
                print(f"  ! translate failed ({tl}): {e}", file=sys.stderr)
                return None
            time.sleep(1.5 * (attempt + 1))
    return None


def cmd_sync(langs):
    en = load_json(os.path.join(TRANS, "en.json"))
    if not en:
        print("sync: run extract first (translations/en.json is empty)", file=sys.stderr)
        return 1
    langs = langs or list(TARGETS)
    for lang in langs:
        tl = TARGETS.get(lang)
        if not tl:
            print(f"sync: unknown language {lang}", file=sys.stderr)
            continue
        existing = load_json(os.path.join(TRANS, f"{lang}.json"))
        overrides = load_json(os.path.join(OVERRIDES, f"{lang}.json"))
        out, new = {}, 0
        for key in en:
            if key in overrides:
                out[key] = overrides[key]
            elif key in existing and existing[key] != key:
                out[key] = existing[key]          # already translated: keep, no call
            else:
                t = google_translate(key, tl)
                out[key] = t if t else key        # fall back to English on failure
                new += 1
                time.sleep(0.25)                  # be gentle on the endpoint
        write_json(os.path.join(TRANS, f"{lang}.json"), out)
        print(f"sync {lang}: {len(out)} strings ({new} newly translated, {len(overrides)} overrides)")
    return 0


# ── LLM generation (the "Noctalia approach"): higher-quality / extra-language ──
# translations produced by a user-configured LLM, written to the layered config
# dir (~/.config/ryoku/i18n/<lang>.json) where I18n layers them over the shipped
# files. Config: ~/.config/ryoku/i18n-llm.json {"provider","key","model","name"}.

def _cfg_home():
    return os.environ.get("XDG_CONFIG_HOME") or os.path.join(os.path.expanduser("~"), ".config")


LLM_CFG = os.path.join(_cfg_home(), "ryoku", "i18n-llm.json")
GEN_DIR = os.path.join(_cfg_home(), "ryoku", "i18n")


def llm_call(cfg, prompt):
    provider = cfg.get("provider", "anthropic")
    key = cfg.get("key", "")
    model = cfg.get("model") or ("claude-sonnet-5" if provider == "anthropic" else "gpt-4o-mini")
    if provider == "anthropic":
        url = "https://api.anthropic.com/v1/messages"
        body = {"model": model, "max_tokens": 4096,
                "messages": [{"role": "user", "content": prompt}]}
        headers = {"x-api-key": key, "anthropic-version": "2023-06-01", "content-type": "application/json"}
    else:  # openai-compatible
        url = cfg.get("url", "https://api.openai.com/v1/chat/completions")
        body = {"model": model, "messages": [{"role": "user", "content": prompt}]}
        headers = {"Authorization": "Bearer " + key, "content-type": "application/json"}
    req = urllib.request.Request(url, data=json.dumps(body).encode(), headers=headers)
    with urllib.request.urlopen(req, timeout=90) as resp:
        data = json.loads(resp.read().decode())
    if provider == "anthropic":
        return data["content"][0]["text"]
    return data["choices"][0]["message"]["content"]


def _extract_json(text):
    a, b = text.find("{"), text.rfind("}")
    return json.loads(text[a:b + 1]) if a >= 0 and b > a else {}


def cmd_llm(langs):
    if not os.path.exists(LLM_CFG):
        print(f"llm: configure a key first at {LLM_CFG} "
              '({"provider":"anthropic","key":"...","model":"..."})', file=sys.stderr)
        return 1
    cfg = load_json(LLM_CFG)
    en = load_json(os.path.join(TRANS, "en.json"))
    if not en:
        cmd_extract(); en = load_json(os.path.join(TRANS, "en.json"))
    keys = list(en)
    for lang in (langs or [cfg.get("target", "es")]):
        out, batch = {}, 60
        for i in range(0, len(keys), batch):
            chunk = keys[i:i + batch]
            prompt = (f"Translate these UI strings to {lang}. Return ONLY a JSON object mapping each "
                      "English source string to its translation. Preserve %1/%2 placeholders exactly, "
                      "keep proper nouns (Wi-Fi, GPU, Ryoku, Bluetooth) untranslated, and match the "
                      "terse tone of a settings app.\n\n" + json.dumps({k: k for k in chunk}, ensure_ascii=False))
            try:
                got = _extract_json(llm_call(cfg, prompt))
                out.update({k: v for k, v in got.items() if k in en})
            except Exception as e:
                print(f"  ! llm batch failed ({lang}): {e}", file=sys.stderr)
            print(f"  {lang}: {len(out)}/{len(keys)}")
        os.makedirs(GEN_DIR, exist_ok=True)
        with open(os.path.join(GEN_DIR, f"{lang}.json"), "w", encoding="utf-8") as fh:
            json.dump(dict(sorted(out.items())), fh, ensure_ascii=False, indent=2)
        print(f"llm {lang}: wrote {len(out)} strings -> {GEN_DIR}/{lang}.json")
    return 0


def main():
    args = sys.argv[1:]
    if not args or args[0] not in ("extract", "sync", "llm"):
        print(__doc__)
        return 2
    if args[0] == "extract":
        cmd_extract()
        return 0
    if args[0] == "llm":
        return cmd_llm(args[1:])
    return cmd_sync(args[1:])


if __name__ == "__main__":
    sys.exit(main())
