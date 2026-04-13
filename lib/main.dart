import 'package:flutter/material.dart';
import 'app_theme.dart'; // 引入主题
import 'pages/login_page.dart'; // 引入你的 login_page.dart

void main() => runApp(const LensFocusApp());

class LensFocusApp extends StatelessWidget {
  const LensFocusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LensFocus AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme, // 使用定义的全局主题
      home: const LoginPage(), // 程序启动页
    );
  }
}