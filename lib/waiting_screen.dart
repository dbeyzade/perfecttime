import 'dart:async';
import 'package:flutter/material.dart';
import 'services/localization_service.dart';

class WaitingScreen extends StatefulWidget {
  final DateTime meetingStartTime;
  final VoidCallback onMeetingStart;

  const WaitingScreen({
    super.key,
    required this.meetingStartTime,
    required this.onMeetingStart,
  });

  @override
  State<WaitingScreen> createState() => _WaitingScreenState();
}

class _WaitingScreenState extends State<WaitingScreen> with SingleTickerProviderStateMixin {
  late Timer _timer;
  Duration _timeLeft = Duration.zero;
  late AnimationController _flashController;
  late Animation<double> _flashAnimation;

  @override
  void initState() {
    super.initState();
    
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _flashAnimation = Tween<double>(begin: 1.0, end: 0.3).animate(_flashController);

    _calculateTimeLeft();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _calculateTimeLeft();
    });
  }

  void _calculateTimeLeft() {
    final now = DateTime.now();
    if (now.isAfter(widget.meetingStartTime)) {
      _timer.cancel();
      _flashController.stop();
      widget.onMeetingStart();
    } else {
      setState(() {
        _timeLeft = widget.meetingStartTime.difference(now);
        
        // Flash effect in the last 10 seconds
        if (_timeLeft.inSeconds <= 10 && _timeLeft.inSeconds >= 0) {
          if (!_flashController.isAnimating) {
            _flashController.repeat(reverse: true);
          }
        } else {
          if (_flashController.isAnimating) {
            _flashController.stop();
            _flashController.reset();
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    _flashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final days = _timeLeft.inDays;
    final hours = _timeLeft.inHours % 24;
    final minutes = _timeLeft.inMinutes % 60;
    final seconds = _timeLeft.inSeconds % 60;

    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: _flashController,
        builder: (context, child) {
          final opacity = _flashAnimation.value;
          
          return Stack(
            fit: StackFit.expand,
            children: [
              // Background Image
              Opacity(
                opacity: opacity,
                child: Image.asset(
                  'assets/images/bekleme salonu.jpeg',
                  fit: BoxFit.cover,
                  opacity: const AlwaysStoppedAnimation(0.3),
                  errorBuilder: (c, o, s) => Container(color: Colors.black),
                ),
              ),
              
              // Back Button (Not flashing, for better UX)
              Positioned(
                top: 40,
                left: 20,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              
              // Main Content
              Opacity(
                opacity: opacity,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.hourglass_empty,
                        color: Colors.blueAccent,
                        size: 80,
                      ),
                      const SizedBox(height: 30),
                      Text(
                        l10n.untilMeetingStarts,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        l10n.waitingMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 50),
                      
                      // Countdown Display
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (days > 0) _buildTimeBox(days.toString(), l10n.day),
                          if (days > 0) _buildSeparator(),
                          _buildTimeBox(hours.toString().padLeft(2, '0'), l10n.hour),
                          _buildSeparator(),
                          _buildTimeBox(minutes.toString().padLeft(2, '0'), l10n.minute),
                          _buildSeparator(),
                          _buildTimeBox(seconds.toString().padLeft(2, '0'), l10n.second),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTimeBox(String value, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.blueAccent.withOpacity(0.5)),
          ),
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              fontFamily: 'Courier', // Monospace for numbers
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 12,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildSeparator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 20.0),
      child: Text(
        ":",
        style: TextStyle(
          color: Colors.white.withOpacity(0.5),
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
