// lib/pages/learning_page.dart
// Web + iOS/Android 모두 지원 + 교사 업로드 PDF 자동 로드

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/platform_view_registry.dart';

import 'report_page.dart';
enum _AiAlertType { lowFocus, highConfusion }

// ── 설정 ──────────────────────────────────────
const String _kGeminiApiKey = 'AIzaSyCdlkOyWaq2B6wTNcDfgMzfPKwOib77VlY';
const String _kFlaskBaseUrl = 'http://127.0.0.1:5001';

class StudentLearningPage extends StatefulWidget {
  final String courseName;
  final String studentId;
  final String? pdfUrl; // ← 교사가 올린 PDF URL
  final String? pdfId;

  const StudentLearningPage({
    super.key,
    required this.courseName,
    required this.studentId,
    this.pdfUrl,
    this.pdfId,
  });

  @override
  State<StudentLearningPage> createState() => _StudentLearningPageState();
}

class _StudentLearningPageState extends State<StudentLearningPage> {
  final _supabase = Supabase.instance.client;

  // PDF
  String? _pdfUrl;
  String? _pdfName;
  Uint8List? _pdfBytes;
  final PdfViewerController _pdfController = PdfViewerController();
  int _currentPage = 1;
  int _totalPages = 1;
  Timer? _pageSaveTimer;
  int? _lastSavedPage;
  bool _pdfLoading = false;
  String? _pdfLoadError;
  String? _pdfIframeViewType;
  StreamSubscription<html.MessageEvent>? _pdfMessageSub;

  // 웹 카메라
  html.VideoElement? _videoElement;
  html.MediaStream? _mediaStream;
  bool _cameraReady = false;
  bool _useRealInference = false;
  bool _isProcessingFrame = false;
  int _lastInferenceTime = 0;
  Timer? _inferenceTimer;
  bool _flaskChecking = false;
  Map<String, dynamic>? _lastInferenceData;
  int? _lastInferenceMetricId;

  // 전문도
  double _focusScore = 0.85;
  bool _showAiBubble = false;
  _AiAlertType _aiAlertType = _AiAlertType.lowFocus;
  int _focusedSec = 0;
  int _confusedSec = 0;
  double _lastConfusion = 0.0;
  bool _showInlineAlert = false;
  String _inlineAlertMsg = '';
  Timer? _inlineAlertTimer;
  bool _askCurrentPageMode = false;
  Completer<Uint8List?>? _pdfCaptureCompleter;
  final TextEditingController _aiInputCtrl = TextEditingController();

  // Gemini
  late final GenerativeModel _geminiModel;
  late final ChatSession _chatSession;
  final List<_Msg> _msgs = [];
  bool _geminiLoading = false;

  @override
  void initState() {
    super.initState();
    _geminiModel = GenerativeModel(
      model: 'gemini-3.1-flash-lite',
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
      _pdfLoading = true;
      _pdfLoadError = null;
      _registerPdfIframe();
      _attachPdfMessageListener();
      _loadPdfBytes();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initWebCamera();
    });
  }

  void _registerPdfIframe() {
    if (!kIsWeb || _pdfUrl == null) return;
    final viewType = 'pdf-iframe-${DateTime.now().millisecondsSinceEpoch}';
    _pdfIframeViewType = viewType;
    final viewerUrl =
        'pdf_viewer.html?file=${Uri.encodeComponent(_pdfUrl!)}';
    registerPdfViewFactory(viewType, viewerUrl);
    // Enable iframe pointer events so PDF is interactive in split layout.
    _setPdfIframePointerEvents(true);
  }

  void _attachPdfMessageListener() {
    if (!kIsWeb) return;
    _pdfMessageSub?.cancel();
    _pdfMessageSub = html.window.onMessage.listen((event) {
      if (event.data is! String) return;
      try {
        final data = jsonDecode(event.data as String) as Map<String, dynamic>;
        final type = data['type'] as String?;
        if (type == 'pdf-page') {
          final page = (data['page'] as num?)?.toInt();
          final total = (data['total'] as num?)?.toInt();
          if (page == null || total == null || total <= 0) return;
          if (!mounted) return;
          setState(() {
            _pdfLoading = false;
            _pdfLoadError = null;
            _currentPage = page;
            _totalPages = total;
          });
          _pageSaveTimer?.cancel();
          _pageSaveTimer = Timer(
            const Duration(milliseconds: 400),
            () => _savePdfPage(_currentPage),
          );
          return;
        }
        if (type == 'pdf-capture') {
          final image = data['image'] as String?;
          if (image == null || image.isEmpty) return;
          final prefix = 'data:image/png;base64,';
          final base64Payload = image.startsWith(prefix) ? image.substring(prefix.length) : image;
          final bytes = base64Decode(base64Payload);
          _pdfCaptureCompleter?.complete(bytes);
          _pdfCaptureCompleter = null;
        }
      } catch (_) {
        // Ignore unrelated postMessage payloads.
      }
    });
  }

  Future<void> _loadPdfBytes() async {
    if (_pdfUrl == null) return;
    try {
      final res = await http.get(Uri.parse(_pdfUrl!));
      final contentType = res.headers['content-type'] ?? 'unknown';
      debugPrint(
          '[PDF] 다운로드 상태=${res.statusCode} bytes=${res.bodyBytes.length} content-type=$contentType');
      if (res.bodyBytes.length >= 8) {
        final head = String.fromCharCodes(res.bodyBytes.take(8));
        final tail = String.fromCharCodes(res.bodyBytes.skip(
            res.bodyBytes.length > 12 ? res.bodyBytes.length - 12 : 0));
        debugPrint('[PDF] header=$head');
        debugPrint('[PDF] tail=$tail');
      }
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        Uint8List bytes = res.bodyBytes;
        try {
          final doc = PdfDocument(inputBytes: bytes);
          final normalized = await doc.save();
          doc.dispose();
          bytes = Uint8List.fromList(normalized);
          debugPrint('[PDF] 정규화 완료 bytes=${bytes.length}');
        } catch (e) {
          debugPrint('[PDF] 정규화 실패: $e');
        }
        if (mounted) {
          setState(() {
            _pdfBytes = bytes;
          });
        } else {
          _pdfBytes = bytes;
        }
      } else {
        debugPrint('[PDF] 다운로드 실패: ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('[PDF] 다운로드 실패: $e');
    }
  }

  @override
  void dispose() {
    _inferenceTimer?.cancel();
    _pageSaveTimer?.cancel();
    _pdfMessageSub?.cancel();
    _stopCamera();
    _aiInputCtrl.dispose();
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
      await _videoElement!.play();

      // Wait for video dimensions to be ready.
      if (_videoElement!.videoWidth == 0 || _videoElement!.videoHeight == 0) {
        await _videoElement!.onLoadedMetadata.first
            .timeout(const Duration(seconds: 2));
      }

      if (mounted) {
        setState(() => _cameraReady = true);
        debugPrint('[Camera] 웹 카메라 초기화 성공');
        _startAiInference();
      }
    } catch (e) {
      debugPrint('[Camera] 웹 카메라 초기화 실패: $e');
    }
  }

  Future<bool> _checkFlaskAndStart() async {
    if (_flaskChecking) return false;
    _flaskChecking = true;
    try {
      final res = await http
          .get(Uri.parse('$_kFlaskBaseUrl/'))
          .timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        if (mounted) setState(() => _useRealInference = true);
        _inferenceTimer ??= Timer.periodic(
          const Duration(seconds: 5),
          (_) => _runWebInference(),
        );
        debugPrint('[Flask] 연결 성공');
        return true;
      }
      _showSnack('서버에 연결할 수 없습니다');
    } catch (_) {
      debugPrint('[Flask] 서버 없음');
      _showSnack('서버에 연결할 수 없습니다');
    } finally {
      _flaskChecking = false;
    }
    return false;
  }

  Future<void> _startAiInference() async {
    if (_useRealInference) return;
    final ok = await _checkFlaskAndStart();
    if (!ok && mounted) {
      _showSnack('서버에 연결할 수 없습니다');
    }
  }

  // ── 웹 카메라 프레임 캡처 및 추론 ──────────
  Future<void> _runWebInference() async {
    if (!_cameraReady || !_useRealInference) return;
    if (_isProcessingFrame) return;
    if (_videoElement == null) return;
    if (_videoElement!.videoWidth == 0 || _videoElement!.videoHeight == 0) {
      debugPrint('[Inference] 비디오 크기 0: 프레임 캡처 생략');
      return;
    }

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
        body: jsonEncode({
          'image': base64,
          'page': _currentPage,
          'client_write': true,
        }),
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        debugPrint('[Inference] 응답: $data');
        final state = (data['state'] as String?) ?? '';
        if (state == 'absent' || state == 'unknown') {
          debugPrint('[Inference] 얼굴 미검출: UI/저장 업데이트 생략');
          return;
        }
        final metrics = {
          'engagement': data['engagement'] ?? data['focus_score'],
          'boredom': data['boredom'] ?? 0.0,
          'confusion': data['confusion'] ?? 0.0,
          'frustration': data['frustration'] ?? 0.0,
          'samples': data['samples'] ?? 1,
          'pdf_name': data['pdf_name'],
        };

        final scoreValue = (metrics['engagement'] as num?) ?? 0.0;
        final confusionValue = (metrics['confusion'] as num?) ?? 0.0;
        _applyScore(
          scoreValue.toDouble(),
          confusion: confusionValue.toDouble(),
        );

        _lastInferenceData = metrics;
        await _saveInferenceMetrics(page: _currentPage, metrics: metrics);
      } else {
        debugPrint('[Inference] HTTP ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      debugPrint('[Inference] 오류: $e');
    } finally {
      _isProcessingFrame = false;
    }
  }

  void _applyScore(double score, {double confusion = 0.0}) {
    if (!mounted) return;
    setState(() {
      _focusScore = score.clamp(0.0, 1.0);
      _lastConfusion = confusion.clamp(0.0, 1.0);
      final confusionScore = confusion.clamp(0.0, 1.0);
      final lowFocus = _focusScore < 0.5;
      final highConfusion = confusionScore > 0.3;
      if (!lowFocus && !highConfusion) {
        _focusedSec += 5;
      } else {
        _confusedSec += 5;
        // show short inline alert in Korean for 3 seconds
        _aiAlertType = highConfusion ? _AiAlertType.highConfusion : _AiAlertType.lowFocus;
        if (_aiAlertType == _AiAlertType.lowFocus) {
          _inlineAlertMsg = '집중도가 감소했습니다. 집중해 주세요.';
        } else {
          _inlineAlertMsg = '혼란도가 감지되었습니다. 궁금한 점이 있으면 AI에게 물어보세요.';
        }
        _showInlineAlert = true;
        _inlineAlertTimer?.cancel();
        _inlineAlertTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) setState(() => _showInlineAlert = false);
        });
      }
    });
  }

  void _setPdfIframePointerEvents(bool enabled) {
    if (!kIsWeb) return;
    if (_pdfIframeViewType == null) return;
    setPdfViewPointerEvents(_pdfIframeViewType!, enabled);
  }

  Future<void> _saveInferenceMetrics({
    required int page,
    required Map<String, dynamic> metrics,
  }) async {
    debugPrint('[Inference] save start page=$page');
    if (_pdfUrl == null) return;
    final authUserId = _supabase.auth.currentUser?.id;
    if (authUserId == null || authUserId.isEmpty) {
      debugPrint('[Inference] save skipped: auth session missing');
      return;
    }
    if (authUserId != widget.studentId) {
      debugPrint('[Inference] save blocked: auth uid($authUserId) != widget.studentId(${widget.studentId})');
      return;
    }
    debugPrint('[Inference] save auth ok uid=$authUserId');
    final resolvedPdfName = (_pdfName ?? widget.courseName).trim().isNotEmpty
      ? (_pdfName ?? widget.courseName)
      : (metrics['pdf_name'] as String?);
    final resolvedPdfId = widget.pdfId?.trim().isNotEmpty == true
        ? widget.pdfId
        : null;
    if (widget.studentId.isEmpty) {
      debugPrint('[Inference] studentId 없음: 저장 생략');
      return;
    }

    try {
      final insert = await _supabase
          .from('engagement_metrics')
          .insert({
            'student_id': widget.studentId,
            'timestamp': DateTime.now().toUtc().toIso8601String(),
            'engagement': metrics['engagement'],
            'boredom': metrics['boredom'],
            'confusion': metrics['confusion'],
            'frustration': metrics['frustration'],
            'samples': metrics['samples'] ?? 1,
            'pdf_page': page,
            'pdf_name': resolvedPdfName,
            'pdf_id': resolvedPdfId,
            'pdf_total_pages': _totalPages,
          })
          .select('id')
          .maybeSingle();

      if (insert != null && insert['id'] != null) {
        _lastInferenceMetricId = insert['id'] as int;
      } else {
        debugPrint('[Inference] Supabase 저장 실패: 응답 없음');
      }
    } catch (e) {
      debugPrint('[Inference] Supabase 저장 실패: $e');
    }
  }


  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
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

  Future<void> _sendToGeminiWithImage(String q, Uint8List imageBytes) async {
    if (q.trim().isEmpty) return;
    setState(() {
      _msgs.add(_Msg(text: q, isUser: true));
      _geminiLoading = true;
    });
    try {
      final pdfName = _pdfName ?? widget.courseName;
      final content = Content.multi([
        TextPart('[현재 강의: $pdfName]\n$q'),
        DataPart('image/png', imageBytes),
      ]);
      final res = await _chatSession.sendMessage(content);
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

  Future<Uint8List?> _requestPdfCapture() async {
    if (!kIsWeb || _pdfIframeViewType == null) return null;
    if (_pdfCaptureCompleter != null) return null;
    _pdfCaptureCompleter = Completer<Uint8List?>();
    postPdfViewMessage(_pdfIframeViewType!, jsonEncode({'type': 'pdf-capture-request'}));
    return _pdfCaptureCompleter!.future.timeout(
      const Duration(seconds: 2),
      onTimeout: () {
        _pdfCaptureCompleter = null;
        return null;
      },
    );
  }

  void _sendAiQuestion(String q) async {
    if (q.trim().isEmpty) return;
    if (_askCurrentPageMode) {
      final pdfName = _pdfName ?? widget.courseName;
      final prompt = '현재 페이지의 내용을 종합하여 대답해 주십시오.\n현재 페이지: $_currentPage/$_totalPages\ncourse: $pdfName\n사용자 문제: $q';
      final capture = await _requestPdfCapture();
      if (capture != null) {
        await _sendToGeminiWithImage(prompt, capture);
      } else {
        await _sendToGemini(prompt);
      }
      return;
    }
    _sendToGemini(q);
  }

  Future<void> _openGemini() async {
    _setPdfIframePointerEvents(false);
    await showModalBottomSheet(
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
    _setPdfIframePointerEvents(true);
  }

  Future<void> _savePdfPage(int page) async {
    if (_pdfUrl == null) return;
    if (_lastSavedPage == page) return;

    _lastSavedPage = page;
    final pdfName = _pdfName ?? widget.courseName;

    try {
      // Prefer updating the most recent inference row written by this page.
      if (_lastInferenceMetricId != null) {
        await _supabase
            .from('engagement_metrics')
            .update({
              'pdf_page': page,
              'pdf_total_pages': _totalPages,
              'timestamp': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', _lastInferenceMetricId!);
        return;
      }

      // If we have inference data but no ID (insert failed), try inserting once.
      if (_lastInferenceData != null) {
        await _saveInferenceMetrics(page: page, metrics: _lastInferenceData!);
        return;
      }

      // No inference data available yet; skip to avoid NULL metrics rows.
      debugPrint('[PDF] 추론 데이터 없음: 페이지 저장 생략');
    } catch (e) {
      debugPrint('[PDF] 페이지 저장 실패: $e');
    }
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
          pdfId: widget.pdfId,
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
              Text(
                '${_pdfName!} • $_currentPage/$_totalPages',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
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
      body: Row(
        children: [
          // Left: PDF viewer (3/4)
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                // PDF 뷰어 또는 플레이스홀더
                _pdfUrl == null ? _placeholder() : _pdfViewer(),
                _pageControls(),

                // 전문도 링 (placed inside left column)
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

                // inline alert (inside left area)
                if (_showInlineAlert)
                  Positioned(
                    top: 16,
                    left: 20,
                    right: 20,
                    child: Material(
                      elevation: 6,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.deepOrange),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_inlineAlertMsg, style: const TextStyle(color: Colors.black87))),
                        ]),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Right: AI sidebar (1/4)
          Expanded(flex: 1, child: _aiSidebar()),
        ],
      ),
      floatingActionButton: null,
    );
  }

  // ── PDF 뷰어 (Syncfusion) ─────────────────
  Widget _pdfViewer() {
    if (kIsWeb && _pdfIframeViewType != null) {
      return HtmlElementView(viewType: _pdfIframeViewType!);
    }

    return Stack(
      children: [
        AbsorbPointer(
          absorbing: false,
          child: _pdfBytes != null
              ? SfPdfViewer.memory(
                  _pdfBytes!,
                  controller: _pdfController,
                  onDocumentLoaded: (details) {
                    setState(() {
                      _pdfLoadError = null;
                      _pdfLoading = false;
                      _totalPages = details.document.pages.count;
                      _currentPage = _pdfController.pageNumber;
                    });
                    _pageSaveTimer?.cancel();
                    _pageSaveTimer = Timer(
                      const Duration(milliseconds: 400),
                      () => _savePdfPage(_currentPage),
                    );
                  },
                  onDocumentLoadFailed: (details) {
                    setState(() {
                      _pdfLoadError = details.description;
                      _pdfLoading = false;
                    });
                    debugPrint('[PDF] 로드 실패: ${details.description}');
                  },
                  onPageChanged: (details) {
                    setState(() {
                      _currentPage = details.newPageNumber;
                    });
                    _pageSaveTimer?.cancel();
                    _pageSaveTimer = Timer(
                      const Duration(milliseconds: 400),
                      () => _savePdfPage(_currentPage),
                    );
                  },
                )
              : SfPdfViewer.network(
                  _pdfUrl!,
                  controller: _pdfController,
                  onDocumentLoaded: (details) {
                    setState(() {
                      _pdfLoadError = null;
                      _pdfLoading = false;
                      _totalPages = details.document.pages.count;
                      _currentPage = _pdfController.pageNumber;
                    });
                    _pageSaveTimer?.cancel();
                    _pageSaveTimer = Timer(
                      const Duration(milliseconds: 400),
                      () => _savePdfPage(_currentPage),
                    );
                  },
                  onDocumentLoadFailed: (details) {
                    setState(() {
                      _pdfLoadError = details.description;
                      _pdfLoading = false;
                    });
                    debugPrint('[PDF] 로드 실패: ${details.description}');
                  },
                  onPageChanged: (details) {
                    setState(() {
                      _currentPage = details.newPageNumber;
                    });
                    _pageSaveTimer?.cancel();
                    _pageSaveTimer = Timer(
                      const Duration(milliseconds: 400),
                      () => _savePdfPage(_currentPage),
                    );
                  },
                ),
        ),
        if (_pdfLoading)
          const Center(child: CircularProgressIndicator()),
        if (_pdfLoadError != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 40, color: Colors.redAccent),
                  const SizedBox(height: 12),
                  Text(
                    'PDF 로드 실패\n$_pdfLoadError',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _goToPage(int page) {
    if (page < 1 || page > _totalPages) return;

    // 翻页后强制恢复 iframe pointer
    _setPdfIframePointerEvents(true);

    _pdfController.jumpToPage(page);

    setState(() => _currentPage = page);
  }

  Widget _pageControls() {
    if (kIsWeb && _pdfIframeViewType != null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: _currentPage > 1 ? () => _goToPage(_currentPage - 1) : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Center(
                child: Text('$_currentPage / $_totalPages',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            IconButton(
              onPressed: _currentPage < _totalPages
                  ? () => _goToPage(_currentPage + 1)
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
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
                    _aiAlertType == _AiAlertType.highConfusion
                        ? '提醒类型: 疑惑度过高'
                        : '提醒类型: 专注度下降',
                    style: const TextStyle(
                        fontSize: 11, color: Colors.deepOrange),
                  ),
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
                          onPressed: () => setState(() {
                            _showAiBubble = false;
                            _setPdfIframePointerEvents(true);
                          }),
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
                            setState(() {
                              _showAiBubble = false;
                              _setPdfIframePointerEvents(true);
                            });
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
              onPressed: () => setState(() {
                _showAiBubble = false;
                _setPdfIframePointerEvents(true);
              }),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _aiBubbleV2() {
    final isConfusion = _aiAlertType == _AiAlertType.highConfusion;
    final title = isConfusion ? 'AI 학습 도우미 · 혼란도 알림' : 'AI 학습 도우미 · 집중도 알림';
    final subtitle = isConfusion ? '알림 유형: 혼란도 높음' : '알림 유형: 집중도 저하';
    final body = isConfusion
        ? '현재 내용에서 헷갈림이 감지되었어요.\n핵심 개념을 쉬운 말로 다시 설명해드릴까요?'
        : '집중도가 ${(_focusScore * 100).toInt()}%로 떨어졌어요.\n지금 페이지 핵심만 빠르게 정리해드릴까요?';
    final prompt = isConfusion
        ? '이 페이지가 헷갈려요. 핵심 개념을 쉬운 예시로 설명해줘.'
        : '집중이 흐트러졌어요. 지금 페이지 핵심 3줄 요약과 바로 할 다음 행동 1가지만 알려줘.';

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
              child: const Icon(Icons.auto_awesome, color: Colors.orange, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF172B4D),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: Colors.deepOrange),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: const TextStyle(fontSize: 12, height: 1.5, color: Colors.black54),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setState(() {
                            _showAiBubble = false;
                            _setPdfIframePointerEvents(true);
                          }),
                          child: const Text('지금은 괜찮아요', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _showAiBubble = false;
                            });

                            // 打开 Gemini 前禁用 iframe
                            _setPdfIframePointerEvents(false);

                            _sendToGemini(prompt);
                            _openGemini();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3B71CA),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('AI 도움 받기', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 16, color: Colors.grey),
              onPressed: () => setState(() {
                _showAiBubble = false;
                _setPdfIframePointerEvents(true);
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _aiSidebar() {
    return Material(
      elevation: 8,
      color: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('AI 패널', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _smallStat('평균 집중도', '${(_focusScore*100).round()}점', Colors.green),
                      _smallStat('혼란도', '${(_lastConfusion*100).round()}%', Colors.orange),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _smallStat('학습 시간', '${((_focusedSec+_confusedSec)/60).round()}분', Colors.blue),
                      _smallStat('현재 페이지', '$_currentPage/$_totalPages', Colors.purple),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('当前页提问模式', style: TextStyle(fontSize: 12, color: Color(0xFF172B4D))),
                  ),
                  Switch.adaptive(
                    value: _askCurrentPageMode,
                    onChanged: (v) => setState(() => _askCurrentPageMode = v),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: _msgs.isEmpty
                        ? Center(child: Text('AI에게 질문하세요', style: TextStyle(color: Colors.grey.shade500)))
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _msgs.length,
                            itemBuilder: (_, i) => _Bubble(msg: _msgs[i]),
                          ),
                  ),
                  Container(
                    padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).viewInsets.bottom + 8),
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade200))),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _aiInputCtrl,
                            onSubmitted: (v) {
                              if (v.trim().isNotEmpty) {
                                _sendAiQuestion(v.trim());
                                _aiInputCtrl.clear();
                              }
                            },
                            decoration: InputDecoration(
                              hintText: 'AI에게 질문하기',
                              filled: true,
                              fillColor: const Color(0xFFF4F7FE),
                              border: OutlineInputBorder(
                                borderSide: BorderSide.none,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            final text = _aiInputCtrl.text.trim();
                            if (text.isEmpty) return;
                            _sendAiQuestion(text);
                            _aiInputCtrl.clear();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: const Color(0xFF3B71CA), shape: BoxShape.circle),
                            child: const Icon(Icons.send, color: Colors.white),
                          ),
                        )
                      ],
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

  Widget _smallStat(String title, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
      ],
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
