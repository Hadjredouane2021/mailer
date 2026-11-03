import 'package:flutter/material.dart';

import 'theme.dart';
import 'widgets.dart';

void showToast(BuildContext context, String message, {bool error = false}) {
  final p = context.palette;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: Duration(seconds: error ? 6 : 3),
        content: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: (error ? p.danger : p.success).withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(
                error ? Icons.priority_high_rounded : Icons.check_rounded,
                color: error ? p.danger : p.success,
                size: 15,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}

/// Boîte de dialogue standard : icône, titre, contenu, actions.
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.title,
    this.icon,
    this.tone = Tone.accent,
    this.subtitle,
    required this.child,
    required this.actions,
    this.maxWidth = 480,
  });

  final String title;
  final IconData? icon;
  final Tone tone;
  final String? subtitle;
  final Widget child;
  final List<Widget> actions;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (icon != null) ...[IconBadge(icon!, tone: tone, size: 42), const SizedBox(width: 14)],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: context.textTheme.titleLarge),
                        if (subtitle != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(subtitle!, style: context.textTheme.bodySmall?.copyWith(color: p.muted)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              child,
              const SizedBox(height: 22),
              Wrap(alignment: WrapAlignment.end, spacing: 10, runSpacing: 10, children: actions),
            ],
          ),
        ),
      ),
    );
  }
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmer',
  bool destructive = false,
  Widget? details,
  IconData? icon,
}) async {
  final p = context.palette;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AppDialog(
      title: title,
      icon: icon ?? (destructive ? Icons.warning_amber_rounded : Icons.send_rounded),
      tone: destructive ? Tone.danger : Tone.accent,
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
        if (destructive)
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: p.danger, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          )
        else
          GradientButton(label: confirmLabel, onPressed: () => Navigator.pop(context, true)),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, style: context.textTheme.bodyMedium?.copyWith(color: p.muted)),
          if (details != null) ...[const SizedBox(height: 16), details],
        ],
      ),
    ),
  );
  return result ?? false;
}

/// Lignes « libellé — valeur » pour les boîtes de confirmation.
class DetailRows extends StatelessWidget {
  const DetailRows(this.rows, {super.key});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: p.surfaceHigh,
        borderRadius: BorderRadius.circular(radiusMd),
        border: Border.all(color: p.line),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: i == 0 ? null : Border(top: BorderSide(color: p.line.withValues(alpha: 0.7))),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 110, child: Text(rows[i].$1, style: context.textTheme.bodySmall)),
                  Expanded(
                    child: Text(rows[i].$2, style: context.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
