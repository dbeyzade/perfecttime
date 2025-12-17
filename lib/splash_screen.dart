import 'dart:math';
import 'package:flutter/material.dart';
import 'main.dart'; // To access AuthGate

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late int _durationSeconds;

  @override
  void initState() {
    super.initState();
    // Random duration between 3 and 10 seconds
    _durationSeconds = Random().nextInt(8) + 3;

    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: _durationSeconds),
    )..addListener(() {
      if (_controller.isCompleted) {
        _navigateToHome();
      }
    });

    _controller.forward();
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const AuthGate()),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Loading',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: 150,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return LinearProgressIndicator(
                    value: _controller.value,
                    backgroundColor: Colors.grey[900],
                    color: Colors.greenAccent,
                    minHeight: 2, // Thin line
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
