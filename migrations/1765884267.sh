echo "Change to openai-codex instead of openai-codex-bin"

if ryoku-pkg-present openai-codex-bin; then
    ryoku-pkg-drop openai-codex-bin
    ryoku-pkg-add openai-codex
fi
