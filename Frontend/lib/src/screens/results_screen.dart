import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/exam_repository.dart';
import '../models/exam.dart';
import '../models/test_attempt.dart';
import '../theme/app_theme.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key, required this.examId, required this.attempt});

  final int examId;
  final TestAttempt attempt;

  @override
  Widget build(BuildContext context) {
    final exam = context.watch<ExamRepository>().examById(examId);
    if (exam == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('This examination could not be found.')),
      );
    }
    final correctCount = exam.questions
        .where(
          (question) =>
              attempt.answers[question.id] == question.correctLabel &&
              question.correctLabel != null,
        )
        .length;
    final percentage = exam.questions.isEmpty
        ? 0
        : (correctCount / exam.questions.length * 100).round();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test results'),
        automaticallyImplyLeading: false,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final horizontal = constraints.maxWidth < 600 ? 16.0 : 36.0;
          return Scrollbar(
            thumbVisibility: true,
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(horizontal, 28, horizontal, 24),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      children: [
                        Text(
                          attempt.student?.fullName ?? 'Test complete',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          exam.name,
                          style: const TextStyle(color: AppColors.muted),
                        ),
                        const SizedBox(height: 22),
                        _ScoreCircle(
                          correctCount: correctCount,
                          totalCount: exam.questions.length,
                          percentage: percentage,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Review your answers',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Each card shows your response and whether it was correct.',
                          style: TextStyle(color: AppColors.muted),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: horizontal),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final question = exam.questions[index];
                      final answer = attempt.answers[question.id];
                      final correct =
                          answer != null && answer == question.correctLabel;
                      return _ResultCard(
                        question: question,
                        answer: answer,
                        correct: correct,
                      );
                    }, childCount: exam.questions.length),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _columns(constraints.maxWidth),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      mainAxisExtent: 124,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(horizontal, 26, horizontal, 36),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: FilledButton.icon(
                        onPressed: () => context.go(
                          '/student/showcase',
                          extra: attempt.student,
                        ),
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: const Text('Go back to main page'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  int _columns(double width) {
    if (width >= 1350) return 5;
    if (width >= 1000) return 4;
    if (width >= 680) return 3;
    if (width >= 420) return 2;
    return 1;
  }
}

class _ScoreCircle extends StatelessWidget {
  const _ScoreCircle({
    required this.correctCount,
    required this.totalCount,
    required this.percentage,
  });

  final int correctCount;
  final int totalCount;
  final int percentage;

  @override
  Widget build(BuildContext context) => Container(
    width: 174,
    height: 174,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: AppColors.green.withValues(alpha: .06),
      border: Border.all(
        color: AppColors.green.withValues(alpha: .35),
        width: 2,
      ),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '$correctCount',
          style: const TextStyle(
            color: AppColors.green,
            fontSize: 54,
            height: 1,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'out of $totalCount · $percentage%',
          style: const TextStyle(
            color: AppColors.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.question,
    required this.answer,
    required this.correct,
  });

  final ExamQuestion question;
  final String? answer;
  final bool correct;

  @override
  Widget build(BuildContext context) {
    final color = correct ? AppColors.green : AppColors.red;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Question ${question.number}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Icon(
                  correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  size: 19,
                  color: color,
                ),
              ],
            ),
            const Spacer(),
            Text(
              answer == null ? 'Your answer: —' : 'Your answer: $answer',
              style: TextStyle(
                color: answer == null ? AppColors.muted : color,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (!correct && question.correctLabel != null) ...[
              const SizedBox(height: 5),
              Text(
                'Correct answer: ${question.correctLabel}',
                style: const TextStyle(color: AppColors.green, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
