import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'package:path_provider/path_provider.dart';

// --- Helper Classes ---

enum ChatMessageRole { user, model }

class ChatMessage {
  final ChatMessageRole role;
  final String content;

  ChatMessage({required this.role, required this.content});

  bool get isUser => role == ChatMessageRole.user;
}

class ChatSession {
  final String id;
  final String title;
  final DateTime date;

  ChatSession({required this.id, required this.title, required this.date});

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'date': date.toIso8601String(),
  };

  factory ChatSession.fromJson(Map<String, dynamic> json) => ChatSession(
    id: json['id'],
    title: json['title'],
    date: DateTime.parse(json['date']),
  );
}

// --- Provider ---

class ChatProvider extends ChangeNotifier {
  Llama? _llama;
  final List<ChatMessage> _messages = [];
  final List<ChatSession> _history = [];

  bool _isTyping = false;
  String? _errorMessage;
  bool _isModelLoaded = false;

  bool get isModelLoaded => _isModelLoaded;
  bool get isTyping => _isTyping;
  String? get errorMessage => _errorMessage;
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  List<ChatSession> get history => List.unmodifiable(_history);

  /// Loads the GGUF model from the filesystem
  Future<void> loadModelFromPath(String path) async {
    try {
      if (await File(path).exists()) {
        // Initialize Llama with the path
        _llama = Llama(path);

        _isModelLoaded = true;
        _errorMessage = null;
        notifyListeners();
      } else {
        throw Exception("Model file not found at $path");
      }
    } catch (e) {
      _errorMessage = "Failed to load brain: $e";
      debugPrint(_errorMessage);
      _isModelLoaded = false;
      notifyListeners();
    }
  }

  /// Sends a message and gets a response
  Future<void> sendMessage(String text) async {
    if (_llama == null) {
      _errorMessage = "Brain not loaded!";
      notifyListeners();
      return;
    }

    _errorMessage = null;

    // 1. Add User Message
    _messages.add(ChatMessage(role: ChatMessageRole.user, content: text));
    _isTyping = true;
    notifyListeners();

    try {
      // 2. Format Prompt for the AI
      String prompt = "";
      for (var msg in _messages) {
        if (msg.role == ChatMessageRole.user) {
          prompt += "User: ${msg.content}\n";
        } else {
          prompt += "Assistant: ${msg.content}\n";
        }
      }
      prompt += "Assistant:";

      // 3. Prepare Bot Message Placeholder
      _messages.add(ChatMessage(role: ChatMessageRole.model, content: ""));
      int botMsgIndex = _messages.length - 1;
      String botResponse = "";

      // 4. Set the prompt
      _llama!.setPrompt(prompt);

      // 5. Generate Response Loop
      while (true) {
        // getNext returns (String token, bool done)
        // logic: token is never null in this version
        var (token, done) = _llama!.getNext();

        botResponse += token;
        _messages[botMsgIndex] = ChatMessage(
          role: ChatMessageRole.model,
          content: botResponse,
        );
        notifyListeners();

        if (done) break;

        // Small delay to prevent UI freezing
        await Future.delayed(Duration.zero);
      }

      _isTyping = false;
      _addToHistoryIfNeeded(text);
      notifyListeners();
    } catch (e) {
      _messages.add(
        ChatMessage(role: ChatMessageRole.model, content: "Error: $e"),
      );
      _isTyping = false;
      notifyListeners();
    }
  }

  /// Clears current chat (UI only)
  void startNewChat() {
    _messages.clear();
    _errorMessage = null;
    notifyListeners();
  }

  void _addToHistoryIfNeeded(String firstMessage) {
    if (_messages.length == 2) {
      final title = firstMessage.length > 30
          ? "${firstMessage.substring(0, 30)}..."
          : firstMessage;
      final newSession = ChatSession(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        date: DateTime.now(),
      );
      _history.insert(0, newSession);
      _saveHistoryToDisk();
      notifyListeners();
    }
  }

  Future<void> loadHistory() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/chat_history.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(content);
        _history.clear();
        _history.addAll(jsonList.map((e) => ChatSession.fromJson(e)).toList());
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error loading history: $e");
    }
  }

  Future<void> _saveHistoryToDisk() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/chat_history.json');
      final jsonList = _history.map((e) => e.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      debugPrint("Error saving history: $e");
    }
  }

  Future<void> clearAllHistory() async {
    _history.clear();
    _messages.clear();
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/chat_history.json');
    if (await file.exists()) {
      await file.delete();
    }
    notifyListeners();
  }
}
