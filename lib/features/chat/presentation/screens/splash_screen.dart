import 'package:flutter/material.dart';
import 'package:chiza_ai/features/chat/presentation/screens/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToHome();
  }

  Future<void> _navigateToHome() async {
    // Show the splash screen for 2 seconds
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      // Navigate to Home, which will handle checking/downloading the AI model
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Added 'const' here to fix the performance warnings
    return const Scaffold(
      backgroundColor: Colors.deepPurple,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Icon(Icons.psychology, size: 100, color: Colors.white),
            SizedBox(height: 24),
            Text(
              "Chiza AI",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 48),
            // Loading Spinner
            CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
