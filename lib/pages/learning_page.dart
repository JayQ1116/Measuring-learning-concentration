import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../app_theme.dart';

class StudentLearningPage extends StatefulWidget {
  final String courseName;

  const StudentLearningPage({super.key, required this.courseName});

  @override
  State<StudentLearningPage> createState() => _StudentLearningPageState();
}

class _StudentLearningPageState extends State<StudentLearningPage> {
  double _focusScore = 0.95;
  bool _showAiBubble = false;
  bool _isAutoSimulating = false;

  void _startLowFocusSimulation() async {
    setState(() { _isAutoSimulating = true; });
    for (double i = 0.95; i >= 0.45; i -= 0.05) {
      if (!_isAutoSimulating) break;
      await Future.delayed(const Duration(milliseconds: 300));
      setState(() {
        _focusScore = i;
        if (_focusScore < 0.6) {
          _showAiBubble = true;
        }
      });
    }
  }

  void _resetFocus() {
    setState(() {
      _focusScore = 0.95;
      _showAiBubble = false;
      _isAutoSimulating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    Color focusColor = _focusScore < 0.4
        ? Colors.red
        : (_focusScore < 0.6 ? Colors.orange : Colors.green);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(
        title: Text("${widget.courseName} - 실시간 학습"),
        actions: [
          _buildStatusTag(),
          const SizedBox(width: 20),
        ],
      ),
      body: Stack(
        children: [
          // 课件内容区
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
                child: _buildLessonContent(),
              ),
            ),
          ),

          // 右上角专注度环
          Positioned(
            right: 16,
            top: 16,
            child: CircularPercentIndicator(
              radius: 45.0,
              lineWidth: 9.0,
              percent: _focusScore,
              animation: true,
              animateFromLastPercent: true,
              circularStrokeCap: CircularStrokeCap.round,
              progressColor: focusColor,
              backgroundColor: Colors.black12,
              center: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "${(_focusScore * 100).toInt()}",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: focusColor),
                  ),
                  const Text("FOCUS", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),

          // AI 气泡
          if (_showAiBubble)
            Positioned(
              left: 16,
              right: 16,
              top: 80,
              child: _buildAiAssistantBubble(),
            ),

          // 底部演示控制栏
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("演示：", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _startLowFocusSimulation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      minimumSize: const Size(90, 35),
                    ),
                    child: const Text("模拟走神", style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _resetFocus,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      minimumSize: const Size(90, 35),
                    ),
                    child: const Text("恢复状态", style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  } // ← build 方法在这里结束

  // ↓ 以下所有方法都在 build 外面，_StudentLearningPageState 里面

  Widget _buildAiAssistantBubble() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 20, spreadRadius: 5)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              const Text("AI 학습 매니저",
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() => _showAiBubble = false),
              ),
            ],
          ),
          const Divider(),
          const Text(
            "김민수님, 집중력이 60% 이하로 떨어졌어요! 😮\n이 부분이 조금 어려우신가요? AI가 보충 설명을 해드릴 수 있습니다.",
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _resetFocus,
                  child: const Text("아뇨, 괜찮아요", style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {},
                  child: const Text("도움받기", style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTag() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam, color: Colors.green, size: 14),
            SizedBox(width: 5),
            Text("AI 모니터링 활성",
                style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      );

  Widget _buildLessonContent() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Chapter 3. Deep Learning Overview",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF102C57)),
        ),
        SizedBox(height: 20),
        Text(
          "인공신경망(ANN)은 생물학적 뇌의 뉴런 구조를 모방하여 만든 알고리즘입니다. "
          "최근에는 수많은 은닉층(Hidden Layers)을 가진 딥러닝이 주류를 이루고 있습니다.",
          style: TextStyle(fontSize: 15, height: 1.8),
        ),
        SizedBox(height: 24),
        Text(
          "주요 개념",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF102C57)),
        ),
        SizedBox(height: 12),
        Text("• 순전파(Forward Propagation): 입력층에서 출력층으로 데이터를 전달하는 과정",
            style: TextStyle(fontSize: 14, height: 1.8)),
        Text("• 역전파(Backpropagation): 오차를 줄이기 위해 가중치를 업데이트하는 과정",
            style: TextStyle(fontSize: 14, height: 1.8)),
        Text("• 활성화 함수(Activation Function): 뉴런의 출력값을 결정하는 함수",
            style: TextStyle(fontSize: 14, height: 1.8)),
        Text("• 경사하강법(Gradient Descent): 손실 함수를 최소화하는 최적화 알고리즘",
            style: TextStyle(fontSize: 14, height: 1.8)),
        SizedBox(height: 24),
        Text(
          "학습 목표",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF102C57)),
        ),
        SizedBox(height: 12),
        Text("이 단원을 마치면 딥러닝의 기본 구조와 학습 원리를 이해하고, "
            "간단한 신경망 모델을 설계할 수 있게 됩니다.",
            style: TextStyle(fontSize: 14, height: 1.8)),
      ],
    );
  }
}