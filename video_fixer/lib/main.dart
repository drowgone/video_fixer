import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:workmanager/workmanager.dart';
import 'services/settings_provider.dart';
import 'services/notification_service.dart';
import 'services/youtube_uploader.dart';
import 'services/video_processing_provider.dart';
import 'services/upload_queue_service.dart';
import 'screens/home_screen.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/splash_screen.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == "syncYouTubeStatus") {
      WidgetsFlutterBinding.ensureInitialized();
      await NotificationService.init();
      final changed = await YouTubeUploader.syncYouTubeStatuses();
      return changed >= 0;
    }
    return true;
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize push notifications and background sync with graceful fallback.
  try {
    await NotificationService.init();
  } catch (e) {
    debugPrint('NotificationService init failed: $e');
  }
  try {
    await Workmanager().initialize(callbackDispatcher);
    await Workmanager().registerPeriodicTask(
      "youtube-sync",
      "syncYouTubeStatus",
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  } catch (e) {
    debugPrint('Workmanager init failed: $e');
  }

  try {
    await UploadQueueService.instance.initialize();
  } catch (e) {
    debugPrint('UploadQueueService init failed: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => VideoProcessingProvider()),
        ChangeNotifierProvider.value(value: UploadQueueService.instance),
      ],
      child: const VideoFixerApp(),
    ),
  );
}

class VideoFixerApp extends StatelessWidget {
  const VideoFixerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VideoFixer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF0000),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'sans-serif',
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

class PulsatingGreenDot extends StatefulWidget {
  const PulsatingGreenDot({super.key});

  @override
  State<PulsatingGreenDot> createState() => _PulsatingGreenDotState();
}

class _PulsatingGreenDotState extends State<PulsatingGreenDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF00FF00),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00FF00).withValues(alpha: 0.6 * _animation.value),
                blurRadius: 6 * _animation.value,
                spreadRadius: 2 * _animation.value,
              ),
            ],
          ),
        );
      },
    );
  }
}

class MainTabScreen extends StatefulWidget {
  static Function(int)? onSwitchTab;

  const MainTabScreen({super.key});

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  int _currentIndex = 0;
  int _previousIndex = 0;
  VideoProcessingProvider? _processingProvider;
  ProcessState _lastState = ProcessState.idle;

  @override
  void initState() {
    super.initState();
    MainTabScreen.onSwitchTab = (index) {
      if (mounted) {
        setState(() {
          _previousIndex = _currentIndex;
          _currentIndex = index;
        });
      }
    };
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = Provider.of<VideoProcessingProvider>(context, listen: false);
    if (_processingProvider != provider) {
      _processingProvider?.removeListener(_onProcessingChanged);
      _processingProvider = provider;
      _processingProvider?.addListener(_onProcessingChanged);
    }
  }

  @override
  void dispose() {
    _processingProvider?.removeListener(_onProcessingChanged);
    MainTabScreen.onSwitchTab = null;
    super.dispose();
  }

  void _onProcessingChanged() {
    if (_processingProvider == null) return;
    final state = _processingProvider!.processingState;
    if (state == ProcessState.done && _lastState == ProcessState.processing) {
      final videoName = _processingProvider!.videoName ?? 'Video';
      NotificationService.showNotification(
        id: 999,
        title: videoName,
        body: 'Tayyor — yuklashga o\'tish uchun bosing',
        payload: 'home',
        channel: NotifChannel.ready,
      );

      if (_currentIndex != 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $videoName tayyor!'),
            action: SnackBarAction(
              label: 'O\'tish',
              textColor: const Color(0xFFFF0000),
              onPressed: () {
                MainTabScreen.onSwitchTab?.call(0);
              },
            ),
            backgroundColor: const Color(0xFF1E1E1E),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
    _lastState = state;
  }

  final List<Widget> _screens = [
    const HomeScreen(),
    const HistoryScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        transitionBuilder: (Widget child, Animation<double> animation) {
          final bool isForward = child.key == ValueKey<int>(_currentIndex)
              ? _currentIndex > _previousIndex
              : _currentIndex < _previousIndex;

          final offsetAnimation = Tween<Offset>(
            begin: Offset(isForward ? 0.5 : -0.5, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOutCubic,
          ));
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: offsetAnimation, child: child),
          );
        },
        child: Container(
          key: ValueKey<int>(_currentIndex),
          child: _screens[_currentIndex],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          if (index == _currentIndex) return;
          setState(() {
            _previousIndex = _currentIndex;
            _currentIndex = index;
          });
        },
        backgroundColor: const Color(0xFF161616),
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black54,
        elevation: 8,
        indicatorColor: const Color(0xFFFF0000).withValues(alpha: 0.25),
        destinations: [
          NavigationDestination(
            icon: Consumer<VideoProcessingProvider>(
              builder: (context, provider, child) {
                final isProcessing = provider.processingState == ProcessState.processing;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.home_outlined),
                    if (isProcessing)
                      const Positioned(
                        top: -2,
                        right: -2,
                        child: PulsatingGreenDot(),
                      ),
                  ],
                );
              },
            ),
            selectedIcon: Consumer<VideoProcessingProvider>(
              builder: (context, provider, child) {
                final isProcessing = provider.processingState == ProcessState.processing;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.home, color: Color(0xFFFF0000)),
                    if (isProcessing)
                      const Positioned(
                        top: -2,
                        right: -2,
                        child: PulsatingGreenDot(),
                      ),
                  ],
                );
              },
            ),
            label: 'Asosiy',
          ),
          NavigationDestination(
            icon: Consumer<UploadQueueService>(
              builder: (context, queue, child) {
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.history_outlined),
                    if (queue.queueCount > 0)
                      Positioned(
                        top: -4,
                        right: -6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          constraints: const BoxConstraints(minWidth: 16),
                          child: Text(
                            '${queue.queueCount}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            selectedIcon: Consumer<UploadQueueService>(
              builder: (context, queue, child) {
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.history, color: Color(0xFFFF0000)),
                    if (queue.queueCount > 0)
                      Positioned(
                        top: -4,
                        right: -6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          constraints: const BoxConstraints(minWidth: 16),
                          child: Text(
                            '${queue.queueCount}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            label: 'Videolar',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings, color: Color(0xFFFF0000)),
            label: 'Sozlamalar',
          ),
        ],
      ),
    );
  }
}
