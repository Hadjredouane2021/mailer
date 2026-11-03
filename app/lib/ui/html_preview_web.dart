import 'dart:js_interop';

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// Affiche un document HTML complet (e-mail) dans une iframe isolée.
class HtmlPreview extends StatefulWidget {
  const HtmlPreview({super.key, required this.html, this.externalUrl});

  final String html;
  final String? externalUrl;

  @override
  State<HtmlPreview> createState() => _HtmlPreviewState();
}

class _HtmlPreviewState extends State<HtmlPreview> {
  web.HTMLIFrameElement? _frame;

  @override
  void didUpdateWidget(HtmlPreview old) {
    super.didUpdateWidget(old);
    if (old.html != widget.html) _frame?.srcdoc = widget.html.toJS;
  }

  @override
  Widget build(BuildContext context) => HtmlElementView.fromTagName(
    tagName: 'iframe',
    onElementCreated: (Object element) {
      final frame = element as web.HTMLIFrameElement;
      frame.style
        ..border = '0'
        ..width = '100%'
        ..height = '100%'
        ..backgroundColor = '#ffffff';
      frame.setAttribute('sandbox', 'allow-popups allow-popups-to-escape-sandbox');
      frame.srcdoc = widget.html.toJS;
      _frame = frame;
    },
  );
}
