
import 'dart:convert';

// A wrapper for tool call messages coming from the Hume API
class ToolCallMessage {
  final String name;
  final Map<String, dynamic> parameters;
  final String toolCallId;
  final bool responseRequired;
  
  ToolCallMessage({
    required this.name,
    required this.parameters,
    required this.toolCallId,
    this.responseRequired = false,
  });
  
  factory ToolCallMessage.fromJson(Map<String, dynamic> json) {
    return ToolCallMessage(
      name: json['name'] ?? '',
      parameters: json['parameters'] is Map ? 
                Map<String, dynamic>.from(json['parameters'] as Map) : 
                <String, dynamic>{},
      toolCallId: json['tool_call_id'] ?? '',
      responseRequired: json['response_required'] ?? false,
    );
  }
}

// A helper function to decode tool call messages
ToolCallMessage decodeToolCallMessage(String json) {
  final Map<String, dynamic> data = jsonDecode(json);
  return ToolCallMessage.fromJson(data);
}
