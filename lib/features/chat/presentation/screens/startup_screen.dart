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
    try {
      final dir = await getApplicationDocumentsDirectory();
      final modelPath = "${dir.path}/qwen2.5-1.5b-instruct-q4_k_m.gguf";

      if (!mounted) return;

      final file = File(modelPath);

      if (await file.exists()) {
        final fileSize = await file.length();

        // FIX: Lower threshold to 800MB (approx 0.8GB).
        // The Q4_K_M model is usually ~1.1GB, so 1.4GB was deleting valid files.
        const minSize = 1024 * 1024 * 800;

        if (fileSize < minSize) {
          debugPrint(
            "Startup: File too small ($fileSize bytes). Deleting corrupt file.",
          );
          await file.delete();
          if (!mounted) return;
          _goToSetup();
          return;
        }

        try {
          if (!mounted) return;
          final chatProvider = Provider.of<ChatProvider>(
            context,
            listen: false,
          );

          // Load existing history (New Feature)
          await chatProvider.loadHistory();

          // Load the Brain
          await chatProvider
              .loadModelFromPath(modelPath)
              .timeout(
                const Duration(seconds: 15),
                onTimeout: () => throw Exception("Timeout"),
              );

          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        } catch (e) {
          debugPrint("Startup: Loading failed ($e). Redirecting.");
          if (!mounted) return;
          _goToSetup();
        }
      } else {
        _goToSetup();
      }
    } catch (e) {
      if (!mounted) return;
      _goToSetup();
    }
  }

  void _goToSetup() {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const ModelSetupScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
