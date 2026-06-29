// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get welcome => 'Bienvenue';

  @override
  String get hello => 'Salut 👋';

  @override
  String get changeTheSettingsHere => 'Modifier les paramètres ici';

  @override
  String get addNewChildHere => 'Ajoute un enfant ici';

  @override
  String get operationFailed => 'Operation failed';

  @override
  String get enterThisCode => 'Enter this code on the child\'s device';

  @override
  String get longPressToCopyOrDoubleTapToShare =>
      'Long press to copy or double tap to share';

  @override
  String get enterThisCodeOnChildDevice =>
      'Enter this code on child\'s device: ';

  @override
  String get sendNotificationToYourChildDevice =>
      'Send notifications to your Child\'s device';

  @override
  String get copyText => 'Code copié !';
}
