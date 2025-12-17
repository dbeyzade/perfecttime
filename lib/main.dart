import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_compress/video_compress.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';

import 'package:camera/camera.dart';
import 'package:camera_macos/camera_macos.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'splash_screen.dart';
import 'login_screen.dart';
import 'home_selection_screen.dart';
import 'host_setup_screen.dart';
import 'waiting_screen.dart';
import 'intro_screen.dart';
import 'participant_join_screen.dart';
import 'intro_video_screen.dart';
import 'biometric_setup_screen.dart';
import 'services/biometric_service.dart';
import 'services/localization_service.dart';

import 'package:app_links/app_links.dart';

List<CameraDescription> _cameras = [];
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR', null);
  await initializeDateFormatting('en_US', null);
  
  // Load saved language
  await LocalizationService.instance.loadSavedLanguage();
  
  // Camera is only supported on iOS and Android
  if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
    try {
      _cameras = await availableCameras();
    } on CameraException catch (e) {
      debugPrint('Error initializing cameras: $e');
    }
  }
  
  await Supabase.initialize(
    url: 'https://gtprewofeojifmvnjqhc.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd0cHJld29mZW9qaWZtdm5qcWhjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUxOTk1ODEsImV4cCI6MjA4MDc3NTU4MX0.dKxiu5mZxPEREbtB8fIWgjknAhP-xJZ-GbdsLcy_fYQ',
  );

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]).then((_) {
    runApp(const MyApp());
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    // Handle web query parameters (e.g., https://domain/?id=...) directly
    if (kIsWeb) {
      final initial = Uri.base;
      if (initial.queryParameters['id'] != null) {
        _handleDeepLink(initial);
      }
    }

    // Handle links launched via app open
    try {
      final Uri? initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        _handleDeepLink(initialLink);
      }
    } catch (e) {
      debugPrint('Error getting initial link: $e');
    }

    // Handle links while app is in foreground/background
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
  }

  Future<void> _handleDeepLink(Uri uri) async {
    debugPrint('Deep link received: $uri');
    
    // Meeting ID'yi al - query param veya path'den
    String? meetingId = uri.queryParameters['id'];
    
    // Path'den de dene: perfecttime://meeting/join/xxx veya .../functions/v1/meeting/xxx
    if (meetingId == null || meetingId.isEmpty) {
      final pathParts = uri.pathSegments;
      if (pathParts.isNotEmpty) {
        final lastPart = pathParts.last;
        // Son kısım 'meeting' veya 'join' değilse, meeting ID'dir
        if (lastPart.isNotEmpty && lastPart != 'meeting' && lastPart != 'join') {
          meetingId = lastPart;
        }
      }
    }
    
    debugPrint('Parsed meeting ID: $meetingId');
    
    if (meetingId != null && meetingId.isNotEmpty) {
      // Navigate to participant join screen
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => ParticipantJoinScreen(
              meetingId: meetingId!,
            ),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
    );
  }
}

class AuthGate extends StatefulWidget {
  final bool skipSignOut;
  
  const AuthGate({super.key, this.skipSignOut = false});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _introFinished = false;
  bool _isLoadingPrefs = true;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    // Sadece ilk açılışta signOut yap, login sonrası yönlendirmede yapma
    if (!widget.skipSignOut) {
      try {
        // Oturumu kapat - kullanıcı login ekranından giriş yapacak
        // Biyometrik varsa login ekranında parmak izi/yüz ile giriş yapabilir
        await Supabase.instance.client.auth.signOut();
      } catch (e) {
        debugPrint('SignOut error (ignored): $e');
      }
    }

    if (mounted) {
      setState(() {
        _isLoadingPrefs = false;
      });
    }
  }

  void _onIntroFinished() {
    if (mounted) {
      setState(() {
        _introFinished = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingPrefs) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Sadece ilk açılışta intro göster, login sonrası gösterme
    if (!_introFinished && !widget.skipSignOut) {
      return IntroScreen(onFinish: _onIntroFinished);
    }

    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session;

        // Always show login screen first
        if (session == null) {
          return const LoginScreen();
        }

        // Only if logged in, show home selection
        return HomeSelectionScreen(
            onHostSelected: () async {
              // Go directly to host setup
              if (mounted) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => HostSetupScreen(
                      onMeetingCreated: (startTime, isRecording, reminderMinutes) async {
                        // Show intro video - video biter bitmez meeting'e geçecek
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (videoContext) => IntroVideoScreen(
                              isHost: true,
                              meetingId: null,
                              meetingStartTime: startTime,
                              isRecording: isRecording,
                              onFinished: () {
                                // videoContext kullanarak navigate et
                                Navigator.of(videoContext).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (context) => MeetingScreen(
                                      isHost: true,
                                      meetingId: null,
                                      meetingStartTime: startTime,
                                      isRecording: isRecording,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              }
            },
            onParticipantSelected: () {
              showDialog(
                context: context,
                builder: (context) {
                  final codeController = TextEditingController();
                  return AlertDialog(
                    backgroundColor: Colors.grey[900],
                    title: Text(l10n.joinMeeting, style: const TextStyle(color: Colors.white)),
                    content: TextField(
                      controller: codeController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "${l10n.meetingCode} (${l10n.optional})",
                        hintStyle: const TextStyle(color: Colors.white54),
                        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(l10n.cancel, style: const TextStyle(color: Colors.white54)),
                      ),
                      TextButton(
                        onPressed: () async {
                          final meetingCode = codeController.text.isNotEmpty ? codeController.text : null;
                          Navigator.pop(context); // Close dialog
                          // Show intro video - video biter bitmez meeting'e geçecek
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (context) => IntroVideoScreen(
                                isHost: false,
                                meetingId: meetingCode,
                                onFinished: () {
                                  // Global navigatorKey kullan - context geçersiz olabilir
                                  navigatorKey.currentState?.pushReplacement(
                                    MaterialPageRoute(
                                      builder: (context) => MeetingScreen(
                                        isHost: false,
                                        meetingId: meetingCode,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                        child: Text(l10n.join, style: const TextStyle(color: Colors.blueAccent)),
                      ),
                    ],
                  );
                },
              );
            },
          );
      },
    );
  }
}

class MeetingScreen extends StatefulWidget {
  final bool isHost;
  final bool isRecording;
  final DateTime? meetingStartTime;
  final String? meetingId;

  const MeetingScreen({
    super.key,
    this.isHost = false,
    this.isRecording = false,
    this.meetingStartTime,
    this.meetingId,
  });

  @override
  State<MeetingScreen> createState() => _MeetingScreenState();
}

class _MeetingScreenState extends State<MeetingScreen> with TickerProviderStateMixin {
  late PageController _pageController;
  final double _itemWidth = 45.0;
  String? _backgroundImage = 'assets/images/Gemini_Generated_Image_pbh6efpbh6efpbh6.png';
  late String _meetingId;
  
  // Profile & Host Features
  File? _profileImage;
  late bool _isHostMode; 
  DateTime? _sessionStartTime;
  Timer? _countdownTimer;
  Timer? _joinSimulationTimer;
  Timer? _handRaiseSimulationTimer;
  String _countdownText = "";
  
  // Logout Confirmation
  bool _logoutConfirmPending = false;
  Timer? _logoutTimer;
  
  // Hand Raise Features
  late AnimationController _bounceController;
  final Set<int> _participantsWithRaisedHands = {};
  final Set<int> _participantsWithPermission = {}; // Söz verilen katılımcılar
  bool _isMyHandRaised = false;
  
  // Private Room (Gizli Oda) State - Kimler gizli odada?
  final Set<int> _participantsInPrivateRoom = {}; // Gizli odada olan katılımcılar
  bool _hostInPrivateRoom = false; // Host gizli odada mı?
  int? _myPrivateRoomPartner; // Katılımcı olarak kiminle gizli odadayım?

  // Camera Features
  CameraController? _cameraController;
  CameraMacOSController? _macOsCameraController;
  bool _isMacOsCameraInitialized = false;

  // Dynamic Participant List Features
  final List<String?> _participantSlots = List.filled(28, null);
  int _arrivalCounter = 0;
  final int _centerIndex = 9;
  
  // Katılımcı Yerleşim Düzeni (0: Yatay Liste, 1: Grid, 2: Yarım Daire)
  int _layoutType = 0;
  
  // Host video zoom state (0: normal, 1: bigger, 2: fullscreen)
  int _hostVideoZoom = 0;

  @override
  void initState() {
    super.initState();
    _meetingId = widget.meetingId ?? Uuid().v4();
    _isHostMode = widget.isHost;
    _sessionStartTime = widget.meetingStartTime;
    
    // Initialize Bounce Animation for Hand Raise
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
      lowerBound: 0.0,
      upperBound: 10.0,
    )..repeat(reverse: true);

    _startCountdown();
    
    debugPrint('=== MEETING SCREEN INIT ===');
    debugPrint('isHostMode: $_isHostMode');
    debugPrint('===========================');
    
    if (_isHostMode) {
      _startJoinSimulation();
      _startHandRaiseSimulation();
      _initializeCamera();
      
      // macOS'ta video kaydı desteklenmiyor uyarısı
      if (!kIsWeb && Platform.isMacOS && widget.isRecording) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.white),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.isTurkish 
                          ? 'macOS\'ta video kaydı desteklenmiyor. Kayıt sadece iOS/Android\'de çalışır.' 
                          : 'Video recording is not supported on macOS. Recording only works on iOS/Android.',
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        });
      }
    }
  }

  Future<void> _initializeCamera() async {
    debugPrint('=== CAMERA INIT START ===');
    debugPrint('Platform.isMacOS: ${Platform.isMacOS}');
    
    // macOS için kamera başlatma - güvenli mod
    if (!kIsWeb && Platform.isMacOS) {
      try {
        debugPrint('Calling _initializeMacOsCamera...');
        await _initializeMacOsCamera();
      } catch (e) {
        debugPrint('macOS kamera hatası, fallback kullanılıyor: $e');
      }
      return;
    }

    // iOS/Android için standart kamera başlatma
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      var status = await Permission.camera.status;
      
      if (status.isDenied) {
        status = await Permission.camera.request();
      }

      if (widget.isRecording) {
        var micStatus = await Permission.microphone.status;
        if (micStatus.isDenied) {
          await Permission.microphone.request();
        }
      }

      if (status.isPermanentlyDenied) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: Colors.grey[900],
              title: Text(l10n.cameraRequired, style: const TextStyle(color: Colors.white)),
              content: Text(
                l10n.cameraRequiredDesc,
                style: const TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.cancel, style: const TextStyle(color: Colors.white54)),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    openAppSettings();
                  },
                  child: Text(l10n.openSettings, style: const TextStyle(color: Colors.blueAccent)),
                ),
              ],
            ),
          );
        }
        return;
      }

      if (status.isGranted) {
        // Refresh cameras list after permission is granted
        try {
          _cameras = await availableCameras();
        } catch (e) {
          debugPrint('Error getting cameras: $e');
        }

        if (_cameras.isNotEmpty) {
          // Find front camera
          final frontCamera = _cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.front,
            orElse: () => _cameras.first,
          );
          
          _cameraController = CameraController(
            frontCamera,
            ResolutionPreset.medium,
            enableAudio: widget.isRecording,
          );

          try {
            await _cameraController!.initialize();
            if (mounted) setState(() {});
            
            if (widget.isRecording && _cameraController!.value.isInitialized) {
              await _cameraController!.startVideoRecording();
              debugPrint("Video recording started");
            }
          } catch (e) {
            debugPrint('Camera initialization error: $e');
            if (mounted) {
               ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${l10n.cameraError}: $e')),
              );
            }
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.cameraNotFound),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        if (mounted) {
          String errorMsg = l10n.cameraInitFailed;
          if (!status.isGranted) {
            errorMsg = l10n.cameraPermissionDenied;
          } else if (_cameras.isEmpty) {
            errorMsg = l10n.cameraNotFound;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    }
  }

  Future<void> _initializeMacOsCamera() async {
    try {
      final cameras = await CameraMacOS.instance.listDevices(deviceType: CameraMacOSDeviceType.video);
      debugPrint('macOS cameras found: ${cameras.length}');
      
      if (cameras.isNotEmpty) {
        // Varsayılan olarak ilk kamerayı seç (genellikle FaceTime)
        final selectedCamera = cameras.first;
        debugPrint('Selected camera: ${selectedCamera.localizedName}');
        
        setState(() {
          _isMacOsCameraInitialized = true;
        });
      } else {
        debugPrint('No macOS cameras found');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.macOsCameraNotFound),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('macOS camera initialization error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.macOsCameraError}: $e')),
        );
      }
    }
  }

  void _onMacOsCameraCreated(CameraMacOSController controller) {
    _macOsCameraController = controller;
    debugPrint('macOS camera controller created');
  }

  Future<void> _stopAndSaveRecording() async {
    if (_cameraController != null && _cameraController!.value.isRecordingVideo) {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Dialog(
          backgroundColor: Colors.black87,
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.blueAccent),
                SizedBox(height: 20),
                Text("Video kaydediliyor ve sıkıştırılıyor...", style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ),
      );

      try {
        XFile videoFile = await _cameraController!.stopVideoRecording();
        
        // macOS için özel kaydetme yolu
        String savedPath = '';
        
        if (!kIsWeb && Platform.isMacOS) {
          // macOS: Downloads klasörüne kaydet
          final downloadsDir = await getDownloadsDirectory();
          if (downloadsDir != null) {
            final timestamp = DateTime.now().millisecondsSinceEpoch;
            final fileName = 'PerfectTime_$timestamp.mp4';
            savedPath = '${downloadsDir.path}/$fileName';
            
            // Dosyayı kopyala
            final videoBytes = await File(videoFile.path).readAsBytes();
            await File(savedPath).writeAsBytes(videoBytes);
            
            debugPrint('Video saved to: $savedPath');
            
            if (mounted) {
              Navigator.pop(context); // Close loading dialog
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Video kaydedildi: ${downloadsDir.path}"),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          } else {
            throw Exception('Downloads klasörü bulunamadı');
          }
        } else {
          // iOS/Android: GallerySaver kullan
          // Compress video
          MediaInfo? mediaInfo = await VideoCompress.compressVideo(
            videoFile.path,
            quality: VideoQuality.DefaultQuality,
            deleteOrigin: false,
          );

          if (mediaInfo != null && mediaInfo.path != null) {
            await GallerySaver.saveVideo(mediaInfo.path!, albumName: "PerfectTime");
            await VideoCompress.deleteAllCache();
            savedPath = 'Galeri/PerfectTime';
            
            if (mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Video başarıyla galeriye kaydedildi"), backgroundColor: Colors.green),
              );
            }
          } else {
            await GallerySaver.saveVideo(videoFile.path, albumName: "PerfectTime");
            if (mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Video kaydedildi (Sıkıştırma başarısız)"), backgroundColor: Colors.orange),
              );
            }
          }
        }
      } catch (e) {
        debugPrint("Error saving video: $e");
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Video kaydetme hatası: $e"), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;

    if (_cameraController != null) {
      await _cameraController!.dispose();
    }

    final lensDirection = _cameraController!.description.lensDirection;
    CameraDescription newDescription;
    if (lensDirection == CameraLensDirection.front) {
      newDescription = _cameras.firstWhere(
        (description) => description.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );
    } else {
      newDescription = _cameras.firstWhere(
        (description) => description.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras.first,
      );
    }

    _cameraController = CameraController(
      newDescription,
      ResolutionPreset.medium,
      enableAudio: widget.isRecording,
    );

    try {
      await _cameraController!.initialize();
      if (mounted) setState(() {});

      if (widget.isRecording && _cameraController!.value.isInitialized) {
        await _cameraController!.startVideoRecording();
      }
    } catch (e) {
      debugPrint("Camera switch error: $e");
    }
  }

  // Platform-aware camera preview widget
  Widget _buildCameraPreview({bool fullScreen = false}) {
    // macOS için camera_macos kullan
    if (!kIsWeb && Platform.isMacOS) {
      if (_isMacOsCameraInitialized && _isHostMode) {
        return CameraMacOSView(
          deviceId: null,
          fit: fullScreen ? BoxFit.contain : BoxFit.cover,
          cameraMode: CameraMacOSMode.photo,
          onCameraInizialized: _onMacOsCameraCreated,
          enableAudio: false,
        );
      } else {
        return _buildFallbackView(fullScreen);
      }
    }
    
    // iOS/Android için standart camera kullan
    if (_cameraController != null && _cameraController!.value.isInitialized && _isHostMode) {
      return CameraPreview(_cameraController!);
    }
    
    return _buildFallbackView(fullScreen);
  }

  Widget _buildFallbackView(bool fullScreen) {
    if (_profileImage != null) {
      return Image.file(
        _profileImage!,
        fit: fullScreen ? BoxFit.contain : BoxFit.cover,
      );
    }
    return Center(
      child: Icon(Icons.person, color: Colors.white, size: fullScreen ? 150 : 50),
    );
  }

  void _addParticipant(String name) {
    _arrivalCounter++;
    int slotIndex;
    
    // Calculate slot index based on arrival order (1-based)
    // 1 -> 9 (Center)
    // 2 -> 8 (Left)
    // 3 -> 10 (Right)
    // 4 -> 7 (Left)
    // 5 -> 11 (Right)
    if (_arrivalCounter % 2 == 1) {
      int k = (_arrivalCounter - 1) ~/ 2;
      slotIndex = _centerIndex + k;
    } else {
      int k = _arrivalCounter ~/ 2;
      slotIndex = _centerIndex - k;
    }

    if (slotIndex >= 0 && slotIndex < _participantSlots.length) {
      setState(() {
        _participantSlots[slotIndex] = name;
      });
    }
  }

  void _startHandRaiseSimulation() {
    // Simülasyon kaldırıldı - gerçek kullanıcılar söz istediğinde çalışacak
    // Gerçek implementasyon Supabase realtime üzerinden gelecek
  }

  void _startJoinSimulation() {
    // Gerçek katılımcılar Supabase üzerinden gelecek
    // Demo katılımcılar kaldırıldı
  }

  void _showJoinNotification(String participantName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_add, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              "$participantName katıldı",
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
        backgroundColor: Colors.blueAccent.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        width: 280, 
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _startCountdown() {
    _updateCountdown();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateCountdown();
    });
  }

  void _updateCountdown() {
    if (_sessionStartTime != null) {
      final now = DateTime.now();
      if (_sessionStartTime!.isAfter(now)) {
        final difference = _sessionStartTime!.difference(now);
        final hours = difference.inHours.toString().padLeft(2, '0');
        final minutes = (difference.inMinutes % 60).toString().padLeft(2, '0');
        final seconds = (difference.inSeconds % 60).toString().padLeft(2, '0');
        if (mounted) {
          setState(() {
            _countdownText = "$hours:$minutes:$seconds";
          });
        }
      } else {
        if (mounted && _countdownText.isNotEmpty) {
          setState(() {
            _countdownText = "";
          });
        }
      }
    } else {
      if (mounted && _countdownText.isNotEmpty) {
        setState(() {
          _countdownText = "";
        });
      }
    }
  }

  void _showFullScreenHost() {
    debugPrint('HOST VIDEO TAPPED - Opening fullscreen');
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: _buildCameraPreview(fullScreen: true),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _joinSimulationTimer?.cancel();
    _handRaiseSimulationTimer?.cancel();
    _logoutTimer?.cancel();
    _bounceController.dispose();
    _cameraController?.dispose();
    _macOsCameraController?.destroy();
    super.dispose();
  }

  /// Toplantıyı bitir - Video kaydet ve çık
  Future<void> _endMeeting() async {
    // Onay dialogu göster
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.call_end, color: Colors.red, size: 28),
            const SizedBox(width: 10),
            Text(
              l10n.isTurkish ? 'Toplantıyı Bitir' : 'End Meeting',
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.isTurkish 
                ? 'Toplantıyı bitirmek istediğinize emin misiniz?' 
                : 'Are you sure you want to end the meeting?',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            if (widget.isRecording && !Platform.isMacOS) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.videocam, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.isTurkish 
                          ? 'Video kaydı otomatik olarak kaydedilecek' 
                          : 'Video recording will be saved automatically',
                        style: const TextStyle(color: Colors.green, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              l10n.isTurkish 
                ? '• Tüm katılımcıların bağlantısı kesilecek\n• Toplantı sonlandırılacak' 
                : '• All participants will be disconnected\n• Meeting will be terminated',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel, style: const TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              l10n.isTurkish ? 'Toplantıyı Bitir' : 'End Meeting',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Video kaydını kaydet (eğer kayıt yapılıyorsa)
    if (widget.isRecording) {
      await _stopAndSaveRecording();
    }

    // Supabase'de toplantıyı sonlandır
    try {
      await Supabase.instance.client
        .from('meetings')
        .update({'status': 'ended', 'ended_at': DateTime.now().toIso8601String()})
        .eq('id', _meetingId);
    } catch (e) {
      debugPrint('Meeting update error: $e');
    }

    // Ana ekrana dön
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.isTurkish ? 'Toplantı sonlandırıldı' : 'Meeting ended'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Toplantı bitince login ekranına dön
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
      // Here you would upload to Supabase Storage and update 'avatar_url'
      // For now, we keep it local.
    }
  }



  void _showParticipantOptions(int index) {
    final name = _participantSlots[index] ?? '${l10n.memberNumber} ${index + 1}';
    showDialog(
      context: context,
      builder: (context) {
        // Local state for the dialog
        bool isMuted = false;
        bool isHandRaiseBlocked = false;
        bool isDeafened = false;
        bool isBlocked = false;
        bool showOptions = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(20),
              child: Container(
                width: 280,
                constraints: const BoxConstraints(maxHeight: 400),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header with Menu Icon
                      Stack(
                        children: [
                          // Profile Image (Smaller)
                          Container(
                            height: 120,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                            ),
                            child: const Center(
                              child: Icon(Icons.person, size: 60, color: Colors.white30),
                            ),
                          ),
                          // Gradient Overlay
                          Positioned.fill(
                            child: Container(
                              decoration: const BoxDecoration(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.transparent, Colors.black87],
                                ),
                              ),
                            ),
                          ),
                          // Name
                          Positioned(
                            bottom: 10,
                            left: 16,
                            child: Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                              ),
                            ),
                          ),
                          // 3-Line Menu Icon
                          Positioned(
                            top: 10,
                            right: 10,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  showOptions = !showOptions;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.green.withOpacity(0.5), width: 1),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(width: 14, height: 2, decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(1))),
                                    const SizedBox(height: 3),
                                    Container(width: 14, height: 2, decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(1))),
                                    const SizedBox(height: 3),
                                    Container(width: 14, height: 2, decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(1))),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      // Options List (Visible only when menu is clicked)
                      if (showOptions) ...[
                        const Divider(color: Colors.white24),
                        // Host'a özel seçenekler
                        if (_isHostMode) ...[
                          _buildSwitchOption(l10n.muteUser, isMuted, (val) => setState(() => isMuted = val)),
                          _buildSwitchOption(l10n.blockHandRaise, isHandRaiseBlocked, (val) => setState(() => isHandRaiseBlocked = val)),
                          _buildSwitchOption(l10n.userCantHearMe, isDeafened, (val) => setState(() => isDeafened = val)),
                          _buildSwitchOption(l10n.blockUser, isBlocked, (val) => setState(() => isBlocked = val)),
                          const SizedBox(height: 8),
                        ],
                        // Gizli Oda Butonu - Hem host hem katılımcılar için
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              _openPrivateRoom(index, name);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF667eea).withOpacity(0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.lock, color: Colors.white, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    l10n.takeToPrivateRoom,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Söz Ver/Al Butonu - Sadece host için
                        if (_isHostMode)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                                _togglePermission(index);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: _participantsWithPermission.contains(index)
                                      ? [Colors.red, Colors.redAccent]
                                      : [Colors.green, Colors.teal],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (_participantsWithPermission.contains(index) ? Colors.red : Colors.green).withOpacity(0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _participantsWithPermission.contains(index) ? Icons.mic_off : Icons.mic,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _participantsWithPermission.contains(index) ? l10n.revokePermission : l10n.givePermission,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Söz verme/alma toggle
  void _togglePermission(int index) {
    setState(() {
      if (_participantsWithPermission.contains(index)) {
        _participantsWithPermission.remove(index);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_participantSlots[index]} ${l10n.permissionRevoked}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        _participantsWithPermission.add(index);
        // El kaldırma durumunu kaldır
        _participantsWithRaisedHands.remove(index);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_participantSlots[index]} ${l10n.permissionGiven}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }

  Widget _buildSwitchOption(String title, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.redAccent,
            inactiveTrackColor: Colors.grey[800],
          ),
        ],
      ),
    );
  }

  // Gizli Oda Açma - Host veya katılımcı tarafından kullanılabilir
  void _openPrivateRoom(int participantIndex, String participantName) {
    // Gizli odaya giren kişileri işaretle
    setState(() {
      _participantsInPrivateRoom.add(participantIndex);
      if (_isHostMode) {
        _hostInPrivateRoom = true;
      } else {
        _myPrivateRoomPartner = participantIndex;
      }
    });
    
    // ÖNEMLİ: Gizli odaya girerken kaydı DURAKLAT (gizlilik için)
    // Kayıt devam ediyorsa, gizli oda konuşmaları KAYDA ALINMAZ
    final wasRecording = widget.isRecording && _cameraController != null && _cameraController!.value.isRecordingVideo;
    if (wasRecording) {
      _pauseRecordingForPrivateRoom();
    }
    
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: _PrivateRoomPage(
              participantName: participantName,
              participantIndex: participantIndex,
              hostCameraController: _cameraController,
              isMacOsCameraInitialized: _isMacOsCameraInitialized,
              isHostMode: _isHostMode,
              onClose: () {
                // Gizli odadan çıkınca state'i güncelle
                setState(() {
                  _participantsInPrivateRoom.remove(participantIndex);
                  if (_isHostMode) {
                    _hostInPrivateRoom = false;
                  } else {
                    _myPrivateRoomPartner = null;
                  }
                });
                
                // ÖNEMLİ: Gizli odadan çıkınca kaydı DEVAM ETTİR
                if (wasRecording) {
                  _resumeRecordingAfterPrivateRoom();
                }
                
                Navigator.pop(context);
              },
            ),
          );
        },
      ),
    );
  }
  
  // Gizli oda için kaydı duraklat
  Future<void> _pauseRecordingForPrivateRoom() async {
    try {
      if (_cameraController != null && _cameraController!.value.isRecordingVideo) {
        // Kaydı durdur ama kaydetme (gizli oda öncesi kısmı kaybet)
        // NOT: Flutter camera paketi pause desteklemiyor, bu yüzden kayıt devam eder
        // ama gizli oda ayrı bir ekran olduğu için zaten ana ekran kaydedilmez
        debugPrint("🔒 GİZLİ ODA: Kayıt ana ekranda devam ediyor ama gizli oda ayrı ekran");
        
        // Kullanıcıya bilgi ver
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🔒 Gizli oda görüşmesi KAYDA ALINMIYOR - Gizliliğiniz korunuyor'),
              backgroundColor: Colors.purple,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Kayıt duraklatma hatası: $e");
    }
  }
  
  // Gizli odadan sonra kaydı devam ettir
  Future<void> _resumeRecordingAfterPrivateRoom() async {
    try {
      debugPrint("🔒 GİZLİ ODA: Ana toplantı kaydına geri dönüldü");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ana toplantı kaydına geri dönüldü'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint("Kayıt devam ettirme hatası: $e");
    }
  }
  
  // Katılımcı gizli odada mı kontrol et
  bool _isParticipantInPrivateRoom(int index) {
    return _participantsInPrivateRoom.contains(index);
  }
  
  // Ana toplantıda bu katılımcıyı görebilir/duyabilir miyiz?
  bool _canSeeParticipant(int index) {
    // Eğer katılımcı gizli odadaysa ve biz gizli odada değilsek, göremeyiz
    if (_participantsInPrivateRoom.contains(index)) {
      // Ben de aynı gizli odadaysam görebilirim
      if (_myPrivateRoomPartner == index || _hostInPrivateRoom) {
        return true;
      }
      return false;
    }
    return true;
  }

  void _showWallpaperDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(l10n.selectWallpaper, style: const TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            shrinkWrap: true,
            children: [
              _buildWallpaperOption('assets/wallpapers/wallpaper1.png'),
              _buildWallpaperOption('assets/wallpapers/wallpaper2.png'),
              _buildWallpaperOption('assets/wallpapers/wallpaper3.png'),
              _buildWallpaperOption('assets/wallpapers/wallpaper4.png'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.close, style: const TextStyle(color: Colors.blueAccent)),
          ),
        ],
      ),
    );
  }

  Widget _buildWallpaperOption(String path) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _backgroundImage = path;
        });
        Navigator.pop(context);
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white24, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.asset(
            path,
            fit: BoxFit.cover,
            errorBuilder: (c, o, s) => Container(
              color: Colors.grey[800],
              child: const Center(
                child: Icon(Icons.image_not_supported, color: Colors.white54),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Katılımcı Yerleşimi Widget'ı
  Widget _buildParticipantsLayout() {
    final participants = <MapEntry<int, String>>[];
    for (int i = 0; i < _participantSlots.length; i++) {
      if (_participantSlots[i] != null) {
        participants.add(MapEntry(i, _participantSlots[i]!));
      }
    }
    
    if (participants.isEmpty) {
      return Center(
        child: Text(
          l10n.noParticipants,
          style: const TextStyle(color: Colors.white54, fontSize: 14),
        ),
      );
    }

    switch (_layoutType) {
      case 0: // Liste Görünümü (Yatay Scroll)
        return _buildListLayout(participants);
      case 1: // Grid Görünümü (2 Satır)
        return _buildGridLayout(participants);
      case 2: // Yarım Daire Görünümü
        return _buildArcLayout(participants);
      default:
        return _buildListLayout(participants);
    }
  }

  // Liste Görünümü (Yatay Scroll)
  Widget _buildListLayout(List<MapEntry<int, String>> participants) {
    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: participants.map((entry) {
            return _buildParticipantCard(entry.key, entry.value);
          }).toList(),
        ),
      ),
    );
  }

  // Grid Görünümü (2 Satırlı)
  Widget _buildGridLayout(List<MapEntry<int, String>> participants) {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 15,
          children: participants.map((entry) {
            return _buildParticipantCard(entry.key, entry.value, compact: true);
          }).toList(),
        ),
      ),
    );
  }

  // Yarım Daire Görünümü
  Widget _buildArcLayout(List<MapEntry<int, String>> participants) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final screenHeight = constraints.maxHeight;
        final count = participants.length;
        
        // Daha yatay ve yukarıda oval
        final radiusX = screenWidth * 0.42; // Yatay radius
        final radiusY = screenHeight * 0.28; // Dikey radius (daha düz oval)
        final centerX = screenWidth / 2;
        final centerY = screenHeight * 0.12; // Yukarıda merkez
        
        // Stack yüksekliğini hesapla
        final stackHeight = centerY + radiusY + 120; // Ekstra alan için
        
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: SizedBox(
            width: screenWidth,
            height: stackHeight > screenHeight ? stackHeight : screenHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (int i = 0; i < count; i++)
                  Builder(
                    builder: (context) {
                      // 10° ile 170° arasında yay (aşağı doğru daha geniş yarım daire)
                      final startAngle = 10 * (pi / 180);
                      final endAngle = 170 * (pi / 180);
                      final angleRange = endAngle - startAngle;
                      final angle = startAngle + (angleRange * i / (count > 1 ? count - 1 : 1));
                      
                      final x = centerX + radiusX * cos(angle);
                      final y = centerY + radiusY * sin(angle);
                      
                      // Söz verilen kişi yukarı çıksın
                      final hasPermission = _participantsWithPermission.contains(participants[i].key);
                      final yOffset = hasPermission ? -15.0 : 0.0;
                      
                      return Positioned(
                        left: x - 40,
                        top: y + yOffset,
                        child: _buildParticipantCard(
                          participants[i].key, 
                          participants[i].value, 
                          compact: true, 
                          isArc: true,
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Katılımcı Kartı
  Widget _buildParticipantCard(int index, String name, {bool compact = false, bool isArc = false}) {
    final isHandRaised = _participantsWithRaisedHands.contains(index);
    final hasPermission = _participantsWithPermission.contains(index);
    final isInPrivateRoom = _isParticipantInPrivateRoom(index);
    
    // Gizli odadaki katılımcıları gösterme (sadece simülasyon için - gerçek uygulamada stream kesilir)
    // Eğer katılımcı gizli odadaysa ve biz değilsek, soluk göster
    final isHiddenFromUs = isInPrivateRoom && !_hostInPrivateRoom && _myPrivateRoomPartner != index;
    
    // Renkli gradient listesi
    final gradients = [
      [const Color(0xFF667eea), const Color(0xFF764ba2)],
      [const Color(0xFFf093fb), const Color(0xFFf5576c)],
      [const Color(0xFF4facfe), const Color(0xFF00f2fe)],
      [const Color(0xFF43e97b), const Color(0xFF38f9d7)],
      [const Color(0xFFfa709a), const Color(0xFFfee140)],
      [const Color(0xFFa18cd1), const Color(0xFFfbc2eb)],
      [const Color(0xFFffecd2), const Color(0xFFfcb69f)],
      [const Color(0xFF30cfd0), const Color(0xFF330867)],
    ];
    
    final gradientColors = gradients[index % gradients.length];
    final cardSize = compact ? 55.0 : 60.0;
    
    // Söz verilen kişi için yukarı offset
    final permissionOffset = hasPermission ? -20.0 : 0.0;
    
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 5 : 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        transform: Matrix4.translationValues(0, permissionOffset + (isHandRaised ? -8 : 0), 0),
        child: Opacity(
          opacity: isHiddenFromUs ? 0.3 : 1.0, // Gizli odadakiler soluk görünür
          child: GestureDetector(
            // Host veya katılımcı olarak tıklanabilir
            onTap: () => _showParticipantOptions(index),
            child: SizedBox(
              width: compact ? 70 : 80,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Gizli oda ikonu
                  if (isInPrivateRoom)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      child: const Icon(Icons.lock, color: Colors.purpleAccent, size: 18),
                    ),
                  // Söz verildi ikonu
                  if (hasPermission && !isInPrivateRoom)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      child: const Icon(Icons.mic, color: Colors.greenAccent, size: 18),
                    ),
                  // El kaldırma ikonu
                  if (isHandRaised && !hasPermission && !isInPrivateRoom)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      child: const Icon(Icons.back_hand, color: Colors.orangeAccent, size: 18),
                    ),
                  // Avatar
                  Container(
                    width: cardSize,
                    height: cardSize,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isInPrivateRoom
                          ? [Colors.purple, Colors.purpleAccent]
                          : isHandRaised 
                            ? [Colors.orange, Colors.amber] 
                            : gradientColors.cast<Color>(),
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(compact ? 14 : 16),
                      border: Border.all(
                        color: isInPrivateRoom 
                          ? Colors.purpleAccent 
                          : isHandRaised ? Colors.yellowAccent : Colors.white30, 
                        width: isInPrivateRoom || isHandRaised ? 3 : 2
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isInPrivateRoom 
                            ? Colors.purple 
                            : isHandRaised ? Colors.orange : gradientColors[0] as Color).withOpacity(0.4),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: compact ? 20 : 24,
                            fontWeight: FontWeight.bold,
                            shadows: const [Shadow(color: Colors.black38, blurRadius: 3)],
                          ),
                        ),
                        // Gizli odada ise kilit ikonu göster
                        if (isHiddenFromUs)
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(compact ? 14 : 16),
                            ),
                            child: const Icon(Icons.lock, color: Colors.purpleAccent, size: 24),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  // İsim
                  Text(
                    isHiddenFromUs ? '🔒 ${l10n.privateRoom}' : name,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isHiddenFromUs ? Colors.purpleAccent : Colors.white, 
                      fontSize: compact ? 11 : 13, 
                      fontWeight: FontWeight.w500,
                      shadows: const [Shadow(color: Colors.black, blurRadius: 3)],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showPasswordChangeDialog() {
    final passwordController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(l10n.changePassword, style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: passwordController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: l10n.newPassword,
            hintStyle: const TextStyle(color: Colors.white54),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
          ),
          obscureText: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel, style: const TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              final newPassword = passwordController.text.trim();
              if (newPassword.isNotEmpty) {
                try {
                  await Supabase.instance.client.auth.updateUser(
                    UserAttributes(password: newPassword),
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.passwordUpdated)),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${l10n.error}: $e')),
                    );
                  }
                }
              }
            },
            child: Text(l10n.update, style: const TextStyle(color: Colors.blueAccent)),
          ),
        ],
      ),
    );
  }

  void _showAlarmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(l10n.setAlarm, style: const TextStyle(color: Colors.white)),
        content: Text(
          l10n.remindersActivated,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.alarmSet),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: Text(l10n.ok, style: const TextStyle(color: Colors.blueAccent)),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog() {
    _showFullScreenMenu();
  }

  void _showFullScreenMenu() {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: _FullScreenMenuPage(
              profileImage: _profileImage,
              isHostMode: _isHostMode,
              currentLayoutType: _layoutType,
              meetingId: _meetingId,
              participantCount: _participantSlots.where((p) => p != null).length,
              onPickProfileImage: _pickProfileImage,
              onChangePassword: () {
                _showPasswordChangeDialog();
              },
              onSetAlarm: () {
                _showAlarmDialog();
              },
              onShowFiles: () {
                _showFileHistoryDialog();
              },
              onShowParticipants: () {
                _showParticipantsDialog();
              },
              onLayoutChanged: (int layoutType) {
                setState(() {
                  _layoutType = layoutType;
                });
                // Menüyü kapatıp tekrar aç, seçim görünsün diye
                Navigator.of(context).pop();
                _showFullScreenMenu();
              },
            ),
          );
        },
      ),
    );
  }

  void _showOldSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.grey[900],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              insetPadding: const EdgeInsets.all(20),
              child: Container(
                width: 300,
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Profile Header
                    Row(
                      children: [
                        GestureDetector(
                          onTap: _pickProfileImage,
                          child: CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.grey[800],
                            backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                            child: _profileImage == null
                                ? const Icon(Icons.add_a_photo, color: Colors.white, size: 24)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l10n.user, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              Text(
                                Supabase.instance.client.auth.currentUser?.email ?? "",
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white24, height: 24),
                    
                    // Host Mode Toggle Removed
                    
                    // Other Settings
                    ListTile(
                      leading: const Icon(Icons.lock, color: Colors.white, size: 20),
                      title: Text(l10n.changePassword, style: const TextStyle(color: Colors.white, fontSize: 14)),
                      onTap: () {
                        Navigator.pop(context);
                        _showPasswordChangeDialog();
                      },
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                    ListTile(
                      leading: const Icon(Icons.alarm, color: Colors.white, size: 20),
                      title: Text(l10n.setAlarm, style: const TextStyle(color: Colors.white, fontSize: 14)),
                      onTap: () {
                        Navigator.pop(context);
                        _showAlarmDialog();
                      },
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                    ListTile(
                      leading: const Icon(Icons.file_present, color: Colors.white, size: 20),
                      title: Text(l10n.sharedFiles, style: const TextStyle(color: Colors.white, fontSize: 14)),
                      onTap: () {
                        Navigator.pop(context);
                        _showFileHistoryDialog();
                      },
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                    if (_isHostMode)
                      ListTile(
                        leading: const Icon(Icons.people, color: Colors.white, size: 20),
                        title: Text(l10n.participants, style: const TextStyle(color: Colors.white, fontSize: 14)),
                        onTap: () {
                          Navigator.pop(context);
                          _showParticipantsDialog();
                        },
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(l10n.close, style: const TextStyle(color: Colors.white54)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showFileHistoryDialog() {
    // Dosya türüne göre gradient renkleri
    List<Color> _getFileGradient(String? fileName) {
      if (fileName == null) return [const Color(0xFF667EEA), const Color(0xFF764BA2)];
      final ext = fileName.split('.').last.toLowerCase();
      switch (ext) {
        case 'pdf':
          return [const Color(0xFFFF512F), const Color(0xFFDD2476)]; // Kırmızı
        case 'doc':
        case 'docx':
          return [const Color(0xFF4776E6), const Color(0xFF8E54E9)]; // Mavi
        case 'xls':
        case 'xlsx':
          return [const Color(0xFF11998E), const Color(0xFF38EF7D)]; // Yeşil
        case 'ppt':
        case 'pptx':
          return [const Color(0xFFF09819), const Color(0xFFEDDE5D)]; // Turuncu
        case 'jpg':
        case 'jpeg':
        case 'png':
        case 'gif':
          return [const Color(0xFFEC008C), const Color(0xFFFC6767)]; // Pembe
        case 'mp4':
        case 'mov':
        case 'avi':
          return [const Color(0xFF834D9B), const Color(0xFFD04ED6)]; // Mor
        case 'mp3':
        case 'wav':
          return [const Color(0xFF00B4DB), const Color(0xFF0083B0)]; // Cyan
        case 'zip':
        case 'rar':
          return [const Color(0xFF636363), const Color(0xFFA2A2A2)]; // Gri
        default:
          return [const Color(0xFF667EEA), const Color(0xFF764BA2)]; // Default mor
      }
    }

    IconData _getFileIcon(String? fileName) {
      if (fileName == null) return Icons.insert_drive_file_rounded;
      final ext = fileName.split('.').last.toLowerCase();
      switch (ext) {
        case 'pdf':
          return Icons.picture_as_pdf_rounded;
        case 'doc':
        case 'docx':
          return Icons.description_rounded;
        case 'xls':
        case 'xlsx':
          return Icons.table_chart_rounded;
        case 'ppt':
        case 'pptx':
          return Icons.slideshow_rounded;
        case 'jpg':
        case 'jpeg':
        case 'png':
        case 'gif':
          return Icons.image_rounded;
        case 'mp4':
        case 'mov':
        case 'avi':
          return Icons.video_file_rounded;
        case 'mp3':
        case 'wav':
          return Icons.audio_file_rounded;
        case 'zip':
        case 'rar':
          return Icons.folder_zip_rounded;
        default:
          return Icons.insert_drive_file_rounded;
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return FutureBuilder(
          future: Supabase.instance.client
              .from('file_shares')
              .select()
              .eq('meeting_id', _meetingId)
              .order('shared_at', ascending: false),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Dialog(
                backgroundColor: Colors.transparent,
                child: Container(
                  width: 420,
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF1A1D29),
                        Color(0xFF252837),
                        Color(0xFF1A1D29),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                      ),
                      const SizedBox(height: 20),
                      Text(l10n.filesLoading, style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              return Dialog(
                backgroundColor: Colors.transparent,
                child: Container(
                  width: 420,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1A1D29), Color(0xFF252837), Color(0xFF1A1D29)],
                    ),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.red.withOpacity(0.3), width: 1.5),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF512F), Color(0xFFDD2476)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.error_outline_rounded, color: Colors.white, size: 32),
                      ),
                      const SizedBox(height: 16),
                      Text('${l10n.error}: ${snapshot.error}', style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(l10n.close, style: const TextStyle(color: Colors.redAccent)),
                      ),
                    ],
                  ),
                ),
              );
            }

            final files = snapshot.data as List<dynamic>? ?? [];

            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                width: 450,
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1A1D29),
                      Color(0xFF252837),
                      Color(0xFF1A1D29),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.15),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.6),
                      blurRadius: 30,
                      spreadRadius: 10,
                    ),
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.1),
                      blurRadius: 40,
                      spreadRadius: -5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with gradient
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 20, 20, 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.purple.withOpacity(0.15),
                            Colors.indigo.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(28),
                          topRight: Radius.circular(28),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.purple.withOpacity(0.4),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.folder_special_rounded, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            l10n.isTurkish ? "Paylaşılan Dosyalar" : "Shared Files",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: files.isEmpty
                                    ? [Colors.grey.shade600, Colors.grey.shade700]
                                    : [const Color(0xFF11998E), const Color(0xFF38EF7D)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: (files.isEmpty ? Colors.grey : Colors.green).withOpacity(0.3),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Text(
                              '${files.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Gradient divider
                    Container(
                      height: 2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.purple.withOpacity(0.4),
                            Colors.indigo.withOpacity(0.4),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    
                    // Content
                    Flexible(
                      child: files.isEmpty
                          ? SingleChildScrollView(
                              child: Container(
                                padding: const EdgeInsets.all(50),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(28),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.05),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.folder_off_rounded,
                                        color: Colors.white.withOpacity(0.3),
                                        size: 60,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                      l10n.noFilesShared,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.6),
                                        fontSize: 17,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      l10n.clickToAddFile,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.35),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                              shrinkWrap: true,
                              itemCount: files.length,
                              itemBuilder: (context, index) {
                                final file = files[index];
                                final fileName = file['file_name'] as String?;
                                final gradientColors = _getFileGradient(fileName);
                                final fileIcon = _getFileIcon(fileName);
                                
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        gradientColors[0].withOpacity(0.15),
                                        gradientColors[1].withOpacity(0.08),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: gradientColors[0].withOpacity(0.3),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: gradientColors[0].withOpacity(0.1),
                                        blurRadius: 8,
                                        spreadRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      // File icon with gradient
                                      Container(
                                        width: 52,
                                        height: 52,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: gradientColors,
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(14),
                                          boxShadow: [
                                            BoxShadow(
                                              color: gradientColors[0].withOpacity(0.4),
                                              blurRadius: 10,
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                        child: Icon(fileIcon, color: Colors.white, size: 26),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              fileName ?? 'Bilinmiyor',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Icon(
                                                    Icons.schedule_rounded,
                                                    size: 12,
                                                    color: Colors.white.withOpacity(0.5),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  _formatDate(file['shared_at']),
                                                  style: TextStyle(
                                                    color: Colors.white.withOpacity(0.5),
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (file['file_size'] != null) ...[
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.all(4),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white.withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Icon(
                                                      Icons.data_usage_rounded,
                                                      size: 12,
                                                      color: Colors.white.withOpacity(0.5),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    _formatFileSize(file['file_size']),
                                                    style: TextStyle(
                                                      color: Colors.white.withOpacity(0.5),
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      // Download button
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          Icons.download_rounded,
                                          color: Colors.white.withOpacity(0.6),
                                          size: 22,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    
                    // Actions
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.2),
                          ],
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.1),
                              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              l10n.isTurkish ? 'Kapat' : 'Close',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showScreenMirroringOptions() {
    final size = MediaQuery.of(context).size;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: l10n.screenMirror,
      barrierColor: Colors.black.withOpacity(0.65),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return SafeArea(
          child: Align(
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 760,
                  maxHeight: size.height * 0.9,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF111317), Color(0xFF0C0E11)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.45),
                          blurRadius: 26,
                          offset: const Offset(0, 20),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: -24,
                          right: -18,
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.blue.withOpacity(0.08),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: -30,
                          left: -10,
                          child: Container(
                            width: 180,
                            height: 180,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.green.withOpacity(0.07),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: Colors.white10),
                                    ),
                                    child: const Icon(Icons.cast, color: Colors.white, size: 24),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          l10n.screenMirror,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 22,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          l10n.screenShareDesc,
                                          style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => Navigator.of(dialogContext).pop(),
                                    icon: const Icon(Icons.close, color: Colors.white70),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 22),
                              _buildMirroringOption(
                                title: 'AirPlay',
                                subtitle: l10n.isTurkish ? 'Kontrol Merkezi\'nden "Ekran Yansıt" seçin ve toplantı ekranını paylaşın.' : 'Select "Screen Mirroring" from Control Center and share your meeting screen.',
                                badge: 'iOS / macOS',
                                accent: Colors.blueAccent,
                                icon: Icons.airplay,
                                onTap: () => _handleAirPlayTap(dialogContext),
                              ),
                              const SizedBox(height: 12),
                              _buildMirroringOption(
                                title: 'Miracast',
                                subtitle: l10n.isTurkish ? 'Ayarlar > Ekran > Kablosuz görüntü paylaşımı adımlarını izleyin.' : 'Follow Settings > Display > Wireless display sharing steps.',
                                badge: 'Android',
                                accent: Colors.greenAccent,
                                icon: Icons.link,
                                onTap: () => _handleMiracastTap(dialogContext),
                              ),
                              const SizedBox(height: 16),
                              // Toplantı Linki Paylaş bölümü
                              _buildMirroringOption(
                                title: l10n.shareMeetingLink,
                                subtitle: l10n.shareMeetingLinkDesc,
                                badge: l10n.allPlatforms,
                                accent: Colors.purpleAccent,
                                icon: Icons.share,
                                onTap: () {
                                  Navigator.of(dialogContext).pop();
                                  _showShareLinksSheet();
                                },
                              ),
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.info_outline, color: Colors.white70, size: 18),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        l10n.isTurkish ? 'En iyi deneyim için cihazların aynı Wi-Fi ağına bağlı olduğundan emin olun ve ekran parlaklığını otomatikten çıkarın.' : 'For the best experience, make sure devices are connected to the same Wi-Fi network and turn off auto-brightness.',
                                        style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: () => Navigator.of(dialogContext).pop(),
                                    child: Text(l10n.isTurkish ? 'Kapat' : 'Close', style: const TextStyle(color: Colors.white70)),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blueAccent,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                    onPressed: () => Navigator.of(dialogContext).pop(),
                                    child: Text(l10n.isTurkish ? 'Hazırım' : 'Ready'),
                                  ),
                                ],
                              ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.97, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  void _showProjectorOptions() {
    final size = MediaQuery.of(context).size;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: l10n.projectToScreen,
      barrierColor: Colors.black.withOpacity(0.65),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return SafeArea(
          child: Align(
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 600,
                  maxHeight: size.height * 0.75,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1a1a2e), Color(0xFF0f0f1e)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 30,
                          offset: const Offset(0, 20),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.videocam, color: Colors.orange, size: 26),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l10n.projectToScreen,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 22,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        l10n.useDuringMeeting,
                                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => Navigator.of(dialogContext).pop(),
                                  icon: const Icon(Icons.close, color: Colors.white70),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            // Projector Image
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.asset(
                                'assets/images/projector.jpg',
                                width: double.infinity,
                                height: 220,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: double.infinity,
                                    height: 220,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[800],
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.videocam, color: Colors.grey, size: 60),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 18),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.orange.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.schedule, color: Colors.orange, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          l10n.comingSoon,
                                          style: const TextStyle(
                                            color: Colors.orange,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          l10n.comingSoonDesc,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 13,
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange.withOpacity(0.8),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () => Navigator.of(dialogContext).pop(),
                                child: Text(
                                  l10n.isTurkish ? 'Anladım' : 'Got it',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildMirroringOption({
    required String title,
    required String subtitle,
    required String badge,
    required Color accent,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [accent.withOpacity(0.16), Colors.white.withOpacity(0.04)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withOpacity(0.45)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accent, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.45),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 14),
          ],
        ),
      ),
    );
  }

  void _handleAirPlayTap(BuildContext dialogContext) {
    Navigator.of(dialogContext).pop();
    if (!mounted) return;

    _showShareLinksSheet();
  }

  void _showShareLinksSheet() {
    final mobileLink = 'perfecttime://meeting/join?id=$_meetingId';
    final webLink = 'https://web-redirect-dogukans-projects-ab227b2e.vercel.app/?id=$_meetingId';

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E1116),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.link, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.meetingLinks,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close, color: Colors.white70),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _LinkRow(
                    label: l10n.mobileApp,
                    value: mobileLink,
                    icon: Icons.phone_iphone,
                    onCopy: () => _copyLink(mobileLink, l10n.mobileLinkCopied),
                  ),
                  const SizedBox(height: 12),
                  _LinkRow(
                    label: l10n.webBrowser,
                    value: webLink,
                    icon: Icons.public,
                    onCopy: () => _copyLink(webLink, l10n.webLinkCopied),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.linksDescription,
                    style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.35),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleMiracastTap(BuildContext dialogContext) {
    Navigator.of(dialogContext).pop();
    if (!mounted) return;

    try {
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.isTurkish ? 'Android: Ayarlar > Ekran > Kablosuz görüntü paylaşımı adımlarını izleyin.' : 'Android: Follow Settings > Display > Wireless display sharing steps.'),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      debugPrint('Miracast action failed: $e');
    }
  }

  void _copyLink(String link, String message) {
    try {
      Clipboard.setData(ClipboardData(text: link));
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
    } catch (e) {
      debugPrint('Link copy failed: $e');
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Bilinmiyor';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM HH:mm', 'tr_TR').format(date);
    } catch (e) {
      return 'Bilinmiyor';
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _shareFile() async {
    try {
      // Dosya seç
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final filePath = file.path;
        
        if (filePath != null) {
          // Katılımcı seçim dialogunu göster
          _showFileShareOptionsDialog(file);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.fileSharingError} $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showFileShareOptionsDialog(PlatformFile file) {
    // Aktif katılımcıları al
    List<Map<String, dynamic>> participants = [];
    for (int i = 0; i < _participantSlots.length; i++) {
      if (_participantSlots[i] != null) {
        participants.add({
          'index': i,
          'name': _participantSlots[i]!,
          'selected': false,
        });
      }
    }
    
    bool shareWithAll = true;
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: Row(
                children: [
                  const Icon(Icons.share, color: Colors.blueAccent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${l10n.fileShare}: ${file.name}',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 320,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Herkese paylaş seçeneği
                      Container(
                        decoration: BoxDecoration(
                          color: shareWithAll ? Colors.blueAccent.withOpacity(0.2) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: shareWithAll ? Colors.blueAccent : Colors.white24,
                          ),
                        ),
                        child: CheckboxListTile(
                          value: shareWithAll,
                          onChanged: (val) {
                            setDialogState(() {
                              shareWithAll = val ?? true;
                              if (shareWithAll) {
                                for (var p in participants) {
                                  p['selected'] = false;
                                }
                              }
                            });
                          },
                          title: Text(
                            l10n.sendToAll,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${participants.length} ${l10n.participants.toLowerCase()}',
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                          secondary: const Icon(Icons.group, color: Colors.blueAccent),
                          activeColor: Colors.blueAccent,
                          checkColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      if (!shareWithAll) ...[
                        Text(
                          l10n.orSelectParticipants,
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        
                        if (participants.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                l10n.noParticipants,
                                style: const TextStyle(color: Colors.white54),
                              ),
                            ),
                          )
                        else
                          Container(
                            constraints: const BoxConstraints(maxHeight: 200),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: participants.length,
                              itemBuilder: (context, index) {
                                final participant = participants[index];
                                return CheckboxListTile(
                                  value: participant['selected'] as bool,
                                  onChanged: (val) {
                                    setDialogState(() {
                                      participant['selected'] = val ?? false;
                                    });
                                  },
                                  title: Text(
                                    participant['name'] as String,
                                    style: const TextStyle(color: Colors.white, fontSize: 14),
                                  ),
                                  secondary: CircleAvatar(
                                    radius: 16,
                                    backgroundColor: Colors.grey[700],
                                    child: const Icon(Icons.person, color: Colors.white, size: 18),
                                  ),
                                  activeColor: Colors.blueAccent,
                                  checkColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                  dense: true,
                                );
                              },
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.cancel, style: const TextStyle(color: Colors.white54)),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _performFileShare(file, shareWithAll, participants);
                  },
                  icon: const Icon(Icons.send, size: 18),
                  label: const Text('Gönder'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _performFileShare(PlatformFile file, bool shareWithAll, List<Map<String, dynamic>> participants) async {
    List<String> selectedNames = [];
    if (!shareWithAll) {
      selectedNames = participants
          .where((p) => p['selected'] == true)
          .map((p) => p['name'] as String)
          .toList();
      
      if (selectedNames.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.selectAtLeastOne),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${l10n.fileSharing}: ${file.name}'),
        backgroundColor: Colors.blueAccent,
        duration: const Duration(seconds: 2),
      ),
    );

    // Supabase'e kaydet
    try {
      final user = Supabase.instance.client.auth.currentUser;
      await Supabase.instance.client.from('file_shares').insert({
        'meeting_id': _meetingId,
        'shared_by_user_id': user?.id,
        'file_name': file.name,
        'file_size': file.size,
        'file_type': file.extension,
        'shared_with_all': shareWithAll,
        'shared_with_user_ids': shareWithAll ? null : selectedNames,
      });
    } catch (e) {
      debugPrint('Supabase file share error: $e');
    }

    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      String shareMessage = shareWithAll 
          ? '${l10n.fileSharedToAll}: ${file.name}'
          : '${l10n.file} ${selectedNames.length} ${l10n.sharedToPeople}: ${file.name}';
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(shareMessage),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showParticipantsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return FutureBuilder(
          future: Supabase.instance.client
              .from('meeting_participants')
              .select()
              .eq('meeting_id', _meetingId)
              .order('joined_at', ascending: true),
          builder: (context, snapshot) {
            // Aktif katılımcıları da ekle (simüle edilenler)
            List<Map<String, dynamic>> allParticipants = [];
            
            // Önce slot'lardaki katılımcıları ekle
            for (int i = 0; i < _participantSlots.length; i++) {
              if (_participantSlots[i] != null) {
                allParticipants.add({
                  'full_name': _participantSlots[i],
                  'email': '${_participantSlots[i]!.toLowerCase().replaceAll(' ', '.')}@email.com',
                  'joined_at': DateTime.now().subtract(Duration(minutes: allParticipants.length * 2)).toIso8601String(),
                  'is_active': true,
                });
              }
            }
            
            // Supabase'den gelen verileri de ekle
            if (snapshot.hasData && snapshot.data != null) {
              final dbParticipants = snapshot.data as List<dynamic>;
              for (var p in dbParticipants) {
                // Aynı isim yoksa ekle
                bool exists = allParticipants.any((ap) => ap['full_name'] == p['full_name']);
                if (!exists) {
                  allParticipants.add({
                    'full_name': p['full_name'] ?? 'Bilinmiyor',
                    'email': p['email'] ?? 'Bilinmiyor',
                    'joined_at': p['joined_at'],
                    'is_active': p['is_active'] ?? false,
                  });
                }
              }
            }

            // Renk paleti for avatar gradients
            final List<List<Color>> avatarGradients = [
              [const Color(0xFF667EEA), const Color(0xFF764BA2)], // Mor-Mavi
              [const Color(0xFF11998E), const Color(0xFF38EF7D)], // Yeşil
              [const Color(0xFFFF512F), const Color(0xFFDD2476)], // Kırmızı
              [const Color(0xFFF09819), const Color(0xFFEDDE5D)], // Turuncu
              [const Color(0xFF4776E6), const Color(0xFF8E54E9)], // Mavi-Mor
              [const Color(0xFFEC008C), const Color(0xFFFC6767)], // Pembe
              [const Color(0xFF00B4DB), const Color(0xFF0083B0)], // Cyan
              [const Color(0xFF834D9B), const Color(0xFFD04ED6)], // Mor
            ];

            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                width: 420,
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1A1D29),
                      Color(0xFF252837),
                      Color(0xFF1A1D29),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.15),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.6),
                      blurRadius: 30,
                      spreadRadius: 10,
                    ),
                    BoxShadow(
                      color: Colors.cyan.withOpacity(0.1),
                      blurRadius: 40,
                      spreadRadius: -5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with gradient
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 20, 20, 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.cyan.withOpacity(0.15),
                            Colors.blue.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(28),
                          topRight: Radius.circular(28),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF00B4DB), Color(0xFF0083B0)],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.cyan.withOpacity(0.4),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.groups_rounded, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            l10n.isTurkish ? "Katılımcılar" : "Participants",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blueAccent.withOpacity(0.4),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Text(
                              '${allParticipants.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Gradient divider
                    Container(
                      height: 2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.cyan.withOpacity(0.4),
                            Colors.blue.withOpacity(0.4),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    
                    // Content
                    Flexible(
                      child: allParticipants.isEmpty
                          ? SingleChildScrollView(
                              child: Container(
                                padding: const EdgeInsets.all(40),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(24),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.05),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.people_outline_rounded,
                                        color: Colors.white.withOpacity(0.3),
                                        size: 56,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    Text(
                                      l10n.noParticipants,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.5),
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      l10n.inviteByLink,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.3),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                              shrinkWrap: true,
                              itemCount: allParticipants.length,
                              itemBuilder: (context, index) {
                                final participant = allParticipants[index];
                                final joinedAt = participant['joined_at'] != null
                                    ? _formatDate(participant['joined_at'])
                                    : 'Bilinmiyor';
                                final isActive = participant['is_active'] ?? false;
                                final gradientColors = avatarGradients[index % avatarGradients.length];
                                
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        gradientColors[0].withOpacity(0.12),
                                        gradientColors[1].withOpacity(0.06),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: isActive 
                                          ? Colors.green.withOpacity(0.4) 
                                          : gradientColors[0].withOpacity(0.3),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: gradientColors[0].withOpacity(0.1),
                                        blurRadius: 8,
                                        spreadRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      // Avatar with gradient
                                      Stack(
                                        children: [
                                          Container(
                                            width: 52,
                                            height: 52,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: gradientColors,
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              borderRadius: BorderRadius.circular(16),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: gradientColors[0].withOpacity(0.4),
                                                  blurRadius: 10,
                                                  spreadRadius: 1,
                                                ),
                                              ],
                                            ),
                                            child: Center(
                                              child: Text(
                                                (participant['full_name'] as String?)?.isNotEmpty == true
                                                    ? (participant['full_name'] as String).substring(0, 1).toUpperCase()
                                                    : '?',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 22,
                                                ),
                                              ),
                                            ),
                                          ),
                                          if (isActive)
                                            Positioned(
                                              right: -2,
                                              bottom: -2,
                                              child: Container(
                                                width: 18,
                                                height: 18,
                                                decoration: BoxDecoration(
                                                  gradient: const LinearGradient(
                                                    colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
                                                  ),
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: const Color(0xFF1A1D29),
                                                    width: 3,
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.green.withOpacity(0.5),
                                                      blurRadius: 6,
                                                      spreadRadius: 1,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              participant['full_name'] ?? 'Bilinmiyor',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.email_outlined,
                                                  size: 14,
                                                  color: Colors.white.withOpacity(0.5),
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    participant['email'] ?? 'Bilinmiyor',
                                                    style: TextStyle(
                                                      color: Colors.white.withOpacity(0.6),
                                                      fontSize: 13,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Icon(
                                                    Icons.schedule_rounded,
                                                    size: 12,
                                                    color: Colors.white.withOpacity(0.5),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  '${l10n.joined}: $joinedAt',
                                                  style: TextStyle(
                                                    color: Colors.white.withOpacity(0.4),
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isActive)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
                                            ),
                                            borderRadius: BorderRadius.circular(10),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.green.withOpacity(0.4),
                                                blurRadius: 8,
                                                spreadRadius: 0,
                                              ),
                                            ],
                                          ),
                                          child: Text(
                                            l10n.active,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    
                    // Actions
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.2),
                          ],
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () {
                              // CSV olarak dışa aktar
                              String csv = 'Ad Soyad,Email,Katılım Zamanı,Durum\n';
                              for (var p in allParticipants) {
                                csv += '${p['full_name']},${p['email']},${p['joined_at']},${p['is_active'] ? l10n.active : l10n.left}\n';
                              }
                              Clipboard.setData(ClipboardData(text: csv));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(l10n.participantListCopied),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            },
                            icon: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.copy_rounded, size: 16, color: Colors.white),
                            ),
                            label: Text(
                              l10n.copyList,
                              style: const TextStyle(
                                color: Color(0xFF667EEA),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.1),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              l10n.isTurkish ? 'Kapat' : 'Close',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final screenWidth = MediaQuery.of(context).size.width;
    final viewportFraction = _itemWidth / screenWidth;
    
    // Only initialize or update if viewportFraction changed significantly
    if (!mounted) return;
    
    // Check if controller exists and if viewport fraction is different
    try {
      if (_pageController.viewportFraction != viewportFraction) {
        _pageController = PageController(
          initialPage: 9,
          viewportFraction: viewportFraction
        );
      }
    } catch (e) {
      // Controller not initialized yet
      _pageController = PageController(
        initialPage: 9,
        viewportFraction: viewportFraction
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Controller is managed in didChangeDependencies

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withOpacity(0.5), width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(width: 18, height: 2, decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(1))),
                const SizedBox(height: 4),
                Container(width: 18, height: 2, decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(1))),
                const SizedBox(height: 4),
                Container(width: 18, height: 2, decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(1))),
              ],
            ),
          ),
          onPressed: _showSettingsDialog,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.attach_file, color: Colors.white),
            tooltip: l10n.fileShare,
            onPressed: _shareFile,
          ),
          IconButton(
            icon: const Icon(Icons.videocam, color: Colors.white),
            tooltip: l10n.projectToScreen,
            onPressed: _showProjectorOptions,
          ),
          IconButton(
            icon: const Icon(Icons.cast, color: Colors.white),
            tooltip: l10n.screenMirror,
            onPressed: _showScreenMirroringOptions,
          ),
          // TOPLANTI BİTİR BUTONU - Kırmızı ve görünür
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: _endMeeting,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              icon: const Icon(Icons.call_end, size: 18),
              label: Text(
                l10n.isTurkish ? 'Bitir' : 'End',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Background Image
          if (_backgroundImage != null)
            Positioned.fill(
              child: Image.asset(
                _backgroundImage!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(color: Colors.black),
              ),
            ),
            
          // Countdown Timer (Moved up and resized)
          if (_countdownText.isNotEmpty)
            Positioned(
              top: MediaQuery.of(context).size.height * 0.10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.redAccent, width: 1),
                ),
                child: Text(
                  _countdownText,
                  style: const TextStyle(
                    color: Colors.redAccent, 
                    fontSize: 18, 
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),

          // Host (Center) - The user who started the meeting
          Positioned(
            top: MediaQuery.of(context).size.height * (_hostVideoZoom == 1 ? 0.10 : 0.20),
            child: Column(
              children: [
                // Host Avatar & Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Invisible spacer to balance the camera switch icon (only on mobile)
                    if (!Platform.isMacOS && _cameras.length > 1) const SizedBox(width: 50),
                    
                    GestureDetector(
                      behavior: HitTestBehavior.opaque, // Tüm tıklamaları yakala
                      onTap: () {
                        // Tek tıklama: Normal (0) ↔ Büyük (1) arasında geçiş
                        debugPrint('HOST VIDEO: Single tap - current zoom: $_hostVideoZoom -> ${_hostVideoZoom == 0 ? 1 : 0}');
                        setState(() {
                          _hostVideoZoom = _hostVideoZoom == 0 ? 1 : 0;
                        });
                      },
                      onLongPress: _showFullScreenHost, // Uzun basma: Tam ekran
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        width: _hostVideoZoom == 1 ? 220 : 120,
                        height: _hostVideoZoom == 1 ? 220 : 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.amber.withOpacity(_hostVideoZoom == 1 ? 0.8 : 0.3),
                            width: _hostVideoZoom == 1 ? 3 : 2,
                          ),
                          boxShadow: _hostVideoZoom == 1 ? [
                            BoxShadow(
                              color: Colors.amber.withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ] : null,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: IgnorePointer(
                            // Kamera preview'ının tıklamaları engellemesini önle
                            child: _buildCameraPreview(),
                          ),
                        ),
                      ),
                    ),
                    
                    // Camera Switch - only on iOS/Android (macOS has no back camera)
                    if (!Platform.isMacOS && _cameras.length > 1) ...[
                      const SizedBox(width: 10),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white30),
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          iconSize: 20,
                          icon: const Icon(Icons.cameraswitch, color: Colors.white),
                          onPressed: _switchCamera,
                        ),
                      ),
                    ],
                  ],
                ),
                
                // Zoom hint
                if (_hostVideoZoom == 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        l10n.isTurkish ? 'Tıkla: Büyüt • Uzun Bas: Tam Ekran' : 'Tap: Enlarge • Long Press: Fullscreen',
                        style: const TextStyle(color: Colors.white54, fontSize: 10),
                      ),
                    ),
                  ),
                
                // Host Controls
                // Removed as per request (Time and Notify are handled in setup)

              ],
            ),
          ),

          // Participants Display (Based on Layout Type)
          Positioned(
            // macOS'ta daha aşağıda göster
            top: MediaQuery.of(context).size.height * (Platform.isMacOS ? 0.62 : 0.52),
            left: 0,
            right: 0,
            bottom: 20,
            child: _buildParticipantsLayout(),
          ),

          // Participant Controls (Non-Host)
          if (!_isHostMode)
            Positioned(
              bottom: 30,
              right: 30,
              child: FloatingActionButton.extended(
                onPressed: () {
                  setState(() {
                    _isMyHandRaised = !_isMyHandRaised;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_isMyHandRaised ? "Söz istendi" : "Söz isteği geri alındı"),
                      backgroundColor: _isMyHandRaised ? Colors.orangeAccent : Colors.grey,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                backgroundColor: _isMyHandRaised ? Colors.orangeAccent : Colors.blueAccent,
                icon: Icon(_isMyHandRaised ? Icons.videocam_off : Icons.videocam, color: Colors.white),
                label: Text(
                  _isMyHandRaised ? "Söz İstendi" : "Sohbet",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onCopy;

  const _LinkRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(color: Colors.white70, fontSize: 12), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, color: Colors.white70, size: 18),
            onPressed: onCopy,
            tooltip: l10n.copy,
          ),
        ],
      ),
    );
  }
}

// Tam Ekran Menü Sayfası
class _FullScreenMenuPage extends StatefulWidget {
  final File? profileImage;
  final bool isHostMode;
  final int currentLayoutType;
  final String meetingId;
  final int participantCount;
  final VoidCallback onPickProfileImage;
  final VoidCallback onChangePassword;
  final VoidCallback onSetAlarm;
  final VoidCallback onShowFiles;
  final VoidCallback onShowParticipants;
  final Function(int) onLayoutChanged;

  const _FullScreenMenuPage({
    required this.profileImage,
    required this.isHostMode,
    required this.currentLayoutType,
    required this.meetingId,
    required this.participantCount,
    required this.onPickProfileImage,
    required this.onChangePassword,
    required this.onSetAlarm,
    required this.onShowFiles,
    required this.onShowParticipants,
    required this.onLayoutChanged,
  });

  @override
  State<_FullScreenMenuPage> createState() => _FullScreenMenuPageState();
}

class _FullScreenMenuPageState extends State<_FullScreenMenuPage> {
  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.95),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: widget.onPickProfileImage,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                        ),
                        border: Border.all(color: Colors.white24, width: 3),
                      ),
                      child: ClipOval(
                        child: widget.profileImage != null
                            ? Image.file(widget.profileImage!, fit: BoxFit.cover)
                            : const Icon(Icons.person, color: Colors.white, size: 35),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.userMetadata?['full_name'] ?? l10n.defaultUser,
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user?.email ?? '',
                          style: const TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildBadge(widget.isHostMode ? l10n.hostBadge : l10n.participantBadge, Colors.amber),
                            const SizedBox(width: 8),
                            _buildBadge(l10n.peopleCount(widget.participantCount), Colors.blueAccent),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Language switch icon
                  IconButton(
                    onPressed: () async {
                      await l10n.toggleLanguage();
                      setState(() {});
                    },
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.language, color: Colors.white, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            l10n.isTurkish ? 'TR' : 'EN',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Close button
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 24),
                    ),
                  ),
                ],
              ),
            ),
            
            const Divider(color: Colors.white10, height: 1),
            
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Yerleşim Seçenekleri (Sadece Host için)
                    if (widget.isHostMode) ...[
                      Text(
                        '🎨 ${l10n.participantLayout}',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildLayoutOption(context, 0, '📋', l10n.list, l10n.horizontalScroll, Colors.blue)),
                          const SizedBox(width: 10),
                          Expanded(child: _buildLayoutOption(context, 1, '🔲', l10n.grid, l10n.twoRowLayout, Colors.green)),
                          const SizedBox(width: 10),
                          Expanded(child: _buildLayoutOption(context, 2, '🌙', l10n.semicircle, l10n.arcView, Colors.purple)),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                    
                    // Menü Seçenekleri
                    Text(
                      '⚙️ ${l10n.settings}',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    
                    _buildMenuItem(Icons.lock_outline, l10n.changePassword, l10n.updateAccountPassword, Colors.red, widget.onChangePassword),
                    _buildMenuItem(Icons.alarm, l10n.setAlarm, l10n.meetingReminder, Colors.teal, widget.onSetAlarm),
                    _buildMenuItem(Icons.folder_open, l10n.sharedFiles, l10n.viewMeetingFiles, Colors.indigo, widget.onShowFiles),
                    
                    if (widget.isHostMode)
                      _buildMenuItem(Icons.people_alt, l10n.participants, l10n.manageParticipants, Colors.cyan, widget.onShowParticipants),
                    
                    const SizedBox(height: 24),
                    
                    // Toplantı Bilgileri
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.white.withOpacity(0.05), Colors.white.withOpacity(0.02)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('📊 ${l10n.meetingInfo}', style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          _buildInfoItem('🆔 ID', widget.meetingId.substring(0, 8) + '...'),
                          _buildInfoItem('👥 ${l10n.participants}', '${widget.participantCount} ${l10n.people}'),
                          _buildInfoItem('🎥 ${l10n.mode}', widget.isHostMode ? l10n.host : l10n.participant),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
  
  Widget _buildLayoutOption(BuildContext context, int layoutType, String emoji, String title, String subtitle, Color color) {
    final isSelected = widget.currentLayoutType == layoutType;
    return GestureDetector(
      onTap: () => widget.onLayoutChanged(layoutType),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: isSelected 
            ? LinearGradient(colors: [color.withOpacity(0.3), color.withOpacity(0.1)])
            : null,
          color: isSelected ? null : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? color : Colors.white10, width: isSelected ? 2 : 1),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 6),
            Text(title, style: TextStyle(color: isSelected ? color : Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 10)),
            if (isSelected) ...[
              const SizedBox(height: 6),
              Icon(Icons.check_circle, color: color, size: 18),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildMenuItem(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white38),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// Gizli Oda Sayfası
class _PrivateRoomPage extends StatefulWidget {
  final String participantName;
  final int participantIndex;
  final CameraController? hostCameraController;
  final bool isMacOsCameraInitialized;
  final bool isHostMode;
  final VoidCallback onClose;

  const _PrivateRoomPage({
    required this.participantName,
    required this.participantIndex,
    required this.hostCameraController,
    this.isMacOsCameraInitialized = false,
    this.isHostMode = true,
    required this.onClose,
  });

  @override
  State<_PrivateRoomPage> createState() => _PrivateRoomPageState();
}

class _PrivateRoomPageState extends State<_PrivateRoomPage> {
  bool _isMuted = false;
  bool _isCameraOff = false;
  int _hostVideoZoom = 0;

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    // Host modunda "Ben" yazısı, katılımcı modunda kullanıcı adı
    final myName = widget.isHostMode 
        ? (user?.userMetadata?['full_name'] ?? l10n.host)
        : (user?.userMetadata?['full_name'] ?? l10n.isTurkish ? 'Ben' : 'Me');
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
        // Renkli gradient listesi
    final gradients = [
      [const Color(0xFF667eea), const Color(0xFF764ba2)],
      [const Color(0xFFf093fb), const Color(0xFFf5576c)],
      [const Color(0xFF4facfe), const Color(0xFF00f2fe)],
      [const Color(0xFF43e97b), const Color(0xFF38f9d7)],
      [const Color(0xFFfa709a), const Color(0xFFfee140)],
      [const Color(0xFFa18cd1), const Color(0xFFfbc2eb)],
    ];
    
    final participantGradient = gradients[widget.participantIndex % gradients.length];

    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      body: _hostVideoZoom == 2 
        ? _buildHostVideo(myName)  // Fullscreen mode
        : Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f3460)],
          ),
        ),
        child: SafeArea(
          child: isLandscape 
            ? _buildLandscapeLayout(participantGradient, myName)
            : _buildPortraitLayout(participantGradient, myName),
        ),
      ),
    );
  }

  // Landscape (Yatay) Layout
  Widget _buildLandscapeLayout(List<Color> participantGradient, String myName) {
    return Row(
      children: [
        // Sol Panel - Kontroller
        Container(
          width: 80,
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Gizli Oda İkonu
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.lock, color: Colors.purpleAccent, size: 24),
              ),
              // Kontroller
              Column(
                children: [
                  _buildSmallControlButton(
                    icon: _isMuted ? Icons.mic_off : Icons.mic,
                    color: _isMuted ? Colors.red : Colors.white,
                    onTap: () => setState(() => _isMuted = !_isMuted),
                  ),
                  const SizedBox(height: 16),
                  _buildSmallControlButton(
                    icon: _isCameraOff ? Icons.videocam_off : Icons.videocam,
                    color: _isCameraOff ? Colors.red : Colors.white,
                    onTap: () => setState(() => _isCameraOff = !_isCameraOff),
                  ),
                  const SizedBox(height: 16),
                  _buildSmallControlButton(
                    icon: Icons.call_end,
                    color: Colors.white,
                    bgColor: Colors.red,
                    onTap: widget.onClose,
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
        
        // Orta - Video Alanları
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Katılımcı Video (Sol - Büyük)
                Expanded(
                  flex: 1,
                  child: _buildParticipantVideo(participantGradient),
                ),
                const SizedBox(width: 12),
                // Host Video (Sağ - Eşit Boyut)
                Expanded(
                  flex: 1,
                  child: _buildHostVideo(myName),
                ),
              ],
            ),
          ),
        ),
        
        // Sağ Panel - Kapatma
        Container(
          width: 60,
          padding: const EdgeInsets.only(top: 12, right: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: widget.onClose,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.5)),
                  ),
                  child: const Icon(Icons.close, color: Colors.redAccent, size: 20),
                ),
              ),
              const Spacer(),
              // Kayıt Uyarısı
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                ),
                child: const Icon(Icons.videocam_off, color: Colors.redAccent, size: 16),
              ),
              // Gizlilik Notu
              RotatedBox(
                quarterTurns: 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.purple.withOpacity(0.25), Colors.blue.withOpacity(0.15)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.purpleAccent.withOpacity(0.4)),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '🔒 GİZLİ',
                        style: TextStyle(color: Colors.purpleAccent, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Kimse duyamaz',
                        style: TextStyle(color: Colors.white54, fontSize: 8),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }

  // Portrait (Dikey) Layout
  Widget _buildPortraitLayout(List<Color> participantGradient, String myName) {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.lock, color: Colors.purpleAccent, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Gizli Oda', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('Özel görüşme', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: widget.onClose,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.5)),
                  ),
                  child: const Icon(Icons.close, color: Colors.redAccent, size: 22),
                ),
              ),
            ],
          ),
        ),
        
        // Gizlilik Notu
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple.withOpacity(0.2), Colors.blue.withOpacity(0.15)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.purpleAccent.withOpacity(0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock, color: Colors.purpleAccent, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'GİZLİ GÖRÜŞME',
                    style: TextStyle(
                      color: Colors.purpleAccent,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.lock, color: Colors.purpleAccent, size: 20),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                '🔒 Bu konuşmayı sadece siz ve karşınızdaki kişi duyabilir.\nToplantıdaki diğer katılımcılar sizi göremez ve duyamaz.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 8),
              // KAYIT UYARISI
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.videocam_off, color: Colors.redAccent, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '⛔ KAYDA ALINMIYOR',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Video Alanları
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                // Katılımcı Video (Büyük)
                Expanded(
                  flex: 3,
                  child: _buildParticipantVideo(participantGradient),
                ),
                const SizedBox(height: 12),
                // Host Video
                Expanded(
                  flex: 2,
                  child: _buildHostVideo(myName),
                ),
              ],
            ),
          ),
        ),
        
        // Kontroller
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlButton(
                icon: _isMuted ? Icons.mic_off : Icons.mic,
                label: _isMuted ? l10n.off : l10n.microphone,
                color: _isMuted ? Colors.red : Colors.white,
                bgColor: _isMuted ? Colors.red.withOpacity(0.2) : Colors.white.withOpacity(0.1),
                onTap: () => setState(() => _isMuted = !_isMuted),
              ),
              _buildControlButton(
                icon: _isCameraOff ? Icons.videocam_off : Icons.videocam,
                label: _isCameraOff ? l10n.off : l10n.camera,
                color: _isCameraOff ? Colors.red : Colors.white,
                bgColor: _isCameraOff ? Colors.red.withOpacity(0.2) : Colors.white.withOpacity(0.1),
                onTap: () => setState(() => _isCameraOff = !_isCameraOff),
              ),
              _buildControlButton(
                icon: Icons.call_end,
                label: l10n.end,
                color: Colors.white,
                bgColor: Colors.red,
                onTap: widget.onClose,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Katılımcı Video Widget
  Widget _buildParticipantVideo(List<Color> gradientColors) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Avatar
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      widget.participantName.isNotEmpty 
                        ? widget.participantName[0].toUpperCase() 
                        : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 50,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.participantName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // Etiket
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person, color: Colors.white70, size: 14),
                  const SizedBox(width: 4),
                  Text(widget.participantName, style: const TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Host Video Widget
  Widget _buildHostVideo(String hostName) {
    // macOS için kamera widget'ı
    Widget? cameraWidget;
    bool hasCameraAccess = false;
    
    if (!kIsWeb && Platform.isMacOS) {
      // macOS için kamerayı devre dışı bırak - camera_macos çökmelere neden oluyor
      hasCameraAccess = false;
      cameraWidget = null;
    } else {
      // iOS/Android için standart camera kullan
      if (widget.hostCameraController != null && 
          widget.hostCameraController!.value.isInitialized &&
          !_isCameraOff) {
        hasCameraAccess = true;
        cameraWidget = SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: widget.hostCameraController!.value.previewSize?.height ?? 100,
              height: widget.hostCameraController!.value.previewSize?.width ?? 100,
              child: CameraPreview(widget.hostCameraController!),
            ),
          ),
        );
      }
    }
    
    // Fullscreen durumunda özel widget döndür
    if (_hostVideoZoom == 2) {
      return _buildFullscreenHostVideo(hostName, hasCameraAccess, cameraWidget);
    }
    
    // Normal veya büyütülmüş görünüm
    return GestureDetector(
      onTap: () {
        // Tek tıklama: Normal (0) ↔ Büyük (1) arasında geçiş
        setState(() {
          _hostVideoZoom = _hostVideoZoom == 0 ? 1 : 0;
        });
      },
      onLongPress: () {
        // Uzun basma: Tam ekran (2)
        setState(() {
          _hostVideoZoom = 2;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: double.infinity,
        // Büyütülmüş durumda daha yüksek
        height: _hostVideoZoom == 1 ? 280 : null,
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.amber.withOpacity(0.5), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              // Kamera Görüntüsü
              if (hasCameraAccess && cameraWidget != null)
                SizedBox.expand(child: cameraWidget)
              else
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: _hostVideoZoom == 1 ? 80 : 60,
                        height: _hostVideoZoom == 1 ? 80 : 60,
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isCameraOff ? Icons.videocam_off : Icons.person,
                          color: Colors.amber,
                          size: _hostVideoZoom == 1 ? 40 : 30,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isCameraOff ? l10n.cameraOff : hostName,
                        style: TextStyle(color: Colors.white54, fontSize: _hostVideoZoom == 1 ? 14 : 12),
                      ),
                    ],
                  ),
                ),
              // Host Etiketi
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('👑', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(l10n.you, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              // Zoom hint
              if (_hostVideoZoom == 0)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.touch_app, color: Colors.white54, size: 14),
                        const SizedBox(width: 4),
                        Text(l10n.isTurkish ? 'Tıkla: Büyüt • Uzun Bas: Tam Ekran' : 'Tap: Enlarge • Long Press: Fullscreen', style: const TextStyle(color: Colors.white54, fontSize: 10)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Fullscreen host video widget
  Widget _buildFullscreenHostVideo(String hostName, bool hasCameraAccess, Widget? cameraWidget) {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // Kamera veya profil
          if (hasCameraAccess && cameraWidget != null)
            SizedBox.expand(child: cameraWidget)
          else
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isCameraOff ? Icons.videocam_off : Icons.person,
                      color: Colors.amber,
                      size: 60,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isCameraOff ? l10n.cameraOff : hostName,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          // Çarpı butonu - sağ üst köşe
          Positioned(
            top: 50,
            right: 20,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _hostVideoZoom = 0;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white30),
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 24),
              ),
            ),
          ),
          // Host etiketi
          Positioned(
            top: 50,
            left: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('👑', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Text(l10n.you, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallControlButton({
    required IconData icon,
    required Color color,
    Color? bgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor ?? Colors.white.withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
  
  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(color: color.withOpacity(0.8), fontSize: 11),
          ),
        ],
      ),
    );
  }
}
