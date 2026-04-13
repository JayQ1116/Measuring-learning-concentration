import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'report_page.dart';

class StudentLearningPage extends StatefulWidget {
  final String courseName;
  final String studentId;
  const StudentLearningPage({super.key, required this.courseName, required this.studentId});

  @override
  State<StudentLearningPage> createState() => _StudentLearningPageState();
}

class _StudentLearningPageState extends State<StudentLearningPage> {
  double _focusScore = 0.85;
  bool _showAiBubble = false;

  void _simulateFocusDrop() {
    setState(() {
      _focusScore = 0.35;
      _showAiBubble = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    Color focusColor = _focusScore < 0.4
        ? Colors.red
        : (_focusScore < 0.7 ? Colors.orange : Colors.green);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(
        title: Text(widget.courseName),
        actions: [
          // ✅ 修复1: ElevatedButton 在 AppBar actions 里不能用 double.infinity
          // 用固定 minimumSize 或直接不设
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              minimumSize: const Size(90, 36), // ← 固定宽度，不用 double.infinity
            ),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (c) => LearningReportPage(
                    studentId: widget.studentId,
                    courseName: widget.courseName,
                  ),
                ),
              );
            },
            child: const Text("학습 종료"),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Stack(
        children: [
          // 课件内容区 — 修复2: 去掉 width: 900，改为全屏自适应
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(
                top: 20, left: 16, right: 16, bottom: 120,
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20)],
                ),
                child: _buildPdfMockContent(),
              ),
            ),
          ),

          // 右上角专注度环
          Positioned(
            right: 16,
            top: 16,
            child: CircularPercentIndicator(
              radius: 42.0,
              lineWidth: 8.0,
              percent: _focusScore,
              center: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "${(_focusScore * 100).toInt()}",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: focusColor),
                  ),
                  const Text("Focus", style: TextStyle(fontSize: 8)),
                ],
              ),
              progressColor: focusColor,
              backgroundColor: Colors.black12,
              circularStrokeCap: CircularStrokeCap.round,
              animation: true,
              animateFromLastPercent: true,
            ),
          ),

          // AI 提醒气泡 — 改为全宽居中显示
          if (_showAiBubble)
            Positioned(
              left: 16,
              right: 16,
              top: 70,
              child: _buildAiBubble(),
            ),

          // 底部演示控制栏 — 全宽显示
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _simulateFocusDrop,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      minimumSize: const Size(120, 36),
                    ),
                    child: const Text("AI 도우미 찾기", style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () => setState(() {
                      _focusScore = 0.9;
                      _showAiBubble = false;
                    }),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(80, 36),
                    ),
                    child: const Text("닫기", style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiBubble() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.orange),
              const SizedBox(width: 10),
              const Text("AI Assistant", style: TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                onPressed: () => setState(() => _showAiBubble = false),
              ),
            ],
          ),
          const Divider(),
          const Text(
            "집중도가 낮아진 것 같아요!\n이해가 안 가는 부분이 있나요? 도움이 필요하시면 말씀해주세요.",
            style: TextStyle(fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              child: const Text("네, 설명이 필요해요"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfMockContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Chapter 3. Deep Learning Overview",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF102C57)),
        ),
        const SizedBox(height: 20),
        const Text(
          "인공신경망(ANN)은 생물학적 뇌의 뉴런 구조를 모방하여 만든 알고리즘입니다. "
          "최근에는 수많은 은닉층(Hidden Layers)을 가진 딥러닝이 주류를 이루고 있습니다.",
          style: TextStyle(fontSize: 15, height: 1.8),
        ),
        const SizedBox(height: 30),
        const Text(
          "주요 개념",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF102C57)),
        ),
        const SizedBox(height: 12),
        const Text("• 순전파(Forward Propagation): 입력층에서 출력층으로 데이터를 전달하는 과정",
            style: TextStyle(fontSize: 14, height: 1.8)),
        const Text("• 역전파(Backpropagation): 오차를 줄이기 위해 가중치를 업데이트하는 과정",
            style: TextStyle(fontSize: 14, height: 1.8)),
        const Text("• 활성화 함수(Activation Function): 뉴런의 출력값을 결정하는 함수",
            style: TextStyle(fontSize: 14, height: 1.8)),
        const Text("• 경사하강법(Gradient Descent): 손실 함수를 최소화하는 최적화 알고리즘",
            style: TextStyle(fontSize: 14, height: 1.8)),
        const SizedBox(height: 30),
        Center(
          child: Container(
            height: 160,
            width: double.infinity, // ← 去掉固定 width: 400
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.image, size: 50, color: Colors.grey),
          ),
        ),
      ],
    );
  }
}