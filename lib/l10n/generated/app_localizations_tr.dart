// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get welcome => 'Hoş Geldiniz';

  @override
  String get hello => 'Selam 👋';

  @override
  String get changeTheSettingsHere => 'Buradaki ayarları değiştir';

  @override
  String get addNewChildHere => 'Buraya yeni bir çocuk ekleyin';

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
