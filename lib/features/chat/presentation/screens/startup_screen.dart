import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:chiza_ai/features/chat/providers/chat_provider.dart';
import 'package:chiza_ai/features/chat/presentation/screens/home_screen.dart';
import 'package:chiza_ai/features/chat/presentation/screens/model_setup_screen.dart';

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  @override
  void initState() {
    super.initState();
    _checkBrain();
  }

  Future<void> _checkBrain() async {
    // 1. Get the path
    final dir = await getApplicationDocumentsDirectory();
    final modelPath = "${dir.path}/qwen2.5-1.5b-instruct-q4_k_m.gguf";

    if (!mounted) return;

    // 2. Check if file exists
    final bool fileExists = File(modelPath).existsSync();

    if (fileExists) {
      // 3a. If Found: Load it and go to Home
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      await chatProvider.loadModelFromPath(modelPath);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } else {
      // 3b. If Missing: Go to Setup Screen to download it
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const ModelSetupScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Simple loading spinner while checking file system
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
