import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chiza_ai/features/chat/providers/chat_provider.dart';
import 'package:chiza_ai/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:chiza_ai/features/chat/presentation/widgets/chat_input_field.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen to the provider
    final chatProvider = Provider.of<ChatProvider>(context);

    // Safety check: If for some reason the model isn't loaded (rare), show a loading spinner
    // instead of the download screen (which is now in ModelSetupScreen).
    if (!chatProvider.isModelLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Chiza (Qwen)"),
        backgroundColor: Colors.deepPurple[100],
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: "New Chat",
            onPressed: () => chatProvider.startNewChat(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: chatProvider.messages.length,
              itemBuilder: (context, index) {
                final msg = chatProvider.messages[index];
                return ChatBubble(message: msg.content, isUser: msg.isUser);
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
