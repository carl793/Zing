import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/router/app_router.dart';
import '../core/services/auth_service.dart';
import '../core/services/location_service.dart';
import '../core/services/storage_service.dart';
import '../core/theme/app_theme.dart';
import '../data/repositories/capsule_repository.dart';
import '../data/repositories/couple_repository.dart';
import '../data/repositories/memory_repository.dart';
import '../data/repositories/pairing_repository.dart';
import '../data/repositories/user_repository.dart';
import '../features/auth/controllers/auth_controller.dart';

class ZingApp extends StatelessWidget {
  const ZingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Data
        Provider(create: (_) => UserRepository()),
        Provider(create: (_) => CoupleRepository()),
        Provider(create: (_) => MemoryRepository()),
        Provider(create: (_) => CapsuleRepository()),
        Provider(
          create: (ctx) => PairingRepository(
            users: ctx.read<UserRepository>(),
            couples: ctx.read<CoupleRepository>(),
          ),
        ),
        // Device and account services
        Provider(create: (ctx) => AuthService(ctx.read<UserRepository>())),
        Provider(create: (_) => StorageService()),
        Provider(create: (_) => LocationService()),
        ChangeNotifierProvider(
          create: (ctx) => AuthController(ctx.read<AuthService>()),
        ),
      ],
      child: MaterialApp(
        title: 'Zing',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        initialRoute: AppRoutes.launch,
        onGenerateRoute: AppRouter.generateRoute,
      ),
    );
  }
}
