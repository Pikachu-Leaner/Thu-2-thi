import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/exam.dart';

class ExamRepository extends ChangeNotifier {
  ExamRepository({http.Client? client, String? apiBaseUrl})
    : _client = client ?? http.Client(),
      _apiBaseUrl =
          apiBaseUrl ??
          const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: 'https://localhost:44311/',
          );

  final http.Client _client;
  final String _apiBaseUrl;
  final List<Exam> _exams = [];

  bool _isLoading = false;
  String? _error;

  List<Exam> get exams => List.unmodifiable(_exams);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> load({bool availableOnly = false}) async {
    _isLoading = true;
    _error = null;
    _exams.clear();
    notifyListeners();
    try {
      final response = await _client
          .get(
            _uri(
              availableOnly
                  ? 'api/services/app/exam/getAvailable'
                  : 'api/services/app/exam/getAll',
            ),
          )
          .timeout(const Duration(seconds: 20));
      final payload = _decodeResponse(response);
      final rows = _resultValue(payload);
      if (rows is! List<dynamic>) {
        throw const FormatException('The exam API did not return a list.');
      }
      _exams
        ..clear()
        ..addAll(
          rows.whereType<Map<String, dynamic>>().map(
            (row) => Exam.fromJson(row),
          ),
        );
    } catch (error) {
      _error = 'Could not load exams: $error';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Exam? examById(int id) {
    for (final exam in _exams) {
      if (exam.id == id) return exam;
    }
    return null;
  }

  Future<void> saveQuestion(Exam exam, ExamQuestion question) async {
    final response = await _client
        .put(
          _uri('api/services/app/exam/updateQuestion'),
          headers: _jsonHeaders,
          body: jsonEncode({
            'questionId': question.id,
            'text': question.text,
            'passageText': question.passage,
            'correctLabel': question.correctLabel,
            'options': question.options
                .map(
                  (option) => {
                    'label': option.label,
                    'text': option.text,
                    'isCorrect': option.isCorrect,
                  },
                )
                .toList(),
          }),
        )
        .timeout(const Duration(seconds: 20));
    _decodeResponse(response);
    notifyListeners();
  }

  Future<void> loadQuestions(Exam exam, {bool requireAvailable = false}) async {
    if (exam.questionsLoaded && !requireAvailable) return;
    await _loadQuestions(exam, requireAvailable: requireAvailable);
    exam.questionsLoaded = true;
    notifyListeners();
  }

  Future<void> saveExam(Exam exam) async {
    final response = await _client
        .put(
          _uri('api/services/app/exam/updateExam'),
          headers: _jsonHeaders,
          body: jsonEncode({
            'id': exam.id,
            'name': exam.name,
            'durationMinutes': exam.durationMinutes,
            'isPublished': exam.isPublished,
            'startAt': exam.startAt?.toUtc().toIso8601String(),
            'endAt': exam.endAt?.toUtc().toIso8601String(),
          }),
        )
        .timeout(const Duration(seconds: 20));
    _decodeResponse(response);
    notifyListeners();
  }

  Future<void> deleteExam(Exam exam) async {
    final response = await _client
        .delete(_uri('api/services/app/exam/delete', {'id': '${exam.id}'}))
        .timeout(const Duration(seconds: 20));
    _decodeResponse(response);
    _exams.removeWhere((item) => item.id == exam.id);
    notifyListeners();
  }

  Future<Exam> importExam({
    required String name,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final request = http.MultipartRequest('POST', _uri('api/exams/import'))
      ..fields['name'] = name
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: fileName),
      );
    final streamed = await _client
        .send(request)
        .timeout(const Duration(minutes: 2));
    final response = await http.Response.fromStream(streamed);
    final payload = _decodeResponse(response);
    var result = _resultValue(payload);
    if (result is Map<String, dynamic> &&
        result['result'] is Map<String, dynamic>) {
      result = result['result'] as Map<String, dynamic>;
    }
    if (result is Map<String, dynamic> && result['errors'] is List<Object?>) {
      final errors = result['errors'] as List<Object?>;
      if (errors.isNotEmpty) {
        throw FormatException(errors.join('\n'));
      }
    }
    await load();
    final createdId = result is Map<String, dynamic>
        ? int.tryParse(result['examId']?.toString() ?? '')
        : null;
    final importedExam = examById(createdId ?? -1);
    if (importedExam != null) return importedExam;
    if (_error != null) {
      throw FormatException(
        'The exam was imported, but the exam list could not be refreshed: $_error',
      );
    }
    throw FormatException(
      createdId == null
          ? 'The import response did not include the new exam ID.'
          : 'The imported exam (ID $createdId) was not returned in the exam list.',
    );
  }

  Future<void> _loadQuestions(
    Exam exam, {
    required bool requireAvailable,
  }) async {
    final response = await _client
        .get(
          _uri(
            requireAvailable
                ? 'api/services/app/exam/getAvailablePreview'
                : 'api/services/app/exam/getPreview',
            {'id': '${exam.id}'},
          ),
        )
        .timeout(const Duration(seconds: 20));
    final result = _resultValue(_decodeResponse(response));
    if (result is! Map<String, dynamic>) {
      throw FormatException('Invalid exam response for "${exam.name}".');
    }
    final groups = (result['groups'] as List<dynamic>?) ?? const [];
    exam.questions
      ..clear()
      ..addAll(
        groups.whereType<Map<String, dynamic>>().expand(
          (group) => (group['questions'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(
                (question) => ExamQuestion.fromJson({
                  ...question,
                  'part': group['part'],
                  'passage': group['content'],
                }),
              ),
        ),
      );
  }

  Uri _uri(String path, [Map<String, String>? queryParameters]) {
    final base = Uri.parse(_apiBaseUrl);
    final rootPath = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    return base.replace(
      path: '$rootPath/$path',
      queryParameters: queryParameters,
    );
  }

  static const _jsonHeaders = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String? message;
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is Map<String, dynamic>) {
          message = error['message']?.toString();
        }
      }
      throw http.ClientException(
        message ?? 'Request failed (${response.statusCode}).',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The server returned invalid JSON.');
    }
    return decoded;
  }

  Object? _resultValue(Map<String, dynamic> payload) =>
      payload['result'] ?? payload;

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}
