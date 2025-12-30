import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chiza_ai/features/chat/providers/chat_provider.dart';
import 'package:chiza_ai/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:chiza_ai/features/chat/presentation/widgets/chat_input_field.dart';
import 'package:chiza_ai/features/chat/presentation/widgets/home_drawer.dart'; // Import Drawer

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);

    // Safety Loading Check
    if (!chatProvider.isModelLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      // Add the drawer here (endDrawer puts it on the RIGHT side)
      endDrawer: const HomeDrawer(),

      appBar: AppBar(
        title: const Text("Chiza (Qwen)"),
        backgroundColor: Colors.deepPurple[100],
        // The hamburger icon is added automatically by Flutter because endDrawer is present
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
