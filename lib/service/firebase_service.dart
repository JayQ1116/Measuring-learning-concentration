// lib/service/firebase_service.dart
// Firebase 认证 + Firestore 数据服务

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  // ─────────────────────────────────────────
  // 认证
  // ─────────────────────────────────────────

  static User? get currentUser => _auth.currentUser;
  static String? get currentUid => _auth.currentUser?.uid;

  /// 登录
  static Future<Map<String, dynamic>?> signIn(
      String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      final uid = cred.user!.uid;
      final doc = await _db.collection('users').doc(uid).get();
      return doc.data();
    } catch (e) {
      return null;
    }
  }

  /// 注册（学生或教师）
  static Future<bool> signUp({
    required String email,
    required String password,
    required String name,
    required String role, // 'student' | 'teacher'
    String classId = 'class_001',
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      final uid = cred.user!.uid;
      await _db.collection('users').doc(uid).set({
        'uid': uid,
        'name': name,
        'email': email,
        'role': role,
        'classId': classId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<void> signOut() => _auth.signOut();

  // ─────────────────────────────────────────
  // 学习会话
  // ─────────────────────────────────────────

  static Future<String> startSession({
    required String studentUid,
    required String pdfName,
    String classId = 'class_001',
  }) async {
    final doc = await _db.collection('sessions').add({
      'studentUid': studentUid,
      'classId': classId,
      'pdfName': pdfName,
      'startTime': FieldValue.serverTimestamp(),
      'endTime': null,
      'totalFocusedSeconds': 0,
      'totalConfusedSeconds': 0,
    });
    return doc.id;
  }

  static Future<void> endSession(String sessionId,
      {required int focusedSec, required int confusedSec}) async {
    await _db.collection('sessions').doc(sessionId).update({
      'endTime': FieldValue.serverTimestamp(),
      'totalFocusedSeconds': focusedSec,
      'totalConfusedSeconds': confusedSec,
    });
  }

  // ─────────────────────────────────────────
  // 专注度日志（每5秒上传一次）
  // ─────────────────────────────────────────

  static Future<void> uploadConcentrationLog({
    required String studentUid,
    required String sessionId,
    required String state, // 'focused' | 'confused'
    required double confidence,
    String classId = 'class_001',
  }) async {
    await _db.collection('concentrationLogs').add({
      'studentUid': studentUid,
      'sessionId': sessionId,
      'classId': classId,
      'timestamp': FieldValue.serverTimestamp(),
      'state': state,
      'confidence': confidence,
    });

    // 同时更新学生实时状态（教师看板用）
    await _db
        .collection('studentLiveState')
        .doc(studentUid)
        .set({
      'studentUid': studentUid,
      'classId': classId,
      'state': state,
      'confidence': confidence,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ─────────────────────────────────────────
  // PDF 进度
  // ─────────────────────────────────────────

  static Future<void> savePdfProgress({
    required String studentUid,
    required String pdfName,
    required int currentPage,
    required int totalPages,
  }) async {
    final docId = '${studentUid}_${pdfName.replaceAll(RegExp(r'[^\w]'), '_')}';
    await _db.collection('pdfProgress').doc(docId).set({
      'studentUid': studentUid,
      'pdfName': pdfName,
      'currentPage': currentPage,
      'totalPages': totalPages,
      'lastReadAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ─────────────────────────────────────────
  // 教师看板：实时学生状态流
  // ─────────────────────────────────────────

  static Stream<QuerySnapshot> classLiveStream(String classId) {
    return _db
        .collection('studentLiveState')
        .where('classId', isEqualTo: classId)
        .snapshots();
  }

  // ─────────────────────────────────────────
  // 学习报告数据
  // ─────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getSessionLogs(
      String sessionId) async {
    final snap = await _db
        .collection('concentrationLogs')
        .where('sessionId', isEqualTo: sessionId)
        .orderBy('timestamp')
        .get();
    return snap.docs.map((d) => d.data()).toList();
  }
}