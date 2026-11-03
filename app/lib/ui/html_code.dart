import 'package:flutter/material.dart';

import 'theme.dart';

/// Contrôleur de l'éditeur HTML : coloration syntaxique (balises, attributs,
/// valeurs, commentaires, variables {{ }}) et petites opérations d'édition.
class HtmlCodeController extends TextEditingController {
  HtmlCodeController({super.text});

  static final _token = RegExp(r'<!--[\s\S]*?-->|\{\{[^}]*\}\}|<\/?[A-Za-z][^>]*>');
  static final _attr = RegExp(r'''([\w:-]+)(\s*=\s*)("[^"]*"|'[^']*')?''');
  static final _tagName = RegExp(r'^<\/?[A-Za-z][\w-]*');

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    if (withComposing && value.isComposingRangeValid) {
      return super.buildTextSpan(context: context, style: style, withComposing: withComposing);
    }
    final p = context.palette;
    final tagStyle = TextStyle(color: p.iris);
    final attrStyle = TextStyle(color: p.info);
    final valueStyle = TextStyle(color: p.success);
    final commentStyle = TextStyle(color: p.faint, fontStyle: FontStyle.italic);
    final varStyle = TextStyle(
      color: p.accent,
      fontWeight: FontWeight.w700,
      backgroundColor: p.accent.withValues(alpha: 0.12),
    );

    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in _token.allMatches(text)) {
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
      final token = m[0]!;
      if (token.startsWith('<!--')) {
        spans.add(TextSpan(text: token, style: commentStyle));
      } else if (token.startsWith('{{')) {
        spans.add(TextSpan(text: token, style: varStyle));
      } else {
        spans.addAll(_tagSpans(token, tagStyle, attrStyle, valueStyle, varStyle));
      }
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return TextSpan(style: style, children: spans);
  }

  List<InlineSpan> _tagSpans(
    String tag,
    TextStyle tagStyle,
    TextStyle attrStyle,
    TextStyle valueStyle,
    TextStyle varStyle,
  ) {
    final name = _tagName.firstMatch(tag);
    if (name == null) return [TextSpan(text: tag, style: tagStyle)];
    final spans = <InlineSpan>[TextSpan(text: name[0], style: tagStyle)];
    final body = tag.substring(name.end);
    var last = 0;
    for (final m in _attr.allMatches(body)) {
      if (m.start > last) spans.add(TextSpan(text: body.substring(last, m.start), style: tagStyle));
      spans.add(TextSpan(text: m[1], style: attrStyle));
      spans.add(TextSpan(text: m[2], style: tagStyle));
      if (m[3] != null) spans.add(TextSpan(text: m[3], style: m[3]!.contains('{{') ? varStyle : valueStyle));
      last = m.end;
    }
    if (last < body.length) spans.add(TextSpan(text: body.substring(last), style: tagStyle));
    return spans;
  }

  /// Entoure la sélection (ou insère au curseur) avec [before]/[after].
  void wrap(String before, [String after = '']) {
    final sel = selection.isValid ? selection : TextSelection.collapsed(offset: text.length);
    final selected = sel.textInside(text);
    final next = sel.textBefore(text) + before + selected + after + sel.textAfter(text);
    final start = sel.start + before.length;
    value = TextEditingValue(
      text: next,
      selection: selected.isEmpty
          ? TextSelection.collapsed(offset: start)
          : TextSelection(baseOffset: start, extentOffset: start + selected.length),
    );
  }

  void insert(String snippet) {
    final sel = selection.isValid ? selection : TextSelection.collapsed(offset: text.length);
    final next = sel.textBefore(text) + snippet + sel.textAfter(text);
    value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: sel.start + snippet.length),
    );
  }

  String get selectedText => selection.isValid ? selection.textInside(text) : '';
}
