import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/router/app_router.dart';
import 'core/services/auth_service.dart';
import 'core/services/couple_service.dart';
import 'core/services/firestore_service.dart';
import 'core/services/location_service.dart';
import 'core/services/storage_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/controllers/auth_controller.dart';

class ZingApp extends StatelessWidget {
  final String initialRoute;
  const ZingApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        Provider<StorageService>(create: (_) => StorageService()),
        Provider<LocationService>(
          create: (ctx) => LocationService(ctx.read<FirestoreService>()),
        ),
        Provider<CoupleService>(
          create: (ctx) => CoupleService(ctx.read<FirestoreService>()),
        ),
        ChangeNotifierProvider<AuthController>(
          create: (ctx) => AuthController(ctx.read<AuthService>()),
        ),
      ],
      child: MaterialApp(
        title: 'Zing',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        initialRoute: initialRoute,
        onGenerateRoute: AppRouter.generateRoute,
      ),
    );
  }
}