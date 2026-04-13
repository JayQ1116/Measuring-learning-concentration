import 'package:flutter/material.dart';
import 'teacher_monitoring_page.dart';

class TeacherDashboardPage extends StatelessWidget {
  const TeacherDashboardPage({super.key});

  static const List<Map<String, dynamic>> _courses = [
    {'name': '머신러닝 기초', 'totalStudents': 28, 'activeStudents': 15, 'avgFocus': 78, 'isLive': true},
    {'name': '딥러닝 심화', 'totalStudents': 32, 'activeStudents': 24, 'avgFocus': 85, 'isLive': true},
    {'name': '자연어 처리', 'totalStudents': 26, 'activeStudents': 18, 'avgFocus': 88, 'isLive': true},
    {'name': '컴퓨터 비전', 'totalStudents': 30, 'activeStudents': 0, 'avgFocus': 0, 'isLive': false},
  ];

  @override
  Widget build(BuildContext context) {
    final totalStudents = _courses.fold<int>(0, (sum, c) => sum + (c['totalStudents'] as int));
    final activeStudents = _courses.fold<int>(0, (sum, c) => sum + (c['activeStudents'] as int));
    final liveCourses = _courses.where((c) => c['isLive'] as bool).toList();
    final avgFocus = liveCourses.isEmpty
        ? 0
        : (liveCourses.fold<int>(0, (sum, c) => sum + (c['avgFocus'] as int)) / liveCourses.length).round();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(color: const Color(0xFF3B71CA), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.person, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("교사 대시보드", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF172B4D))),
                Text("이수민 선생님", style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.normal)),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
            child: const Text("로그아웃", style: TextStyle(color: Color(0xFF172B4D), fontSize: 13)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("학급 선택", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF172B4D))),
            const SizedBox(height: 4),
            const Text("모니터링하실 강의를 선택해주세요", style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 20),

            // 통계 카드 2x2
            Row(
              children: [
                _buildTopStatCard("전체 학급", "${_courses.length}개", Colors.black87, Icons.group_outlined),
                const SizedBox(width: 12),
                _buildTopStatCard("전체 학생", "${totalStudents}명", Colors.green, Icons.people_outline),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildTopStatCard("현재 학습 중", "${activeStudents}명", Colors.orange, Icons.access_time_outlined),
                const SizedBox(width: 12),
                _buildTopStatCard("평균 집중도", "${avgFocus}점", Colors.purple, Icons.psychology_outlined),
              ],
            ),

            const SizedBox(height: 24),

            Row(
              children: [
                Container(width: 9, height: 9, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                const Text("실시간 활동 중", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF172B4D))),
              ],
            ),
            const SizedBox(height: 16),

            // 강의 카드 — 竖向列表
            for (int i = 0; i < _courses.length; i++) ...[
              _buildCourseCard(context, _courses[i]),
              if (i < _courses.length - 1) const SizedBox(height: 16),
            ],

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTopStatCard(String title, String value, Color valueColor, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey), overflow: TextOverflow.ellipsis),
                ),
                Icon(icon, size: 16, color: Colors.grey.withValues(alpha: 0.5)),
              ],
            ),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: valueColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseCard(BuildContext context, Map<String, dynamic> course) {
    final isLive = course['isLive'] as bool;
    final avgFocus = course['avgFocus'] as int;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(course['name'],
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF172B4D))),
              ),
              if (isLive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 5, height: 5, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      const Text("실시간", style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.menu_book_outlined, size: 13, color: Colors.grey),
              const SizedBox(width: 4),
              Text(course['name'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildMiniStat("${course['totalStudents']}", "전체 학생", const Color(0xFF172B4D)),
              const SizedBox(width: 28),
              _buildMiniStat("${course['activeStudents']}", "학습 중", Colors.green),
              const SizedBox(width: 28),
              _buildMiniStat(isLive ? "$avgFocus" : "-", "평균 집중도", Colors.orange),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isLive
                  ? () => Navigator.push(context,
                        MaterialPageRoute(builder: (c) => TeacherMonitoringPage(courseName: course['name'])))
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: isLive ? const Color(0xFF3B71CA) : Colors.grey.shade300,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(isLive ? "실시간 모니터링 시작" : "수업 준비 중",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  if (isLive) ...[const SizedBox(width: 4), const Icon(Icons.chevron_right, size: 18)],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String value, String label, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}