import 'dart:async';

import 'package:flutter/material.dart';
import 'package:times_up_flutter/services/background_service_manager.dart';
import 'package:times_up_flutter/widgets/show_logger.dart';

class JHAppLifecycleObserver extends StatefulWidget {
  const JHAppLifecycleObserver({required this.child, Key? key})
      : super(key: key);
  final Widget child;

  @override
  // ignore: library_private_types_in_public_api
  _JHAppLifecycleObserverState createState() => _JHAppLifecycleObserverState();
}

class _JHAppLifecycleObserverState extends State<JHAppLifecycleObserver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // ponytail: defer FGS/notifications until after first frame — main was blocking runApp
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(BackgroundServiceManager.initializeAppServices());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.resumed:
        JHLogger.$.d('${state.name} - result: ');
        await BackgroundServiceManager.instance.startIfChildDevice();
        break;
      case AppLifecycleState.inactive:
        JHLogger.$.e('${state.name} - result: ');

        break;
      case AppLifecycleState.paused:
        JHLogger.$.e('${state.name} - result:');

        break;
      case AppLifecycleState.detached:
        JHLogger.$.e('${state.name} - result: ');

        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
