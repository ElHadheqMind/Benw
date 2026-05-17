import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:benw_edu/theme/app_theme.dart';
import 'package:benw_edu/providers/calendar_provider.dart';
import 'package:benw_edu/providers/subjects_provider.dart';
import 'package:benw_edu/providers/settings_provider.dart';
import 'package:benw_edu/screens/home_screen.dart';
import 'package:benw_edu/services/notification_service.dart';
import 'package:benw_edu/services/background_service_manager.dart';
import 'package:benw_edu/services/benw_edu_service.dart';

// NOTE: overlayMain() and OverlayCompanionBubble have been REMOVED.
// The system overlay (flutter_overlay_window) created a transparent Flutter
// render surface that caused Impeller to allocate a ~16M px GPU texture →
// SIGSEGV crash in JNISurfaceTextu. The companion chat now lives only
// inside the app. Notification tap → app opens → in-app chat opens.

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Prevent Google Fonts from hanging the UI thread
  GoogleFonts.config.allowRuntimeFetching = false;

  await FlutterGemma.initialize();
  await NotificationService().init();
  await NotificationService().requestPermissions();
  await BackgroundServiceManager().init();
  
  // Start AI Core initialization (extraction/mapping) early
  // ignore: unawaited_futures
  BenwEduService().init();

  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.surface,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(const BenwEduApp());
}

class BenwEduApp extends StatelessWidget {
  const BenwEduApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CalendarProvider()),
        ChangeNotifierProvider(create: (_) => SubjectsProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: MaterialApp(
        title: 'Benw Education',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const HomeScreen(),
      ),
    );
  }
}
