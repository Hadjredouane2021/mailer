import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'theme.dart';
import 'widgets.dart';

/// Hors web, Flutter n'a pas de moteur HTML intégré : on propose
/// d'ouvrir l'aperçu rendu par l'API dans le navigateur.
class HtmlPreview extends StatelessWidget {
  const HtmlPreview({super.key, required this.html, this.externalUrl});

  final String html;
  final String? externalUrl;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.palette.surfaceHigh,
    child: EmptyState(
      icon: Icons.open_in_browser_rounded,
      title: 'Aperçu dans le navigateur',
      message:
          'L’aperçu intégré est disponible dans la version web. '
          'Enregistrez puis ouvrez le rendu exact envoyé aux destinataires.',
      action: externalUrl == null
          ? null
          : FilledButton.icon(
              onPressed: () => launchUrl(Uri.parse(externalUrl!)),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Ouvrir l’aperçu'),
            ),
    ),
  );
}
