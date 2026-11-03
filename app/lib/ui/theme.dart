import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Jetons de couleur de Mailler Studio, inspirés de l'identité FMA / RDV de l'Assurance :
/// bleu #477BBB, turquoise #27A78E, bordeaux #9E1845, gris clair #F2F3F4.
/// Les teintes sont éclaircies sur fond sombre et approfondies sur fond clair (contraste AA).
@immutable
class Palette extends ThemeExtension<Palette> {
  const Palette({
    required this.bg,
    required this.surface,
    required this.surfaceHigh,
    required this.raised,
    required this.glass,
    required this.field,
    required this.code,
    required this.line,
    required this.lineStrong,
    required this.text,
    required this.muted,
    required this.faint,
    required this.accent,
    required this.onAccent,
    required this.iris,
    required this.wine,
    required this.success,
    required this.danger,
    required this.warning,
    required this.info,
    required this.inverse,
    required this.onInverse,
  });

  /// Fond de l'application.
  final Color bg;

  /// Cartes.
  final Color surface;

  /// Zones en retrait à l'intérieur d'une carte (pistes de jauge, segments…).
  final Color surfaceHigh;

  /// Élément sélectionné posé sur [surfaceHigh] (segment actif…).
  final Color raised;

  /// Surfaces flottantes translucides (barre latérale, dock, palette de commandes).
  final Color glass;
  final Color field;
  final Color code;
  final Color line;
  final Color lineStrong;
  final Color text;
  final Color muted;
  final Color faint;

  /// Bleu de marque : accents, focus, graphiques.
  final Color accent;
  final Color onAccent;

  /// Turquoise de marque (dégradés, seconde série, réussite).
  final Color iris;

  /// Bordeaux de marque (rôle administrateur, touches décoratives).
  final Color wine;
  final Color success;
  final Color danger;
  final Color warning;
  final Color info;

  /// Bouton principal : blanc sur sombre, noir sur clair.
  final Color inverse;
  final Color onInverse;

  /// Couleurs du visuel de référence.
  static const brandBlue = Color(0xFF477BBB);
  static const brandTurquoise = Color(0xFF27A78E);
  static const brandWine = Color(0xFF9E1845);
  static const brandGrey = Color(0xFFF2F3F4);

  static const dark = Palette(
    bg: Color(0xFF0B0D10),
    surface: Color(0xFF12151A),
    surfaceHigh: Color(0xFF1A1E24),
    raised: Color(0xFF2A3038),
    glass: Color(0xC712151A),
    field: Color(0xFF0E1115),
    code: Color(0xFF0D1014),
    line: Color(0xFF232831),
    lineStrong: Color(0xFF343B46),
    text: brandGrey,
    muted: Color(0xFFA0A8B3),
    faint: Color(0xFF6B737E),
    accent: Color(0xFF6E9DD9),
    onAccent: Color(0xFFFFFFFF),
    iris: Color(0xFF34BFA3),
    wine: Color(0xFFE8668C),
    success: Color(0xFF34BFA3),
    danger: Color(0xFFE8668C),
    warning: Color(0xFFF2B34B),
    info: Color(0xFF63B3ED),
    inverse: brandGrey,
    onInverse: Color(0xFF0B0D10),
  );

  static const light = Palette(
    bg: brandGrey,
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFF4F5F6),
    raised: Color(0xFFFFFFFF),
    glass: Color(0xD9FFFFFF),
    field: Color(0xFFFFFFFF),
    code: Color(0xFFFAFBFB),
    line: Color(0xFFE1E4E8),
    lineStrong: Color(0xFFCDD2D8),
    text: Color(0xFF0F1720),
    muted: Color(0xFF56606C),
    faint: Color(0xFF949CA6),
    accent: Color(0xFF3D6DAA),
    onAccent: Color(0xFFFFFFFF),
    iris: Color(0xFF1E8572),
    wine: brandWine,
    success: Color(0xFF1E8572),
    danger: brandWine,
    warning: Color(0xFFA95C08),
    info: Color(0xFF2B7BB9),
    inverse: Color(0xFF0F1720),
    onInverse: Color(0xFFFFFFFF),
  );

  /// Dégradé de marque bleu → turquoise (logo, actions principales) : texte blanc AA partout.
  static const brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3D6DAA), Color(0xFF1E8572)],
  );

  /// Halo des éléments au dégradé de marque.
  static const brandGlow = Color(0xFF3D6DAA);

  @override
  Palette copyWith({Color? accent, Color? iris}) => Palette(
    bg: bg,
    surface: surface,
    surfaceHigh: surfaceHigh,
    raised: raised,
    glass: glass,
    field: field,
    code: code,
    line: line,
    lineStrong: lineStrong,
    text: text,
    muted: muted,
    faint: faint,
    accent: accent ?? this.accent,
    onAccent: onAccent,
    iris: iris ?? this.iris,
    wine: wine,
    success: success,
    danger: danger,
    warning: warning,
    info: info,
    inverse: inverse,
    onInverse: onInverse,
  );

  @override
  Palette lerp(Palette? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return Palette(
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      surfaceHigh: l(surfaceHigh, other.surfaceHigh),
      raised: l(raised, other.raised),
      glass: l(glass, other.glass),
      field: l(field, other.field),
      code: l(code, other.code),
      line: l(line, other.line),
      lineStrong: l(lineStrong, other.lineStrong),
      text: l(text, other.text),
      muted: l(muted, other.muted),
      faint: l(faint, other.faint),
      accent: l(accent, other.accent),
      onAccent: l(onAccent, other.onAccent),
      iris: l(iris, other.iris),
      wine: l(wine, other.wine),
      success: l(success, other.success),
      danger: l(danger, other.danger),
      warning: l(warning, other.warning),
      info: l(info, other.info),
      inverse: l(inverse, other.inverse),
      onInverse: l(onInverse, other.onInverse),
    );
  }
}

extension ThemeContext on BuildContext {
  Palette get palette => Theme.of(this).extension<Palette>()!;
  TextTheme get textTheme => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

const radiusXl = 24.0;
const radiusLg = 18.0;
const radiusMd = 12.0;
const radiusSm = 8.0;

const tabularFigures = [FontFeature.tabularFigures()];

TextStyle monoStyle({double size = 13, Color? color, FontWeight? weight}) =>
    GoogleFonts.geistMono(fontSize: size, color: color, fontWeight: weight, height: 1.55);

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final p = dark ? Palette.dark : Palette.light;
  final scheme = ColorScheme.fromSeed(seedColor: p.accent, brightness: brightness).copyWith(
    primary: p.accent,
    onPrimary: p.onAccent,
    secondary: p.iris,
    secondaryContainer: p.surfaceHigh,
    onSecondaryContainer: p.text,
    surface: p.surface,
    onSurface: p.text,
    onSurfaceVariant: p.muted,
    surfaceContainerHighest: p.surfaceHigh,
    outline: p.line,
    outlineVariant: p.line,
    error: p.danger,
  );
  final base = ThemeData(useMaterial3: true, brightness: brightness, colorScheme: scheme);
  final text = GoogleFonts.geistTextTheme(base.textTheme).apply(bodyColor: p.text, displayColor: p.text);

  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(radiusMd),
    borderSide: BorderSide(color: p.line),
  );
  final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd));
  const buttonPadding = EdgeInsets.symmetric(horizontal: 18, vertical: 14);
  const buttonSize = Size(0, 44);
  final buttonText = text.labelLarge?.copyWith(fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: -0.1);

  return base.copyWith(
    scaffoldBackgroundColor: p.bg,
    canvasColor: p.bg,
    extensions: [p],
    splashFactory: NoSplash.splashFactory,
    hoverColor: p.text.withValues(alpha: 0.04),
    highlightColor: p.text.withValues(alpha: 0.06),
    focusColor: p.accent.withValues(alpha: 0.14),
    textTheme: text.copyWith(
      displayMedium: text.displayMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -2),
      displaySmall: text.displaySmall?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -1.6),
      headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -1.1, fontSize: 30),
      headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.7),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.5, fontSize: 20),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.25),
      titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.1),
      bodyLarge: text.bodyLarge?.copyWith(fontSize: 15, height: 1.5),
      bodyMedium: text.bodyMedium?.copyWith(fontSize: 14, height: 1.5),
      bodySmall: text.bodySmall?.copyWith(color: p.muted, fontSize: 12.5, height: 1.45),
      labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      labelMedium: text.labelMedium?.copyWith(fontWeight: FontWeight.w500),
      labelSmall: text.labelSmall?.copyWith(
        color: p.muted,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        fontSize: 11,
      ),
    ),
    dividerColor: p.line,
    dividerTheme: DividerThemeData(color: p.line, thickness: 1, space: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.inverse,
        foregroundColor: p.onInverse,
        disabledBackgroundColor: p.surfaceHigh,
        disabledForegroundColor: p.faint,
        shape: buttonShape,
        padding: buttonPadding,
        minimumSize: buttonSize,
        textStyle: buttonText,
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.text,
        backgroundColor: dark ? Colors.transparent : p.surface,
        disabledForegroundColor: p.faint,
        side: BorderSide(color: p.line),
        shape: buttonShape,
        padding: buttonPadding,
        minimumSize: buttonSize,
        textStyle: buttonText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.text,
        shape: buttonShape,
        textStyle: buttonText,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: p.muted,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.field,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: TextStyle(color: p.faint, fontWeight: FontWeight.w400),
      labelStyle: TextStyle(color: p.muted),
      floatingLabelStyle: TextStyle(color: p.accent, fontWeight: FontWeight.w600),
      prefixIconColor: p.faint,
      suffixIconColor: p.faint,
      suffixStyle: TextStyle(color: p.faint),
      border: inputBorder,
      enabledBorder: inputBorder,
      disabledBorder: inputBorder.copyWith(borderSide: BorderSide(color: p.line.withValues(alpha: 0.6))),
      focusedBorder: inputBorder.copyWith(borderSide: BorderSide(color: p.accent, width: 1.6)),
      errorBorder: inputBorder.copyWith(borderSide: BorderSide(color: p.danger)),
      focusedErrorBorder: inputBorder.copyWith(borderSide: BorderSide(color: p.danger, width: 1.6)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : p.muted),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.accent : p.surfaceHigh),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Colors.transparent : p.lineStrong,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      side: BorderSide(color: p.lineStrong, width: 1.5),
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.accent : null),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: p.surfaceHigh,
      side: BorderSide(color: p.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSm)),
      labelStyle: text.labelMedium?.copyWith(color: p.text),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusXl),
        side: BorderSide(color: p.line),
      ),
      titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.5),
      barrierColor: Colors.black.withValues(alpha: dark ? 0.6 : 0.35),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      modalBarrierColor: Colors.black.withValues(alpha: dark ? 0.6 : 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(radiusXl)),
        side: BorderSide(color: p.line),
      ),
      showDragHandle: true,
      dragHandleColor: p.lineStrong,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: p.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha: dark ? 0.5 : 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        side: BorderSide(color: p.line),
      ),
      textStyle: text.bodyMedium,
      labelTextStyle: WidgetStatePropertyAll(text.bodyMedium?.copyWith(color: p.text)),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(p.surface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(12),
        shadowColor: WidgetStatePropertyAll(Colors.black.withValues(alpha: dark ? 0.5 : 0.12)),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
            side: BorderSide(color: p.line),
          ),
        ),
      ),
    ),
    menuButtonTheme: MenuButtonThemeData(
      style: MenuItemButton.styleFrom(
        foregroundColor: p.text,
        iconColor: p.muted,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSm)),
        textStyle: text.bodyMedium,
        minimumSize: const Size(180, 40),
      ),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(p.surface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: p.inverse, borderRadius: BorderRadius.circular(radiusSm)),
      textStyle: text.labelMedium?.copyWith(color: p.onInverse, fontWeight: FontWeight.w500),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      waitDuration: const Duration(milliseconds: 350),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.inverse,
      contentTextStyle: text.bodyMedium?.copyWith(color: p.onInverse, fontWeight: FontWeight.w500),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
      elevation: 8,
      width: 460,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: p.accent,
      linearTrackColor: p.surfaceHigh,
      circularTrackColor: Colors.transparent,
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(p.faint.withValues(alpha: 0.4)),
      radius: const Radius.circular(8),
      thickness: const WidgetStatePropertyAll(6),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: p.accent,
      selectionColor: p.accent.withValues(alpha: 0.3),
      selectionHandleColor: p.accent,
    ),
  );
}
