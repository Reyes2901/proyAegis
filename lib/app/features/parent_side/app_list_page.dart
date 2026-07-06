import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:times_up_flutter/app/features/parent_side/time_limit_page.dart';
import 'package:times_up_flutter/app/helpers/parsing_extension.dart';
import 'package:times_up_flutter/models/blocked_app_model.dart';
import 'package:times_up_flutter/models/child_model/child_model.dart';
import 'package:times_up_flutter/models/time_rule_model.dart';
import 'package:times_up_flutter/services/api_path.dart';
import 'package:times_up_flutter/services/database.dart';

class AppListPage extends StatelessWidget {
  const AppListPage({
    required this.childModel,
    required this.database,
    super.key,
  });

  final ChildModel childModel;
  final Database database;

  static Future<void> show(
    BuildContext context,
    ChildModel model,
  ) async {
    final database = Provider.of<Database>(context, listen: false);
    await Navigator.of(context).push(
      PageRouteBuilder<Widget>(
        pageBuilder: (context, animation, secondaryAnimation) {
          return AppListPage(childModel: model, database: database);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1, 0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          final tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          final offsetAnimation = animation.drive(tween);
          return SlideTransition(
            position: offsetAnimation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Installed apps'),
        elevation: 0,
        backgroundColor: themeData.scaffoldBackgroundColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.timer_outlined),
            tooltip: 'Daily screen time limit',
            onPressed: () => TimeLimitPage.show(
              context,
              childModel: childModel,
              packageName: APIPath.totalTimeRuleId,
              appName: 'Total screen time',
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<BlockedApp>>(
        stream: database.getBlockedAppsStream(childModel.id),
        builder: (context, blockedSnap) {
          final blockedApps = blockedSnap.data ?? const <BlockedApp>[];
          final blockedPackages = {
            for (final app in blockedApps)
              if (app.blocked && app.packageName.isNotEmpty) app.packageName,
          };

          return StreamBuilder<List<TimeRule>>(
            stream: database.getTimeRulesStream(childModel.id),
            builder: (context, rulesSnap) {
              final timeRules = rulesSnap.data ?? const <TimeRule>[];
              final limits = {
                for (final r in timeRules)
                  if (r.isEnabled) r.packageName: r.dailyLimitMinutes,
              };

              return ListView.builder(
                physics: const BouncingScrollPhysics(
                  decelerationRate: ScrollDecelerationRate.fast,
                ),
                itemCount: childModel.appsUsageModel.length,
                itemBuilder: (context, index) {
                  final app = childModel.appsUsageModel[index];
                  final packageName = app.packageName;
                  if (packageName.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  final isBlocked = blockedPackages.contains(packageName);
                  final limit = limits[packageName];

                  return Opacity(
                    opacity: isBlocked ? 0.45 : 1,
                    child: ListTile(
                      onTap: () => TimeLimitPage.show(
                        context,
                        childModel: childModel,
                        packageName: packageName,
                        appName: app.appName,
                        appIcon: app.appIcon,
                      ),
                      leading: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          if (app.appIcon != null)
                            Image.memory(app.appIcon!, height: 35)
                          else
                            const Icon(Icons.android),
                          if (isBlocked)
                            const Positioned(
                              right: -4,
                              bottom: -4,
                              child: Icon(
                                Icons.lock,
                                size: 14,
                                color: Colors.red,
                              ),
                            ),
                        ],
                      ),
                      title: Text(
                        app.appName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: themeData.dividerColor,
                        ),
                      ),
                      subtitle: Text(
                        isBlocked
                            ? 'Blocked'
                            : limit != null
                                ? 'Limit: $limit min/day'
                                : 'Tap to set time limit',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            app.usage.toString().t(),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: themeData.dividerColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Switch(
                            value: isBlocked,
                            onChanged: (value) => database.setBlockedApp(
                              childModel.id,
                              packageName,
                              value,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
