import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/student.dart';
import '../theme/app_theme.dart';

class EntryScreen extends StatefulWidget {
  const EntryScreen({super.key});

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _studentIdController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _studentIdController.dispose();
    super.dispose();
  }

  void _continue() {
    if (!_formKey.currentState!.validate()) return;
    final student = Student(
      studentId: _studentIdController.text.trim(),
      fullName: _nameController.text.trim(),
    );
    context.go('/student/showcase', extra: student);
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 680;
    return Scaffold(
      appBar: AppBar(title: const _Brand()),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(compact ? 20 : 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(compact ? 22 : 34),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.menu_book_rounded,
                        size: 42,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Ready to begin?',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enter your student details to see currently available TOEIC Reading tests.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: AppColors.muted),
                      ),
                      const SizedBox(height: 28),
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Họ và Tên',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Please enter your full name.'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _studentIdController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'MSSV',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Please enter your student ID.'
                            : null,
                      ),
                      const SizedBox(height: 22),
                      FilledButton.icon(
                        onPressed: _continue,
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: const Text('Continue to tests'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.menu_book_rounded,
          color: Colors.white,
          size: 19,
        ),
      ),
      const SizedBox(width: 10),
      const Text(
        'Readwise TOEIC',
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
      ),
    ],
  );
}
