import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'models/student.dart';
import 'models/test_attempt.dart';
import 'screens/edit_exam_screen.dart';
import 'screens/entry_screen.dart';
import 'screens/results_screen.dart';
import 'screens/showcase_screen.dart';
import 'screens/take_test_screen.dart';
import 'theme/app_theme.dart';

class ToeicApp extends StatefulWidget {
  const ToeicApp({super.key});

  @override
  State<ToeicApp> createState() => _ToeicAppState();
}

class _ToeicAppState extends State<ToeicApp> {
  late final GoRouter _router = GoRouter(
    initialLocation: '/student',
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/student'),
      GoRoute(
        path: '/teacher',
        builder: (_, _) => const ShowcaseScreen(teacherMode: true),
        routes: [
          GoRoute(
            path: 'exams/:examId',
            builder: (_, state) => EditExamScreen(
              examId: int.parse(state.pathParameters['examId']!),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/student',
        builder: (_, _) => const EntryScreen(),
        routes: [
          GoRoute(
            path: 'showcase',
            builder: (_, state) => ShowcaseScreen(
              teacherMode: false,
              student: state.extra as Student?,
            ),
            routes: [
              GoRoute(
                path: 'exams/:examId',
                builder: (_, state) => TakeTestScreen(
                  examId: int.parse(state.pathParameters['examId']!),
                  student: state.extra is Student
                      ? state.extra as Student
                      : null,
                ),
                routes: [
                  GoRoute(
                    path: 'results',
                    builder: (_, state) => ResultsScreen(
                      examId: int.parse(state.pathParameters['examId']!),
                      attempt: state.extra is TestAttempt
                          ? state.extra as TestAttempt
                          : TestAttempt(student: null, answers: const {}),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.uri.path}')),
    ),
  );

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'TOEIC Reading',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    routerConfig: _router,
  );
}
