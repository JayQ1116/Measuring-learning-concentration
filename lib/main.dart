import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'firebase_options.dart';
import 'pages/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 10));
    debugPrint('[Firebase] 초기화 성공');
  } catch (e) {
    debugPrint('[Firebase] 초기화 실패: $e');
  }
  runApp(const LensFocusApp());
}

class LensFocusApp extends StatelessWidget {
  const LensFocusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LensFocus AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const LoginPage(),
    );
  }
}