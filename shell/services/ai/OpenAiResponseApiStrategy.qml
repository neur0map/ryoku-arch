import QtQuick

ApiStrategy {
    property bool isReasoning: false
    property var functionCalls: ({})
    property var emittedFunctionCallIds: ({})
    property var pendingFunctionCall: null

    function buildEndpoint(model: AiModel): string {
        return model.endpoint;
    }

    function _normalizeTools(tools) {
        return (tools ?? []).map(tool => {
            if (!tool?.function) return tool;
            return {
                "type": "function",
                "name": tool.function.name,
                "description": tool.function.description ?? "",
                "parameters": tool.function.parameters ?? { "type": "object", "properties": {} },
                "strict": tool.function.strict ?? true,
            };
        });
    }

    function _messageToInputItem(message) {
        if (message.functionResponse !== undefined && message.functionName?.length > 0) {
            return {
                "type": "function_call_output",
                "call_id": message.functionCall?.call_id ?? message.functionCall?.id ?? message.functionName,
                "output": message.functionResponse,
            };
        }
        if (message.functionCall !== undefined && message.functionName?.length > 0) {
            return {
                "type": "function_call",
                "call_id": message.functionCall?.call_id ?? message.functionCall?.id ?? message.functionName,
                "name": message.functionName,
                "arguments": JSON.stringify(message.functionCall?.args ?? {}),
            };
        }
        return {
            "role": message.role,
            "content": message.rawContent,
        };
    }

    function buildRequestData(model: AiModel, messages, systemPrompt: string, temperature: real, tools: list<var>, filePath: string) {
        let inputMessages = messages.map(message => {
            return _messageToInputItem(message);
        });

        let data = {
            "model": model.model,
            "input": inputMessages,
            "stream": true,
        };

        if (systemPrompt && systemPrompt.length > 0) {
            data.instructions = systemPrompt;
        }

        if (temperature !== undefined) {
            data.temperature = temperature;
        }

        if (tools && tools.length > 0) {
            data.tools = _normalizeTools(tools);
        }

        return model.extraParams ? Object.assign({}, data, model.extraParams) : data;
    }

    function buildAuthorizationHeader(apiKeyEnvVarName: string): string {
        return `-H "Authorization: Bearer \$\{${apiKeyEnvVarName}\}"`;
    }

    function _functionCallKey(dataJson) {
        if (dataJson.output_index !== undefined) return String(dataJson.output_index);
        if (dataJson.item_id) return dataJson.item_id;
        if (dataJson.item?.id) return dataJson.item.id;
        return "";
    }

    function _recordFunctionCall(dataJson) {
        const item = dataJson.item ?? {};
        const key = _functionCallKey(dataJson);
        if (!key || item.type !== "function_call") return;
        const existing = functionCalls[key] ?? {};
        functionCalls[key] = {
            id: item.id ?? existing.id ?? key,
            call_id: item.call_id ?? existing.call_id ?? item.id ?? key,
            name: item.name ?? existing.name ?? "",
            arguments: item.arguments ?? existing.arguments ?? "",
        };
    }

    function _appendFunctionArguments(dataJson) {
        const key = _functionCallKey(dataJson);
        if (!key) return;
        const existing = functionCalls[key] ?? {
            id: dataJson.item_id ?? key,
            call_id: dataJson.call_id ?? dataJson.item_id ?? key,
            name: dataJson.name ?? "",
            arguments: "",
        };
        existing.arguments = dataJson.arguments ?? ((existing.arguments ?? "") + (dataJson.delta ?? ""));
        if (dataJson.item?.name) existing.name = dataJson.item.name;
        if (dataJson.item?.call_id) existing.call_id = dataJson.item.call_id;
        functionCalls[key] = existing;
    }

    function _emitFunctionCall(call, message) {
        if (!call || !call.name) return {};
        const callId = call.call_id ?? call.id ?? call.name;
        if (emittedFunctionCallIds[callId]) return {};
        emittedFunctionCallIds[callId] = true;
        let args = {};
        try {
            args = JSON.parse(call.arguments || "{}");
        } catch (e) {
            args = {};
        }
        const newContent = `\n\n[[ Function: ${call.name}(${JSON.stringify(args, null, 2)}) ]]\n`;
        message.rawContent += newContent;
        message.content += newContent;
        message.functionName = call.name;
        message.functionCall = { name: call.name, args, id: callId, call_id: callId };
        return { functionCall: message.functionCall };
    }

    function parseResponseLine(line, message) {
        let cleanData = line.trim();

        if (cleanData.startsWith("event:")) return {};

        if (cleanData.startsWith("data:")) {
            cleanData = cleanData.slice(5).trim();
        }

        if (!cleanData || cleanData === "[DONE]") {
            if (cleanData === "[DONE]") return { finished: true };
            return {};
        }

        try {
            const dataJson = JSON.parse(cleanData);

            if (dataJson.error) {
                const errorMsg = `**Error**: ${dataJson.error.message || JSON.stringify(dataJson.error)}`;
                message.rawContent += errorMsg;
                message.content += errorMsg;
                return { finished: true };
            }

            if (dataJson.type === "response.output_item.added") {
                _recordFunctionCall(dataJson);
                return {};
            }

            if (dataJson.type === "response.function_call_arguments.delta") {
                _appendFunctionArguments(dataJson);
                return {};
            }

            if (dataJson.type === "response.function_call_arguments.done") {
                _appendFunctionArguments(dataJson);
                pendingFunctionCall = functionCalls[_functionCallKey(dataJson)];
                return {};
            }

            if (dataJson.type === "response.output_item.done" && dataJson.item?.type === "function_call") {
                _recordFunctionCall(dataJson);
                pendingFunctionCall = functionCalls[_functionCallKey(dataJson)];
                return {};
            }

            let newContent = "";

            if (dataJson.type === "response.output_text.delta") {
                if (dataJson.delta && dataJson.delta.length > 0) {
                    if (isReasoning) {
                        isReasoning = false;
                        message.content += "\n\n</think>\n\n";
                        message.rawContent += "\n\n</think>\n\n";
                    }
                    newContent = dataJson.delta;
                }
            }

            if (newContent.length > 0) {
                message.content += newContent;
                message.rawContent += newContent;
            }

            if (dataJson.type === "response.completed") {
                const functionResult = _emitFunctionCall(pendingFunctionCall, message);
                if (dataJson.response?.usage) {
                    return Object.assign(functionResult, {
                        tokenUsage: {
                            input: dataJson.response.usage.input_tokens ?? -1,
                            output: dataJson.response.usage.output_tokens ?? -1,
                            total: dataJson.response.usage.total_tokens ?? -1
                        },
                        finished: true
                    });
                }
                return Object.assign(functionResult, { finished: true });
            }

        } catch (e) {
            console.log("[AI] OpenAI Response: Could not parse line: ", e);
            message.rawContent += cleanData;
            message.content += cleanData;
        }

        return {};
    }

    function onRequestFinished(message) {
        return {};
    }

    function reset() {
        isReasoning = false;
        functionCalls = ({});
        emittedFunctionCallIds = ({});
        pendingFunctionCall = null;
    }
}
