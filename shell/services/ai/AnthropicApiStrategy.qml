import QtQuick

ApiStrategy {
    property string currentEvent: ""
    property bool isThinking: false
    property var toolUseBlocks: ({})
    property var emittedToolUseIds: ({})
    property var pendingToolUse: null

    function buildEndpoint(model: AiModel): string {
        let ep = model.endpoint;
        if (!ep.includes("/v1/messages")) {
            ep = ep.replace(/\/+$/, "") + "/v1/messages";
        }
        return ep;
    }

    function _messageToAnthropicMessage(message) {
        if (message.functionResponse !== undefined && message.functionName?.length > 0) {
            return {
                "role": "user",
                "content": [{
                    "type": "tool_result",
                    "tool_use_id": message.functionCall?.id ?? message.functionName,
                    "content": message.functionResponse,
                }],
            };
        }
        if (message.functionCall !== undefined && message.functionName?.length > 0) {
            return {
                "role": "assistant",
                "content": [{
                    "type": "tool_use",
                    "id": message.functionCall?.id ?? message.functionName,
                    "name": message.functionName,
                    "input": message.functionCall?.args ?? {},
                }],
            };
        }
        return {
            "role": message.role,
            "content": message.rawContent,
        };
    }

    function buildRequestData(model: AiModel, messages, systemPrompt: string, temperature: real, tools: list<var>, filePath: string) {
        let data = {
            "model": model.model,
            "max_tokens": model.extraParams?.max_tokens ?? 4096,
            "messages": messages.map(message => {
                return _messageToAnthropicMessage(message);
            }),
            "stream": true,
        };

        if (systemPrompt && systemPrompt.length > 0) {
            data.system = systemPrompt;
        }

        if (temperature !== undefined) {
            data.temperature = temperature;
        }

        if (tools && tools.length > 0) {
            data.tools = tools;
        }

        return model.extraParams ? Object.assign({}, data, model.extraParams) : data;
    }

    function buildAuthorizationHeader(apiKeyEnvVarName: string): string {
        return `-H "x-api-key: \$\{${apiKeyEnvVarName}\}" -H "anthropic-version: 2023-06-01"`;
    }

    function _recordToolUseStart(dataJson) {
        const block = dataJson.content_block ?? {};
        if (block.type !== "tool_use") return;
        const key = String(dataJson.index ?? block.id);
        toolUseBlocks[key] = {
            id: block.id ?? key,
            name: block.name ?? "",
            inputJson: "",
        };
    }

    function _appendToolUseDelta(dataJson) {
        const key = String(dataJson.index ?? "");
        if (!toolUseBlocks[key]) return;
        toolUseBlocks[key].inputJson += dataJson.delta?.partial_json ?? "";
    }

    function _emitToolUse(dataJson, message) {
        const call = dataJson?.id ? dataJson : toolUseBlocks[String(dataJson?.index ?? "")];
        if (!call || !call.name || emittedToolUseIds[call.id]) return {};
        emittedToolUseIds[call.id] = true;
        let args = {};
        try {
            args = JSON.parse(call.inputJson || "{}");
        } catch (e) {
            args = {};
        }
        const newContent = `\n\n[[ Function: ${call.name}(${JSON.stringify(args, null, 2)}) ]]\n`;
        message.rawContent += newContent;
        message.content += newContent;
        message.functionName = call.name;
        message.functionCall = { name: call.name, args, id: call.id };
        return { functionCall: message.functionCall };
    }

    function parseResponseLine(line, message) {
        let cleanLine = line.trim();

        if (cleanLine.startsWith("event:")) {
            currentEvent = cleanLine.slice(6).trim();
            return {};
        }

        if (cleanLine.startsWith("data:")) {
            let cleanData = cleanLine.slice(5).trim();

            if (!cleanData) return {};

            try {
                const dataJson = JSON.parse(cleanData);

                switch (dataJson.type) {
                    case "message_start":
                        if (dataJson.message?.usage) {
                            return {
                                tokenUsage: {
                                    input: dataJson.message.usage.input_tokens ?? -1,
                                    output: -1,
                                    total: -1
                                }
                            };
                        }
                        break;

                    case "content_block_start":
                        _recordToolUseStart(dataJson);
                        break;

                    case "content_block_delta":
                        const delta = dataJson.delta;
                        if (delta?.type === "text_delta" && delta.text) {
                            if (isThinking) {
                                isThinking = false;
                                message.content += "\n\n</think>\n\n";
                                message.rawContent += "\n\n</think>\n\n";
                            }
                            message.content += delta.text;
                            message.rawContent += delta.text;
                        } else if (delta?.type === "thinking_delta" && delta.thinking) {
                            if (!isThinking) {
                                isThinking = true;
                                message.rawContent += "\n\n<think>\n\n";
                                message.content += "\n\n<think>\n\n";
                            }
                            message.rawContent += delta.thinking;
                            message.content += delta.thinking;
                        } else if (delta?.type === "input_json_delta") {
                            _appendToolUseDelta(dataJson);
                        }
                        break;

                    case "content_block_stop":
                        pendingToolUse = toolUseBlocks[String(dataJson.index ?? "")] ?? pendingToolUse;
                        break;

                    case "message_delta":
                        if (dataJson.usage) {
                            return {
                                tokenUsage: {
                                    input: -1,
                                    output: dataJson.usage.output_tokens ?? -1,
                                    total: -1
                                }
                            };
                        }
                        break;

                    case "message_stop":
                        return Object.assign(_emitToolUse(pendingToolUse, message), { finished: true });

                    case "error":
                        const errorMsg = `**Error**: ${dataJson.error?.message || JSON.stringify(dataJson.error)}`;
                        message.rawContent += errorMsg;
                        message.content += errorMsg;
                        return { finished: true };
                }

            } catch (e) {
                console.log("[AI] Anthropic: Could not parse line: ", e);
                message.rawContent += cleanData;
                message.content += cleanData;
            }
        }

        return {};
    }

    function onRequestFinished(message) {
        return {};
    }

    function reset() {
        currentEvent = "";
        isThinking = false;
        toolUseBlocks = ({});
        emittedToolUseIds = ({});
        pendingToolUse = null;
    }
}
