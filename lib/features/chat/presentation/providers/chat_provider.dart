import 'package:flutter/material.dart';
import 'package:chiza_ai/core/services/ai_service.dart';
import 'package:chiza_ai/features/chat/domain/message.dart';

class ChatProvider extends ChangeNotifier {
  final AIService _aiService = AIService();

  // State
  final List<Message> _messages = [];
  bool _isTyping = false;
  bool _isModelLoaded = false;

  // Getters
  List<Message> get messages => _messages;
  bool get isTyping => _isTyping;
  bool get isModelLoaded => _isModelLoaded;

  /// Called by the Splash Screen once the download is finished
  Future<void> loadModelFromPath(String path) async {
    try {
      _aiService.loadModel(path);
      _isModelLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint("❌ Error loading model in provider: $e");
      _isModelLoaded = false;
      notifyListeners();
    }
  }

  Future<void> initialize() async {
    // Intentionally empty
  }

  /// Sends a message and streams the AI response
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || !_isModelLoaded) return;

    // 1. Add User Message (FIX: Added timestamp)
    _messages.add(
      Message(content: text, isUser: true, timestamp: DateTime.now()),
    );
    _isTyping = true;
    notifyListeners();

    try {
      // 2. Create a placeholder for AI response (FIX: Added timestamp)
      String fullResponse = "";
      _messages.add(
        Message(content: "", isUser: false, timestamp: DateTime.now()),
      );

      int aiIndex = _messages.length - 1;

      // 3. Stream the response
      await for (final token in _aiService.streamResponse(text)) {
        fullResponse += token;

        // Update the last message with the new chunk of text (FIX: Added timestamp)
        _messages[aiIndex] = Message(
          content: fullResponse,
          isUser: false,
          timestamp: DateTime.now(),
        );
        notifyListeners();
      }
    } catch (e) {
      // (FIX: Added timestamp)
      _messages.add(
        Message(content: "Error: $e", isUser: false, timestamp: DateTime.now()),
      );
    } finally {
      _isTyping = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _aiService.unload();
    super.dispose();
  }
}
