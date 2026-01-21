import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chiza_ai/features/chat/providers/chat_provider.dart';
import 'package:chiza_ai/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:chiza_ai/features/chat/presentation/widgets/chat_input_field.dart';
import 'package:chiza_ai/features/chat/presentation/screens/settings_screen.dart';

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
      appBar: AppBar(
        title: const Text("Chiza (Qwen)"),
        backgroundColor: Colors.deepPurple[100],
      ),
      
      // Changed from 'endDrawer' to standard 'drawer' (Left side)
      // and defined directly here to ensure navigation works.
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.deepPurple),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.psychology, color: Colors.white, size: 48),
                  SizedBox(height: 10),
                  Text(
                    "Chiza AI", 
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context); // Close drawer first
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.exit_to_app),
              title: const Text('Close App'),
              onTap: () => Navigator.of(context).pop(), // Just closes drawer for now
            ),
          ],
        ),
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