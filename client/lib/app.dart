import 'package:flutter/material.dart';

import 'core/app_theme.dart';
import 'features/idle/idle_page.dart';

class ClassroomNotesApp extends StatelessWidget {
  const ClassroomNotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '课堂速记',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const IdlePage(),
    );
  }
}
