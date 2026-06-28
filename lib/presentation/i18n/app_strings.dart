import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:siddur_am_israel_chai/presentation/i18n/app_locale.dart';
import 'package:siddur_am_israel_chai/presentation/providers/prayer_providers.dart';

/// Framework-UI string table, keyed by string id then by language code.
///
/// Scope: tab labels, screen titles, settings labels, menu tiles. The prayer
/// texts themselves are NEVER translated here — they live in the JSON assets
/// and are always Hebrew. Hebrew liturgical proper nouns (Shacharit, Birkat
/// HaMazon, …) are transliterated in the non-Hebrew columns.
const Map<String, Map<String, String>> _table = {
  // ── Bottom navigation ──────────────────────────────────────────────────
  'tab_prayers': {
    'he': 'תפילות',
    'en': 'Prayers',
    'ru': 'Молитвы',
    'fr': 'Prières',
  },
  'tab_berachot': {
    'he': 'ברכות',
    'en': 'Blessings',
    'ru': 'Благословения',
    'fr': 'Bénédictions',
  },
  'tab_settings': {
    'he': 'הגדרות',
    'en': 'Settings',
    'ru': 'Настройки',
    'fr': 'Réglages',
  },
  'tab_calendar': {
    'he': 'לוח',
    'en': 'Calendar',
    'ru': 'Календарь',
    'fr': 'Calendrier',
  },
  // ── Calendar location (zmanim) ──────────────────────────────────────────
  'section_zmanim_location': {
    'he': 'מיקום לזמנים',
    'en': 'Location for times',
    'ru': 'Местоположение для времён',
    'fr': 'Lieu pour les horaires',
  },
  'use_gps': {
    'he': 'מיקום נוכחי (GPS)',
    'en': 'Current location (GPS)',
    'ru': 'Текущее местоположение (GPS)',
    'fr': 'Position actuelle (GPS)',
  },
  'use_gps_sub': {
    'he': 'זמנים מדויקים לפי מיקומך · דורש הרשאה',
    'en': 'Accurate times for your location · needs permission',
    'ru': 'Точное время по местоположению · нужно разрешение',
    'fr': 'Horaires précis selon votre position · autorisation requise',
  },
  'city_for_times': {
    'he': 'עיר לזמני היום',
    'en': 'City for times',
    'ru': 'Город для времён',
    'fr': 'Ville pour les horaires',
  },
  'choose_city': {
    'he': 'בחר עיר',
    'en': 'Choose a city',
    'ru': 'Выберите город',
    'fr': 'Choisir une ville',
  },
  // ── Prayer list ────────────────────────────────────────────────────────
  'shacharit': {
    'he': 'שחרית',
    'en': 'Shacharit',
    'ru': 'Шахарит',
    'fr': "Cha'harit",
  },
  'mincha': {
    'he': 'מנחה',
    'en': 'Mincha',
    'ru': 'Минха',
    'fr': "Min'ha",
  },
  'maariv': {
    'he': 'ערבית',
    'en': 'Maariv',
    'ru': 'Маарив',
    'fr': 'Arvit',
  },
  'now_badge': {
    'he': 'עכשיו',
    'en': 'Now',
    'ru': 'Сейчас',
    'fr': 'Maintenant',
  },
  'jump_to_section': {
    'he': 'קפיצה לקטע',
    'en': 'Jump to section',
    'ru': 'Перейти к разделу',
    'fr': 'Aller à la section',
  },
  // {nusach} is replaced at runtime with the localized rite name.
  'banner_nusach_notice': {
    'he': 'התפילה מוצגת בנוסח {nusach}. ניתן לשנות בהגדרות.',
    'en': 'The prayer is shown in the {nusach} rite. You can change this in Settings.',
    'ru': 'Молитва показана в нусахе {nusach}. Изменить можно в настройках.',
    'fr': 'La prière est affichée selon le rite {nusach}. Modifiable dans les réglages.',
  },
  'open_settings': {
    'he': 'פתח הגדרות',
    'en': 'Open settings',
    'ru': 'Открыть настройки',
    'fr': 'Ouvrir les réglages',
  },
  'close': {
    'he': 'סגור',
    'en': 'Close',
    'ru': 'Закрыть',
    'fr': 'Fermer',
  },
  // ── Berachot list ──────────────────────────────────────────────────────
  'birkat_hamazon': {
    'he': 'ברכת המזון',
    'en': 'Birkat HaMazon',
    'ru': 'Биркат а-Мазон',
    'fr': 'Birkat HaMazon',
  },
  'birkat_hamazon_sub': {
    'he': 'לאחר סעודת לחם',
    'en': 'After a bread meal',
    'ru': 'После трапезы с хлебом',
    'fr': 'Après un repas avec du pain',
  },
  'meein_shalosh': {
    'he': 'ברכה מעין שלוש',
    'en': "Me'ein Shalosh",
    'ru': 'Меэйн Шалош',
    'fr': 'Méein Chaloch',
  },
  'meein_shalosh_sub': {
    'he': 'לאחר מזונות, יין ופירות',
    'en': 'After grains, wine & fruit',
    'ru': 'После злаков, вина и фруктов',
    'fr': 'Après céréales, vin et fruits',
  },
  'tefilat_haderech': {
    'he': 'תפילת הדרך',
    'en': "Traveler's Prayer",
    'ru': 'Дорожная молитва',
    'fr': 'Prière du voyageur',
  },
  'tefilat_haderech_sub': {
    'he': 'לפני יציאה לדרך',
    'en': 'Before setting out',
    'ru': 'Перед дорогой',
    'fr': 'Avant de prendre la route',
  },
  'kiddush_levana': {
    'he': 'קידוש לבנה',
    'en': 'Kiddush Levana',
    'ru': 'Кидуш Левана',
    'fr': 'Kiddouch Levana',
  },
  'coming_soon': {
    'he': 'בקרוב',
    'en': 'Coming soon',
    'ru': 'Скоро',
    'fr': 'Bientôt',
  },
  // ── Settings: sections & options ───────────────────────────────────────
  'section_nusach': {
    'he': 'נוסח התפילה',
    'en': 'Prayer rite',
    'ru': 'Нусах молитвы',
    'fr': 'Rite de prière',
  },
  'nusach_ashkenaz': {
    'he': 'אשכנז',
    'en': 'Ashkenaz',
    'ru': 'Ашкеназ',
    'fr': 'Achkénaze',
  },
  'nusach_sfard': {
    'he': 'ספרד',
    'en': 'Sfard',
    'ru': 'Сфард',
    'fr': 'Sfarad',
  },
  'nusach_edot_mizrach': {
    'he': 'עדות המזרח',
    'en': 'Edot HaMizrach',
    'ru': 'Эдот а-Мизрах',
    'fr': 'Edot HaMizrah',
  },
  'section_davener': {
    'he': 'מתפלל/ת',
    'en': 'Worshipper',
    'ru': 'Молящийся',
    'fr': 'Fidèle',
  },
  'i_am_woman': {
    'he': 'אני אשה',
    'en': 'I am a woman',
    'ru': 'Я женщина',
    'fr': 'Je suis une femme',
  },
  'section_location': {
    'he': 'מיקום',
    'en': 'Location',
    'ru': 'Местоположение',
    'fr': 'Lieu',
  },
  'in_israel': {
    'he': 'אני בארץ ישראל',
    'en': 'I am in the Land of Israel',
    'ru': 'Я в Земле Израиля',
    'fr': "Je suis en Terre d'Israël",
  },
  'section_prayer': {
    'he': 'תפילה',
    'en': 'Prayer',
    'ru': 'Молитва',
    'fr': 'Prière',
  },
  'with_minyan': {
    'he': 'מתפלל במניין',
    'en': 'Praying with a minyan',
    'ru': 'Молюсь с миньяном',
    'fr': 'Je prie avec un minyan',
  },
  'section_purim': {
    'he': 'פורים',
    'en': 'Purim',
    'ru': 'Пурим',
    'fr': 'Pourim',
  },
  'purim_14': {
    'he': 'י״ד אדר (פרזים)',
    'en': '14 Adar (unwalled cities)',
    'ru': '14 Адара (города без стен)',
    'fr': '14 Adar (villes ouvertes)',
  },
  'purim_15': {
    'he': 'ט״ו אדר (מוקפין — ירושלים)',
    'en': '15 Adar (walled cities — Jerusalem)',
    'ru': '15 Адара (города со стеной — Иерусалим)',
    'fr': '15 Adar (villes fortifiées — Jérusalem)',
  },
  'purim_both': {
    'he': 'שני הימים (מסופק)',
    'en': 'Both days (doubtful)',
    'ru': 'Оба дня (сомнение)',
    'fr': 'Les deux jours (doute)',
  },
  'section_display': {
    'he': 'תצוגה',
    'en': 'Display',
    'ru': 'Отображение',
    'fr': 'Affichage',
  },
  'show_labels': {
    'he': 'הצגת כותרות קטעים',
    'en': 'Show section labels',
    'ru': 'Показывать заголовки разделов',
    'fr': 'Afficher les titres de sections',
  },
  'section_font': {
    'he': 'גודל גופן',
    'en': 'Font size',
    'ru': 'Размер шрифта',
    'fr': 'Taille de police',
  },
  'section_language': {
    'he': 'שפת הממשק',
    'en': 'Interface language',
    'ru': 'Язык интерфейса',
    'fr': "Langue de l'interface",
  },
  'section_contact': {
    'he': 'יצירת קשר',
    'en': 'Contact',
    'ru': 'Связаться',
    'fr': 'Contact',
  },
  'send_support_email': {
    'he': 'שלח מייל לתמיכה',
    'en': 'Email support',
    'ru': 'Написать в поддержку',
    'fr': 'Contacter le support',
  },
  'support': {
    'he': 'לתמיכה',
    'en': 'Support',
    'ru': 'Поддержка',
    'fr': 'Support',
  },
  // ── Compass (prayer direction toward Har HaBayit) ───────────────────────
  'compass_title': {
    'he': 'כיוון התפילה',
    'en': 'Prayer direction',
    'ru': 'Направление молитвы',
    'fr': 'Direction de la prière',
  },
  'compass_tooltip': {
    'he': 'כיוון התפילה',
    'en': 'Prayer direction',
    'ru': 'Направление молитвы',
    'fr': 'Direction de la prière',
  },
  'compass_facing': {
    'he': 'אתה פונה להר הבית',
    'en': "You're facing the Temple Mount",
    'ru': 'Вы обращены к Храмовой горе',
    'fr': 'Vous êtes face au mont du Temple',
  },
  'compass_instruction': {
    'he': 'החזק את המכשיר במאוזן וסובב עד שהחץ פונה כלפי מעלה',
    'en': 'Hold the device flat and turn until the arrow points up',
    'ru': 'Держите устройство горизонтально и поворачивайте, пока стрелка не укажет вверх',
    'fr': "Tenez l'appareil à plat et tournez jusqu'à ce que la flèche pointe vers le haut",
  },
  'compass_no_sensor': {
    'he': 'אין חיישן מצפן במכשיר זה',
    'en': 'This device has no compass sensor',
    'ru': 'На этом устройстве нет датчика компаса',
    'fr': "Cet appareil n'a pas de boussole",
  },
  'compass_note_gps': {
    'he': 'הכיוון מחושב לפי מיקומך הנוכחי',
    'en': 'Direction based on your current location',
    'ru': 'Направление по вашему текущему местоположению',
    'fr': 'Direction selon votre position actuelle',
  },
  'compass_note_city': {
    'he': 'מיקום מדויק לא זמין · הכיוון לפי {city}',
    'en': 'Precise location unavailable · direction for {city}',
    'ru': 'Точное местоположение недоступно · направление для {city}',
    'fr': 'Position précise indisponible · direction pour {city}',
  },
};

/// Resolves framework-UI strings for the active interface language.
/// Falls back to Hebrew, then to the raw key, so a missing translation can
/// never crash or render blank.
class AppStrings {
  const AppStrings(this.language);

  final AppLanguage language;

  String t(String key) {
    final entry = _table[key];
    if (entry == null) return key;
    return entry[language.code] ?? entry['he'] ?? key;
  }
}

/// Current interface language, derived from the persisted [appLanguageProvider].
final appLanguageEnumProvider = Provider<AppLanguage>(
  (ref) => AppLanguage.fromCode(ref.watch(appLanguageProvider)),
);

/// Framework-UI string resolver bound to the active language.
final appStringsProvider = Provider<AppStrings>(
  (ref) => AppStrings(ref.watch(appLanguageEnumProvider)),
);
