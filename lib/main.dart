import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

void main() => runApp(const MLCApp());

class MLCApp extends StatelessWidget {
  const MLCApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo, brightness: Brightness.dark),
      ),
      home: const MainContainer(),
    );
  }
}

enum AppPage { login, studentCourse, studentStudy, teacherDashboard }
enum UserRole { student, teacher }

class MainContainer extends StatefulWidget {
  const MainContainer({super.key});

  @override
  State<MainContainer> createState() => _MainContainerState();
}

class _MainContainerState extends State<MainContainer> {
  AppPage _currentPage = AppPage.login;
  UserRole _selectedRole = UserRole.student;

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _loginError = '';

  String _selectedCourse = '高等数学';
  String _selectedClass = '高三一班';

  final List<String> _courseList = ['高等数学', '英语听力', '物理实验', '计算机基础'];
  final List<String> _classList = ['高三一班', '高三二班', '高一三班'];

  final Map<String, List<Map<String, dynamic>>> _classStudents = {
    '高三一班': [
      {'name': '张三', 'score': 0.85},
      {'name': '李四', 'score': 0.72},
      {'name': '王五', 'score': 0.63},
    ],
    '高三二班': [
      {'name': '赵六', 'score': 0.90},
      {'name': '钱七', 'score': 0.58},
      {'name': '孙八', 'score': 0.67},
    ],
    '高一三班': [
      {'name': '周九', 'score': 0.79},
      {'name': '吴十', 'score': 0.88},
      {'name': '郑十一', 'score': 0.69},
    ],
  };

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() {
    String username = _usernameController.text.trim();
    String password = _passwordController.text.trim();
    bool valid = false;
    if (_selectedRole == UserRole.student) {
      valid = username == 'student' && password == '1234';
    } else {
      valid = username == 'teacher' && password == '1234';
    }

    if (valid) {
      setState(() {
        _loginError = '';
        _currentPage = _selectedRole == UserRole.student ? AppPage.studentCourse : AppPage.teacherDashboard;
      });
    } else {
      setState(() {
        _loginError = '登录失败，请使用模拟账号 student/1234 或 teacher/1234';
      });
    }
  }

  void _logout() {
    setState(() {
      _currentPage = AppPage.login;
      _selectedRole = UserRole.student;
      _usernameController.clear();
      _passwordController.clear();
      _loginError = '';
    });
  }

  Widget _buildPage() {
    switch (_currentPage) {
      case AppPage.login:
        return _buildLoginPage();
      case AppPage.studentCourse:
        return StudentCoursePage(
          selectedCourse: _selectedCourse,
          courseList: _courseList,
          onCourseSelected: (value) => setState(() => _selectedCourse = value),
          onStartLearning: () => setState(() => _currentPage = AppPage.studentStudy),
        );
      case AppPage.studentStudy:
        return StudentStudyPage(
          course: _selectedCourse,
          onBack: () => setState(() => _currentPage = AppPage.studentCourse),
        );
      case AppPage.teacherDashboard:
        return TeacherDashboardPage(
          selectedClass: _selectedClass,
          classList: _classList,
          classStudents: _classStudents,
          onClassSelected: (value) => setState(() => _selectedClass = value),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MLC 教育平台'),
        centerTitle: true,
        actions: _currentPage == AppPage.login
            ? null
            : [
                IconButton(
                  icon: const Icon(Icons.logout),
                  tooltip: '退出登录',
                  onPressed: _logout,
                )
              ],
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _buildPage(),
        ),
      ),
    );
  }

  Widget _buildLoginPage() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('欢迎登录 MLC 教育平台', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                const Text('请选择身份并使用模拟账号登录：学生 student / 1234，教师 teacher / 1234。'),
                const SizedBox(height: 20),
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('学生'),
                      selected: _selectedRole == UserRole.student,
                      onSelected: (_) => setState(() => _selectedRole = UserRole.student),
                    ),
                    const SizedBox(width: 12),
                    ChoiceChip(
                      label: const Text('教师'),
                      selected: _selectedRole == UserRole.teacher,
                      onSelected: (_) => setState(() => _selectedRole = UserRole.teacher),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _usernameController,
                  decoration: const InputDecoration(labelText: '用户名'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: '密码'),
                ),
                if (_loginError.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(_loginError, style: const TextStyle(color: Colors.redAccent)),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _login,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text('登录', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StudentCoursePage extends StatelessWidget {
  final String selectedCourse;
  final List<String> courseList;
  final ValueChanged<String> onCourseSelected;
  final VoidCallback onStartLearning;

  const StudentCoursePage({
    super.key,
    required this.selectedCourse,
    required this.courseList,
    required this.onCourseSelected,
    required this.onStartLearning,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('学生端课程选择', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          const Text('请选择课件，然后点击开始学习。'),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('课程列表', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCourse,
                    items: courseList.map((course) => DropdownMenuItem(value: course, child: Text(course))).toList(),
                    onChanged: (value) {
                      if (value != null) onCourseSelected(value);
                    },
                    decoration: const InputDecoration(border: OutlineInputBorder(), labelText: '选择课程'),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: onStartLearning,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text('开始学习', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('学习建议', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    SizedBox(height: 12),
                    Text('1. 保持摄像头正对面部，确保系统能实时评估专注度。'),
                    SizedBox(height: 8),
                    Text('2. 学习中请避免频繁离开屏幕，系统会记录专注分数。'),
                    SizedBox(height: 8),
                    Text('3. 结束后会生成学习总结图表。'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StudentStudyPage extends StatefulWidget {
  final String course;
  final VoidCallback onBack;

  const StudentStudyPage({super.key, required this.course, required this.onBack});

  @override
  State<StudentStudyPage> createState() => _StudentStudyPageState();
}

class _StudentStudyPageState extends State<StudentStudyPage> {
  bool _permissionGranted = false;
  bool _studyEnded = false;
  double _attentionScore = 0.82;

  void _requestCameraPermission() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('摄像头权限请求'),
        content: const Text('模拟请求摄像头权限，用于学习过程中的专注度监测。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              setState(() => _permissionGranted = true);
              Navigator.pop(context);
            },
            child: const Text('允许'),
          ),
        ],
      ),
    );
  }

  void _endStudy() {
    setState(() {
      _studyEnded = true;
      _attentionScore = 0.78;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('学习过程', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              TextButton.icon(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back),
                label: const Text('返回课程选择'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('当前课程：${widget.course}', style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 20),
          if (!_permissionGranted)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('摄像头权限', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    const Text('请先授予摄像头访问权限，系统将模拟获取摄像头流用于专注度检测。'),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _requestCameraPermission,
                      child: const Text('请求摄像头权限'),
                    ),
                  ],
                ),
              ),
            )
          else if (!_studyEnded)
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('学习中...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
                          child: const Center(child: Text('模拟摄像头视频流', style: TextStyle(color: Colors.white54))),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _endStudy,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Text('结束学习', style: TextStyle(fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: SummaryCard(
                course: widget.course,
                attentionScore: _attentionScore,
              ),
            ),
        ],
      ),
    );
  }
}

class SummaryCard extends StatelessWidget {
  final String course;
  final double attentionScore;

  const SummaryCard({super.key, required this.course, required this.attentionScore});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('学习总结', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: CircularPercentIndicator(
                    radius: 90,
                    lineWidth: 12,
                    percent: attentionScore,
                    center: Text('${(attentionScore * 100).toInt()}%', style: const TextStyle(fontSize: 20)),
                    progressColor: attentionScore > 0.7 ? Colors.greenAccent : Colors.orangeAccent,
                    backgroundColor: Colors.white10,
                    circularStrokeCap: CircularStrokeCap.round,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('课程：$course', style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 12),
                      Text('专注度评分：${(attentionScore * 100).toInt()}分', style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 8),
                      const Text('持续专注时间：45分钟', style: TextStyle(fontSize: 16)),
                      const SizedBox(height: 8),
                      const Text('低头次数：2次', style: TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('学习过程图表', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Expanded(
              child: Row(
                children: const [
                  _DetailBar(label: '专注', value: 0.8, color: Colors.greenAccent),
                  _DetailBar(label: '分心', value: 0.15, color: Colors.orangeAccent),
                  _DetailBar(label: '离线', value: 0.05, color: Colors.redAccent),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailBar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _DetailBar({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    heightFactor: value,
                    child: Container(
                      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center),
            Text('${(value * 100).toInt()}%', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class TeacherDashboardPage extends StatelessWidget {
  final String selectedClass;
  final List<String> classList;
  final Map<String, List<Map<String, dynamic>>> classStudents;
  final ValueChanged<String> onClassSelected;

  const TeacherDashboardPage({
    super.key,
    required this.selectedClass,
    required this.classList,
    required this.classStudents,
    required this.onClassSelected,
  });

  @override
  Widget build(BuildContext context) {
    final students = classStudents[selectedClass] ?? [];
    double averageScore = students.isEmpty ? 0 : students.map((e) => e['score'] as double).reduce((a, b) => a + b) / students.length;
    int offlineCount = students.where((e) => (e['score'] as double) < 0.6).length;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('教师端班级视图', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('选择班级：', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: selectedClass,
                items: classList.map((clazz) => DropdownMenuItem(value: clazz, child: Text(clazz))).toList(),
                onChanged: (value) {
                  if (value != null) onClassSelected(value);
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _OverviewTile(title: '学生人数', value: students.length.toString(), icon: Icons.group),
              const SizedBox(width: 12),
              _OverviewTile(title: '平均专注度', value: '${(averageScore * 100).toInt()}%', icon: Icons.analytics),
              const SizedBox(width: 12),
              _OverviewTile(title: '低专注学生', value: offlineCount.toString(), icon: Icons.warning, color: Colors.redAccent),
            ],
          ),
          const SizedBox(height: 24),
          const Text('学生专注度名单', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: students.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final student = students[index];
                final score = student['score'] as double;
                return ListTile(
                  leading: CircleAvatar(child: Text(student['name'][0])),
                  title: Text(student['name']),
                  subtitle: Text('专注度 ${(score * 100).toInt()}%'),
                  trailing: Text(
                    score > 0.7 ? '正常' : '提醒',
                    style: TextStyle(color: score > 0.7 ? Colors.greenAccent : Colors.orangeAccent),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _OverviewTile({required this.title, required this.value, required this.icon, this.color = Colors.indigoAccent});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 12),
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(title, style: const TextStyle(fontSize: 14, color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }
}
