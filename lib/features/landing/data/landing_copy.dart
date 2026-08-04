/// All user-facing text on the welcome page, in English and Tagalog.
///
/// Scoped to the landing page only — this is not app-wide localization
/// (the rest of SBS stays English), just the one page that has to speak to
/// a resident before they have ever touched the product. A single object
/// per language keeps every section's copy in one place instead of
/// scattering `isTagalog ? ... : ...` ternaries through the widget tree.
class LandingCopy {
  const LandingCopy({
    required this.langLabel,
    required this.navAbout,
    required this.navFeatures,
    required this.navSteps,
    required this.navDownload,
    required this.navSignIn,
    required this.navRegister,
    required this.heroBadge,
    required this.heroHeadline,
    required this.heroSubtext,
    required this.heroCtaPrimary,
    required this.heroCtaSecondary,
    required this.heroFootnote,
    required this.mockGreeting,
    required this.mockWelcome,
    required this.mockSearch,
    required this.mockAvailable,
    required this.mockItems,
    required this.aboutEyebrow,
    required this.aboutHeading,
    required this.aboutBody,
    required this.aboutPoints,
    required this.featuresEyebrow,
    required this.featuresHeading,
    required this.features,
    required this.stepsEyebrow,
    required this.stepsHeading,
    required this.steps,
    required this.downloadEyebrow,
    required this.downloadHeading,
    required this.downloadBody,
    required this.downloadButtonLabel,
    required this.downloadErrorText,
    required this.downloadFallbackVersion,
    required this.downloadVersionPrefix,
    required this.footerTagline,
    required this.footerGetStarted,
    required this.footerOffice,
    required this.footerOfficeLines,
    required this.footerCopyright,
  });

  /// Shown on the toggle itself — "EN" / "FIL", not a translated word.
  final String langLabel;

  final String navAbout;
  final String navFeatures;
  final String navSteps;
  final String navDownload;
  final String navSignIn;
  final String navRegister;

  final String heroBadge;
  final String heroHeadline;
  final String heroSubtext;
  final String heroCtaPrimary;
  final String heroCtaSecondary;
  final String heroFootnote;

  final String mockGreeting;
  final String mockWelcome;
  final String mockSearch;
  final String mockAvailable;

  /// (label, category) pairs for the three preview rows in the phone mock.
  final List<(String, String)> mockItems;

  final String aboutEyebrow;
  final String aboutHeading;
  final String aboutBody;

  /// (title, body) — icons are fixed, defined alongside the section.
  final List<(String, String)> aboutPoints;

  final String featuresEyebrow;
  final String featuresHeading;

  /// (title, body) — icons are fixed, defined alongside the section.
  final List<(String, String)> features;

  final String stepsEyebrow;
  final String stepsHeading;

  /// (title, body).
  final List<(String, String)> steps;

  final String downloadEyebrow;
  final String downloadHeading;
  final String downloadBody;
  final String downloadButtonLabel;
  final String downloadErrorText;
  final String downloadFallbackVersion;

  /// e.g. "Version " — the release number itself is not translated.
  final String downloadVersionPrefix;

  final String footerTagline;
  final String footerGetStarted;
  final String footerOffice;
  final List<String> footerOfficeLines;

  /// e.g. "© {year} Municipality of Bongabong · All rights reserved" —
  /// call with the current year.
  final String Function(int year) footerCopyright;

  static const en = LandingCopy(
    langLabel: 'EN',
    navAbout: 'About',
    navFeatures: 'Features',
    navSteps: 'How it works',
    navDownload: 'Download',
    navSignIn: 'Sign in',
    navRegister: 'Register',
    heroBadge: 'Municipality of Bongabong',
    heroHeadline: 'Borrow LGU equipment\nwithout the paperwork.',
    heroSubtext:
        'Reserve a venue, book a municipal vehicle, or borrow equipment '
        'for your barangay event — request it from your phone and track '
        'it through to return.',
    heroCtaPrimary: 'Create an account',
    heroCtaSecondary: 'Sign in',
    heroFootnote: 'Free for residents · No email required to sign up',
    mockGreeting: 'Hello, Maria',
    mockWelcome: 'Welcome to SBS',
    mockSearch: 'Search items…',
    mockAvailable: 'Available now',
    mockItems: [
      ('Municipal Gymnasium', 'VENUE'),
      ('Passenger Van', 'VEHICLE'),
      ('Monobloc Chairs', 'EQUIPMENT'),
    ],
    aboutEyebrow: 'About the system',
    aboutHeading: 'Replacing the logbook\nat the LGU counter.',
    aboutBody:
        'The Schedule Borrowing System keeps track of everything the '
        'municipality lends out. Residents request what they need, '
        'staff review it, and the condition of each item is '
        'photographed at handoff and at return — so nothing depends '
        'on remembering who had what.',
    aboutPoints: [
      (
        'One shared catalogue',
        'Venues, vehicles, and equipment from every office in one registry.',
      ),
      (
        'Accountable by default',
        'Every request is reviewed, and every handoff and return is on record.',
      ),
      (
        'Built for residents',
        'No walk-in queue to reserve something — the whole request happens online.',
      ),
    ],
    featuresEyebrow: 'Features',
    featuresHeading: 'Everything the counter did,\nbut faster.',
    features: [
      (
        'Schedule or borrow',
        'Reserve a venue or vehicle for a date, or take equipment with you — '
            'the flow adapts to which one you picked.',
      ),
      (
        'Same-day requests',
        'No minimum lead time. Ask for something you need this afternoon, or '
            'plan an event up to a year out.',
      ),
      (
        'Reviewed before pickup',
        'Requests route to the office that owns the item, so the right staffer '
            'approves it.',
      ),
      (
        'Photo evidence',
        'Condition is captured at handoff and again at return, protecting both '
            'the borrower and the LGU.',
      ),
      (
        'Told the moment it changes',
        'Approvals, upcoming due dates, and overdue items reach you as push '
            'notifications.',
      ),
      (
        'Verified once',
        'Staff check your ID at your first pickup. Every request after that is '
            'already accounted for.',
      ),
    ],
    stepsEyebrow: 'How it works',
    stepsHeading: 'From request to return\nin five steps.',
    steps: [
      (
        'Create your account',
        'Full name, a username, your contact number, and a photo of any valid '
            'government ID. No email needed.',
      ),
      (
        'Find what you need',
        'Browse the catalogue, or pick Schedule for venues and vehicles and '
            'Borrow for equipment.',
      ),
      (
        'Send the request',
        'Choose your dates, the quantity, and when you will pick it up. Submit '
            'and you are in the queue.',
      ),
      (
        'Get approved',
        'The office that owns the item reviews it. You are notified the moment '
            'the decision lands.',
      ),
      (
        'Pick up and return',
        'Staff photograph the item with you at handoff, and again when you '
            'bring it back. That closes the loan.',
      ),
    ],
    downloadEyebrow: 'Get the app',
    downloadHeading: 'Install SBS on your Android phone.',
    downloadBody:
        'The app adds push notifications and camera capture at '
        'handoff. Everything else works here in the browser too.',
    downloadButtonLabel: 'Download the APK',
    downloadErrorText: 'The download link is unavailable right now.',
    downloadFallbackVersion: 'Android 6.0 and up',
    downloadVersionPrefix: 'Version ',
    footerTagline:
        "Schedule Borrowing System — the Municipality of Bongabong's "
        'platform for reserving and borrowing LGU property.',
    footerGetStarted: 'Get started',
    footerOffice: 'Office',
    footerOfficeLines: ['Municipal Hall, Bongabong', 'Oriental Mindoro'],
    footerCopyright: _footerCopyrightEn,
  );

  static const tl = LandingCopy(
    langLabel: 'FIL',
    navAbout: 'Tungkol Dito',
    navFeatures: 'Mga Tampok',
    navSteps: 'Paano Gumagana',
    navDownload: 'I-download',
    navSignIn: 'Mag-sign In',
    navRegister: 'Mag-rehistro',
    heroBadge: 'Bayan ng Bongabong',
    heroHeadline: 'Humiram ng gamit ng LGU\nnang walang papeles.',
    heroSubtext:
        'Mag-reserve ng venue, mag-book ng sasakyan ng bayan, o humiram ng '
        'kagamitan para sa inyong barangay event — mag-request gamit ang '
        'iyong telepono at subaybayan ito hanggang sa pagsauli.',
    heroCtaPrimary: 'Gumawa ng account',
    heroCtaSecondary: 'Mag-sign in',
    heroFootnote: 'Libre para sa mga residente · Hindi kailangan ng email',
    mockGreeting: 'Kumusta, Maria',
    mockWelcome: 'Maligayang pagdating sa SBS',
    mockSearch: 'Maghanap ng item…',
    mockAvailable: 'Available ngayon',
    mockItems: [
      ('Municipal Gymnasium', 'VENUE'),
      ('Passenger Van', 'SASAKYAN'),
      ('Monobloc Chairs', 'KAGAMITAN'),
    ],
    aboutEyebrow: 'Tungkol sa sistema',
    aboutHeading: 'Papalit sa logbook\nsa counter ng LGU.',
    aboutBody:
        'Sinusubaybayan ng Schedule Borrowing System ang lahat ng '
        'pinapahiram ng bayan. Nagre-request ang mga residente ng '
        'kailangan nila, sinusuri ito ng staff, at kinukunan ng larawan '
        'ang kondisyon ng bawat item kapag kinuha at kapag isinauli — '
        'kaya walang kailangang tandaan kung sino ang may hawak ng ano.',
    aboutPoints: [
      (
        'Iisang katalogo',
        'Mga venue, sasakyan, at kagamitan mula sa bawat opisina, nasa iisang talaan.',
      ),
      (
        'May pananagutan bilang default',
        'Sinusuri ang bawat request, at nakarehistro ang bawat pagkuha at pagsauli.',
      ),
      (
        'Ginawa para sa mga residente',
        'Walang pila para mag-reserve — buong request ay online.',
      ),
    ],
    featuresEyebrow: 'Mga Tampok',
    featuresHeading: 'Lahat ng ginawa ng counter,\npero mas mabilis.',
    features: [
      (
        'Mag-schedule o humiram',
        'Mag-reserve ng venue o sasakyan para sa isang petsa, o dalhin ang '
            'kagamitan — umaangkop ang proseso sa napili mo.',
      ),
      (
        'Same-day na request',
        'Walang minimum na araw ng paghihintay. Humiling ng kailangan mo '
            'ngayong hapon, o mag-plano ng event hanggang isang taon.',
      ),
      (
        'Sinusuri bago kunin',
        'Napupunta ang request sa opisinang may-ari ng item, kaya ang '
            'tamang staff ang mag-a-approve.',
      ),
      (
        'May larawan bilang ebidensya',
        'Kinukunan ng larawan ang kondisyon kapag kinuha at kapag isinauli, '
            'para protektado ang parehong nanghiram at ang LGU.',
      ),
      (
        'Alam mo agad kapag may pagbabago',
        'Ang mga approval, paparating na deadline, at overdue na item ay '
            'darating bilang push notification.',
      ),
      (
        'Isang beses lang i-verify',
        'Susuriin ng staff ang iyong ID sa unang pagkuha. Bawat request '
            'pagkatapos noon ay nakatala na.',
      ),
    ],
    stepsEyebrow: 'Paano ito gumagana',
    stepsHeading: 'Mula sa request hanggang sa pagsauli\nsa limang hakbang.',
    steps: [
      (
        'Gumawa ng account',
        'Buong pangalan, username, numero ng telepono, at larawan ng '
            'valid na government ID. Hindi kailangan ng email.',
      ),
      (
        'Hanapin ang kailangan mo',
        'Mag-browse sa katalogo, o piliin ang Schedule para sa venue at '
            'sasakyan, at Borrow para sa kagamitan.',
      ),
      (
        'Ipadala ang request',
        'Piliin ang petsa, dami, at oras ng pagkuha. I-submit at ikaw ay '
            'nasa pila na.',
      ),
      (
        'Ma-approve',
        'Sinusuri ito ng opisinang may-ari ng item. Aabisuhan ka agad '
            'pagdating ng desisyon.',
      ),
      (
        'Kunin at isauli',
        'Kukunan ka ng staff ng larawan kasama ang item kapag kinuha, at '
            'muli kapag isinauli. Doon nagsasara ang paghiram.',
      ),
    ],
    downloadEyebrow: 'Kunin ang app',
    downloadHeading: 'I-install ang SBS sa iyong Android phone.',
    downloadBody:
        'Idinadagdag ng app ang push notification at pagkuha ng larawan '
        'gamit ang camera. Gumagana rin ang lahat dito sa browser.',
    downloadButtonLabel: 'I-download ang APK',
    downloadErrorText: 'Hindi available ang download link sa ngayon.',
    downloadFallbackVersion: 'Android 6.0 pataas',
    downloadVersionPrefix: 'Bersyon ',
    footerTagline:
        'Schedule Borrowing System — ang plataporma ng Bayan ng Bongabong '
        'para sa pag-reserve at paghiram ng ari-arian ng LGU.',
    footerGetStarted: 'Magsimula',
    footerOffice: 'Opisina',
    footerOfficeLines: ['Munisipyo ng Bongabong', 'Oriental Mindoro'],
    footerCopyright: _footerCopyrightTl,
  );

  static String _footerCopyrightEn(int year) =>
      '© $year Municipality of Bongabong · All rights reserved';

  static String _footerCopyrightTl(int year) =>
      '© $year Bayan ng Bongabong · Nakalaan ang lahat ng karapatan';
}
