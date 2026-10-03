import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pixel_button.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/models/user_model.dart';

class PairingSuccessScreen extends StatefulWidget {
  const PairingSuccessScreen({super.key});

  @override
  State<PairingSuccessScreen> createState() => _PairingSuccessScreenState();
}

class _PairingSuccessScreenState extends State<PairingSuccessScreen> {
  String _mySprite = '👻';
  String _partnerSprite = '😈';
  String _myName = '';
  String _partnerName = '';
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadNames();
  }

  Future<void> _loadNames() async {
    final auth = context.read<AuthService>();
    final fs = context.read<FirestoreService>();
    final uid = auth.currentUser!.uid;

    final mySnap = await fs.doc('users/$uid').get();
    final me = UserModel.fromMap(uid, mySnap.data()!);

    if (me.coupleId != null) {
      final coupleSnap = await fs.doc('couples/${me.coupleId}').get();
      final memberUids = List<String>.from(coupleSnap.data()?['memberUids'] ?? []);
      final partnerUid = memberUids.firstWhere((u) => u != uid, orElse: () => '');

      if (partnerUid.isNotEmpty) {
        final partnerSnap = await fs.doc('users/$partnerUid').get();
        final partner = UserModel.fromMap(partnerUid, partnerSnap.data()!);
        setState(() {
          _myName = me.displayName;
          _partnerName = partner.displayName;
          _mySprite = me.avatarSpriteId;
          _partnerSprite = partner.avatarSpriteId;
          _loaded = true;
        });
        return;
      }
    }
    setState(() {
      _myName = me.displayName;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl, vertical: AppSpacing.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Sprites + heart
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_mySprite, style: const TextStyle(fontSize: 44)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('❤️', style: TextStyle(fontSize: 28)),
                  ),
                  Text(_partnerSprite, style: const TextStyle(fontSize: 44)),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              // Title
              Text(
                'YOU\'RE LINKED!',
                textAlign: TextAlign.center,
                style: AppTextStyles.header.copyWith(
                  fontSize: 22,
                  color: AppColors.yellow,
                  shadows: [
                    const Shadow(
                        color: Colors.black,
                        offset: Offset(4, 4),
                        blurRadius: 0)
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Subtitle
              if (_loaded && _partnerName.isNotEmpty)
                Text(
                  '$_myName & $_partnerName ARE NOW\nCONNECTED IN THE\nOVERWORLD.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.cyan, fontSize: 8, height: 1.8),
                )
              else
                Text(
                  'YOU ARE NOW CONNECTED\nIN THE OVERWORLD.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.cyan, fontSize: 8, height: 1.8),
                ),
              const SizedBox(height: AppSpacing.xxl),

              PixelButton(
                label: '[ ENTER OVERWORLD ]',
                style: PixelButtonStyle.coral,
                onPressed: () => Navigator.of(context)
                    .pushReplacementNamed(AppRoutes.dashboard),
              ),
            ],
          ),
        ),
      ),
    );
  }
}