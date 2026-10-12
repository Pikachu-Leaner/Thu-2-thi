import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:toeic_exam/src/app.dart';
import 'package:toeic_exam/src/data/exam_repository.dart';
import 'package:toeic_exam/src/models/exam.dart';

http.Response _jsonResponse(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
);

http.Client _examApiClient({List<String>? requestedPaths}) =>
    MockClient((request) async {
      requestedPaths?.add(request.url.path);
      if (request.url.path.endsWith('/getAll') ||
          request.url.path.endsWith('/getAvailable')) {
        return _jsonResponse({
          'result': [
            {
              'id': 41,
              'name': 'Database Reading Test',
              'durationMinutes': 75,
              'totalQuestions': 1,
              'isPublished': true,
              'startAt': '2026-01-01T00:00:00Z',
              'endAt': '2030-01-01T00:00:00Z',
            },
          ],
        });
      }
      if (request.url.path.endsWith('/getAvailablePreview')) {
        return _jsonResponse({
          'result': {
            'id': 41,
            'name': 'Database Reading Test',
            'groups': [
              {
                'part': 5,
                'content': null,
                'questions': [
                  {
                    'id': 401,
                    'number': 101,
                    'text': 'Choose the correct answer.',
                    'options': [
                      {'label': 'A', 'text': 'Option A', 'isCorrect': true},
                      {'label': 'B', 'text': 'Option B', 'isCorrect': false},
                      {'label': 'C', 'text': 'Option C', 'isCorrect': false},
                      {'label': 'D', 'text': 'Option D', 'isCorrect': false},
                    ],
                  },
                ],
              },
            ],
          },
        });
      }
      return _jsonResponse({'result': {}});
    });

ExamRepository _repository({List<String>? requestedPaths}) => ExamRepository(
  client: _examApiClient(requestedPaths: requestedPaths),
  apiBaseUrl: 'https://api.example.test/',
);

void main() {
  test('exam data is loaded only from the configured SQL API', () async {
    final requestedPaths = <String>[];
    final repository = _repository(requestedPaths: requestedPaths);
    await repository.load();
    expect(repository.exams, hasLength(1));
    expect(repository.exams.single.id, 41);
    expect(requestedPaths, contains('/api/services/app/exam/getAll'));

    await repository.load(availableOnly: true);
    expect(requestedPaths, contains('/api/services/app/exam/getAvailable'));
    expect(repository.exams.single.name, 'Database Reading Test');
    repository.dispose();
  });

  test(
    'an API failure does not fall back to local/mock examination data',
    () async {
      final repository = ExamRepository(
        apiBaseUrl: 'https://api.example.test/',
        client: MockClient((_) async => throw http.ClientException('offline')),
      );
      await repository.load();

      expect(repository.exams, isEmpty);
      expect(repository.error, contains('offline'));
      repository.dispose();
    },
  );

  test('imported unscheduled exam remains disabled', () {
    final exam = Exam.fromJson({
      'id': 61,
      'name': 'Imported Reading',
      'durationMinutes': 75,
      'totalQuestions': 100,
    });

    expect(exam.isPublished, isFalse);
    expect(exam.startAt, isNull);
    expect(exam.endAt, isNull);
  });

  test('import unwraps the ABP response and finds the created exam', () async {
    final requestedMethods = <String>[];
    final repository = ExamRepository(
      apiBaseUrl: 'https://api.example.test/',
      client: MockClient((request) async {
        requestedMethods.add('${request.method} ${request.url.path}');
        if (request.url.path == '/api/exams/import') {
          return _jsonResponse({
            'result': {
              'result': {'examId': 41, 'errors': []},
            },
          });
        }
        if (request.url.path.endsWith('/getAll')) {
          return _jsonResponse({
            'result': [
              {
                'id': 41,
                'name': 'Imported Reading',
                'durationMinutes': 75,
                'totalQuestions': 100,
              },
            ],
          });
        }
        return _jsonResponse({'result': {}});
      }),
    );

    final imported = await repository.importExam(
      name: 'Imported Reading',
      fileName: 'reading.docx',
      bytes: Uint8List.fromList([1, 2, 3]),
    );

    expect(imported.id, 41);
    expect(imported.name, 'Imported Reading');
    expect(requestedMethods, [
      'POST /api/exams/import',
      'GET /api/services/app/exam/getAll',
    ]);
    repository.dispose();
  });

  test('all tests use the required 75-minute duration', () {
    final exam = Exam.fromJson({
      'id': 62,
      'name': 'Existing test',
      'durationMinutes': 120,
      'totalQuestions': 100,
    });

    expect(exam.durationMinutes, 75);
  });

  test('question updates use PUT and include the passage text', () async {
    http.Request? capturedRequest;
    final repository = ExamRepository(
      apiBaseUrl: 'https://api.example.test/',
      client: MockClient((request) async {
        capturedRequest = request;
        return _jsonResponse({'result': {}});
      }),
    );
    final exam = Exam(id: 1, name: 'Test', durationMinutes: 75, questions: []);
    final question = ExamQuestion(
      id: 147,
      number: 147,
      text: 'Question text',
      part: 7,
      passage: 'Shared paragraph',
      options: [
        AnswerOption(label: 'A', text: 'A', isCorrect: true),
        AnswerOption(label: 'B', text: 'B', isCorrect: false),
        AnswerOption(label: 'C', text: 'C', isCorrect: false),
        AnswerOption(label: 'D', text: 'D', isCorrect: false),
      ],
    );

    await repository.saveQuestion(exam, question);

    expect(capturedRequest?.method, 'PUT');
    expect(capturedRequest?.url.path, '/api/services/app/exam/updateQuestion');
    expect(
      jsonDecode(capturedRequest!.body)['passageText'],
      'Shared paragraph',
    );
    repository.dispose();
  });

  test('test settings and deletion use their supported HTTP verbs', () async {
    final requests = <(String, String)>[];
    final repository = ExamRepository(
      apiBaseUrl: 'https://api.example.test/',
      client: MockClient((request) async {
        requests.add((request.method, request.url.path));
        return _jsonResponse({'result': {}});
      }),
    );
    final exam = Exam(id: 1, name: 'Test', durationMinutes: 75, questions: []);

    await repository.saveExam(exam);
    await repository.deleteExam(exam);

    expect(requests, [
      ('PUT', '/api/services/app/exam/updateExam'),
      ('DELETE', '/api/services/app/exam/delete'),
    ]);
    repository.dispose();
  });

  testWidgets('student portal opens on the student entry form', (tester) async {
    final repository = _repository();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: repository, child: const ToeicApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ready to begin?'), findsOneWidget);
    expect(find.text('Họ và Tên'), findsOneWidget);
    expect(find.text('MSSV'), findsOneWidget);
    expect(find.text('Teacher portal'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    repository.dispose();
  });

  testWidgets('student test answers are initially blank', (tester) async {
    final repository = _repository();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: repository, child: const ToeicApp()),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Test Student');
    await tester.enterText(find.byType(TextFormField).last, '12345678');
    await tester.tap(find.text('Continue to tests'));
    await tester.pumpAndSettle();

    expect(find.text('Database Reading Test'), findsOneWidget);
    await tester.tap(find.text('Database Reading Test'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    final group = tester.widget<RadioGroup<String>>(
      find.byType(RadioGroup<String>).first,
    );
    expect(group.groupValue, isNull);

    await tester.tap(find.byType(Radio<String>).first);
    await tester.pump();
    final updatedGroup = tester.widget<RadioGroup<String>>(
      find.byType(RadioGroup<String>).first,
    );
    expect(updatedGroup.groupValue, 'A');

    await tester.pumpWidget(const SizedBox.shrink());
    repository.dispose();
  });

  testWidgets('student question pills jump across all question parts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final questions = List.generate(100, (index) {
      final number = index + 101;
      return {
        'id': number + 300,
        'number': number,
        'text': 'Question $number text',
        'options': [
          {'label': 'A', 'text': 'Option A', 'isCorrect': false},
          {'label': 'B', 'text': 'Option B', 'isCorrect': false},
          {'label': 'C', 'text': 'Option C', 'isCorrect': false},
          {'label': 'D', 'text': 'Option D', 'isCorrect': false},
        ],
      };
    });
    final groups = [
      {'part': 5, 'content': null, 'questions': questions.sublist(0, 30)},
      {
        'part': 6,
        'content': 'Part 6 passage',
        'questions': questions.sublist(30, 46),
      },
      {
        'part': 7,
        'content': 'Part 7 passage',
        'questions': questions.sublist(46),
      },
    ];
    final repository = ExamRepository(
      apiBaseUrl: 'https://api.example.test/',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/getAvailable')) {
          return _jsonResponse({
            'result': [
              {
                'id': 41,
                'name': 'Database Reading Test',
                'durationMinutes': 75,
                'totalQuestions': 100,
                'isPublished': true,
                'startAt': '2026-01-01T00:00:00Z',
                'endAt': '2030-01-01T00:00:00Z',
              },
            ],
          });
        }
        if (request.url.path.endsWith('/getAvailablePreview')) {
          return _jsonResponse({
            'result': {
              'id': 41,
              'name': 'Database Reading Test',
              'groups': groups,
            },
          });
        }
        return _jsonResponse({'result': {}});
      }),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: repository, child: const ToeicApp()),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Test Student');
    await tester.enterText(find.byType(TextFormField).last, '12345678');
    await tester.tap(find.text('Continue to tests'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Database Reading Test'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byTooltip('Question 102'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byTooltip('Question 168'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    final target = tester.getTopLeft(find.text('Question 168'));
    expect(target.dy, greaterThanOrEqualTo(0));
    expect(target.dy, lessThan(tester.view.physicalSize.height));

    await tester.pumpWidget(const SizedBox.shrink());
    repository.dispose();
  });
}
