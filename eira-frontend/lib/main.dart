// lib/main.dart (CORRECTED)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
// Conditional import for File/html.File
import 'dart:io' if (kIsWeb) 'dart:html' show File;
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
// Renamed file_picker import to avoid conflicts
import 'package:file_picker/file_picker.dart' as p;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:camera/camera.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:dio/dio.dart';
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';
import 'package:flutter_application_1/login_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_application_1/registration_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_application_1/api_service.dart';

// --- THIS IS THE NEW IMPORT FOR YOUR CENTRALIZED CLASS ---
import 'package:flutter_application_1/models/platform_file_wrapper.dart';
import 'package:flutter_application_1/models/chat_message.dart';
import 'package:flutter_application_1/models/chat_session.dart';


const Color kEiraYellow = Color(0xFFFDB821);
const Color kEiraYellowLight = Color(0xFFFFF8E6);
const Color kEiraYellowHover = Color(0xFFE6A109);
const Color kEiraText = Color(0xFF343541);
const Color kEiraTextSecondary = Color(0xFF6E6E80);
const Color kEiraBackground = Color(0xFFFFFFFF);
const Color kEiraSidebarBg = Color(0xFFF7F7F8);
const Color kEiraBorder = Color(0xFFE5E5E5);
const Color kEiraUserBg = Color(0xFFF7F7F8);
const double kSidebarWidth = 280.0;
const double kSidebarCollapsedWidth = 90.0;

class UserInfo {
  final String username;
  final String email;
  final String? firstName;
  final String? lastName;

  UserInfo({
    required this.username,
    required this.email,
    this.firstName,
    this.lastName,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      username: json['username'] ?? 'User',
      email: json['email'] ?? 'your.account@email.com',
      firstName: json['first_name'],
      lastName: json['last_name'],
    );
  }

  String get displayName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    } else if (firstName != null) {
      return firstName!;
    }
    return username;
  }

  String get initials {
    if (firstName != null && lastName != null) {
      return '${firstName![0]}${lastName![0]}'.toUpperCase();
    } else if (firstName != null) {
      return firstName![0].toUpperCase();
    }
    return username[0].toUpperCase();
  }
}

class ResponsiveUtils {
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 768;
  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 768 &&
      MediaQuery.of(context).size.width < 1024;
  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1024;

  static double getContentWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 1200) return 1200;
    if (screenWidth > 800) return screenWidth * 0.85;
    return screenWidth;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }
  runApp(const EiraApp());
}

// --- THE PlatformFileWrapper CLASS HAS BEEN REMOVED FROM THIS FILE ---


// REPLACE THE ENTIRE EiraApp WIDGET WITH THIS

class EiraApp extends StatelessWidget {
  const EiraApp({super.key});

  // Helper function to check for the JWT in secure storage.
  Future<bool> _isUserLoggedIn() async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'jwt_token');
    return token != null;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eira',
      debugShowCheckedModeBanner: false,
      locale: const Locale('en', 'US'),
      theme: ThemeData(
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: kEiraBackground,
        primaryColor: kEiraYellow,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: kEiraText, fontFamily: 'Roboto'),
          bodyMedium: TextStyle(color: kEiraText, fontFamily: 'Roboto'),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: kEiraBackground,
          elevation: 0,
          iconTheme: IconThemeData(color: kEiraText),
          titleTextStyle: TextStyle(
            color: kEiraText,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            fontFamily: 'Roboto',
          ),
        ),
      ),
      // This FutureBuilder replaces the old StreamBuilder.
      home: FutureBuilder<bool>(
        future: _isUserLoggedIn(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasData && snapshot.data == true) {
            return const HomeScreen(); // If token exists, go to home.
          }
          return const LoginScreen(); // Otherwise, go to login.
        },
      ),
    );
  }
}




class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
 final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isSidebarCollapsed = false;
  bool _hasActiveChat = false;
  final List<ChatMessage> _messages = [];
  final List<ChatSession> _sessions = [];
  String _currentModel = 'Eira 0.1';
  final List<String> _availableModels = ['Eira 0.1', 'Eira 0.2', 'Eira 1'];
  final ApiService _apiService = ApiService();
  bool _isLoadingHistory = false;
  int? _currentSessionId;
final TextEditingController _textController = TextEditingController();
  // ** NEW: User information state **
  UserInfo? _userInfo;
  bool _isLoadingUser = false;

  // ** NEW: Recorder instance for web and mobile **
  final AudioRecorder _audioRecorder = AudioRecorder(); // Use Record from the record package

  // Mobile-specific recorders
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _recognizedText = '';
  FlutterSoundRecorder? _audioRecorderMobile; // Renamed for clarity
  bool _isRecordingAudio = false;
  String? _audioPath;
  CameraController? _cameraController;
  Future<void>? _initializeCameraFuture;
  bool _isRecordingVideo = false;
  bool _isCameraInitialized = false;

  final List<PlatformFileWrapper> _pendingFiles = [];
  final Dio _dio = Dio();

   
  @override
  void initState() {
    super.initState();
    _loadUserInfo(); // Load user info first
    _loadSessions();
   _initializeCamera();
    if (!kIsWeb) {
      _speech = stt.SpeechToText();
      _initializeSpeech();
      _initAudioRecorder();
    }
  }
 String _userName = "User";
  String _userEmail = "your.account@email.com";
  // NEW: Load user information from API or storage
  Future<void> _loadUserInfo() async {
    if (_isLoadingUser) return;
    
    setState(() {
      _isLoadingUser = true;
    });

    try {
      // Try to get user info from API first
      final userInfo = await _apiService.getUserInfo();
      if (mounted) {
        setState(() {
          _userInfo = UserInfo.fromJson(userInfo);
        });
      }
    } catch (e) {
      // If API call fails, try to get cached user info from secure storage
      try {
        const storage = FlutterSecureStorage();
        final cachedUserData = await storage.read(key: 'user_info');
        if (cachedUserData != null && mounted) {
          // Parse the cached JSON if you stored it as JSON string
          // For now, we'll set default values
          setState(() {
            _userInfo = UserInfo(
              username: 'User',
              email: 'your.account@email.com',
            );
          });
        }
      } catch (e2) {
        // Set default user info if everything fails
        if (mounted) {
          setState(() {
            _userInfo = UserInfo(
              username: 'User',
              email: 'your.account@email.com',
            );
          });
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingUser = false;
        });
      }
    }
  }

  Future<void> _initAudioRecorder() async {
    if (kIsWeb) return;
    try {
      _audioRecorderMobile = FlutterSoundRecorder();
      await _audioRecorderMobile!.openRecorder();
    } catch (e) {
      // Handle error
    }
  }

  
  Future<void> _loadSessions() async {
    try {
      final List<ChatSession> sessions = await _apiService.fetchSessions();
      if (mounted) {
        setState(() {
          _sessions.clear();
          _sessions.addAll(sessions);
        });
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar("Could not load sessions.", Colors.red);
      }
    }
  }
  

  // UPDATED: Logout function now also clears user info
Future<void> _handleLogout() async {
  await _apiService.logout(); // Calls the ApiService to delete the token
  
  // Clear user info from state
  setState(() {
    _userInfo = null;
  });
  
  if (mounted) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }
}

  Future<void> _editSessionTitle(ChatSession session) async {
    final newTitleController = TextEditingController(text: session.title);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Session Name'),
        content: TextField(
          controller: newTitleController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter new name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final newTitle = newTitleController.text.trim();
      if (newTitle.isNotEmpty && newTitle != session.title) {
        try {
          await _apiService.updateSessionTitle(session.id, newTitle);
          if (mounted) {
            setState(() {
              final index = _sessions.indexWhere((s) => s.id == session.id);
              if (index != -1) {
                _sessions[index] = ChatSession(
                  id: session.id,
                  title: newTitle,
                  createdAt: session.createdAt,
                );
              }
            });
            _showSnackBar('Session name updated!', kEiraYellow);
          }
        } catch (e) {
          if (mounted) {
            _showSnackBar('Failed to update session name.', Colors.red);
          }
        }
      }
    }
  }

  Future<bool> _deleteSession(int sessionId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Session?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await _apiService.deleteSession(sessionId);
        if (mounted) {
          setState(() {
            _sessions.removeWhere((s) => s.id == sessionId);
            if (_currentSessionId == sessionId) {
              _startNewChat();
            }
          });
          _showSnackBar('Session deleted.', kEiraYellow);
        }
        return true;
      } catch (e) {
        if (mounted) {
          _showSnackBar('Failed to delete session.', Colors.red);
        }
        return false;
      }
    }
    return false;
  }

 Future<void> _loadChatHistory({int? sessionId}) async {
  // --- THIS IS THE FIX ---
  // If no session ID is provided, there's no history to load.
  // We clear the messages and set the state for a new chat.
  if (sessionId == null) {
    if (mounted) {
      setState(() {
        _hasActiveChat = false;
        _messages.clear();
        _currentSessionId = null;
      });
    }
    return; // Exit the function early.
  }
  // ----------------------

  if (mounted) {
    setState(() {
      _isLoadingHistory = true;
      _messages.clear();
    });
  }

  try {
    // This code will now only run if sessionId is guaranteed to have a value.
    final List<ChatMessage> history =
        await _apiService.fetchMessages(sessionId: sessionId);

    if (mounted) {
      setState(() {
        _messages.addAll(history);
        _hasActiveChat = true;
        _currentSessionId = sessionId; // Update the current session ID
      });
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Could not load chat history."),
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    if (mounted) {
      setState(() {
        _isLoadingHistory = false;
      });
    }
  }
}

  void _onModelChanged(String? newModel) {
    if (newModel != null && newModel != _currentModel) {
      if (mounted) {
        setState(() {
          _currentModel = newModel;
        });
        _showSnackBar('Switched to $newModel', kEiraYellow);
      }
    }
  }

  void _initializeSpeech() async {
    if (kIsWeb) return;
    try {
      await _speech.initialize(
        onStatus: (val) {},
        onError: (val) {},
      );
    } catch (e) {}
  }


  Future<void> _initializeCamera() async {
  try {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      _showErrorDialog("No camera found on this device.");
      return;
    }

    CameraDescription? frontCamera;
    for (var camera in cameras) {
      if (camera.lensDirection == CameraLensDirection.front) {
        frontCamera = camera;
        break;
      }
    }

    final selectedCamera = frontCamera ?? cameras.first;

    _cameraController = CameraController(
      selectedCamera,
      ResolutionPreset.medium,
      enableAudio: false, 
    );

    _initializeCameraFuture = _cameraController!.initialize().then((_) {
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    }).catchError((e) {
      _showErrorDialog("Could not initialize camera: $e");
    });

  } catch (e) {
    _showErrorDialog("Failed to access camera: $e");
  }
}
  void _startNewChat() {
    if (mounted) {
      setState(() {
        _hasActiveChat = false;
        _messages.clear();
        _currentSessionId = null;
      });
    }
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _requestPermissions() async {
    if (kIsWeb) return;
    try {
      await [
        Permission.microphone,
        Permission.camera,
        Permission.storage,
      ].request();
    } catch (e) {}
  }

 Future<void> _startAudioRecording() async {
  try {
    if (kIsWeb) {
      if (await _audioRecorder.hasPermission()) {
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.wav),
          path: 'web_recording.wav',
        );
        setState(() {
          _isRecordingAudio = true;
        });
        _showSnackBar('Recording started on web...', Colors.green);
      } else {
        _showPermissionDeniedDialog('Microphone');
      }
    } else {
      await _requestPermissions();
      final status = await Permission.microphone.status;
      if (status != PermissionStatus.granted) {
        _showPermissionDeniedDialog('Microphone');
        return;
      }
      if (_audioRecorderMobile == null) {
        await _initAudioRecorder();
      }
      if (_audioRecorderMobile != null) {
        final tempDir = await getTemporaryDirectory();
        final fileName = 'audio_${DateTime.now().millisecondsSinceEpoch}.wav';
        final filePath = '${tempDir.path}/$fileName';
        await _audioRecorderMobile!.startRecorder(
          toFile: filePath,
          codec: Codec.pcm16WAV,
        );
        if (mounted) {
          setState(() {
            _isRecordingAudio = true;
            _audioPath = filePath;
            _recognizedText = '';
          });
        }
        _showSnackBar('Recording started...', Colors.green);
      }
    }
  } catch (e) {
    _showErrorDialog('Failed to start audio recording: $e');
  }
}
  Future<void> _stopAudioRecording() async {
    try {
      if (kIsWeb) {
        final String? path = await _audioRecorder.stop();
        if (path != null) {
          final response = await Dio().get(path, options: Options(responseType: ResponseType.bytes));
          final bytes = response.data as Uint8List;
          setState(() {
            _isRecordingAudio = false;
            final fileName = 'audio_${DateTime.now().millisecondsSinceEpoch}.wav';
            _pendingFiles.add(PlatformFileWrapper(
              name: fileName,
              bytes: bytes,
            ));
          });
          _showSnackBar('Audio recorded! Press send to share.', Colors.green);
        }
      } else {
        if (_audioRecorderMobile != null && _isRecordingAudio) {
          String? recordedPath = await _audioRecorderMobile!.stopRecorder();
          if (mounted) {
            setState(() {
              _isRecordingAudio = false;
            });
          }
          if (recordedPath != null && await File(recordedPath).exists()) {
            final file = File(recordedPath);
            if (mounted) {
              setState(() {
                _pendingFiles.add(PlatformFileWrapper(
                  name: path.basename(file.path),
                  path: file.path,
                ));
              });
              _showSnackBar('Audio recorded! Press send to share.', Colors.green);
            }
          }
        }
      }
    } catch (e) {
      _showErrorDialog('Failed to stop audio recording: $e');
    }
  }

Future<void> _startVideoRecording() async {
  try {
    if (!kIsWeb) {
      await _requestPermissions();
      final status = await Permission.camera.status;
      if (status != PermissionStatus.granted) {
        _showPermissionDeniedDialog('Camera');
        return;
      }
    }

    if (_cameraController == null || !_isCameraInitialized) {
      await _initializeCamera();
      if (_initializeCameraFuture != null) {
        await _initializeCameraFuture!;
      }
    }

    if (_cameraController != null && _cameraController!.value.isInitialized) {
      await _cameraController!.startVideoRecording();
      if (mounted) {
        setState(() {
          _isRecordingVideo = true;
        });
        _showSnackBar('Video recording started...', Colors.green);
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return VideoRecordingPreview(
            cameraController: _cameraController!,
            onStopRecording: () async {
              await _stopVideoRecording();
              if (mounted) Navigator.of(context).pop();
            },
            onClose: () async {
              if (_isRecordingVideo) {
                await _stopVideoRecording();
              }
              if (mounted) Navigator.of(context).pop();
            },
          );
        },
      );
    } else {
      _showErrorDialog('Camera not initialized. Please allow camera access.');
    }
  } catch (e) {
    _showErrorDialog('Failed to start video recording: $e');
  }
}

Future<void> _stopVideoRecording() async {
  try {
    if (_cameraController == null || !_isRecordingVideo) return;

    final XFile videoFile = await _cameraController!.stopVideoRecording();

    if (mounted) {
      setState(() {
        _isRecordingVideo = false;
      });
    }

    final String fileName = 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
    
    if (kIsWeb) {
      final Uint8List videoBytes = await videoFile.readAsBytes();
      if (mounted) {
        setState(() {
          _pendingFiles.add(PlatformFileWrapper(
            name: fileName,
            bytes: videoBytes,
          ));
        });
      }
    } else {
      final File file = File(videoFile.path);
      if (await file.exists() && mounted) {
        setState(() {
          _pendingFiles.add(PlatformFileWrapper(
            name: fileName,
            path: file.path,
          ));
        });
      }
    }
    
    _showSnackBar('Video recorded! Press send to share.', Colors.green);

  } catch (e) {
    _showErrorDialog('Failed to stop video recording: $e');
  }
}


  Future<void> _pickFiles() async {
    try {
      final p.FilePickerResult? result = await p.FilePicker.platform.pickFiles(
        type: p.FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'mp4', 'mp3', 'aac', 'wav', 'mov'],
        allowMultiple: true,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        List<PlatformFileWrapper> pickedFiles = [];

        if (kIsWeb) {
          pickedFiles = result.files
              .where((file) => file.bytes != null)
              .map((file) => PlatformFileWrapper(name: file.name, bytes: file.bytes!))
              .toList();
        } else {
          pickedFiles = result.paths
              .where((path) => path != null)
              .map((path) => PlatformFileWrapper(
                    name: path!.split(RegExp(r'[/\\]')).last,
                    path: path,
                  ))
              .toList();
        }

        if (pickedFiles.isNotEmpty && mounted) {
          setState(() {
            _pendingFiles.addAll(pickedFiles);
          });
          _showSnackBar(
            '${pickedFiles.length} file(s) added. Press send to share.',
            kEiraYellow,
          );
        }
      }
    } catch (e) {
      _showErrorDialog('Failed to pick files: $e');
    }
  }

  void _addMessage(String text, bool isUser, [List<PlatformFileWrapper>? attachments]) {
    if (mounted) {
      setState(() {
        _messages.add(ChatMessage(
          text: text,
          isUser: isUser,
          attachments: attachments,
        ));
        if (!_hasActiveChat) {
          _hasActiveChat = true;
        }
      });
    }
  }

  void _removePendingFile(int index) {
    if (mounted) {
      setState(() {
        _pendingFiles.removeAt(index);
      });
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecordingAudio) {
      await _stopAudioRecording();
    } else {
      await _startAudioRecording();
    }
  }

  Future<void> _toggleVideoRecording() async {
    if (_isRecordingVideo) {
      await _stopVideoRecording();
    } else {
      await _startVideoRecording();
    }
  }

  void _onSessionTapped(int sessionId) {
    if (ResponsiveUtils.isMobile(context)) {
      Navigator.of(context).pop();
    }
    _loadChatHistory(sessionId: sessionId);
  }

  Future<void> _sendMessage() async {
    final messageText = _textController.text.trim();
    final attachments = List<PlatformFileWrapper>.from(_pendingFiles);

    if (messageText.isEmpty && attachments.isEmpty) return;

    final bool isNewSession = _currentSessionId == null;

    _addMessage(
      messageText.isEmpty
          ? (attachments.length == 1 ? "File sent" : "Files sent")
          : messageText,
      true,
      attachments.isNotEmpty ? attachments : null,
    );
    if (mounted) {
      setState(() {
        _textController.clear();
        _pendingFiles.clear();
        if (!_hasActiveChat) {
          _hasActiveChat = true;
        }
      });
    }

    try {
      int? newSessionId;

      if (attachments.isNotEmpty) {
        for (var file in attachments) {
          final responseData = await _apiService.storeFileMessage(
            messageText,
            file,
            sessionId: _currentSessionId,
          );

          if (isNewSession && _currentSessionId == null) {
            newSessionId = responseData['session_id'];
            if (mounted) {
              setState(() {
                _currentSessionId = newSessionId;
              });
            }
          }
        }
      } else {
        final responseData = await _apiService.storeTextMessage(
          messageText,
          sessionId: _currentSessionId,
        );
        if (isNewSession) {
          newSessionId = responseData['session_id'];
          if (mounted) {
            setState(() {
              _currentSessionId = newSessionId;
            });
          }
        }
      }

      if (isNewSession && newSessionId != null) {
        try {
          String newTitle = messageText.isNotEmpty
              ? (messageText.length > 40
                  ? '${messageText.substring(0, 40)}...'
                  : messageText)
              : "Chat with Attachments";

          await _apiService.updateSessionTitle(newSessionId, newTitle);
        } catch (e) {
          if (mounted) {
            _showSnackBar("Failed to update session name.", Colors.red);
          }
        }
      }

      await _loadSessions();
    } catch (e) {
      if (mounted) {
        _showSnackBar("Failed to send. Please try again.", Colors.red);
        setState(() {
          _textController.text = messageText;
        });
      }
    }
  }

  void _showPermissionDeniedDialog(String permission) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('$permission Permission Required'),
          content:
              Text('Please grant $permission permission to use this feature.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              child: const Text('Settings'),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
  
  void _handleRefresh() {
    _loadSessions();
    _loadUserInfo(); // Also refresh user info
    if (_currentSessionId != null) {
      _loadChatHistory(sessionId: _currentSessionId);
    }
    _showSnackBar('Data refreshed!', kEiraYellow);
  }

 void _showFeatureNotAvailableDialog(String featureName) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(featureName),
      content: const Text(
          'This feature is not yet available. It will be added in a future update.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

Future<void> _loadUserData() async {
  const storage = FlutterSecureStorage();
  final name = await storage.read(key: 'user_name');
  final email = await storage.read(key: 'user_email');
  if (mounted) {
    setState(() {
      _userName = name ?? "User";
      _userEmail = email ?? "email@example.com";
    });
  }
}

 Future<void> _showChangeUsernameDialog() async {
  final newNameController = TextEditingController(text: _userName);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Change Username'),
      content: TextField(
        controller: newNameController,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Enter new username'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Save')),
      ],
    ),
  );

  if (confirmed == true) {
    final newName = newNameController.text.trim();
    if (newName.isNotEmpty) {
      try {
        final response = await _apiService.changeUsername(newName: newName);
        // After success, update the stored name and the UI state
        const storage = FlutterSecureStorage();
        await storage.write(key: 'user_name', value: response['user']['name']);
        await _loadUserData(); // Reloads user data to update the UI
        _showSnackBar('Username updated successfully!', Colors.green);
      } catch (e) {
        _showErrorDialog(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }
}

Future<void> _showChangePasswordDialog() async {
  final oldPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Change Password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: oldPasswordController, obscureText: true, decoration: const InputDecoration(hintText: 'Old Password')),
          const SizedBox(height: 8),
          TextField(controller: newPasswordController, obscureText: true, decoration: const InputDecoration(hintText: 'New Password')),
          const SizedBox(height: 8),
          TextField(controller: confirmPasswordController, obscureText: true, decoration: const InputDecoration(hintText: 'Confirm New Password')),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Save')),
      ],
    ),
  );

  if (confirmed == true) {
    final oldPassword = oldPasswordController.text;
    final newPassword = newPasswordController.text;
    final confirmPassword = confirmPasswordController.text;

    if (newPassword != confirmPassword) {
      _showErrorDialog("New passwords do not match.");
      return;
    }
    
    if (newPassword.length < 6) {
      _showErrorDialog("New password must be at least 6 characters.");
      return;
    }

    try {
      await _apiService.changePassword(oldPassword: oldPassword, newPassword: newPassword);
      _showSnackBar('Password updated successfully!', Colors.green);
    } catch (e) {
      _showErrorDialog(e.toString().replaceFirst('Exception: ', ''));
    }
  }
}

  void _showChangeEmailInfoDialog() {
  _showFeatureNotAvailableDialog('Change Email');
}


  @override
void dispose() {
  _audioRecorder.dispose(); 
  _cameraController?.dispose();
  _dio.close();
  _textController.dispose();
  super.dispose();
}

  @override
Widget build(BuildContext context) {
  // Get user info with fallback values
  final userName = _userInfo?.displayName ?? "Eira User";
  final userEmail = _userInfo?.email ?? "Your Account";
  final userInitial = _userInfo?.initials ?? "U";

  final bool isMobile = ResponsiveUtils.isMobile(context);
  final bool isDesktop = ResponsiveUtils.isDesktop(context);

  return Scaffold(
    key: _scaffoldKey,
    appBar: AppBar(
      backgroundColor: kEiraBackground,
      elevation: 0,
      centerTitle: true,
      leading: isMobile
          ? Center(
              child: Container(
                height: 40,
                width: 40,
                margin: const EdgeInsets.only(left: 12),
                decoration: BoxDecoration(
                  color: kEiraYellow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.menu, color: Colors.white, size: 20),
                  onPressed: () {
                    _scaffoldKey.currentState?.openDrawer();
                  },
                ),
              ),
            )
          : null,
      title: ModelDropdown(
        currentModel: _currentModel,
        availableModels: _availableModels,
        onModelChanged: _onModelChanged,
      ),
      actions: [
        Center(
          child: Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: _isLoadingUser
                ? const SizedBox(
                    width: 40,
                    height: 40,
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : PopupMenuButton<String>(
                    offset: const Offset(0, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: kEiraBorder.withOpacity(0.5)),
                    ),
                    elevation: 8,
                    color: kEiraBackground,
                    onSelected: (value) {
                      switch (value) {
                        case 'logout':
                          _handleLogout();
                          break;
                        case 'change_username':
                          _showChangeUsernameDialog();
                          break;
                        case 'change_password':
                          _showChangePasswordDialog();
                          break;
                        case 'change_email':
                          _showChangeEmailInfoDialog();
                          break;
                      }
                    },
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'user_info',
                        enabled: false,
                        padding: EdgeInsets.zero,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: kEiraBackground,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: kEiraYellow,
                                child: Text(
                                  userInitial,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    fontFamily: 'Roboto',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      userName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                        color: kEiraText,
                                        fontFamily: 'Roboto',
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      userEmail,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: kEiraTextSecondary,
                                        fontFamily: 'Roboto',
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const PopupMenuDivider(height: 1),
                      PopupMenuItem<String>(
                        value: 'change_username',
                        child: const Row(
                          children: [
                            Icon(Icons.edit_outlined, color: kEiraTextSecondary, size: 20),
                            SizedBox(width: 12),
                            Text('Change Username', style: TextStyle(fontFamily: 'Roboto', fontSize: 15)),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'change_password',
                        child: const Row(
                          children: [
                            Icon(Icons.lock_outline, color: kEiraTextSecondary, size: 20),
                            SizedBox(width: 12),
                            Text('Change Password', style: TextStyle(fontFamily: 'Roboto', fontSize: 15)),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'change_email',
                        child: const Row(
                          children: [
                            Icon(Icons.email_outlined, color: kEiraTextSecondary, size: 20),
                            SizedBox(width: 12),
                            Text('Change Email', style: TextStyle(fontFamily: 'Roboto', fontSize: 15)),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(height: 1),
                      const PopupMenuItem<String>(
                        value: 'logout',
                        child: Row(
                          children: [
                            Icon(Icons.logout, color: Colors.red, size: 20),
                            SizedBox(width: 12),
                            Text('Logout', style: TextStyle(color: Colors.red, fontFamily: 'Roboto', fontSize: 15)),
                          ],
                        ),
                      ),
                    ],
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: kEiraYellow,
                      child: Text(
                        userInitial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          fontFamily: 'Roboto',
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    ),
    drawer: isMobile
        ? Drawer(
            width: MediaQuery.of(context).size.width * 0.75,
            child: AppDrawer(
              onNewSession: _startNewChat,
              sessions: _sessions,
              onSessionTapped: _onSessionTapped,
              onSessionEdited: _editSessionTitle,
              onSessionDeleted: (id) => _deleteSession(id),
              isCollapsed: false,
              onToggle: () {},
              onRefresh: _handleRefresh,
              onLogout: _handleLogout,
            ),
          )
        : null,
    body: Stack(
        children: [
          Row(
            children: [
              if (isDesktop)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  width: _isSidebarCollapsed ? 0 : kSidebarWidth,
                  child: ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.centerLeft,
                      maxWidth: kSidebarWidth,
                      child: Visibility(
                        visible: !_isSidebarCollapsed,
                        maintainState: true,
                        child: AppDrawer(
                          onNewSession: _startNewChat,
                          sessions: _sessions,
                          onSessionTapped: _onSessionTapped,
                          onSessionEdited: _editSessionTitle,
                          onSessionDeleted: _deleteSession,
                          onLogout: _handleLogout,
                          isCollapsed: _isSidebarCollapsed,
                          onToggle: () {
                            setState(() {
                              _isSidebarCollapsed = !_isSidebarCollapsed;
                            });
                          },
                          onRefresh: _handleRefresh,
                        ),
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: isDesktop ? 800 : double.infinity,
                  ),
                  child: Stack(
                    children: [
                      if (isDesktop && _isSidebarCollapsed)
                        Positioned(
                          top: 16,
                          left: 16,
                          child: Container(
                            decoration: BoxDecoration(
                              color: kEiraYellow,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.menu,
                                color: Colors.white,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isSidebarCollapsed = false;
                                });
                              },
                              tooltip: 'Show Sidebar',
                            ),
                          ),
                        ),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        bottom: _pendingFiles.isNotEmpty ? 180.0 : 140.0,
                        child: _hasActiveChat
                            ? _isLoadingHistory
                                ? const Center(
                                    child: CircularProgressIndicator())
                                : MessagesListView(
                                    messages: _messages,
                                    currentModel: _currentModel,
                                    extraBottomPadding: 20.0,
                                  )
                            : WelcomeView(
                                currentModel: _currentModel,
                                onCapabilityTap: () {},
                              ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_pendingFiles.isNotEmpty)
                              PendingFilesDisplay(
                                files: _pendingFiles,
                                onRemove: _removePendingFile,
                              ),
                            ChatInputArea(
                              isRecordingAudio: _isRecordingAudio,
                              isRecordingVideo: _isRecordingVideo,
                              recognizedText: _recognizedText,
                              textController: _textController,
                              onRecordToggle: _toggleRecording,
                              onFileAdd: _pickFiles,
                              onCameraOpen: _toggleVideoRecording,
                              onSendMessage: _sendMessage,
                              hasPendingFiles: _pendingFiles.isNotEmpty,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
class ModelDropdown extends StatelessWidget {
  final String currentModel;
  final List<String> availableModels;
  final ValueChanged<String?> onModelChanged;

  const ModelDropdown({
    super.key,
    required this.currentModel,
    required this.availableModels,
    required this.onModelChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 140),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: kEiraBorder.withOpacity(0.3), width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentModel,
          icon: Container(
            padding: const EdgeInsets.all(2),
            child: const Icon(
              Icons.keyboard_arrow_down,
              color: kEiraYellow,
              size: 20,
            ),
          ),
          style: const TextStyle(
            color: kEiraText,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: 'Roboto',
          ),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(16),
          elevation: 12,
          menuMaxHeight: 200,
          onChanged: onModelChanged,
          items: availableModels.map<DropdownMenuItem<String>>((String model) {
            final isSelected = model == currentModel;
            return DropdownMenuItem<String>(
              value: model,
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  color: isSelected ? kEiraYellowLight : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isSelected ? kEiraYellow : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? kEiraYellow
                              : kEiraTextSecondary.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        model,
                        style: TextStyle(
                          color: isSelected ? kEiraYellow : kEiraText,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 14,
                          fontFamily: 'Roboto',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isSelected)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: kEiraYellow,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Active',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Roboto',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
          selectedItemBuilder: (BuildContext context) {
            return availableModels.map<Widget>((String model) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: kEiraYellow,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    model,
                    style: const TextStyle(
                      color: kEiraYellow,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ],
              );
            }).toList();
          },
        ),
      ),
    );
  }
}

class PendingFilesDisplay extends StatelessWidget {
  final List<PlatformFileWrapper> files;
  final Function(int) onRemove;

  const PendingFilesDisplay({
    super.key,
    required this.files,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final List<Widget> fileChips = files.asMap().entries.map((entry) {
      int index = entry.key;
      PlatformFileWrapper file = entry.value;
      return Padding(
        padding: const EdgeInsets.only(right: 8.0),
        child: PendingFileChip(
          file: file,
          onRemove: () => onRemove(index),
        ),
      );
    }).toList();

    return Container(
      width: double.infinity,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: kEiraBackground,
        border: Border(
          top: BorderSide(color: kEiraBorder.withOpacity(0.3)),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: fileChips,
        ),
      ),
    );
  }
}

class PendingFileChip extends StatelessWidget {
  final PlatformFileWrapper file;
  final VoidCallback onRemove;

  const PendingFileChip({
    super.key,
    required this.file,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = file.name;
    final displayIcon = _getFileIcon(displayName);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kEiraBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            displayIcon,
            color: kEiraTextSecondary,
            size: 16,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              displayName,
              style: const TextStyle(
                fontSize: 13,
                color: kEiraText,
                fontFamily: 'Roboto',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(
              Icons.close,
              color: kEiraTextSecondary,
              size: 14,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String name) {
    final extension = name.split('.').last.toLowerCase();
    if (['pdf'].contains(extension)) return Icons.insert_drive_file;
    if (['jpg', 'jpeg', 'png'].contains(extension)) return Icons.image;
    if (['mp4', 'mov'].contains(extension)) return Icons.videocam;
    if (['mp3', 'aac', 'wav'].contains(extension)) return Icons.mic;
    return Icons.insert_drive_file;
  }
}

class AppDrawer extends StatelessWidget {
  final VoidCallback onNewSession;
  final List<ChatSession> sessions;
  final Function(int) onSessionTapped;
  final Future<void> Function(ChatSession) onSessionEdited;
  final Future<void> Function(int) onSessionDeleted;
  final bool isCollapsed;
  final VoidCallback onToggle;
  final VoidCallback onRefresh;
  final VoidCallback onLogout;

  const AppDrawer({
    super.key,
    required this.onNewSession,
    required this.sessions,
    required this.onSessionTapped,
    required this.onSessionEdited,
    required this.onSessionDeleted,
    this.isCollapsed = false,
    required this.onToggle,
    required this.onRefresh,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isCollapsed ? kSidebarCollapsedWidth : kSidebarWidth,
      color: kEiraSidebarBg,
      child: SafeArea(
        child: Column(
          children: [
            if (!isCollapsed) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: ElevatedButton.icon(
                  onPressed: onNewSession,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text("New Session", style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kEiraYellow,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: OutlinedButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh, size: 20, color: kEiraTextSecondary),
                  label: const Text("Refresh Sessions", style: TextStyle(color: kEiraTextSecondary, fontWeight: FontWeight.normal)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 40),
                    side: BorderSide(color: kEiraBorder.withOpacity(0.8)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Recent Sessions", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: sessions.isEmpty
                    ? const Center(child: Text("No recent sessions.", style: TextStyle(color: kEiraTextSecondary)))
                    : ListView.builder(
                        itemCount: sessions.length,
                        itemBuilder: (context, index) {
                          final session = sessions[index];
                          return ListTile(
                            title: Text(session.title, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis),
                            subtitle: Text("Session from ${session.createdAt.toLocal().toString().substring(0, 10)}"),
                            leading: const Icon(Icons.history_outlined, color: kEiraTextSecondary),
                            onTap: () => onSessionTapped(session.id),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'rename') onSessionEdited(session);
                                if (value == 'delete') onSessionDeleted(session.id);
                              },
                              itemBuilder: (BuildContext context) => [
                                const PopupMenuItem<String>(value: 'rename', child: ListTile(leading: Icon(Icons.edit_outlined, size: 20), title: Text('Rename'))),
                                const PopupMenuItem<String>(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline, color: Colors.red, size: 20), title: Text('Delete', style: TextStyle(color: Colors.red)))),
                              ],
                              icon: const Icon(Icons.more_vert, color: kEiraTextSecondary, size: 20),
                            ),
                          );
                        },
                      ),
              ),
              const Divider(color: kEiraBorder, height: 1),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text("Logout", style: TextStyle(color: Colors.red)),
                onTap: onLogout,
              ),
            ] else ...[
              IconButton(icon: const Icon(Icons.menu_open, color: kEiraTextSecondary), onPressed: onToggle),
            ],
          ],
        ),
      ),
    );
  }
}

class WelcomeView extends StatelessWidget {
  final VoidCallback onCapabilityTap;
  final String currentModel;

  const WelcomeView(
      {super.key, required this.onCapabilityTap, required this.currentModel});

  String _getLogoForModel(String model) {
    switch (model) {
      case 'Eira 0.1':
        return 'assets/images/Eira 0.1.png';
      case 'Eira 0.2':
        return 'assets/images/Eira 0.2.png';
      case 'Eira 1':
        return 'assets/images/Eira 1.png';
      default:
        return 'assets/images/Eira 1.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = ResponsiveUtils.isMobile(context);
    final bool isTablet = ResponsiveUtils.isTablet(context);
    final double contentWidth = ResponsiveUtils.getContentWidth(context);

    return Center(
      child: Container(
        width: contentWidth,
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 20.0 : 40.0,
          vertical: 16.0,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                _getLogoForModel(currentModel),
                key: ValueKey(currentModel),
                height: isMobile ? 120 : 150,
              ),
              const SizedBox(height: 12),
              const Text(
                "Eira - Your AI Health Assistant",
                style: TextStyle(
                  fontSize: 16,
                  color: kEiraTextSecondary,
                  fontWeight: FontWeight.w400,
                  fontFamily: 'Roboto',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  int crossAxisCount;
                  double childAspectRatio;

                  if (isMobile) {
                    crossAxisCount = 2;
                    childAspectRatio = 1.0;
                  } else if (isTablet) {
                    crossAxisCount = 3;
                    childAspectRatio = 1.1;
                  } else {
                    crossAxisCount = 4;
                    childAspectRatio = 1.2;
                  }

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: isMobile ? 12.0 : 16.0,
                      mainAxisSpacing: isMobile ? 12.0 : 16.0,
                      childAspectRatio: childAspectRatio,
                    ),
                    itemCount: 4,
                    itemBuilder: (context, index) {
                      List<Map<String, dynamic>> cardsData = [
                        {
                          'icon': Icons.medical_information,
                          'title': 'Medical Assistance',
                          'description':
                              'Get reliable medical information and health guidance',
                          'color': const Color(0xFF8A5FFC)
                        },
                        {
                          'icon': Icons.medication,
                          'title': 'Medication Info',
                          'description':
                              'Learn about medications, dosages, and interactions',
                          'color': const Color(0xFFF97316)
                        },
                        {
                          'icon': Icons.biotech,
                          'title': 'Health Analysis',
                          'description':
                              'Understand symptoms and get preliminary health insights',
                          'color': const Color(0xFF3B82F6)
                        },
                        {
                          'icon': Icons.favorite,
                          'title': 'Wellness Tips',
                          'description':
                              'Receive personalized wellness and lifestyle recommendations',
                          'color': const Color(0xFFEC4899)
                        },
                      ];
                      final card = cardsData[index];
                      return CapabilityCard(
                        icon: card['icon'],
                        title: card['title'],
                        description: card['description'],
                        color: card['color'],
                        onTap: onCapabilityTap,
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class CapabilityCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const CapabilityCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kEiraBackground,
          border: Border.all(color: kEiraBorder.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: kEiraText,
                fontFamily: 'Roboto',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: kEiraTextSecondary,
                height: 1.3,
                fontFamily: 'Roboto',
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class MessagesListView extends StatefulWidget {
  final List<ChatMessage> messages;
  final String currentModel;
  final double extraBottomPadding;

  const MessagesListView({
    super.key,
    required this.messages,
    required this.currentModel,
    this.extraBottomPadding = 0.0,
  });

  @override
  State<MessagesListView> createState() => _MessagesListViewState();
}

class _MessagesListViewState extends State<MessagesListView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  @override
  void didUpdateWidget(MessagesListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.length > oldWidget.messages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = ResponsiveUtils.isMobile(context);

    if (widget.messages.isEmpty) {
      return const Center(
        child: Text(
          'Start a conversation...',
          style: TextStyle(
            color: kEiraTextSecondary,
            fontSize: 16,
            fontFamily: 'Roboto',
          ),
        ),
      );
    }

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800),
        child: ListView.builder(
          controller: _scrollController,
          padding: EdgeInsets.only(
            left: isMobile ? 16.0 : 24.0,
            right: isMobile ? 16.0 : 24.0,
            top: 16.0,
            bottom: 16.0 + widget.extraBottomPadding,
          ),
          itemCount: widget.messages.length,
          itemBuilder: (context, index) {
            final message = widget.messages[index];
            return MessageBubble(
              isUser: message.isUser,
              text: message.text,
              attachments: message.attachments,
              timestamp: message.timestamp,
              modelName: widget.currentModel,
              fileUrl: message.fileUrl,
              fileType: message.fileType,
            );
          },
        ),
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  final bool isUser;
  final String text;
  final List<PlatformFileWrapper>? attachments;
  final DateTime timestamp;
  final String modelName;
  final String? fileUrl;
  final String? fileType;

  const MessageBubble({
    super.key,
    required this.isUser,
    required this.text,
    this.attachments,
    required this.timestamp,
    required this.modelName,
    this.fileUrl,
    this.fileType,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasLocalAttachment =
        attachments != null && attachments!.isNotEmpty;
    final bool hasRemoteAttachment = fileUrl != null;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      decoration: BoxDecoration(
        color: isUser ? kEiraUserBg : kEiraBackground,
        border: const Border(bottom: BorderSide(color: kEiraBorder)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: isUser ? kEiraText : kEiraYellow,
            child: isUser
                ? const Text("U",
                    style: TextStyle(color: Colors.white, fontFamily: 'Roboto'))
                : const Icon(Icons.health_and_safety,
                    color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(isUser ? "You" : modelName,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isUser ? kEiraText : kEiraYellowHover,
                          fontFamily: 'Roboto')),
                  const SizedBox(width: 8),
                  Text(_formatTime(timestamp),
                      style: const TextStyle(
                          fontSize: 12,
                          color: kEiraTextSecondary,
                          fontFamily: 'Roboto')),
                ]),
                const SizedBox(height: 4),
                if (text.isNotEmpty)
                  Text(text,
                      style: const TextStyle(height: 1.5, fontFamily: 'Roboto')),
                if (hasLocalAttachment) ...[
                  const SizedBox(height: 10),
                  ...attachments!.map((file) => AttachmentChip(file: file)),
                ],
                if (hasRemoteAttachment) ...[
                  const SizedBox(height: 10),
                  RemoteAttachmentChip(fileUrl: fileUrl!, fileType: fileType),
                ]
              ],
            ),
          )
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
  }
}

class RemoteAttachmentChip extends StatelessWidget {
  final String fileUrl;
  final String? fileType;

  const RemoteAttachmentChip(
      {super.key, required this.fileUrl, this.fileType});

  IconData _getIconForMimeType(String? mimeType) {
    if (mimeType == null) return Icons.insert_drive_file;
    if (mimeType.startsWith('image/')) return Icons.image;
    if (mimeType.startsWith('video/')) return Icons.videocam;
    if (mimeType.startsWith('audio/')) return Icons.audiotrack;
    if (mimeType == 'application/pdf') return Icons.picture_as_pdf;
    return Icons.insert_drive_file;
  }

  String _getCleanFileName(String url) {
    try {
      final decodedUrl = Uri.decodeComponent(url);
      final lastSlashIndex = decodedUrl.lastIndexOf('/');
      if (lastSlashIndex == -1) {
        return decodedUrl;
      }
      final fullFileName = decodedUrl.substring(lastSlashIndex + 1);
      final firstUnderscoreIndex = fullFileName.indexOf('_');
      if (firstUnderscoreIndex == -1) {
        return fullFileName;
      }
      return fullFileName.substring(firstUnderscoreIndex + 1);
    } catch (e) {
      return "Attachment";
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileName = _getCleanFileName(fileUrl);
    final icon = _getIconForMimeType(fileType);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Opening file: $fileName')));
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: kEiraYellowHover, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  fileName,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AttachmentChip extends StatelessWidget {
  final PlatformFileWrapper file;

  const AttachmentChip({super.key, required this.file});

  @override
  Widget build(BuildContext context) {
    final fileName = file.name;
    final fileSize = file.path != null && !kIsWeb
        ? _formatFileSize((File(file.path!) as dynamic).lengthSync())
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: () => _openFile(context, file),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_getFileIcon(fileName), color: kEiraYellowHover, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w500, fontFamily: 'Roboto'),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (fileSize != null)
                      Text(
                        fileSize,
                        style: const TextStyle(
                          fontSize: 12,
                          color: kEiraTextSecondary,
                          fontFamily: 'Roboto',
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openFile(BuildContext context, PlatformFileWrapper file) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Opening ${file.name}')),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  IconData _getFileIcon(String name) {
    final extension = name.split('.').last.toLowerCase();
    if (['pdf'].contains(extension)) return Icons.picture_as_pdf;
    if (['jpg', 'jpeg', 'png'].contains(extension)) return Icons.image;
    if (['mp4', 'mov'].contains(extension)) return Icons.videocam;
    if (['mp3', 'aac', 'wav'].contains(extension)) return Icons.audiotrack;
    return Icons.insert_drive_file;
  }
}

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const CircleAvatar(
          backgroundColor: kEiraYellow,
          child: Icon(Icons.health_and_safety, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(20)),
          child: Row(
            children: List.generate(3, (index) {
              return AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final double t = ((_controller.value + (index * 0.2)) % 1.0);
                  final double scale = 1.0 - (4.0 * math.pow(t - 0.5, 2));
                  return Transform.scale(scale: scale, child: child);
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  child: CircleAvatar(
                      radius: 4, backgroundColor: Colors.grey.shade500),
                ),
              );
            }),
          ),
        )
      ],
    );
  }
}

class ChatInputArea extends StatefulWidget {
  final bool isRecordingAudio;
  final bool isRecordingVideo;
  final String recognizedText;
  final TextEditingController textController;
  final VoidCallback onRecordToggle;
  final VoidCallback onFileAdd;
  final VoidCallback onCameraOpen;
  final VoidCallback onSendMessage;
  final bool hasPendingFiles;

  const ChatInputArea({
    super.key,
    required this.isRecordingAudio,
    required this.isRecordingVideo,
    required this.recognizedText,
    required this.textController,
    required this.onRecordToggle,
    required this.onFileAdd,
    required this.onCameraOpen,
    required this.onSendMessage,
    required this.hasPendingFiles,
  });

  @override
  State<ChatInputArea> createState() => _ChatInputAreaState();
}

class _ChatInputAreaState extends State<ChatInputArea> {
  @override
  void didUpdateWidget(ChatInputArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.recognizedText != oldWidget.recognizedText) {
      widget.textController.text = widget.recognizedText;
    }
  }

    @override
  Widget build(BuildContext context) {
    final bool isMobile = ResponsiveUtils.isMobile(context);
    final bool isWeb = kIsWeb;

    return Container(
      padding: EdgeInsets.all(isMobile ? 20.0 : 24.0),
      decoration: BoxDecoration(
        color: kEiraBackground,
        border: Border(top: BorderSide(color: kEiraBorder.withOpacity(0.3))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 800),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: kEiraBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: widget.textController,
                    decoration: const InputDecoration(
                      hintText: "Start typing a prompt",
                      hintStyle: TextStyle(
                          color: kEiraTextSecondary, fontFamily: 'Roboto'),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 20.0, vertical: 16.0),
                    ),
                    style: const TextStyle(fontFamily: 'Roboto'),
                    maxLines: null,
                    minLines: 1,
                  ),
                ),
                // --- MODIFICATION START ---
                // REMOVED the Refresh IconButton from this area
                // --- MODIFICATION END ---
                IconButton(
                  icon: const Icon(Icons.add, color: kEiraTextSecondary),
                  onPressed: widget.onFileAdd,
                ),
                Container(
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: kEiraYellow,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: widget.onSendMessage,
                  ),
                ),
              ],
            ),
          ),
          
          if (isWeb || isMobile) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildActionButton(
                  icon: widget.isRecordingAudio ? Icons.stop : Icons.mic,
                  label: widget.isRecordingAudio ? "Stop" : "Talk",
                  onPressed: widget.onRecordToggle,
                  isActive: widget.isRecordingAudio,
                ),
                const SizedBox(width: 24),
                _buildActionButton(
                  icon: widget.isRecordingVideo ? Icons.stop : Icons.videocam,
                  label: widget.isRecordingVideo ? "Stop" : "Webcam",
                  onPressed: widget.onCameraOpen,
                  isActive: widget.isRecordingVideo,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isActive = false,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? kEiraYellow.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isActive ? kEiraYellow : kEiraText,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isActive ? kEiraYellow : kEiraText,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                fontFamily: 'Roboto',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VideoRecordingPreview extends StatelessWidget {
  final CameraController cameraController;
  final VoidCallback onStopRecording;
  final VoidCallback onClose;

  const VideoRecordingPreview({
    super.key,
    required this.cameraController,
    required this.onStopRecording,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (cameraController.value.isInitialized)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 240,
                  height: 320,
                  child: CameraPreview(cameraController),
                ),
              )
            else
              const SizedBox(
                width: 240,
                height: 320,
                child: Center(child: CircularProgressIndicator()),
              ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: onStopRecording,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade400,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                  child: const Text("Stop Recording",
                      style: TextStyle(fontFamily: 'Roboto')),
                ),
                const SizedBox(width: 16),
                OutlinedButton(
                  onPressed: onClose,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kEiraText,
                    side: const BorderSide(color: kEiraBorder),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                  child:
                      const Text("Close", style: TextStyle(fontFamily: 'Roboto')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}