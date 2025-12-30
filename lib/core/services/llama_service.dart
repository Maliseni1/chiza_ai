import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart' hide Message;
import 'package:chiza_ai/features/chat/domain/message.dart';

class LlamaService {
  Llama? _llama;

  Future<void> initModel(String path) async {
    if (!File(path).existsSync()) throw Exception("Model missing: $path");
    if (Platform.isAndroid) Llama.libraryPath = "libllama.so";

    try {
      // Initialize with default settings (likely 512 context)
      // We will manage memory manually in _buildPrompt to prevent overflows.
      _llama = Llama(path);
      debugPrint("LlamaService: Brain Online.");
    } catch (e) {
      throw Exception("Native Library Error: $e");
    }
  }

  Stream<String> streamResponse(
    List<Message> history,
    String newQuestion,
  ) async* {
    if (_llama == null) throw Exception("Model not initialized");

    // Build a prompt that fits in the default memory window
    final String prompt = _buildPrompt(history, newQuestion);

    // Debug: See exactly what we are sending
    debugPrint(
      "--- SENDING PROMPT (${prompt.length} chars) ---\n$prompt\n----------------",
    );

    _llama!.setPrompt(prompt);

    while (true) {
      final (token, done) = _llama!.getNext();
      if (done) break;

      // Filter out system tags
      if (!token.contains("<|im_") && !token.contains("<|")) {
        yield token;
      }
      await Future.delayed(Duration.zero);
    }
  }

  String _buildPrompt(List<Message> history, String newQuestion) {
    String prompt =
        "<|im_start|>system\n"
        "You are Chiza, a helpful assistant. Answer briefly.\n"
        "<|im_end|>\n";

    // --- SMART MEMORY WINDOW ---
    // We only take the last 4 messages (approx).
    // This leaves enough 'RAM' for the AI to generate a full answer.
    // If we send too much history, the AI runs out of token space and cuts off.

    int count = 0;
    List<Message> recentMessages = [];

    // Iterate backwards from the newest message
    for (var i = history.length - 1; i >= 0; i--) {
      var msg = history[i];
      if (msg.content == "Thinking..." || msg.content.startsWith("Error:")) {
        continue;
      }

      recentMessages.add(msg);
      count++;

      // Stop after 4 previous bubbles. This is the "Sliding Window".
      // It allows long conversations without crashing the context limit.
      if (count >= 4) break;
    }

    recentMessages = recentMessages.reversed.toList();

    for (var msg in recentMessages) {
      String role = msg.isUser ? "user" : "assistant";
      prompt += "<|im_start|>$role\n${msg.content.trim()}\n<|im_end|>\n";
    }

    // Add the current question
    prompt +=
        "<|im_start|>user\n$newQuestion\n<|im_end|>\n"
        "<|im_start|>assistant\n";

    return prompt;
  }

  void dispose() {
    _llama?.dispose();
  }
}
