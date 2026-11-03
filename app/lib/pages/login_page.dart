import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models.dart';
import '../services/session.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'common.dart';

/// Connexion (e-mail + mot de passe) ou, au premier lancement, création du compte administrateur.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final Session _session = context.read<Session>();
  late final _url = TextEditingController(text: _session.serverUrl);
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _setupKey = TextEditingController();

  Health? _health;
  bool _probing = true;
  String? _probeError;
  bool _showServer = false;
  bool _busy = false;
  String? _error;

  bool get _setup => _health?.needsSetup ?? false;

  @override
  void initState() {
    super.initState();
    _probe();
  }

  @override
  void dispose() {
    for (final c in [_url, _name, _email, _password, _confirm, _setupKey]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _probe() async {
    setState(() {
      _probing = true;
      _probeError = null;
    });
    try {
      final health = await _session.probe(_url.text);
      if (mounted) setState(() => _health = health);
    } catch (e) {
      if (mounted) {
        setState(() {
          _probeError = '$e';
          _showServer = true;
        });
      }
    } finally {
      if (mounted) setState(() => _probing = false);
    }
  }

  String? _validate() {
    if (_setup && _name.text.trim().isEmpty) return 'Indiquez votre nom.';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(_email.text.trim())) return 'Adresse e-mail invalide.';
    if (_password.text.isEmpty) return 'Saisissez votre mot de passe.';
    if (_setup) {
      if (_password.text.length < 8) return 'Le mot de passe doit contenir au moins 8 caractères.';
      if (_password.text != _confirm.text) return 'Les deux mots de passe ne correspondent pas.';
      if ((_health?.setupRequiresKey ?? false) && _setupKey.text.trim().isEmpty) {
        return 'La clé d’installation est requise.';
      }
    }
    return null;
  }

  Future<void> _submit() async {
    final problem = _validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_setup) {
        await _session.setup(
          _url.text,
          name: _name.text,
          email: _email.text,
          password: _password.text,
          setupKey: _setupKey.text,
        );
      } else {
        await _session.signIn(_url.text, _email.text, _password.text);
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 1000;
    final form = Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: wide ? 48 : 20, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: FadeIn(child: _form(context, wide)),
        ),
      ),
    );
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: wide
            ? Row(
                children: [
                  const Expanded(flex: 11, child: _Showcase()),
                  Expanded(flex: 9, child: form),
                ],
              )
            : form,
      ),
    );
  }

  Widget _form(BuildContext context, bool wide) {
    final p = context.palette;
    final notice = _session.notice;
    final host = Uri.tryParse(_url.text)?.authority ?? _url.text;

    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!wide) ...[
            const Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(fit: BoxFit.scaleDown, child: PartnerLogos(height: 32, gap: 18)),
            ),
            const SizedBox(height: 28),
          ],
          if (_setup) ...[
            const Align(
              alignment: Alignment.centerLeft,
              child: Eyebrow('Premier lancement', icon: Icons.auto_awesome_outlined),
            ),
            const SizedBox(height: 14),
          ],
          Text(
            _setup ? 'Créer le compte administrateur' : 'Bon retour',
            style: context.textTheme.headlineMedium?.copyWith(fontSize: 30),
          ),
          const SizedBox(height: 8),
          Text(
            _setup
                ? 'Ce compte aura tous les droits : il pourra ensuite inviter votre équipe.'
                : 'Connectez-vous pour accéder à vos campagnes.',
            style: context.textTheme.bodyMedium?.copyWith(color: p.muted),
          ),
          const SizedBox(height: 28),
          if (notice != null && !_setup) ...[
            InfoBanner(tone: Tone.warning, icon: Icons.lock_clock_outlined, text: notice),
            const SizedBox(height: 18),
          ],
          if (_probeError != null) ...[
            InfoBanner(
              tone: Tone.danger,
              icon: Icons.cloud_off_rounded,
              text: _probeError!,
              action: TextButton(onPressed: _probe, child: const Text('Réessayer')),
            ),
            const SizedBox(height: 18),
          ],
          if (_setup) ...[
            Field(
              label: 'Nom complet',
              child: TextField(
                controller: _name,
                autofillHints: const [AutofillHints.name],
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.person_outline_rounded, size: 19),
                  hintText: 'Prénom Nom',
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Field(
            label: 'Adresse e-mail',
            child: TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email, AutofillHints.username],
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.alternate_email_rounded, size: 19),
                hintText: 'vous@fma.org.ma',
              ),
            ),
          ),
          const SizedBox(height: 16),
          Field(
            label: 'Mot de passe',
            child: PasswordField(
              controller: _password,
              showStrength: _setup,
              autofillHints: [_setup ? AutofillHints.newPassword : AutofillHints.password],
              hint: _setup ? '8 caractères minimum' : '••••••••',
              onSubmitted: (_) => _setup ? null : _submit(),
            ),
          ),
          if (_setup) ...[
            const SizedBox(height: 16),
            Field(
              label: 'Confirmer le mot de passe',
              child: PasswordField(controller: _confirm, autofillHints: const [AutofillHints.newPassword]),
            ),
            if (_health?.setupRequiresKey ?? false) ...[
              const SizedBox(height: 16),
              Field(
                label: 'Clé d’installation',
                hint: 'Valeur API_TOKEN du fichier backend/.env.local : elle prouve que vous administrez le serveur.',
                child: TextField(
                  controller: _setupKey,
                  obscureText: true,
                  onSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.key_rounded, size: 19)),
                ),
              ),
            ],
          ],
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: _error == null
                ? const SizedBox(height: 26, width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: InfoBanner(tone: Tone.danger, icon: Icons.error_outline_rounded, text: _error!),
                  ),
          ),
          GradientButton(
            label: _setup ? 'Créer le compte et continuer' : 'Se connecter',
            icon: _setup ? Icons.shield_outlined : Icons.arrow_forward_rounded,
            expand: true,
            loading: _busy,
            onPressed: _probing || _probeError != null ? null : _submit,
          ),
          const SizedBox(height: 26),
          Row(
            children: [
              Icon(Icons.circle, size: 8, color: _probing ? p.faint : (_probeError == null ? p.success : p.danger)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _probing ? 'Connexion au serveur…' : 'Serveur $host',
                  style: monoStyle(size: 12, color: p.muted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _showServer = !_showServer),
                child: Text(_showServer ? 'Masquer' : 'Modifier'),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            child: !_showServer
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _url,
                            keyboardType: TextInputType.url,
                            onSubmitted: (_) => _probe(),
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.dns_outlined, size: 19),
                              hintText: 'http://localhost:4100',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton(onPressed: _probing ? null : _probe, child: const Text('Vérifier')),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Panneau de présentation (grand écran) : toujours sombre, dégradé de marque.
class _Showcase extends StatelessWidget {
  const _Showcase();

  @override
  Widget build(BuildContext context) {
    const white = Colors.white;
    final dim = white.withValues(alpha: 0.62);
    return Padding(
      padding: const EdgeInsets.all(14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0E1A2B), Color(0xFF0A0E14), Color(0xFF0A1A18)],
                  ),
                ),
              ),
            ),
            Positioned(top: -160, left: -120, child: _blob(Palette.brandBlue, 560, 0.55)),
            Positioned(bottom: -220, right: -160, child: _blob(Palette.brandTurquoise, 620, 0.4)),
            Positioned(top: 220, right: 40, child: _blob(Palette.brandWine, 300, 0.35)),
            Positioned.fill(child: CustomPaint(painter: _GridPainter())),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(44, 40, 44, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const BrandMark(size: 40),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mailler Studio',
                              style: context.textTheme.titleMedium?.copyWith(color: white, letterSpacing: -0.4),
                            ),
                            Text('FMA · RDV de l’Assurance', style: TextStyle(color: dim, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(width: 24),
                        const Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: PartnerLogos(height: 34, dark: true, gap: 20),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      'Vos campagnes e-mail,\norchestrées avec précision.',
                      style: context.textTheme.displaySmall?.copyWith(
                        color: white,
                        fontSize: 44,
                        height: 1.08,
                        letterSpacing: -1.8,
                      ),
                    ),
                    const SizedBox(height: 18),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Text(
                        'Envois par lots maîtrisés, suivi en direct et gestion d’équipe : '
                        'tout votre e-mailing FMA dans un seul studio.',
                        style: context.textTheme.bodyLarge?.copyWith(color: dim, fontSize: 16),
                      ),
                    ),
                    const SizedBox(height: 34),
                    const Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _Feature(Icons.layers_outlined, 'Envois par lots'),
                        _Feature(Icons.monitor_heart_outlined, 'Suivi en direct'),
                        _Feature(Icons.groups_2_outlined, 'Équipe & rôles'),
                        _Feature(Icons.data_object_rounded, 'Personnalisation'),
                      ],
                    ),
                    const Spacer(),
                    const _LiveCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _blob(Color color, double size, double alpha) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: alpha),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    ),
  );
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.045)
      ..strokeWidth = 1;
    const gap = 44.0;
    for (var x = 0.0; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}

class _Feature extends StatelessWidget {
  const _Feature(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF9DC0EA)),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ],
    ),
  );
}

/// Carte « envoi en cours » décorative, animée en boucle.
class _LiveCard extends StatefulWidget {
  const _LiveCard();

  @override
  State<_LiveCard> createState() => _LiveCardState();
}

class _LiveCardState extends State<_LiveCard> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dim = Colors.white.withValues(alpha: 0.6);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final v = 0.18 + 0.78 * Curves.easeInOut.transform(_c.value);
            final sent = (v * 2480).round();
            return Row(
              children: [
                SizedBox(
                  width: 62,
                  height: 62,
                  child: CustomPaint(
                    painter: _MiniRing(v),
                    child: Center(
                      child: Text(
                        '${(v * 100).round()}%',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const PulseDot(color: Color(0xFF5FD3BB)),
                          const SizedBox(width: 8),
                          Text(
                            'Envoi en cours · lot ${1 + (v * 124).floor()}',
                            style: const TextStyle(color: Color(0xFF5FD3BB), fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '21st Annual Gulf Insurance Forum',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${sent.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]} ')} / 2 480 e-mails envoyés',
                        style: TextStyle(color: dim, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MiniRing extends CustomPainter {
  _MiniRing(this.value);

  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(3.5);
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7,
    );
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      Paint()
        ..shader = const SweepGradient(
          colors: [Color(0xFF6E9DD9), Color(0xFF34BFA3), Color(0xFF6E9DD9)],
          transform: GradientRotation(-math.pi / 2),
        ).createShader(Offset.zero & size)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 7,
    );
  }

  @override
  bool shouldRepaint(_MiniRing old) => old.value != value;
}
