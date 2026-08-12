import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../services/db_helper.dart';
import '../services/video_processing_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _logoAnimController;
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;

  late AnimationController _textAnimController;
  late Animation<int> _textLength;

  late AnimationController _progressAnimController;
  late Animation<double> _progressValue;

  final String _appName = "VideoFixer";

  @override
  void initState() {
    super.initState();
    // Pre-cache logo image if possible, but AssetImage loads quickly anyway.

    _logoAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(CurvedAnimation(parent: _logoAnimController, curve: Curves.easeOutBack));
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _logoAnimController, curve: Curves.easeIn));

    _textAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _textLength = IntTween(begin: 0, end: _appName.length).animate(CurvedAnimation(parent: _textAnimController, curve: Curves.linear));

    _progressAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _progressValue = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _progressAnimController, curve: Curves.easeInOut));

    _startAnimations();
  }

  void _startAnimations() async {
    // 1. Logo pop
    await _logoAnimController.forward();
    // 2. Typewriter text
    await _textAnimController.forward();
    // 3. Progress bar
    await _progressAnimController.forward();

    // Run startup maintenance in parallel
    try {
      await Future.wait([
        VideoProcessingProvider.cleanupOrphanedTempFiles(),
        DBHelper.instance.syncHistoryFromVideoFixerFolder(),
      ]);
    } catch (_) {}

    // Small delay before transition
    await Future.delayed(const Duration(milliseconds: 200));

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (context, animation, secondaryAnimation) => const MainTabScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }
  }

  @override
  void dispose() {
    _logoAnimController.dispose();
    _textAnimController.dispose();
    _progressAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.black,
    ));

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            // Logo
            AnimatedBuilder(
              animation: _logoAnimController,
              builder: (context, child) {
                return Opacity(
                  opacity: _logoFade.value,
                  child: Transform.scale(
                    scale: _logoScale.value,
                    child: Image.asset(
                      'assets/logo.png', // Fallback to an icon if not found
                      width: 120,
                      height: 120,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.video_library, size: 120, color: Colors.red),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            // Typewriter Text
            AnimatedBuilder(
              animation: _textAnimController,
              builder: (context, child) {
                String visibleString = _appName.substring(0, _textLength.value);
                return Text(
                  visibleString,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                  ),
                );
              },
            ),
            const Spacer(),
            // Thin green progress bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 40.0),
              child: AnimatedBuilder(
                animation: _progressAnimController,
                builder: (context, child) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: _progressValue.value,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF0000)),
                      minHeight: 3,
                    ),
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
