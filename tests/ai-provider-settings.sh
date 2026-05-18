#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_file() {
  local path="$1"

  [[ -f $path ]] || fail "missing file: $path"
}

assert_contains() {
  local path="$1"
  local needle="$2"

  grep -qF "$needle" "$path" || fail "$path should contain: $needle"
}

assert_matches() {
  local path="$1"
  local pattern="$2"

  rg -q "$pattern" "$path" || fail "$path should match: $pattern"
}

assert_not_matches() {
  local path="$1"
  local pattern="$2"
  local message="$3"

  ! rg -q "$pattern" "$path" || fail "$message"
}

ai_service="shell/services/Ai.qml"
default_config="shell/defaults/config.json"
config_qml="shell/modules/common/Config.qml"
services_config="shell/modules/settings/ServicesConfig.qml"
qmldir="shell/services/ai/qmldir"
anthropic_strategy="shell/services/ai/AnthropicApiStrategy.qml"
responses_strategy="shell/services/ai/OpenAiResponseApiStrategy.qml"

assert_file "$anthropic_strategy"
assert_file "$responses_strategy"

assert_contains "$qmldir" "AnthropicApiStrategy 1.0 AnthropicApiStrategy.qml"
assert_contains "$qmldir" "OpenAiResponseApiStrategy 1.0 OpenAiResponseApiStrategy.qml"

assert_contains "$ai_service" "property Component anthropicApiStrategy: AnthropicApiStrategy {}"
assert_contains "$ai_service" "property Component openaiResponseApiStrategy: OpenAiResponseApiStrategy {}"
assert_contains "$ai_service" '"anthropic": anthropicApiStrategy.createObject(this)'
assert_contains "$ai_service" '"openai-response": openaiResponseApiStrategy.createObject(this)'
assert_contains "$ai_service" '"anthropic": {'
assert_contains "$ai_service" '"openai-response": {'
assert_contains "$ai_service" "property list<var> defaultProviderModels"
assert_contains "$ai_service" "defaultProvidersBackfilled"
assert_contains "$ai_service" "root.defaultProviderModels.forEach"
assert_contains "$ai_service" "configuredModels.push(Object.assign({}, model))"
assert_contains "$ai_service" "property var _loadedExtraModelIds: []"
assert_contains "$ai_service" "function _syncExtraModels()"
assert_contains "$ai_service" "Config.options?.ai?.extraModels"
assert_contains "$ai_service" "root._syncExtraModels()"
assert_contains "$ai_service" "function onConfigChanged() { root._syncExtraModels() }"
assert_contains "$ai_service" "root.addModel(safeModelName, model)"
assert_contains "$ai_service" "addFunctionOutputMessage(name, Translation.tr(\"Config updated.\"), message.functionCall)"
assert_contains "$ai_service" "requester.handleStrategyResult(result)"
assert_contains "$ai_service" "property var pendingFunctionCall"
assert_contains "$ai_service" "requester.pendingFunctionCall = result.functionCall"
assert_contains "$ai_service" "root.handleFunctionCall(functionCall.name, functionCall.args, functionMessage)"
assert_contains "$ai_service" '"name": "get_shell_config"'
assert_contains "$ai_service" '"strict": true'
assert_not_matches "$ai_service" '"openai-response": \{[[:space:][:print:]]*"function": \{' "Responses tools should use flat function schema"

assert_contains "$default_config" '"extraModels": ['
assert_contains "$default_config" '"defaultProvidersBackfilled": true'
assert_contains "$default_config" '"api_format": "gemini"'
assert_contains "$default_config" '"api_format": "mistral"'
assert_contains "$config_qml" 'property list<var> extraModels: ['
assert_contains "$config_qml" 'property bool defaultProvidersBackfilled: false'
assert_contains "$config_qml" '"api_format": "gemini"'
assert_contains "$config_qml" '"api_format": "mistral"'

assert_contains "$services_config" "AI Providers"
assert_contains "$services_config" "Add AI Provider"
assert_contains "$services_config" "providerForm"
assert_contains "$services_config" "ConfigSelectionArray"
assert_contains "$services_config" 'value: "anthropic"'
assert_contains "$services_config" 'value: "openai-response"'
assert_contains "$services_config" 'value: "mistral"'
assert_contains "$services_config" "KeyringStorage.setNestedField([\"apiKeys\", keyId], apiKey)"
assert_contains "$services_config" "Config.setNestedValue(\"ai.extraModels\", models)"
assert_contains "$services_config" "Compatible with OpenAI, Mistral, Ollama, OpenRouter, vLLM"
assert_contains "$services_config" 'url.includes("/v1/responses")'

assert_contains "$anthropic_strategy" "x-api-key"
assert_contains "$anthropic_strategy" "anthropic-version"
assert_contains "$anthropic_strategy" "/v1/messages"
assert_contains "$anthropic_strategy" "tool_use"
assert_contains "$anthropic_strategy" "input_json_delta"
assert_contains "$anthropic_strategy" "tool_result"
assert_contains "$anthropic_strategy" "functionCall: message.functionCall"
assert_contains "$anthropic_strategy" "pendingToolUse"
assert_contains "$anthropic_strategy" "message_stop"
assert_contains "$responses_strategy" '"input": inputMessages'
assert_contains "$responses_strategy" "function_call_output"
assert_contains "$responses_strategy" "_normalizeTools"
assert_contains "$responses_strategy" "response.output_item.added"
assert_contains "$responses_strategy" "response.function_call_arguments.delta"
assert_contains "$responses_strategy" "response.function_call_arguments.done"
assert_contains "$responses_strategy" "functionCall: message.functionCall"
assert_contains "$responses_strategy" "pendingFunctionCall"
assert_contains "$responses_strategy" "response.output_text.delta"
assert_contains "$responses_strategy" "response.completed"

touched_files=(
  "$ai_service"
  "$default_config"
  "$config_qml"
  "$services_config"
  "$qmldir"
  "$anthropic_strategy"
  "$responses_strategy"
)

legacy_brand="i""NiR"
legacy_brand_alt="I""nir"
legacy_cmd="i""nir"
legacy_upper="I""NIR"
legacy_pattern="$legacy_brand|$legacy_brand_alt|$legacy_upper|scripts/$legacy_cmd|Appearance\\.$legacy_cmd""Everywhere|\\b$legacy_cmd\\b|/$legacy_cmd"

for path in "${touched_files[@]}"; do
  assert_file "$path"
  assert_not_matches "$path" "$legacy_pattern" "$path should use Ryoku naming only"
done

echo "PASS: AI provider settings and strategy wiring are ported"
