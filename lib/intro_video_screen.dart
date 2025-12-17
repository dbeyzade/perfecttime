import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:video_player/video_player.dart';
import 'dart:io' show Platform;
import 'services/localization_service.dart';
// Intro video screen shown before entering a meeting. Caller supplies a
// completion handler that proceeds to the meeting screen.

class IntroVideoScreen extends StatefulWidget {
  final bool isHost;
  final String? meetingId;
  final DateTime? meetingStartTime;
  final bool isRecording;
  final VoidCallback onFinished;

  const IntroVideoScreen({
    Key? key,
    required this.isHost,
    this.meetingId,
    this.meetingStartTime,
    this.isRecording = false,
    required this.onFinished,
  }) : super(key: key);

  @override
  State<IntroVideoScreen> createState() => _IntroVideoScreenState();
}

class _IntroVideoScreenState extends State<IntroVideoScreen> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasFinished = false;

  @override
  void initState() {
    super.initState();
    
    // macOS'ta kayıt açıksa bilgilendirme göster
    if (!kIsWeb && Platform.isMacOS && widget.isRecording) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showMacOSRecordingInfo();
      });
    } else {
      _initializeVideo();
    }
  }

  Future<void> _showMacOSRecordingInfo() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.isTurkish ? 'Ekran Kaydı Bilgisi' : 'Screen Recording Info',
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.isTurkish 
                ? 'macOS\'ta uygulama içi video kaydı desteklenmiyor.' 
                : 'In-app video recording is not supported on macOS.',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.isTurkish 
                      ? '📹 Toplantıyı kaydetmek için:' 
                      : '📹 To record the meeting:',
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.keyboard, color: Colors.white70, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '⌘ + ⇧ + 5',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Menlo',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.isTurkish 
                      ? 'Bu kısayol macOS ekran kaydını başlatır.' 
                      : 'This shortcut starts macOS screen recording.',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.isTurkish 
                ? '💡 İpucu: Önce ekran kaydını başlatın, sonra "Devam Et" butonuna basın.' 
                : '💡 Tip: Start screen recording first, then press "Continue".',
              style: const TextStyle(color: Colors.amber, fontSize: 12),
            ),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _initializeVideo();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.play_arrow, color: Colors.white),
            label: Text(
              l10n.isTurkish ? 'Devam Et' : 'Continue',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _initializeVideo() async {
    // Tüm platformlarda video oynatmayı dene
    try {
      _controller = VideoPlayerController.asset('assets/videos/intro.mp4');

      await _controller!.initialize();

      // Mute audio
      await _controller!.setVolume(0.0);

      // Set playback speed to 1.5x (biraz hızlı)
      await _controller!.setPlaybackSpeed(1.5);

      if (!mounted) return;
      
      setState(() {
        _isInitialized = true;
      });

      // Auto-play
      _controller!.play();

      // Listen to video completion
      _controller!.addListener(() {
        if (_controller != null && 
            _controller!.value.isInitialized &&
            _controller!.value.position >= _controller!.value.duration &&
            _controller!.value.duration.inMilliseconds > 0) {
          _transitionToMeeting();
        }
      });
    } catch (e) {
      print('Video initialization error: $e');
      // If video fails to load, proceed to meeting
      _transitionToMeeting();
    }
  }

  void _transitionToMeeting() {
    if (_hasFinished) return;
    _hasFinished = true;
    
    // Stop video before transitioning
    try {
      _controller?.pause();
    } catch (e) {
      print('Error pausing video: $e');
    }
    
    // Directly call callback - let parent handle navigation
    widget.onFinished();
  }

  @override
  void dispose() {
    try {
      _controller?.dispose();
    } catch (e) {
      print('Error disposing video controller: $e');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Video Player
          if (_isInitialized && _controller != null)
            Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),

          // Skip button (optional)
          Positioned(
            top: 50,
            right: 20,
            child: GestureDetector(
              onTap: _transitionToMeeting,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  l10n.skip,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),

          // Loading indicator at bottom
          if (_isInitialized && _controller != null && _controller!.value.duration.inMilliseconds > 0)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: _controller!.value.position.inMilliseconds /
                        _controller!.value.duration.inMilliseconds,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.purpleAccent),
                    minHeight: 2,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.preparingForMeeting,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
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
