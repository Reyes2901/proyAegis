// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get welcome => 'Welcome';

  @override
  String get hello => 'Hello 👋';

  @override
  String get changeTheSettingsHere => 'change the settings here';

  @override
  String get addNewChildHere => 'Add a new child here ';

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
