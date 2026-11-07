import 'package:flutter/foundation.dart' show kIsWeb;
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
      // On the web the UI is phone-sized, so pin it to a left-aligned 9:16
      // column and leave the rest of the window blank.
      builder: (BuildContext context, Widget? child) {
        if (!kIsWeb) return child!;
        return ColoredBox(
          color: Colors.black,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double width = constraints.maxHeight * 9 / 16;
              return Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: width,
                  height: constraints.maxHeight,
                  child: ClipRect(child: child!),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
