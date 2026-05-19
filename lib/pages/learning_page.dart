// lib/pages/learning_page.dart
// Web + iOS/Android 모두 지원 + 교사 업로드 PDF 자동 로드

import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'package:percent_indicator/circular_percent_indicator.dart';
// ignore: undefined_prefixed_name
import 'dart:ui_web' as ui_web;

import 'report_page.dart';

// ── 설정 ──────────────────────────────────────
const String _kGeminiApiKey = 'AIzaSyD_qyYVJF411bsNXgGThAPHMN0xTtUv9MI';
const String _kFlaskBaseUrl = 'http://192.168.200.191:5001';

class StudentLearningPage extends StatefulWidget {
  final String courseName;
  final String studentId;
  final String? pdfUrl; // ← 교사가 올린 PDF URL

  const StudentLearningPage({
    super.key,
    required this.courseName,
    required this.studentId,
    this.pdfUrl,
  });

  @override
  State<StudentLearningPage> createState() => _StudentLearningPageState();
}

class _StudentLearningPageState extends State<StudentLearningPage> {

  // PDF
  String? _pdfUrl;
  String? _pdfName;

  // 웹 카메라
  html.VideoElement? _videoElement;
  html.MediaStream? _mediaStream;
  bool _cameraReady = false;
  bool _useRealInference = false;
  bool _isProcessingFrame = false;
  int _lastInferenceTime = 0;
  Timer? _inferenceTimer;

  // 전문도
  double _focusScore = 0.85;
  bool _showAiBubble = false;
  int _focusedSec = 0;
  int _confusedSec = 0;

  // Gemini
  late final GenerativeModel _geminiModel;
  late final ChatSession _chatSession;
  final List<_Msg> _msgs = [];
  bool _geminiLoading = false;

  @override
  void initState() {
    super.initState();
    _geminiModel = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: _kGeminiApiKey,
      systemInstruction: Content.system(
        '당신은 학생의 학습을 돕는 친절한 AI 도우미입니다. '
        '간결하고 쉽게 200자 이내로 한국어로 답변해주세요.',
      ),
    );
    _chatSession = _geminiModel.startChat();

    // 교사가 올린 PDF URL 자동 설정
    if (widget.pdfUrl != null && widget.pdfUrl!.isNotEmpty) {
      _pdfUrl = widget.pdfUrl;
      _pdfName = widget.courseName;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initWebCamera();
    });
  }

  @override
  void dispose() {
    _inferenceTimer?.cancel();
    _stopCamera();
    super.dispose();
  }

  void _stopCamera() {
    _mediaStream?.getTracks().forEach((track) => track.stop());
    _videoElement?.remove();
    _mediaStream = null;
    _videoElement = null;
  }

  // ── 웹 카메라 초기화 ──────────────────────
  Future<void> _initWebCamera() async {
    try {
      final stream = await html.window.navigator.mediaDevices!.getUserMedia({
        'video': {'facingMode': 'user', 'width': 320, 'height': 240},
        'audio': false,
      });

      _mediaStream = stream;
      _videoElement = html.VideoElement()
        ..srcObject = stream
        ..autoplay = true
        ..muted = true
        ..style.display = 'none';

      html.document.body!.append(_videoElement!);
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        setState(() => _cameraReady = true);
        debugPrint('[Camera] 웹 카메라 초기화 성공');
      }

      await _checkFlask();

      _inferenceTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _runWebInference(),
      );
    } catch (e) {
      debugPrint('[Camera] 웹 카메라 초기화 실패: $e');
    }
  }

  Future<void> _checkFlask() async {
    try {
      final res = await http
          .get(Uri.parse('$_kFlaskBaseUrl/'))
          .timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        if (mounted) setState(() => _useRealInference = true);
        debugPrint('[Flask] 연결 성공');
      }
    } catch (_) {
      debugPrint('[Flask] 서버 없음');
    }
  }

  // ── 웹 카메라 프레임 캡처 및 추론 ──────────
  Future<void> _runWebInference() async {
    if (!_cameraReady || !_useRealInference) return;
    if (_isProcessingFrame) return;
    if (_videoElement == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastInferenceTime < 5000) return;

    _isProcessingFrame = true;
    _lastInferenceTime = now;

    try {
      final canvas = html.CanvasElement(
        width: _videoElement!.videoWidth,
        height: _videoElement!.videoHeight,
      );
      final ctx = canvas.context2D;
      ctx.drawImage(_videoElement!, 0, 0);

      final dataUrl = canvas.toDataUrl('image/jpeg', 0.8);
      final base64 = dataUrl.split(',').last;

      final res = await http.post(
        Uri.parse('$_kFlaskBaseUrl/infer'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'image': base64, 'page': 1}),
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _applyScore((data['focus_score'] as num).toDouble());
      }
    } catch (e) {
      debugPrint('[Inference] 오류: $e');
    } finally {
      _isProcessingFrame = false;
    }
  }

  void _applyScore(double score) {
    if (!mounted) return;
    setState(() {
      _focusScore = score.clamp(0.0, 1.0);
      if (_focusScore >= 0.6) {
        _focusedSec += 5;
      } else {
        _confusedSec += 5;
        if (!_showAiBubble) _showAiBubble = true;
      }
    });
  }

  // ── Gemini ────────────────────────────────
  Future<void> _sendToGemini(String q) async {
    if (q.trim().isEmpty) return;
    setState(() {
      _msgs.add(_Msg(text: q, isUser: true));
      _geminiLoading = true;
    });
    try {
      final pdfName = _pdfName ?? widget.courseName;
      final res = await _chatSession.sendMessage(
        Content.text('[현재 강의: $pdfName]\n$q'),
      );
      setState(() {
        _msgs.add(_Msg(text: res.text ?? '응답 없음', isUser: false));
      });
    } catch (e) {
      setState(() {
        _msgs.add(_Msg(text: '오류: $e', isUser: false, isError: true));
      });
    } finally {
      if (mounted) setState(() => _geminiLoading = false);
    }
  }

  void _openGemini() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GeminiSheet(
        pdfName: _pdfName,
        msgs: _msgs,
        loading: _geminiLoading,
        onSend: _sendToGemini,
      ),
    );
  }

  void _endLearning() {
    _inferenceTimer?.cancel();
    _stopCamera();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => LearningReportPage(
          studentId: widget.studentId,
          courseName: widget.courseName,
        ),
      ),
    );
  }

  // ── BUILD ─────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final Color fc = _focusScore < 0.4
        ? Colors.red
        : (_focusScore < 0.6 ? Colors.orange : Colors.green);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.courseName,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF172B4D))),
            if (_pdfName != null)
              Text(_pdfName!,
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        actions: [
          // 카메라 상태
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: (_cameraReady
                      ? (_useRealInference ? Colors.green : Colors.orange)
                      : Colors.grey)
                  .withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _cameraReady ? Icons.visibility : Icons.visibility_off,
                  color: _cameraReady
                      ? (_useRealInference ? Colors.green : Colors.orange)
                      : Colors.grey,
                  size: 13,
                ),
                const SizedBox(width: 4),
                Text(
                  !_cameraReady
                      ? '준비 중'
                      : (_useRealInference ? 'AI 추론' : '서버 없음'),
                  style: TextStyle(
                    color: _cameraReady
                        ? (_useRealInference ? Colors.green : Colors.orange)
                        : Colors.grey,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // 종료 버튼
          TextButton(
            onPressed: _endLearning,
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('종료', style: TextStyle(fontSize: 13)),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          // PDF 뷰어 또는 플레이스홀더
          _pdfUrl == null ? _placeholder() : _webPdfViewer(),

          // 전문도 링
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: CircularPercentIndicator(
                radius: 32.0,
                lineWidth: 5.0,
                percent: _focusScore,
                center: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${(_focusScore * 100).toInt()}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: fc,
                      ),
                    ),
                    Text(
                      'FOCUS',
                      style: TextStyle(
                        fontSize: 6,
                        color: fc,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                progressColor: fc,
                backgroundColor: Colors.black12,
                circularStrokeCap: CircularStrokeCap.round,
                animation: true,
                animateFromLastPercent: true,
              ),
            ),
          ),

          // AI 기포
          if (_showAiBubble)
            Positioned(
              top: 100,
              left: 12,
              right: 12,
              child: _aiBubble(),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openGemini,
        backgroundColor: const Color(0xFF3B71CA),
        icon: const Icon(Icons.auto_awesome, color: Colors.white),
        label: const Text('AI 질문', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  // ── Web PDF 뷰어 (iframe) ─────────────────
  Widget _webPdfViewer() {
    final viewId = 'pdf-${widget.courseName.hashCode}';

    ui_web.platformViewRegistry.registerViewFactory(
      viewId,
      (int id) {
        final iframe = html.IFrameElement()
          ..src = _pdfUrl
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.border = 'none';
        return iframe;
      },
    );

    return HtmlElementView(viewType: viewId);
  }

  Widget _placeholder() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.picture_as_pdf_outlined,
              size: 80, color: Colors.black26),
          SizedBox(height: 20),
          Text('PDF 강의 자료를 불러오는 중...',
              style: TextStyle(fontSize: 17, color: Colors.black45)),
          SizedBox(height: 8),
          Text('교사가 PDF를 업로드하면 여기에 표시됩니다',
              style: TextStyle(fontSize: 13, color: Colors.black26)),
        ],
      ),
    );
  }

  Widget _aiBubble() {
    return Material(
      elevation: 8,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(4),
        topRight: Radius.circular(16),
        bottomLeft: Radius.circular(16),
        bottomRight: Radius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(color: Colors.orange.withOpacity(0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome,
                  color: Colors.orange, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('AI 학습 매니저',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFF172B4D))),
                  const SizedBox(height: 4),
                  Text(
                    '집중도가 ${(_focusScore * 100).toInt()}%로 떨어졌어요! 😮\n'
                    '이해가 안 되는 부분이 있나요?',
                    style: const TextStyle(
                        fontSize: 12, height: 1.5, color: Colors.black54),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              setState(() => _showAiBubble = false),
                          style: OutlinedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('괜찮아요',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() => _showAiBubble = false);
                            _sendToGemini('지금 보고 있는 내용을 쉽게 설명해줘');
                            _openGemini();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3B71CA),
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                          child: const Text('AI 도움받기',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 16, color: Colors.grey),
              onPressed: () => setState(() => _showAiBubble = false),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// Gemini 시트
// ═══════════════════════════════════════════════
class _GeminiSheet extends StatefulWidget {
  final String? pdfName;
  final List<_Msg> msgs;
  final bool loading;
  final Function(String) onSend;

  const _GeminiSheet({
    required this.pdfName,
    required this.msgs,
    required this.loading,
    required this.onSend,
  });

  @override
  State<_GeminiSheet> createState() => _GeminiSheetState();
}

class _GeminiSheetState extends State<_GeminiSheet> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
            decoration: const BoxDecoration(
              color: Color(0xFF3B71CA),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome,
                    color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Gemini AI 학습 도우미',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      Text(
                        widget.pdfName != null
                            ? '${widget.pdfName}에 대해 질문하세요'
                            : '강의 내용에 대해 질문하세요',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          if (widget.msgs.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip('이 내용 요약해줘'),
                  _chip('핵심 개념 설명해줘'),
                  _chip('쉬운 예시로 설명해줘'),
                  _chip('어려운 용어 알려줘'),
                ],
              ),
            ),

          Expanded(
            child: widget.msgs.isEmpty
                ? Center(
                    child: Text(
                      '궁금한 내용을 질문하세요!',
                      style: TextStyle(
                          fontSize: 14, color: Colors.grey.shade400),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    itemCount:
                        widget.msgs.length + (widget.loading ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == widget.msgs.length) {
                        return const _TypingDots();
                      }
                      return _Bubble(msg: widget.msgs[i]);
                    },
                  ),
          ),

          Container(
            padding: EdgeInsets.fromLTRB(
                16, 12, 16,
                MediaQuery.of(context).viewInsets.bottom + 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border:
                  Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    enabled: !widget.loading,
                    decoration: InputDecoration(
                      hintText: '질문을 입력하세요...',
                      hintStyle: TextStyle(
                          fontSize: 14, color: Colors.grey.shade400),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF4F7FE),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 14),
                    maxLines: 4,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (v) {
                      if (v.trim().isNotEmpty) {
                        widget.onSend(v.trim());
                        _ctrl.clear();
                        _scrollBottom();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                widget.loading
                    ? const SizedBox(
                        width: 44,
                        height: 44,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : GestureDetector(
                        onTap: () {
                          if (_ctrl.text.trim().isNotEmpty) {
                            widget.onSend(_ctrl.text.trim());
                            _ctrl.clear();
                            _scrollBottom();
                          }
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: Color(0xFF3B71CA),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.send_rounded,
                              color: Colors.white, size: 20),
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label) {
    return GestureDetector(
      onTap: () {
        widget.onSend(label);
        _scrollBottom();
      },
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF3B71CA).withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: const Color(0xFF3B71CA).withOpacity(0.2)),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 12, color: Color(0xFF3B71CA))),
      ),
    );
  }
}

class _Msg {
  final String text;
  final bool isUser;
  final bool isError;
  _Msg({required this.text, required this.isUser, this.isError = false});
}

class _Bubble extends StatelessWidget {
  final _Msg msg;
  const _Bubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment:
            msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!msg.isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                  color: Color(0xFF3B71CA), shape: BoxShape.circle),
              child: const Icon(Icons.auto_awesome,
                  color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: msg.isUser
                    ? const Color(0xFF3B71CA)
                    : msg.isError
                        ? Colors.red.shade50
                        : const Color(0xFFF4F7FE),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(msg.isUser ? 16 : 2),
                  bottomRight: Radius.circular(msg.isUser ? 2 : 16),
                ),
              ),
              child: Text(msg.text,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: msg.isUser
                        ? Colors.white
                        : msg.isError
                            ? Colors.red
                            : const Color(0xFF172B4D),
                  )),
            ),
          ),
          if (msg.isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.3, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
                color: Color(0xFF3B71CA), shape: BoxShape.circle),
            child: const Icon(Icons.auto_awesome,
                color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F7FE),
              borderRadius: BorderRadius.circular(16),
            ),
            child: AnimatedBuilder(
              animation: _anim,
              builder: (_, __) => Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  3,
                  (i) => Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 3),
                    child: Opacity(
                      opacity: i == 1
                          ? _anim.value
                          : (i == 0 ? 0.3 : 0.6),
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                            color: Color(0xFF3B71CA),
                            shape: BoxShape.circle),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}