import 'package:flutter/material.dart';
import 'services/localization_service.dart';

class IntroScreen extends StatefulWidget {
  final VoidCallback onFinish;
  
  const IntroScreen({
    super.key, 
    required this.onFinish,
  });

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;

  List<Map<String, String>> get _slides => [
    {
      'image': 'assets/images/joy66.jpeg',
      'text': l10n.isTurkish ? 'Toplantılara katılabilirsiniz.' : 'You can join meetings.',
    },
    {
      'image': 'assets/images/spking.jpeg',
      'text': l10n.isTurkish ? 'Düşüncelerinizi ve fikirlerinizi paylaşın.' : 'Share your thoughts and opinions.',
    },
    {
      'image': 'assets/images/vdeo.jpeg',
      'text': l10n.isTurkish ? 'Toplantınızı kaydedin ve istediğiniz gibi kullanın.' : 'Record your meeting and use it as you wish.',
    },
    {
      'image': 'assets/images/sharefiles.jpg',
      'text': l10n.isTurkish ? 'Meslektaşlarınızla her türlü dosyayı paylaşın.' : 'Share any files with your colleagues.',
    },
    {
      'image': 'assets/images/top-secret.jpg',
      'text': l10n.isTurkish ? 'Gizli odada arkadaşınızla özel bir görüşme yapın - kimse duyamaz!' : 'Have a private conversation with your friend in a secret room - no one can hear you!',
    },
    {
      'image': 'assets/images/share-link.jpg',
      'text': l10n.isTurkish ? 'Toplantı linkini arkadaşlarınızla paylaşın ve aynı ortamda olun.' : 'Share the meeting link with your friends and be in the same environment.',
    },
    {
      'image': 'assets/images/st4.jpeg',
      'text': l10n.isTurkish ? 'Hadi başlayalım...' : 'Let\'s get started...',
    },
  ];

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _blinkAnimation = Tween<double>(begin: 1.0, end: 0.3).animate(_blinkController);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _blinkController.dispose();
    super.dispose();
  }

  void _finishIntro() {
    widget.onFinish();
  }

  void _nextPage() {
    if (_currentIndex < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finishIntro();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background Images PageView
          PageView.builder(
            controller: _pageController,
            itemCount: _slides.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    _slides[index]['image']!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[900],
                        child: const Center(
                          child: Icon(Icons.image_not_supported, color: Colors.white, size: 50),
                        ),
                      );
                    },
                  ),
                  // Dark gradient overlay for better text visibility
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.8),
                        ],
                        stops: const [0.6, 1.0],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // Skip Button
          Positioned(
            top: 50,
            right: 20,
            child: TextButton(
              onPressed: _finishIntro,
              child: Text(
                l10n.isTurkish ? 'Atla' : 'Skip',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                ),
              ),
            ),
          ),

          // Language Toggle Button
          Positioned(
            top: 50,
            left: 20,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  l10n.toggleLanguage();
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.language, color: Colors.white, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      l10n.isTurkish ? 'TR' : 'EN',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Next Button (Right Side, Above Dots)
          Positioned(
            bottom: 110,
            right: 20,
            child: FadeTransition(
              opacity: _blinkAnimation,
              child: ElevatedButton(
                onPressed: _nextPage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  _currentIndex == _slides.length - 1 
                      ? (l10n.isTurkish ? 'BAŞLA' : 'START') 
                      : (l10n.isTurkish ? 'İLERİ' : 'NEXT'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),

          // Page Indicator (Dots)
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentIndex == index ? Colors.white : Colors.white24,
                  ),
                );
              }),
            ),
          ),

          // Text (Bottom, High Contrast)
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _slides[_currentIndex]['text']!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  shadows: [Shadow(color: Colors.black, blurRadius: 2)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
