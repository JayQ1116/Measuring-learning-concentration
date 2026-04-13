import 'package:flutter/material.dart';

class AppTheme {
  // 1. 核心颜色定义 (确保变量名与 pages 里的调用完全一致)
  static const Color primaryBlue = Color(0xFF102C57);
  static const Color primaryColor = primaryBlue; // 别名，增加兼容性
  static const Color scaffoldBackgroundColor = Color(0xFFF4F7FE);
  static const Color successColor = Color(0xFF2DCE89);
  static const Color errorColor = Color(0xFFF5365C);
  static const Color textMain = Color(0xFF172B4D);

  // 2. 登录页渐变色
  static const Color loginBgStart = Color(0xFF1A469D);
  static const Color loginBgEnd = Color(0xFF3B71CA);

  // 3. 全局主题配置 (注意：ThemeData 前面不要加 const)
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: scaffoldBackgroundColor,
    
    // AppBar 样式
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: textMain,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 18, 
        fontWeight: FontWeight.bold, 
        color: textMain
      ),
    ),

    cardTheme: CardThemeData(
  color: Colors.white,
  elevation: 0,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
    side: const BorderSide(color: Color(0xFFE9ECEF), width: 1),
  ),
),

    // 按钮样式
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 0,
      ),
    ),

    // 输入框样式 (对齐图片中的质感)
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE9ECEF)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE9ECEF)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryBlue, width: 2),
      ),
    ),
  );
}