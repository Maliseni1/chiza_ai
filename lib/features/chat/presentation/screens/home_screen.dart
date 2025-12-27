import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart'; // For nice AI text
import 'package:chiza_ai/features/chat/presentation/providers/chat_provider.dart';
import 'package:chiza_ai/features/chat/domain/message.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // This waits until the widget is fully built before running logic
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Check 'mounted' to ensure the screen is still there
      if (mounted) {
        Provider.of<ChatProvider>(context, listen: false).initialize();
      }
    });
  }

  void _scrollToBottom() {
    // wait a bit for the list to render new message
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Listen to changes in the ChatProvider
    final chatProvider = Provider.of<ChatProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Chiza AI"),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // Indicator to show if model is loaded
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Icon(
              Icons.circle,
              size: 14,
              color: chatProvider.isModelLoaded ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. The Chat List
          Expanded(
            child: chatProvider.messages.isEmpty
                ? const Center(
                    child: Text(
                      "🤖 I am ready.\nAsk me anything!",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: chatProvider.messages.length,
                    itemBuilder: (context, index) {
                      final msg = chatProvider.messages[index];
                      return _buildChatBubble(msg, context);
                    },
                  ),
          ),

          // 2. The Input Area
          if (chatProvider.isTyping)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(),
            ),

          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: "Type a message...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(chatProvider),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: chatProvider.isTyping
                      ? null // Disable button while thinking
                      : () => _sendMessage(chatProvider),
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage(ChatProvider provider) {
    final text = _controller.text;
    if (text.trim().isEmpty) return;

    _controller.clear();
    provider.sendMessage(text);
    _scrollToBottom();
  }

  Widget _buildChatBubble(Message msg, BuildContext context) {
    final isUser = msg.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? Theme.of(context).colorScheme.primary
              : Colors.grey[200], // AI uses grey
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
            bottomRight: isUser ? Radius.zero : const Radius.circular(16),
          ),
        ),
        child: isUser
            ? Text(msg.content, style: const TextStyle(color: Colors.white))
            : MarkdownBody(
                data: msg.content, // Renders bold, code blocks, etc.
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(color: Colors.black87),
                ),
              ),
      ),
    );
  }
}
