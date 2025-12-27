import 'dart:async';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'package:flutter/foundation.dart';

class AIService {
  Llama? _llama;

  /// Loads the model from the given file path into RAM.
  void loadModel(String modelPath) {
    if (_llama != null) return; // Already loaded

    try {
      debugPrint("🧠 Loading AI Model from: $modelPath");

      // Initialize with just the path.
      // This uses the default settings safe for v0.1.x of the library.
      _llama = Llama(modelPath);

      debugPrint("✅ Model Loaded Successfully!");
    } catch (e) {
      debugPrint("❌ Error Loading Model: $e");
      throw Exception("Could not load AI model");
    }
  }

  /// Sends a prompt to the model and returns a stream of text.
  Stream<String> streamResponse(String prompt) async* {
    if (_llama == null) {
      throw Exception("Model not loaded yet!");
    }

    // 1. Format the prompt specifically for Chat Models (like Qwen/Llama)
    // This structure tells the AI: "This is the user speaking, now you answer."
    final fullPrompt =
        "<|im_start|>user\n$prompt<|im_end|>\n<|im_start|>assistant\n";

    // 2. Set the prompt inside the engine
    _llama!.setPrompt(fullPrompt);

    // 3. Generate tokens one by one
    // We use a manual loop because it is the most stable method for this library version.
    while (true) {
      // getNext() returns a record: (String token, bool done)
      final result = _llama!.getNext();
      final token = result.$1; // The actual text part
      final done = result.$2; // The boolean "is finished" part

      yield token;

      if (done) {
        break;
      }
    }
  }

  void unload() {
    _llama?.dispose();
    _llama = null;
  }
}
