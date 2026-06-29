// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get welcome => 'Bienvenido !';

  @override
  String get hello => 'Hola 👋';

  @override
  String get changeTheSettingsHere => 'Cambiar la configuración aquí';

  @override
  String get addNewChildHere => 'Añadir un nuevo niño[a] aquí';

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
