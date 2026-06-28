import 'package:flutter/widgets.dart';

/// Tiny in-app localisation: English + Hindi (Devanagari). Access via
/// `context.s` (see [LangX]); switch by rebuilding [Lang] with a new `hi` flag
/// (held in the app shell, like the theme mode). Devanagari renders thanks to
/// the font fallback (theme/fonts.dart).
///
/// SCOPE: UI chrome only. Catalogue data (drug names, salts, pharmacy names) and
/// the backend's safety label/message come through as-is — translating those is a
/// later backend-i18n task.
class S {
  const S(this.hi);

  /// true = Hindi, false = English.
  final bool hi;

  String _(String en, String hin) => hi ? hin : en;

  // Capture
  String get appTitle => _('Brand → Generic', 'ब्रांड → जेनेरिक');
  String get captureHeadline =>
      _('Scan a pharmacy receipt', 'दवा की रसीद स्कैन करें');
  String get captureSubtitle => _(
        'See cheaper generics, official Jan Aushadhi prices, and prescription-safety flags.',
        'सस्ते जेनेरिक, आधिकारिक जन औषधि कीमतें और पर्ची-सुरक्षा चेतावनियाँ देखें।',
      );
  String get scanReceipt => _('Scan receipt', 'रसीद स्कैन करें');
  String get chooseFromGallery => _('Choose from gallery', 'गैलरी से चुनें');
  String get privacyShort => _(
        'Your photo is read on your device and never uploaded — only the text is used.',
        'आपकी फ़ोटो आपके डिवाइस पर ही पढ़ी जाती है और कभी अपलोड नहीं होती — केवल टेक्स्ट इस्तेमाल होता है।',
      );
  String get viewSample => _('View sample results', 'नमूना परिणाम देखें');
  String cameraError(Object e) =>
      _('Could not open camera/gallery: $e', 'कैमरा/गैलरी नहीं खुल सका: $e');

  // Analyzing
  String get analyzing => _('Analyzing', 'विश्लेषण हो रहा है');
  String get reading => _('Reading your receipt…', 'आपकी रसीद पढ़ी जा रही है…');
  String get matching =>
      _('Finding cheaper generics…', 'सस्ते जेनेरिक खोजे जा रहे हैं…');
  String get onDeviceNote => _(
        'The photo is read on your device and never uploaded.',
        'फ़ोटो आपके डिवाइस पर पढ़ी जाती है और कभी अपलोड नहीं होती।',
      );
  String get couldntFinish => _("Couldn't finish", 'पूरा नहीं हो सका');
  String get tryAnotherPhoto => _('Try another photo', 'दूसरी फ़ोटो आज़माएँ');
  String get showRecognizedText =>
      _('Show recognized text', 'पहचाना गया टेक्स्ट दिखाएँ');
  String get noTextFound => _('No text found', 'कोई टेक्स्ट नहीं मिला');
  String get noTextHint => _(
        'Try a clearer, well-lit photo of the itemised section.',
        'मदों वाले हिस्से की साफ़, अच्छी रोशनी वाली फ़ोटो लें।',
      );
  String linesReadOnDevice(int n, int ms) => _(
        'Read $n lines on-device · $ms ms',
        'डिवाइस पर $n पंक्तियाँ पढ़ीं · $ms ms',
      );
  String get connectServiceHint => _(
        'Read on-device. Connect the price service to match these to cheaper generics + safety flags.',
        'डिवाइस पर पढ़ा गया। सस्ते जेनेरिक और सुरक्षा चेतावनियों से मिलान के लिए प्राइस सर्विस जोड़ें।',
      );

  // Vendors (shown in the results subtitle)
  String get vendorYourReceipt => _('your receipt', 'आपकी रसीद');
  String get vendorSample => _('sample', 'नमूना');

  // Results
  String get scanResults => _('Scan results', 'स्कैन परिणाम');
  String get sampleResults => _('Sample results', 'नमूना परिणाम');
  String medicinesCount(int n) => _('$n medicines', '$n दवाइयाँ');
  String get yourMedicines => _('Your medicines', 'आपकी दवाइयाँ');
  String get safety => _('Safety', 'सुरक्षा');
  String get youCouldSave => _('you could save', 'आप बचा सकते हैं');
  String savingsAcross(int found, int total, int rxFlagged) {
    final base = _('across $found of $total medicines',
        '$total में से $found दवाइयों पर');
    if (rxFlagged <= 0) return base;
    return base +
        _(' · $rxFlagged need a prescription', ' · $rxFlagged को पर्ची चाहिए');
  }

  String get findNearby => _('Find nearby pharmacies', 'पास की फ़ार्मेसी खोजें');
  String get scanAnother => _('Scan another', 'दूसरी स्कैन करें');
  String get rxOnly => _('Rx only', 'पर्ची ज़रूरी');
  String get scheduleX => _('Schedule X', 'शेड्यूल X');
  String savePct(int pct) => _('save $pct%', '$pct% बचत');
  String couldntMatch(int n) => _(
        "Couldn't match $n ${n == 1 ? 'line' : 'lines'}",
        '$n ${n == 1 ? 'पंक्ति' : 'पंक्तियाँ'} मेल नहीं खाईं',
      );
  String get couldntMatchHint => _(
        'Receipt header/details or items not in the catalogue — check manually.',
        'रसीद का शीर्ष/विवरण या कैटलॉग में न मौजूद मदें — स्वयं जाँचें।',
      );
  String get couldntIdentify => _(
        "Couldn't identify — check the label manually",
        'पहचान नहीं हो सकी — लेबल स्वयं जाँचें',
      );

  // Item detail
  String get whatYourePaying => _("What you're paying", 'आप क्या चुका रहे हैं');
  String mrpPack(String mrp, String pack) =>
      pack.isEmpty ? _('MRP $mrp', 'एमआरपी $mrp') : _('MRP $mrp · $pack', 'एमआरपी $mrp · $pack');
  String switchingSaves(String amount, int qty) => _(
        'Switching could save $amount on $qty unit${qty == 1 ? '' : 's'}',
        'बदलने पर $qty यूनिट पर $amount बच सकते हैं',
      );
  String cheaperAlternatives(int n) =>
      _('Cheaper alternatives ($n)', 'सस्ते विकल्प ($n)');
  String get cheaperAlternativesPlain =>
      _('Cheaper alternatives', 'सस्ते विकल्प');
  String get noCheaper =>
      _('No cheaper equivalent found in the catalogue.',
          'कैटलॉग में कोई सस्ता समकक्ष नहीं मिला।');
  String showingCheapest(int shown, int total) => _(
        'Showing the $shown cheapest of $total',
        '$total में से सबसे सस्ते $shown दिखाए जा रहे हैं',
      );
  String get whereToBuy => _('Where to buy', 'कहाँ से खरीदें');
  String get generic => _('Generic', 'जेनेरिक');
  String perUnit(String price) => _('$price/unit', '$price/यूनिट');
  String savingsLine(String altPrice, String basePrice, String lineSaving, int qty) =>
      _(
        '$altPrice/unit vs $basePrice · save $lineSaving on $qty',
        '$altPrice/यूनिट बनाम $basePrice · $qty पर $lineSaving बचत',
      );

  // Safety / disclaimer
  String get janAushadhi => _('Jan Aushadhi', 'जन औषधि');
  String get iHavePrescription =>
      _('I have a prescription  →', 'मेरे पास पर्ची है  →');
  String get disclaimer => _(
        'Not medical advice. Prices are estimates from public catalogues — confirm with '
            'your pharmacist. Substituting a generic is a decision for you and your doctor.',
        'चिकित्सकीय सलाह नहीं। कीमतें सार्वजनिक कैटलॉग से अनुमानित हैं — अपने फ़ार्मासिस्ट से '
            'पुष्टि करें। जेनेरिक अपनाना आपका और आपके डॉक्टर का निर्णय है।',
      );

  // Nearby
  String get nearbyPharmacies => _('Nearby pharmacies', 'पास की फ़ार्मेसी');
  String foundCount(int n) => _('$n found', '$n मिलीं');
  String nearLabel(String label, int n) =>
      _('Near $label · $n found', '$label के पास · $n मिलीं');
  String janAushadhiCount(int n) =>
      _(' · $n Jan Aushadhi', ' · $n जन औषधि');
  String get list => _('List', 'सूची');
  String get map => _('Map', 'नक्शा');
  String get search => _('Search', 'खोजें');
  String get searchHint =>
      _('Search an address or area', 'पता या क्षेत्र खोजें');
  String get addressNotFound => _(
        "Couldn't find that address. Try adding a city or postcode.",
        'वह पता नहीं मिला। शहर या पिनकोड जोड़कर देखें।',
      );
  String get somethingWrong =>
      _('Something went wrong. Try again.', 'कुछ गड़बड़ हुई। फिर कोशिश करें।');
  String get noPharmaciesNear =>
      _('No pharmacies found near there.', 'वहाँ पास कोई फ़ार्मेसी नहीं मिली।');
  String get tryWiderArea =>
      _('Try a nearby landmark or a wider area.', 'कोई पास का स्थल या बड़ा क्षेत्र आज़माएँ।');
  String get searchToFind => _(
        'Search an address to find pharmacies nearby.',
        'पास की फ़ार्मेसी खोजने के लिए कोई पता खोजें।',
      );
  String get searchingAddr => _('Searching…', 'खोज रहे हैं…');
  String get noMatches => _('No matching places found', 'कोई स्थान नहीं मिला');
  String seeAll(int n) => _('See all $n', 'सभी $n देखें');
  String kmAway(String km) => _('$km km away', '$km कि.मी. दूर');
  String km(String v) => _('$v km', '$v कि.मी.');
  String get openInMaps => _('Open in Maps', 'मैप्स में खोलें');

  // Settings
  String get settings => _('Settings', 'सेटिंग्स');
  String get appearance => _('Appearance', 'रूप-रंग');
  String get theme => _('Theme', 'थीम');
  String get themeSubtitle => _(
        'Light, dark, or follow the system',
        'हल्का, गहरा, या सिस्टम के अनुसार',
      );
  String get language => _('Language', 'भाषा');
  String get location => _('Location', 'स्थान');
  String get locationNotSet =>
      _('Not set — tap to choose', 'सेट नहीं — चुनने के लिए टैप करें');
  String get setLocation => _('Set your location', 'अपना स्थान सेट करें');
  String get clear => _('Clear', 'हटाएँ');
  String get locationSettingHint => _(
        'Saved on this device and used to find nearby pharmacies when location is off.',
        'इस डिवाइस पर सहेजा जाता है और स्थान बंद होने पर पास की फ़ार्मेसी खोजने में उपयोग होता है।',
      );
  String get privacy => _('Privacy', 'गोपनीयता');
  String get privacyLong => _(
        'Your receipt photo is read on your device and never uploaded. Only the '
            'extracted text is sent — over a signed, encrypted connection — to look up '
            'prices. Location, if you allow it, is used only to rank nearby pharmacies '
            'and is never stored.',
        'आपकी रसीद की फ़ोटो आपके डिवाइस पर ही पढ़ी जाती है और कभी अपलोड नहीं होती। केवल '
            'निकाला गया टेक्स्ट — एक हस्ताक्षरित, एन्क्रिप्टेड कनेक्शन पर — कीमत देखने के लिए '
            'भेजा जाता है। अनुमति देने पर स्थान का उपयोग केवल पास की फ़ार्मेसी क्रमबद्ध करने '
            'के लिए होता है और कभी संग्रहीत नहीं होता।',
      );
  String get about => _('About', 'परिचय');
  String get version => _('Version 0.1.0 (dev)', 'संस्करण 0.1.0 (dev)');
  String get aboutBody => _(
        'Generic equivalents and prescription-safety flags for Indian pharmacy '
            'receipts. Prices from the open Indian Medicine Dataset and official Jan '
            'Aushadhi catalogue; pharmacies from OpenStreetMap.',
        'भारतीय दवा रसीदों के लिए जेनेरिक समकक्ष और पर्ची-सुरक्षा चेतावनियाँ। कीमतें ओपन '
            'इंडियन मेडिसिन डेटासेट और आधिकारिक जन औषधि कैटलॉग से; फ़ार्मेसी OpenStreetMap से।',
      );
}

/// Inherited language flag. Rebuild with a new `hi` to switch the whole UI.
class Lang extends InheritedWidget {
  const Lang({super.key, required this.hi, required super.child});

  final bool hi;

  S get strings => S(hi);

  static Lang of(BuildContext context) {
    final w = context.dependOnInheritedWidgetOfExactType<Lang>();
    assert(w != null, 'No Lang in context — wrap the app in a Lang widget.');
    return w!;
  }

  @override
  bool updateShouldNotify(Lang oldWidget) => oldWidget.hi != hi;
}

extension LangX on BuildContext {
  /// The active strings. Use as `context.s.scanReceipt`.
  S get s => Lang.of(this).strings;

  /// The live language flag. Reads from [Lang] (above the Navigator), so it stays
  /// correct after a switch even inside an already-pushed route.
  bool get isHindi => Lang.of(this).hi;
}
