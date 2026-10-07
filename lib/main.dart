import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'app.dart';
import 'core/router/app_router.dart';
import 'core/services/audio_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AudioService.instance.init();
  runApp(const ZingApp(initialRoute: AppRoutes.launch));
}
