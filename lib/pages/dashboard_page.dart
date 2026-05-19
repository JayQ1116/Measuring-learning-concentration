// lib/pages/dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_theme.dart';
import 'course_list_page.dart';
import 'login_page.dart';

class StudentDashboard extends StatelessWidget {
  final String studentId;
  final String studentName;

  const StudentDashboard({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.book, color: AppTheme.primaryColor),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('학습 플랫폼', style: TextStyle(fontSize: 16)),
                Text('$studentName 학생',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
                );
              }
            },
            icon: const Icon(Icons.logout),
            label: const Text('로그아웃'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '안녕하세요, $studentName님! 👋',
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text('오늘도 열심히 학습해볼까요?',
                style: TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 24),

            // 통계 카드
            Row(
              children: [
                _statCard('총 학습 시간', '47시간',
                    Colors.orange, Icons.trending_up),
                const SizedBox(width: 12),
                _statCard('평균 집중도', '82점',
                    Colors.green, Icons.psychology),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _statCard('완료한 강의', '5개',
                    Colors.purple, Icons.check_circle_outline),
                const SizedBox(width: 12),
                _statCard('학습 연속일', '7일',
                    Colors.blue, Icons.local_fire_department),
              ],
            ),
            const SizedBox(height: 24),

            // 강의 섹션
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('📖 내 강의',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CourseListPage(
                              studentId: studentId,
                              studentName: studentName,
                            ),
                          ),
                        ),
                        child: const Text('전체 보기 →',
                            style: TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _courseItem('머신러닝 기초', 0.65, '2시간 전'),
                  _courseItem('딥러닝 심화', 0.32, '1일 전'),
                  _courseItem('자연어 처리', 0.89, '3일 전'),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CourseListPage(
                          studentId: studentId,
                          studentName: studentName,
                        ),
                      ),
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('+ 강의 시작하기',
                          style: TextStyle(
                              color: Colors.grey, fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(
      String title, String val, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: color, width: 4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey),
                      overflow: TextOverflow.ellipsis),
                ),
                Icon(icon, size: 16, color: color.withOpacity(0.7)),
              ],
            ),
            const SizedBox(height: 8),
            Text(val,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ],
        ),
      ),
    );
  }

  Widget _courseItem(String name, double progress, String time) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
              Text(time,
                  style: const TextStyle(
                      fontSize: 11, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
                value: progress, minHeight: 7),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text('${(progress * 100).toInt()}%',
                style: const TextStyle(
                    fontSize: 11, color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}