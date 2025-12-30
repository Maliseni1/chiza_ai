import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chiza_ai/features/chat/providers/chat_provider.dart';
// FIX: Added 'presentation' to the import path to match your folder structure
import 'package:chiza_ai/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:chiza_ai/features/chat/presentation/widgets/chat_input_field.dart';

class ChatScreen extends StatefulWidget {
  final String modelPath;

  const ChatScreen({super.key, required this.modelPath});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  @override
  void initState() {
    super.initState();
    // Load model after the UI is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().loadModelFromPath(widget.modelPath);
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Chiza AI Chat"),
        actions: [
          // Clear Chat Button
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: "Start New Chat",
            onPressed: () {
              chatProvider.startNewChat();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (!chatProvider.isModelLoaded && chatProvider.errorMessage == null)
            const Expanded(child: Center(child: CircularProgressIndicator())),

          if (chatProvider.errorMessage != null)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(
                    chatProvider.errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),

          if (chatProvider.isModelLoaded)
            Expanded(
              child: chatProvider.messages.isEmpty
                  ? const Center(child: Text("Say Hello to Chiza!"))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: chatProvider.messages.length,
                      itemBuilder: (context, index) {
                        final msg = chatProvider.messages[index];
                        return ChatBubble(
                          message: msg.content,
                          isUser: msg.isUser,
                        );
                      },
                    ),
            ),

          ChatInputField(
            onSend: (text) => chatProvider.sendMessage(text),
            isTyping: chatProvider.isTyping,
          ),
        ],
      ),
    );
  }
}
