import 'dart:async';
import 'dart:io'; // Needed for File and Platform checks
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:flutter/material.dart';

// Hide Message from the library so we can use YOUR Message class
import 'package:llama_cpp_dart/llama_cpp_dart.dart' hide Message;

// Import your domain Message class
import 'package:chiza_ai/features/chat/domain/message.dart';

class ChatProvider extends ChangeNotifier {
  final List<Message> _messages = [];

  bool _isTyping = false;
  bool _isModelLoaded = false;
  String? _errorMessage; // NEW: Variable to store load errors

  Llama? _llamaProcessor;

  List<Message> get messages => _messages;
  bool get isTyping => _isTyping;
  bool get isModelLoaded => _isModelLoaded;
  String? get errorMessage => _errorMessage; // NEW: Expose error to UI

  Future<void> loadModelFromPath(String path) async {
    // 1. Reset state before loading
    _isModelLoaded = false;
    _errorMessage = null;
    notifyListeners();

    try {
      debugPrint("Initializing Llama from: $path");

      // 2. Check if file actually exists
      if (!File(path).existsSync()) {
        throw Exception("Model file missing at: $path");
      }

      // 3. Android-specific library mapping (Crucial for many Android devices)
      if (Platform.isAndroid) {
        Llama.libraryPath = "libllama.so";
      }

      // 4. Initialize Brain
      _llamaProcessor = Llama(path);

      // 5. Set System Prompt
      _llamaProcessor!.setPrompt("You are Chiza, a helpful AI assistant.");

      // Success!
      _isModelLoaded = true;
      notifyListeners();
      debugPrint("Brain (Llama) is Online!");
    } catch (e) {
      debugPrint("CRITICAL ERROR LOADING BRAIN: $e");

      // FIX: Store the error so the UI can stop spinning and show it
      _errorMessage = "Failed to load Brain: $e";
      _isModelLoaded = false;
      notifyListeners();
    }
  }

  Future<void> sendMessage(String content) async {
    if (_llamaProcessor == null) {
      _messages.add(
        Message(
          content: "Brain is not loaded yet.",
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
      notifyListeners();
      return;
    }

    // Add User Message
    _messages.add(
      Message(content: content, isUser: true, timestamp: DateTime.now()),
    );

    _isTyping = true;
    notifyListeners();

    try {
      // Feed input to Llama
      _llamaProcessor!.setPrompt(content);

      StringBuffer buffer = StringBuffer();

      // Loop to get tokens one by one (Streaming effect)
      while (true) {
        final (token, done) = _llamaProcessor!.getNext();
        buffer.write(token);

        // Allow UI to breathe/update
        await Future.delayed(Duration.zero);

        if (done) break;
      }

      String fullReply = buffer.toString().trim();
      if (fullReply.isEmpty) fullReply = "...";

      // Add AI Reply
      _messages.add(
        Message(content: fullReply, isUser: false, timestamp: DateTime.now()),
      );
    } catch (e) {
      debugPrint("Generation Error: $e");
      _messages.add(
        Message(
          content: "Error generating reply: $e",
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
    } finally {
      _isTyping = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _llamaProcessor?.dispose();
    super.dispose();
  }
}
