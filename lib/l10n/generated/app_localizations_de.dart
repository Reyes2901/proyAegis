// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get welcome => 'Wilkommen';

  @override
  String get hello => 'Hallo 👋';

  @override
  String get changeTheSettingsHere => 'Ändern Sie hier die Einstellungen';

  @override
  String get addNewChildHere => 'Fügen Sie hier ein neues Kind hinzu';

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
  String get copyText => 'Code Copied!';
}
