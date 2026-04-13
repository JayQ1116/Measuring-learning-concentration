import 'package:flutter/material.dart';
import '../app_theme.dart';
import 'environment_page.dart';

class CourseListPage extends StatelessWidget {
  final String studentId;
  const CourseListPage({super.key, required this.studentId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackgroundColor,
      appBar: AppBar(title: const Text("내 강의"), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "전체 강의 목록",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
            ),
            const SizedBox(height: 4),
            const Text("학습하고 싶은 강의를 선택해주세요", style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 24),
            const Text("📖 진행 중인 강의", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            // 改为竖向列表，不用 GridView
            _buildCourseCard(context, "머신러닝 기초", "머신러닝의 기본 개념과 알고리즘을 학습합니다", 0.65, "초급"),
            const SizedBox(height: 16),
            _buildCourseCard(context, "딥러닝 심화", "신경망과 딥러닝 모델을 깊이 있게 다룹니다", 0.32, "중급"),
            const SizedBox(height: 16),
            _buildCourseCard(context, "자연어 처리", "NLP 기초부터 트랜스포머 모델까지", 0.89, "중급"),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseCard(BuildContext context, String title, String desc, double progress, String level) {
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
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(level, style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            desc,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: progress, minHeight: 7),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${(progress * 100).toInt()}% 완료",
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const Text("16/24 완료", style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (c) => StudentLearningPage(courseName: title, studentId: studentId),
                ),
              ),
              child: const Text("학습 계속하기"),
            ),
          ),
        ],
      ),
    );
  }
}