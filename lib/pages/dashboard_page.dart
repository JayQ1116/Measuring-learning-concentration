import 'package:flutter/material.dart';
import '../app_theme.dart';
import 'course_list_page.dart';

class StudentDashboard extends StatelessWidget {
  final String studentId;
  const StudentDashboard({super.key, required this.studentId});

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
                const Text("학습 플랫폼", style: TextStyle(fontSize: 16)),
                Text("$studentId 학생", style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_none), onPressed: () {}),
          TextButton.icon(
            onPressed: () => Navigator.of(context).popUntil(ModalRoute.withName('/')),
            icon: const Icon(Icons.logout),
            label: const Text("로그아웃"),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "안녕하세요, 나고님! 👋",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              "오늘도 열심히 학습해볼까요?",
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 24),

            // 统计卡片 — 竖向排列，每行2个
            Row(
              children: [
                _buildStatCard("총 학습 시간", "47시간", Colors.orange, Icons.trending_up),
                const SizedBox(width: 12),
                _buildStatCard("평균 집중도", "82점", Colors.green, Icons.menu_book),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildStatCard("완료한 강의", "5개", Colors.purple, Icons.history),
                const SizedBox(width: 12),
                _buildStatCard("학습 연속일", "7일", Colors.blue, Icons.local_fire_department),
              ],
            ),

            const SizedBox(height: 24),

            // 내 강의 섹션
            _buildCourseSection(context),

            const SizedBox(height: 20),

            // 최근 활동
            _buildActivityCard(),

            const SizedBox(height: 20),

            // 내 정보
            _buildProfileCard(),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String val, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: color, width: 4)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(icon, size: 16, color: color.withValues(alpha: 0.7)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              val,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("📖 내 강의", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (c) => CourseListPage(studentId: studentId)),
                ),
                child: const Text("전체 보기 →", style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildCourseItem("머신러닝 기초", 0.65, "2시간 전"),
          _buildCourseItem("딥러닝 심화", 0.32, "1일 전"),
          _buildCourseItem("자연어 처리", 0.89, "3일 전"),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              "+ 새로운 강의 시작하기",
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseItem(String name, double progress, String time) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text(time, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: progress, minHeight: 7),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              "${(progress * 100).toInt()}%",
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("🕒 최근 활동", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          SizedBox(height: 12),
          Text("• 머신러닝 기초 학습 완료", style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.8)),
          Text("• 집중도 85점 달성", style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.8)),
          Text("• 딥러닝 심화 32% 진행 중", style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.8)),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.person, color: Colors.white70, size: 18),
              SizedBox(width: 8),
              Text("내 정보", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const Divider(color: Colors.white24, height: 24),
          _infoRow("학번:", "20240315"),
          _infoRow("이름:", "김민수"),
          _infoRow("학년:", "3학년"),
          _infoRow("학급:", "2반"),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white24,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {},
              child: const Text("프로필 편집"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String l, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            Text(v, style: const TextStyle(color: Colors.white, fontSize: 13)),
          ],
        ),
      );
}