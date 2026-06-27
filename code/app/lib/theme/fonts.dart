/// Font families. Geist (Latin) is primary; Noto Sans Devanagari is the fallback
/// so Hindi/Devanagari text (UI strings in Hindi, or Devanagari drug names from a
/// receipt) renders instead of tofu boxes — Geist has no Devanagari glyphs.
///
/// Every TextStyle in the app uses both: `fontFamily: AppFonts.family` +
/// `fontFamilyFallback: AppFonts.fallback`. The shadcn component text theme gets
/// the same fallback via `.apply(fontFamilyFallback: AppFonts.fallback)`.
class AppFonts {
  static const String family = 'Geist';
  static const List<String> fallback = ['NotoSansDevanagari'];
}
