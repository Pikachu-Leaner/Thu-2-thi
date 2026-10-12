import 'student.dart';

class TestAttempt {
  const TestAttempt({
    required this.student,
    required this.answers,
  });

  final Student? student;
  final Map<int, String> answers;
}
