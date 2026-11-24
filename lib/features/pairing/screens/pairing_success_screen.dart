import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pixel_button.dart';
import '../../../core/router/app_router.dart';
import '../../../data/repositories/couple_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/constants/sprite_options.dart';
import '../../../core/models/user_model.dart';
import '../../../core/widgets/sprite_avatar.dart';

class PairingSuccessScreen extends StatefulWidget {
  const PairingSuccessScreen({super.key});

  @override
  State<PairingSuccessScreen> createState() => _PairingSuccessScreenState();
}

class _PairingSuccessScreenState extends State<PairingSuccessScreen> {
  String _mySprite = SpriteOptions.fallback;
  String _partnerSprite = SpriteOptions.fallback;
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
    final users = context.read<UserRepository>();
    final couples = context.read<CoupleRepository>();
    final uid = auth.currentUser!.uid;

    UserModel? me;
    UserModel? partner;
    try {
      me = await users.fetch(uid);
      final coupleId = me?.coupleId ?? '';
      final couple = coupleId.isEmpty ? null : await couples.fetch(coupleId);
      final partnerUid = couple?.partnerUid(uid) ?? '';
      if (partnerUid.isNotEmpty) partner = await users.fetch(partnerUid);
    } catch (e) {
      // The celebration still shows; only the names and sprites are missing.
      debugPrint('Loading the paired profiles failed: $e');
    }
    if (!mounted) return;
    final (loadedMe, loadedPartner) = (me, partner);
    setState(() {
      if (loadedMe != null) {
        _myName = loadedMe.displayName;
        if (loadedMe.avatarSpriteId.isNotEmpty) _mySprite = loadedMe.avatarSpriteId;
      }
      if (loadedPartner != null) {
        _partnerName = loadedPartner.displayName;
        if (loadedPartner.avatarSpriteId.isNotEmpty) {
          _partnerSprite = loadedPartner.avatarSpriteId;
        }
      }
      _loaded = true;
    });
  }

  // Blank until loaded, so the default sprite doesn't flash first.
  Widget _sprite(String spriteId) => _loaded
      ? SpriteAvatar(spriteId: spriteId, size: 56)
      : const SizedBox(width: 56, height: 56);

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
                  _sprite(_mySprite),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('❤️', style: TextStyle(fontSize: 28)),
                  ),
                  _sprite(_partnerSprite),
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
                    .pushReplacementNamed(AppRoutes.shell),
              ),
            ],
          ),
        ),
      ),
    );
  }
}