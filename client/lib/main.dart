import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // media_kit needs its native bindings initialised before any player exists.
  MediaKit.ensureInitialized();
  runApp(const ClassroomNotesApp());
}
