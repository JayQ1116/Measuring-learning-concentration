import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

void main() => runApp(const MLCApp());

// ================= 全局视觉定义 =================
class GaoLuoTheme {
  // 藏蓝色: 用于 Appbar, 主按钮, 导航
  static const Color navy = Color(0xFF102C57);
  // 白色/浅米色: 用于全局背景
  static const Color background = Color(0xFFFEFAF6);
  // 黄色: 用于图标点缀, 警示, 高亮
  static const Color yellow = Color(0xFFFFD700);
  // 灰色: 用于次要文字和边框
  static const Color grey = Color(0xFFDAC0A3);
  static const Color textDark = Color(0xFF102C57);
  static const Color textLight = Colors.white;

  static ThemeData get lightTheme {
    return newMethod();
  }

  static ThemeData newMethod() {
    return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: background,
    primaryColor: navy,
    colorScheme: const ColorScheme.light(
      primary: navy,
      secondary: yellow,
      surface: Colors.white,
    ),
    // 全局卡片样式：圆角+微阴影
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    // AppBar 样式
    appBarTheme: const AppBarTheme(
      backgroundColor: navy,
      foregroundColor: textLight,
      centerTitle: true,
      titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.1),
    ),
    // 输入框样式
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: navy, width: 2)),
    ),
    // 按钮样式
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: navy,
        foregroundColor: textLight,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 3,
      ),
    ),
  );
  }
}

class MLCApp extends StatelessWidget {
  const MLCApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: GaoLuoTheme.lightTheme,
      home: const LoginPage(),
    );
  }
}

// ================= 1. 登录页面 (美化版) =================
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  String _userRole = 'Student';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GaoLuoTheme.navy, // 登录页使用藏蓝背景，营造专业感
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              // Logo/图标 占位
              const Icon(Icons.school_outlined, size: 80, color: GaoLuoTheme.yellow),
              const SizedBox(height: 20),
              const Text("MLC AI 교육 플랫폼", style: TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 50),
              // 登录卡片
              _buildLoginCard(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: GaoLuoTheme.background,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, 10))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("사용자 로그인", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: GaoLuoTheme.textDark)),
          const SizedBox(height: 30),
          DropdownButtonFormField<String>(
            value: _userRole,
            decoration: const InputDecoration(labelText: "신분 선택"),
            items: ['Student', 'Teacher'].map((role) => DropdownMenuItem(
              value: role, child: Text(role == 'Student' ? "학생" : "교사")
            )).toList(),
            onChanged: (v) => setState(() => _userRole = v!),
          ),
          const SizedBox(height: 20),
          const TextField(decoration: InputDecoration(hintText: "아이디")),
          const SizedBox(height: 15),
          const TextField(decoration: InputDecoration(hintText: "비밀번호"), obscureText: true),
          const SizedBox(height: 35),
          ElevatedButton(
            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => _userRole == 'Student' ? const CourseSelectionPage() : const TeacherMainPage())),
            child: const Text("로그인"),
          ),
        ],
      ),
    );
  }
}

// ================= 2. 学生端：课程选择 (美化版) =================
class CourseSelectionPage extends StatelessWidget {
  const CourseSelectionPage({super.key});
  final List<Map<String, String>> courses = const [
    {"title": "딥러닝 입문", "pages": "24"},
    {"title": "컴퓨터 비전 기초", "pages": "18"},
    {"title": "NLP 자연어 처리", "pages": "30"}
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("나의 학습 코스")),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: courses.length,
        separatorBuilder: (ctx, idx) => const SizedBox(height: 15),
        itemBuilder: (context, index) => _buildCourseCard(context, courses[index]),
      ),
    );
  }

  Widget _buildCourseCard(BuildContext context, Map<String, String> course) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        leading: const CircleAvatar(backgroundColor: GaoLuoTheme.background, child: Icon(Icons.import_contacts, color: GaoLuoTheme.navy)),
        title: Text(course["title"]!, style: const TextStyle(fontWeight: FontWeight.bold, color: GaoLuoTheme.textDark)),
        subtitle: Text("PDF 교재 | ${course["pages"]} 페이지", style: const TextStyle(color: Colors.black54)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 18, color: GaoLuoTheme.grey),
        onTap: () => _showPermissionDialog(context, course["title"]!),
      ),
    );
  }

  void _showPermissionDialog(BuildContext context, String courseName) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.photo_camera, size: 50, color: GaoLuoTheme.yellow),
              const SizedBox(height: 20),
              const Text("카메라 접근 권한 요청", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: GaoLuoTheme.textDark)),
              const SizedBox(height: 15),
              const Text("AI 기반 실시간 집중도 모니터링을 위해 카메라 권한이 필요합니다. 학습 중에만 사용됩니다.", textAlign: TextAlign.center, style: TextStyle(color: Colors.black87)),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text("거부", style: TextStyle(color: GaoLuoTheme.navy)))),
                  const SizedBox(width: 15),
                  Expanded(child: ElevatedButton(onPressed: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => StudentLearningPage(courseName: courseName))); }, child: const Text("허용"))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= 3. 学生端：实时学习页面 (美化版) =================
class StudentLearningPage extends StatefulWidget {
  final String courseName;
  const StudentLearningPage({super.key, required this.courseName});
  @override
  State<StudentLearningPage> createState() => _StudentLearningPageState();
}

class _StudentLearningPageState extends State<StudentLearningPage> {
  double _score = 0.88; // 模拟初始分数

  @override
  Widget build(BuildContext context) {
    Color statusColor = _score > 0.7 ? Colors.greenAccent : (_score > 0.4 ? Colors.orangeAccent : Colors.redAccent);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.courseName),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 15),
            child: ElevatedButton(
              onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LearningReportPage())),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white24, foregroundColor: Colors.white, minimumSize: const Size(80, 36)),
              child: const Text("학습 종료", style: TextStyle(fontSize: 12)),
            ),
          )
        ],
      ),
      body: Row(
        children: [
          // 左侧：PDF 阅读区 (模拟)
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.03), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.black12)),
              child: const Center(child: Text("교재 내용 표시 (PDF Viewer Mock)", style: TextStyle(color: Colors.black45))),
            ),
          ),
          // 右侧：HUD 状态栏
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text("실시간 모니터링", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: GaoLuoTheme.textDark)),
                  const SizedBox(height: 10),
                  // 对应你 Focus Ring 设计
                  CircularPercentIndicator(
                    radius: 70.0, lineWidth: 10.0, percent: _score,
                    center: Text("${(_score * 100).toInt()}%", style: TextStyle(fontSize: 26, color: statusColor, fontWeight: FontWeight.bold)),
                    progressColor: statusColor, backgroundColor: Colors.black12,
                    animation: true, animateFromLastPercent: true, circularStrokeCap: CircularStrokeCap.round,
                  ),
                  const SizedBox(height: 10),
                  Text("상태: ${_score > 0.7 ? 'Focused' : 'Distracted'}", style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  const Text("시뮬레이션 조절 (Demonstration Only)"),
                  Slider(value: _score, activeColor: statusColor, onChanged: (v) => setState(() => _score = v)),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================= 4. 学生端：学习总结报告 (美化版) =================
class LearningReportPage extends StatelessWidget {
  const LearningReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("오늘의 학습 리포트")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // 顶部统计
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ReportStatCard(label: "총 학습 시간", value: "45 분", icon: Icons.timer, color: GaoLuoTheme.navy),
                _ReportStatCard(label: "평균 집중도", value: "85 점", icon: Icons.analytics, color: Colors.green),
                _ReportStatCard(label: "집중도 저하 탐지", value: "3 회", icon: Icons.warning, color: Colors.orange),
              ],
            ),
            const SizedBox(height: 30),
            // 模拟图表
            Container(
              height: 220, width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.black12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("집중도 변화 추이 (시뮬레이션)", style: TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  const Center(child: Text("[집중도 곡선 그래프 점선 예시]")),
                  Container(height: 2, color: GaoLuoTheme.grey),
                  const Spacer(),
                ],
              ),
            ),
            const SizedBox(height: 30),
            // AI 建议卡片
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: GaoLuoTheme.background, borderRadius: BorderRadius.circular(16), border: Border.all(color: GaoLuoTheme.navy, width: 0.5)),
              child: const Row(
                children: [
                  Icon(Icons.smart_toy_outlined, color: GaoLuoTheme.navy, size: 30),
                  SizedBox(width: 15),
                  Expanded(child: Text("AI 학습 조언: 학습 중반부(약 20분 경)에 집중도가 급격히 낮아졌습니다. 이 시점에 5분간 휴식을 취하는 것을 추천합니다.")),
                ],
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text("나의 코스로 돌아가기")),
          ],
        ),
      ),
    );
  }
}

class _ReportStatCard extends StatelessWidget {
  final String label, value; final IconData icon; final Color color;
  const _ReportStatCard({required this.label, required this.value, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      width: 100, height: 110,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black.withOpacity(0.05))),
      child: Column(children: [Icon(icon, color: color), const Spacer(), Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.center), Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: GaoLuoTheme.textDark))]),
    );
  }
}

// ================= 5. 教师端页面 (美化版) =================
class TeacherMainPage extends StatefulWidget {
  const TeacherMainPage({super.key});
  @override
  State<TeacherMainPage> createState() => _TeacherMainPageState();
}

class _TeacherMainPageState extends State<TeacherMainPage> {
  String _selectedClass = "딥러닝 입문 A반";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("교수 관리 대시보드"),
        actions: [IconButton(onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage())), icon: const Icon(Icons.logout, color: GaoLuoTheme.yellow))],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // 藏蓝色 班级选择框
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: GaoLuoTheme.navy, borderRadius: BorderRadius.circular(12)),
              child: DropdownButton<String>(
                value: _selectedClass, icon: const Icon(Icons.arrow_drop_down, color: Colors.white), isExpanded: true, underline: Container(), dropdownColor: GaoLuoTheme.navy, style: const TextStyle(color: Colors.white),
                items: ["딥러닝 입문 A반", "컴퓨터 비전 기초 B반"].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _selectedClass = v!),
              ),
            ),
            const SizedBox(height: 25),
            const Align(alignment: Alignment.centerLeft, child: Text("학생별 실시간 집중도 현황", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: GaoLuoTheme.textDark))),
            const SizedBox(height: 15),
            // 学生列表
            Expanded(
              child: ListView.separated(
                itemCount: 8,
                separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  double score = 0.55 + (index % 5) * 0.1;
                  return Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black.withOpacity(0.05))),
                    child: Row(
                      children: [
                        const CircleAvatar(backgroundColor: GaoLuoTheme.background, child: Icon(Icons.person, color: GaoLuoTheme.navy)),
                        const SizedBox(width: 15),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text("학생 GAO_LUO_01$index", style: const TextStyle(fontWeight: FontWeight.bold, color: GaoLuoTheme.textDark)),
                          const Text("상태: 온라인 학습 중", style: TextStyle(fontSize: 11, color: Colors.black54)),
                        ])),
                        CircularPercentIndicator(radius: 20.0, lineWidth: 3.0, percent: score, progressColor: score > 0.7 ? Colors.green : Colors.orange, backgroundColor: Colors.black12, center: Text("${(score*100).toInt()}%", style: const TextStyle(fontSize: 9))),
                      ],
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