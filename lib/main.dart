import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

// Import your providers and constants
import 'package:chiza_ai/features/settings/providers/download_provider.dart';
import 'package:chiza_ai/features/chat/providers/chat_provider.dart';
import 'package:chiza_ai/core/model_constants.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => DownloadProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chiza AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const StartupScreen(),
    );
  }
}

/// New Wrapper to handle Auto-Detection Logic
class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  @override
  void initState() {
    super.initState();
    // Check for the model after the first frame renders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkExistingModel();
    });
  }

  Future<void> _checkExistingModel() async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final dir = await getApplicationDocumentsDirectory();

    // Uses the Single Source of Truth for the filename
    final modelPath = "${dir.path}/${ModelConstants.fileName}";

    debugPrint("Startup Check: Looking for model at $modelPath");

    // AUTO-LOAD: If file exists, try to load it immediately
    if (File(modelPath).existsSync()) {
      debugPrint("File found. Attempting to load brain...");
      if (mounted) {
        chatProvider.loadModelFromPath(modelPath);
      }
    } else {
      debugPrint("No model found. Staying on Setup Screen.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);

    // 1. If Brain is Loaded -> Go to Chat
    if (chatProvider.isModelLoaded) {
      return const ChatScreen();
    }

    // 2. If Not Loaded -> Show Setup/Download (or Error) Screen
    return const ModelSetupScreen();
  }
}

class ModelSetupScreen extends StatelessWidget {
  const ModelSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Watch both providers
    final chatProvider = Provider.of<ChatProvider>(context);
    final downloadProvider = Provider.of<DownloadProvider>(context);

    // --- CASE 1: CRITICAL ERROR (Stops the endless spinner) ---
    if (chatProvider.errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 60, color: Colors.red),
                const SizedBox(height: 20),
                const Text(
                  "Brain Initialization Failed",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Text(
                    chatProvider.errorMessage!, // Show the actual error
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text("Retry Loading"),
                  onPressed: () async {
                    // Retry loading the file
                    final dir = await getApplicationDocumentsDirectory();
                    chatProvider.loadModelFromPath(
                      "${dir.path}/${ModelConstants.fileName}",
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    // --- CASE 2: NORMAL SETUP UI ---
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.psychology, size: 80, color: Colors.deepPurple),
              const SizedBox(height: 20),
              const Text(
                "Setup Chiza Brain",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
              _buildDownloadSection(context, downloadProvider, chatProvider),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDownloadSection(
    BuildContext context,
    DownloadProvider downloadProvider,
    ChatProvider chatProvider,
  ) {
    // A. Downloading...
    if (downloadProvider.isDownloading) {
      return Column(
        children: [
          LinearProgressIndicator(value: downloadProvider.progress),
          const SizedBox(height: 15),
          Text(downloadProvider.statusMessage),
        ],
      );
    }

    // B. Download Done -> Initializing...
    if (downloadProvider.progress >= 1.0) {
      // Trigger load automatically if not already failed
      Future.delayed(Duration.zero, () async {
        if (chatProvider.errorMessage == null) {
          final dir = await getApplicationDocumentsDirectory();
          chatProvider.loadModelFromPath(
            "${dir.path}/${ModelConstants.fileName}",
          );
        }
      });
      return const Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 10),
          Text("Initializing Brain..."),
        ],
      );
    }

    // C. Idle -> Download Button
    return ElevatedButton.icon(
      icon: const Icon(Icons.download),
      label: const Text("Download Brain"),
      onPressed: () async {
        final dir = await getApplicationDocumentsDirectory();
        downloadProvider.downloadModel(
          "${dir.path}/${ModelConstants.fileName}",
        );
      },
    );
  }
}

// --- CHAT SCREEN ---
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);

    // Auto-scroll to bottom when new messages arrive
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text("Chiza AI Chat"),
        backgroundColor: Colors.deepPurple[50],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: chatProvider.messages.length,
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final msg = chatProvider.messages[index];
                return Align(
                  alignment: msg.isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: msg.isUser ? Colors.deepPurple : Colors.grey[200],
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: msg.isUser
                            ? const Radius.circular(16)
                            : Radius.zero,
                        bottomRight: msg.isUser
                            ? Radius.zero
                            : const Radius.circular(16),
                      ),
                    ),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    child: Text(
                      msg.content,
                      style: TextStyle(
                        color: msg.isUser ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (chatProvider.isTyping)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: LinearProgressIndicator(minHeight: 2),
            ),

          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: "Ask something...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.deepPurple,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: () {
                      if (_controller.text.trim().isNotEmpty) {
                        chatProvider.sendMessage(_controller.text.trim());
                        _controller.clear();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
