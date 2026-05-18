// lib/pages/learning_page.dart
import 'dart:async';
import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image/image.dart' as img;

import '../service/firebase_service.dart';
import 'report_page.dart';

// ── 설정 ──────────────────────────────────────
const String _kGeminiApiKey = 'AIzaSyD_qyYVJF411bsNXgGThAPHMN0xTtUv9MI';
const String _kFlaskBaseUrl = 'http://192.168.200.191:5001';

class StudentLearningPage extends StatefulWidget {
  final String courseName;
  final String studentId;

  const StudentLearningPage({
    super.key,
    required this.courseName,
    required this.studentId,
  });

  @override
  State<StudentLearningPage> createState() => _StudentLearningPageState();
}

class _StudentLearningPageState extends State<StudentLearningPage>
    with WidgetsBindingObserver {

  // PDF
  String? _pdfPath;
  int _currentPage = 0;
  int _totalPages = 0;
  PDFViewController? _pdfController;
  bool _pdfLoading = false;

  // 카메라
  CameraController? _cameraCtrl;
  bool _cameraReady = false;
  bool _useRealInference = false;
  bool _cameraPermissionDenied = false;
  bool _cameraPermissionPermanentlyDenied = false;
  bool _cameraPermissionDialogVisible = false;
  bool _isProcessingFrame = false;
  int _lastInferenceTime = 0;

  // 전문도
  double _focusScore = 0.85;
  bool _showAiBubble = false;
  int _focusedSec = 0;
  int _confusedSec = 0;

  // Firebase
  String? _sessionId;

  // Gemini
  late final GenerativeModel _geminiModel;
  late final ChatSession _chatSession;
  final List<_Msg> _msgs = [];
  bool _geminiLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _geminiModel = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: _kGeminiApiKey,
      systemInstruction: Content.system(
        '당신은 학생의 학습을 돕는 친절한 AI 도우미입니다. '
        '간결하고 쉽게 200자 이내로 한국어로 답변해주세요.',
      ),
    );
    _chatSession = _geminiModel.startChat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initCamera();
      _startSession();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final ctrl = _cameraCtrl;
    _cameraCtrl = null;
    _cameraReady = false;
    try {
      ctrl?.stopImageStream();
    } catch (_) {}
    ctrl?.dispose();
    _endSession();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_cameraReady) {
      Future.delayed(const Duration(milliseconds: 250), _initCamera);
    }
  }

  // ── Firebase ──────────────────────────────
  Future<void> _startSession() async {
    try {
      _sessionId = await FirebaseService.startSession(
        studentUid: widget.studentId,
        pdfName: widget.courseName,
      );
    } catch (e) {
      debugPrint('[Firebase] 세션 시작 실패: $e');
    }
  }

  Future<void> _endSession() async {
    if (_sessionId == null) return;
    try {
      await FirebaseService.endSession(
        _sessionId!,
        focusedSec: _focusedSec,
        confusedSec: _confusedSec,
      );
    } catch (e) {
      debugPrint('[Firebase] 세션 종료 실패: $e');
    }
  }

  // ── 카메라 ────────────────────────────────
  Future<void> _initCamera() async {
    if (!mounted) return;

    final status = await Permission.camera.status;
    debugPrint('[Camera] 권한 초기 상태: $status');
    if (!mounted) return;

    if (!status.isGranted) {
      final result = await Permission.camera.request();
      debugPrint('[Camera] 권한 요청 결과: $result');
      if (!mounted) return;
      if (!result.isGranted) {
        setState(() {
          _cameraPermissionDenied = true;
          _cameraPermissionPermanentlyDenied =
              result.isPermanentlyDenied || result.isRestricted;
          _cameraReady = false;
        });
        _showCameraPermissionDialog(_cameraPermissionPermanentlyDenied);
        return;
      }
    }

    setState(() {
      _cameraPermissionDenied = false;
      _cameraPermissionPermanentlyDenied = false;
    });
    await _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      if (_cameraCtrl != null) {
        try { await _cameraCtrl!.stopImageStream(); } catch (_) {}
        await _cameraCtrl!.dispose();
        _cameraCtrl = null;
        _cameraReady = false;
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        debugPrint('[Camera] 카메라 없음');
        return;
      }

      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final ctrl = CameraController(
        front,
        ResolutionPreset.low,
        enableAudio: false,
      );
      await ctrl.initialize();

      if (!mounted) {
        await ctrl.dispose();
        return;
      }

      _cameraCtrl = ctrl;
      setState(() => _cameraReady = true);
      debugPrint('[Camera] 초기화 성공');

      await _checkFlask();

      // 이미지 스트림으로 실시간 추론 (takePicture 대신)
      ctrl.startImageStream((CameraImage image) async {
        if (!_useRealInference) return;
        if (_isProcessingFrame) return;

        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - _lastInferenceTime < 5000) return; // 5초 간격

        _isProcessingFrame = true;
        _lastInferenceTime = now;
        await _runInferenceFromFrame(image);
        _isProcessingFrame = false;
      });
    } catch (e) {
      debugPrint('[Camera] 초기화 실패: $e');
    }
  }

  void _showCameraPermissionDialog(bool permanentlyDenied) {
    if (!mounted || _cameraPermissionDialogVisible) return;
    _cameraPermissionDialogVisible = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('카메라 권한 필요'),
        content: Text(permanentlyDenied
            ? '카메라 권한이 영구적으로 거부되었습니다. 설정에서 허용해주세요.'
            : '카메라 권한이 필요합니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          if (!permanentlyDenied)
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _initCamera();
              },
              child: const Text('다시 요청'),
            ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await openAppSettings();
            },
            child: const Text('설정 열기'),
          ),
        ],
      ),
    ).then((_) => _cameraPermissionDialogVisible = false);
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

  // ── 이미지 스트림으로 추론 (스크린샷 없음) ──
  Future<void> _runInferenceFromFrame(CameraImage image) async {
  try {
    // YUV420 → JPEG 변환
    final img.Image? convertedImage = _convertCameraImage(image);
    if (convertedImage == null) return;

    final jpegBytes = img.encodeJpg(convertedImage, quality: 80);
    final b64 = base64Encode(jpegBytes);

    final res = await http.post(
      Uri.parse('$_kFlaskBaseUrl/infer'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'image': b64, 'page': _currentPage + 1}),
    ).timeout(const Duration(seconds: 8));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      _applyScore((data['focus_score'] as num).toDouble());
    }
  } catch (e) {
    debugPrint('[Inference] 오류: $e');
  }
}

img.Image? _convertCameraImage(CameraImage image) {
  try {
    final int width = image.width;
    final int height = image.height;

    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final yBytes = yPlane.bytes;
    final uBytes = uPlane.bytes;
    final vBytes = vPlane.bytes;

    final imgResult = img.Image(width: width, height: height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int yIndex = y * yPlane.bytesPerRow + x;
        final int uvIndex =
            (y ~/ 2) * uPlane.bytesPerRow + (x ~/ 2) * uPlane.bytesPerPixel!;

        final int yVal = yBytes[yIndex];
        final int uVal = uBytes[uvIndex];
        final int vVal = vBytes[uvIndex];

        final int r = (yVal + 1.402 * (vVal - 128)).clamp(0, 255).toInt();
        final int g = (yVal - 0.344136 * (uVal - 128) - 0.714136 * (vVal - 128))
            .clamp(0, 255).toInt();
        final int b = (yVal + 1.772 * (uVal - 128)).clamp(0, 255).toInt();

        imgResult.setPixelRgb(x, y, r, g, b);
      }
    }
    return imgResult;
  } catch (e) {
    debugPrint('[Convert] 오류: $e');
    return null;
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
    _uploadLog(score);
  }

  Future<void> _uploadLog(double score) async {
    if (_sessionId == null) return;
    try {
      await FirebaseService.uploadConcentrationLog(
        studentUid: widget.studentId,
        sessionId: _sessionId!,
        state: score >= 0.6 ? 'focused' : 'confused',
        confidence: score,
      );
    } catch (e) {
      debugPrint('[Firebase] 로그 실패: $e');
    }
  }

  // ── PDF ───────────────────────────────────
  Future<void> _pickPdf() async {
    setState(() => _pdfLoading = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result != null && result.files.single.path != null && mounted) {
        setState(() {
          _pdfPath = result.files.single.path!;
          _currentPage = 0;
          _msgs.clear();
        });
      }
    } catch (e) {
      debugPrint('[PDF] 선택 오류: $e');
    } finally {
      if (mounted) setState(() => _pdfLoading = false);
    }
  }

  // ── Gemini ────────────────────────────────
  Future<void> _sendToGemini(String q) async {
    if (q.trim().isEmpty) return;
    setState(() {
      _msgs.add(_Msg(text: q, isUser: true));
      _geminiLoading = true;
    });
    try {
      final pdfName = _pdfPath?.split('/').last ?? widget.courseName;
      final res = await _chatSession.sendMessage(
        Content.text('[현재: $pdfName ${_currentPage + 1}페이지]\n$q'),
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
        pdfPath: _pdfPath,
        currentPage: _currentPage,
        msgs: _msgs,
        loading: _geminiLoading,
        onSend: _sendToGemini,
      ),
    );
  }

  void _endLearning() {
    _endSession();
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
            if (_pdfPath != null)
              Text('${_currentPage + 1} / $_totalPages 페이지',
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        actions: [
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
                  _cameraPermissionDenied
                      ? '권한 거부'
                      : (!_cameraReady
                          ? '준비 중'
                          : (_useRealInference ? 'AI 추론' : '서버 없음')),
                  style: TextStyle(
                    color: _cameraPermissionDenied
                        ? Colors.redAccent
                        : (_cameraReady
                            ? (_useRealInference ? Colors.green : Colors.orange)
                            : Colors.grey),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: _pdfLoading ? null : _pickPdf,
            icon: _pdfLoading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.file_open_outlined, size: 16),
            label: const Text('PDF', style: TextStyle(fontSize: 13)),
          ),
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
          _pdfPath == null ? _placeholder() : _pdfViewer(),

          // 전문도 링 - 오른쪽 상단 플로팅
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

          if (_cameraPermissionDenied)
            Positioned(
              top: 16,
              left: 14,
              right: 80,
              child: _cameraPermissionBanner(),
            ),

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

  Widget _cameraPermissionBanner() {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _cameraPermissionPermanentlyDenied
                    ? '카메라 권한 거부됨. 설정에서 허용하세요.'
                    : '카메라 권한이 필요합니다.',
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
            TextButton(
              onPressed: _cameraPermissionPermanentlyDenied
                  ? openAppSettings
                  : _initCamera,
              child: Text(
                _cameraPermissionPermanentlyDenied ? '설정' : '허용',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.picture_as_pdf_outlined,
              size: 80, color: Colors.black26),
          const SizedBox(height: 20),
          const Text('PDF 강의 자료를 불러오세요',
              style: TextStyle(fontSize: 17, color: Colors.black45)),
          const SizedBox(height: 8),
          const Text('상단 [PDF] 버튼을 눌러 파일을 선택하세요',
              style: TextStyle(fontSize: 13, color: Colors.black26)),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: _pdfLoading ? null : _pickPdf,
            icon: const Icon(Icons.upload_file),
            label: const Text('PDF 파일 선택'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B71CA),
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pdfViewer() {
    return Stack(
      children: [
        PDFView(
          filePath: _pdfPath!,
          enableSwipe: true,
          autoSpacing: true,
          pageFling: true,
          fitPolicy: FitPolicy.BOTH,
          onRender: (p) => setState(() => _totalPages = p ?? 0),
          onViewCreated: (c) => _pdfController = c,
          onPageChanged: (p, t) => setState(() {
            _currentPage = p ?? 0;
            _totalPages = t ?? 0;
          }),
          onError: (e) {
            if (mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text('PDF 오류: $e')));
            }
          },
        ),
        Positioned(
          bottom: 100,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left,
                        color: Colors.white, size: 22),
                    onPressed: _currentPage > 0
                        ? () => _pdfController?.setPage(_currentPage - 1)
                        : null,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 16),
                  Text('${_currentPage + 1} / $_totalPages',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13)),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.chevron_right,
                        color: Colors.white, size: 22),
                    onPressed: _currentPage < _totalPages - 1
                        ? () => _pdfController?.setPage(_currentPage + 1)
                        : null,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
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
  final String? pdfPath;
  final int currentPage;
  final List<_Msg> msgs;
  final bool loading;
  final Function(String) onSend;

  const _GeminiSheet({
    required this.pdfPath,
    required this.currentPage,
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
                        widget.pdfPath != null
                            ? '${widget.currentPage + 1}페이지에 대해 질문하세요'
                            : 'PDF를 먼저 불러오세요',
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

          if (widget.msgs.isEmpty && widget.pdfPath != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('빠른 질문',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _chip('이 페이지 요약해줘'),
                      _chip('핵심 개념 설명해줘'),
                      _chip('쉬운 예시로 설명해줘'),
                      _chip('어려운 용어 알려줘'),
                    ],
                  ),
                ],
              ),
            ),

          Expanded(
            child: widget.msgs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 56, color: Colors.grey.shade200),
                        const SizedBox(height: 12),
                        Text(
                          widget.pdfPath == null
                              ? 'PDF를 먼저 불러오세요'
                              : '궁금한 내용을 질문하세요!',
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey.shade400),
                        ),
                      ],
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
                    enabled: widget.pdfPath != null && !widget.loading,
                    decoration: InputDecoration(
                      hintText: widget.pdfPath == null
                          ? 'PDF를 먼저 불러오세요'
                          : '질문을 입력하세요...',
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
                        onTap: widget.pdfPath == null
                            ? null
                            : () {
                                if (_ctrl.text.trim().isNotEmpty) {
                                  widget.onSend(_ctrl.text.trim());
                                  _ctrl.clear();
                                  _scrollBottom();
                                }
                              },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: widget.pdfPath == null
                                ? Colors.grey.shade300
                                : const Color(0xFF3B71CA),
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