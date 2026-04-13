import 'dart:async';

class LensFocusDatabase {
  static final LensFocusDatabase instance = LensFocusDatabase._init();
  LensFocusDatabase._init();

  final List<Map<String, String>> _mockUsers = [
    {"id": "GAO_LUO", "pw": "123", "role": "Student"},
  ];

  final List<Map<String, dynamic>> _mockTasks = [];

  Future<Map<String, String>?> loginUser(String id, String pw, String role) async {
    await Future.delayed(const Duration(milliseconds: 500));
    try {
      return _mockUsers.firstWhere((u) => u['id'] == id && u['pw'] == pw && u['role'] == role);
    } catch (e) { return null; }
  }

  Future<bool> registerUser(String id, String pw, String role) async {
    if (_mockUsers.any((u) => u['id'] == id)) return false;
    _mockUsers.add({"id": id, "pw": pw, "role": role});
    return true;
  }

  Future<List<Map<String, dynamic>>> getTasks(String studentId) async {
    return _mockTasks.where((t) => t['student_id'] == studentId).toList();
  }

  Future<void> addTask(String studentId, String taskName) async {
    _mockTasks.add({
      "id": DateTime.now().millisecondsSinceEpoch,
      "student_id": studentId,
      "task_name": taskName,
      "is_done": 0
    });
  }

  Future<void> updateTaskStatus(int taskId, bool isDone) async {
    final index = _mockTasks.indexWhere((t) => t['id'] == taskId);
    if (index != -1) _mockTasks[index]['is_done'] = isDone ? 1 : 0;
  }
}