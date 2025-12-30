import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chiza_ai/features/chat/domain/message.dart';
import 'package:chiza_ai/core/services/llama_service.dart';

class ChatProvider extends ChangeNotifier {
  List<Message> _messages = [];
  final LlamaService _llamaService = LlamaService();

  bool _isTyping = false;
  bool _isModelLoaded = false;
  String? _errorMessage;

  List<Message> get messages => _messages;
  bool get isTyping => _isTyping;
  bool get isModelLoaded => _isModelLoaded;
  String? get errorMessage => _errorMessage;

  Future<void> loadModelFromPath(String path) async {
    _isModelLoaded = false;
    _errorMessage = null;
    notifyListeners();

    try {
      await _llamaService.initModel(path);
      await _loadHistoryFromStorage();
      _isModelLoaded = true;
      notifyListeners();
    } catch (e) {
      _errorMessage = "Error: $e";
      _isModelLoaded = false;
      notifyListeners();
    }
  }

  Future<void> sendMessage(String content) async {
    if (!_isModelLoaded) return;

    // 1. Add User Message
    final userMsg = Message(
      content: content,
      isUser: true,
      timestamp: DateTime.now(),
    );
    _messages.add(userMsg);
    _saveHistoryToStorage();

    _isTyping = true;
    notifyListeners();

    try {
      final aiMessageIndex = _messages.length;
      String currentAiResponse = "";

      // 2. THIS ADDS THE "THINKING..." BUBBLE
      _messages.add(
        Message(
          content: "Thinking...",
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
      notifyListeners();

      // 3. Send relevant history to AI (excluding the "Thinking..." bubble)
      final historyToSend = _messages.sublist(0, _messages.length - 1);

      await for (final token in _llamaService.streamResponse(
        historyToSend,
        content,
      )) {
        currentAiResponse += token;

        // Update the bubble in real-time
        _messages[aiMessageIndex] = Message(
          content: currentAiResponse.trim(),
          isUser: false,
          timestamp: DateTime.now(),
        );
        notifyListeners();
      }

      _saveHistoryToStorage();
    } catch (e) {
      _messages.add(
        Message(content: "Error: $e", isUser: false, timestamp: DateTime.now()),
      );
    } finally {
      _isTyping = false;
      notifyListeners();
    }
  }

  // 3. THIS HANDLES THE "NEW CHAT" BUTTON
  Future<void> startNewChat() async {
    _messages.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('chat_history');
    notifyListeners();
  }

  Future<void> _saveHistoryToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = jsonEncode(
      _messages
          .map(
            (m) => {
              'content': m.content,
              'isUser': m.isUser,
              'timestamp': m.timestamp.toIso8601String(),
            },
          )
          .toList(),
    );
    await prefs.setString('chat_history', encodedData);
  }

  Future<void> _loadHistoryFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('chat_history');
    if (data != null) {
      final List<dynamic> decoded = jsonDecode(data);
      _messages = decoded
          .map(
            (item) => Message(
              content: item['content'],
              isUser: item['isUser'],
              timestamp:
                  DateTime.tryParse(item['timestamp'] ?? "") ?? DateTime.now(),
            ),
          )
          .toList();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _llamaService.dispose();
    super.dispose();
  }
}
