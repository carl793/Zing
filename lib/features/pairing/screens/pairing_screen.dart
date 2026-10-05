import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pixel_button.dart';
import '../../../core/widgets/pixel_tab_bar.dart';
import '../../../core/widgets/onboarding_progress_bar.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/router/app_router.dart';
import '../controllers/pairing_controller.dart';

class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  Future<void> _logout() async {
    final auth = context.read<AuthService>();
    final navigator = Navigator.of(context);
    await auth.logout();
    navigator.pushNamedAndRemoveUntil(
      AppRoutes.welcome,
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthService>().currentUser!.uid;
    return ChangeNotifierProvider(
      create: (_) => PairingController(
        context.read<FirestoreService>(),
        currentUid: uid,
      ),
      child: _PairingView(onLogout: _logout),
    );
  }
}

class _PairingView extends StatelessWidget {
  final VoidCallback onLogout;
  const _PairingView({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<PairingController>();

    if (ctrl.linked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.pairingSuccess);
      });
    }

    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const OnboardingProgressBar(currentStep: 3),
              const SizedBox(height: AppSpacing.lg),

              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Row(children: [
                  Text('◀ BACK',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.cyan)),
                ]),
              ),
              const SizedBox(height: AppSpacing.lg),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('👻', style: TextStyle(fontSize: 32)),
                  Expanded(
                    child: Text(
                      'ZING:\nROMANCE SPACE',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.header.copyWith(
                        fontSize: 18,
                        color: AppColors.cyan,
                        height: 1.4,
                        shadows: [
                          const Shadow(
                              color: Colors.black,
                              offset: Offset(3, 3),
                              blurRadius: 0)
                        ],
                      ),
                    ),
                  ),
                  const Text('😈', style: TextStyle(fontSize: 32)),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              Text(
                'PRESS START TO CONNECT',
                textAlign: TextAlign.center,
                style: AppTextStyles.body
                    .copyWith(color: AppColors.yellow, fontSize: 8),
              ),
              const SizedBox(height: AppSpacing.lg),

              PixelTabBar(
                labels: const ['CREATE ROOM', 'JOIN ROOM'],
                activeIndex: ctrl.tab == PairingTab.create ? 0 : 1,
                onTap: (i) => ctrl.switchTab(
                    i == 0 ? PairingTab.create : PairingTab.join),
              ),
              const SizedBox(height: AppSpacing.md),

              ctrl.tab == PairingTab.create
                  ? const _CreatePanel()
                  : const _JoinPanel(),

              const SizedBox(height: AppSpacing.xl),
              const Divider(color: Colors.white12, thickness: 1),
              const SizedBox(height: AppSpacing.md),

              Center(
                child: TextButton(
                  onPressed: onLogout,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.coral,
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  ),
                  child: Text(
                    '[ LOGOUT ]',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.coral,
                      fontSize: 7,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CREATE PANEL
// ─────────────────────────────────────────────
class _CreatePanel extends StatelessWidget {
  const _CreatePanel();

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<PairingController>();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.purple,
        border: Border.all(color: Colors.black, width: 2),
        boxShadow: const [
          BoxShadow(
              color: Colors.black, offset: Offset(5, 5), blurRadius: 0)
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: switch (ctrl.createState) {
        CreateState.idle => _CreateIdle(ctrl: ctrl),
        CreateState.loading => const Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: CircularProgressIndicator(color: AppColors.yellow),
            ),
          ),
        CreateState.waiting => _CreateWaiting(ctrl: ctrl),
      },
    );
  }
}

class _CreateIdle extends StatelessWidget {
  final PairingController ctrl;
  const _CreateIdle({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: AppSpacing.md),
        const Text('🔑', style: TextStyle(fontSize: 32)),
        const SizedBox(height: AppSpacing.md),
        Text(
          'GENERATE A 6-DIGIT CODE TO\nSHARE WITH YOUR PARTNER.\nTHE CODE STAYS VALID FOR\n24 HOURS.',
          textAlign: TextAlign.center,
          style: AppTextStyles.body
              .copyWith(color: Colors.white70, fontSize: 7, height: 1.8),
        ),
        const SizedBox(height: AppSpacing.lg),
        PixelButton(
          label: '[ GENERATE CODE ]',
          style: PixelButtonStyle.yellow,
          onPressed: ctrl.generateCode,
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}

class _CreateWaiting extends StatelessWidget {
  final PairingController ctrl;
  const _CreateWaiting({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'YOUR 6-DIGIT PAIRING CODE',
          textAlign: TextAlign.center,
          style: AppTextStyles.label.copyWith(color: AppColors.cyan),
        ),
        const SizedBox(height: AppSpacing.md),

        Container(
          decoration: BoxDecoration(
            color: AppColors.charcoal,
            border: Border.all(color: Colors.black, width: 2),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black, offset: Offset(3, 3), blurRadius: 0)
            ],
          ),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                ctrl.generatedCode ?? '------',
                style: AppTextStyles.header
                    .copyWith(color: Colors.white, fontSize: 20),
              ),
              GestureDetector(
                onTap: () => ctrl.copyCode(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.yellow,
                    border: Border.all(color: Colors.black, width: 2),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black,
                          offset: Offset(2, 2),
                          blurRadius: 0)
                    ],
                  ),
                  child: Text(
                    '[COPY]',
                    style: AppTextStyles.caption
                        .copyWith(color: Colors.black, fontSize: 7),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        Text(
          'CODE EXPIRES IN ${ctrl.countdownDisplay}',
          textAlign: TextAlign.center,
          style: AppTextStyles.caption.copyWith(color: AppColors.gray),
        ),
        const SizedBox(height: AppSpacing.sm),

        Text(
          'SHARE THIS CODE WITH YOUR\nPARTNER TO LINK ACCOUNTS.',
          textAlign: TextAlign.center,
          style: AppTextStyles.caption
              .copyWith(color: Colors.white70, height: 1.8),
        ),
        const SizedBox(height: AppSpacing.md),

        Text(
          '... WAITING FOR PARTNER\nTO JOIN...',
          textAlign: TextAlign.center,
          style: AppTextStyles.body
              .copyWith(color: AppColors.cyan, fontSize: 8, height: 1.6),
        ),
        const SizedBox(height: AppSpacing.md),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: ctrl.regenerateCode,
              child: Text(
                '[ NEW CODE ]',
                style: AppTextStyles.caption.copyWith(color: AppColors.cyan),
              ),
            ),
            GestureDetector(
              onTap: () => ctrl.cancelRoom(),
              child: Text(
                '[ CANCEL ]',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.coral),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// JOIN PANEL
// ─────────────────────────────────────────────
class _JoinPanel extends StatefulWidget {
  const _JoinPanel();

  @override
  State<_JoinPanel> createState() => _JoinPanelState();
}

class _JoinPanelState extends State<_JoinPanel> {
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<PairingController>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.purple,
            border: Border.all(color: Colors.black, width: 2),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black, offset: Offset(5, 5), blurRadius: 0)
            ],
          ),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              const Text('🔗', style: TextStyle(fontSize: 28)),
              const SizedBox(height: AppSpacing.md),
              Text(
                'ENTER THE 6-DIGIT CODE\nYOUR PARTNER SHARED\nWITH YOU.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(
                    color: Colors.white70, fontSize: 7, height: 1.8),
              ),
              const SizedBox(height: AppSpacing.lg),

              Container(
                decoration: BoxDecoration(
                  color: AppColors.charcoal,
                  border: Border.all(
                    color: ctrl.joinError != JoinError.none
                        ? AppColors.coral
                        : Colors.black,
                    width: 2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black,
                        offset: Offset(0, 3),
                        blurRadius: 0)
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
                child: TextField(
                  controller: _codeController,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: AppTextStyles.header
                      .copyWith(color: Colors.white, fontSize: 14),
                  cursorColor: AppColors.cyan,
                  decoration: InputDecoration(
                    hintText: 'ENTER CODE..',
                    hintStyle: AppTextStyles.body.copyWith(
                        color: const Color(0xFF555577), fontSize: 8),
                    border: InputBorder.none,
                    isDense: true,
                    counterText: '',
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),

              if (ctrl.joinError != JoinError.none) ...[
                const SizedBox(height: AppSpacing.sm),
                _JoinErrorBanner(error: ctrl.joinError),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        PixelButton(
          label: ctrl.joinLoading ? '...' : '[ CONNECT PARTNERS ]',
          style: PixelButtonStyle.coral,
          onPressed: ctrl.joinLoading
              ? null
              : () => ctrl.joinRoom(_codeController.text),
        ),
      ],
    );
  }
}

class _JoinErrorBanner extends StatelessWidget {
  final JoinError error;
  const _JoinErrorBanner({required this.error});

  @override
  Widget build(BuildContext context) {
    final message = switch (error) {
      JoinError.notFound =>
        '✕ THAT CODE DOESN\'T EXIST.\nDOUBLE-CHECK AND TRY AGAIN.',
      JoinError.expired =>
        '⌛ THIS CODE HAS EXPIRED.\nASK YOUR PARTNER TO\nGENERATE A NEW ONE.',
      JoinError.alreadyLinked =>
        '✕ THIS CODE IS ALREADY\nLINKED TO ANOTHER COUPLE.',
      JoinError.selfJoin =>
        '✕ THAT\'S YOUR OWN CODE!\nSHARE IT WITH YOUR\nPARTNER INSTEAD.',
      JoinError.network =>
        '⚠ NO CONNECTION.\nCHECK YOUR INTERNET.',
      JoinError.none => '',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.charcoal,
        border: Border.all(color: AppColors.coral, width: 2),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: AppTextStyles.error.copyWith(fontSize: 6, height: 1.8),
      ),
    );
  }
}