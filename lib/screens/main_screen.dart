import 'package:flutter/material.dart';
import '../services/agent_chat_service.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';
import 'goals_screen.dart';
import 'forecast_screen.dart';
import 'analytics_screen.dart';
import 'investments_screen.dart';
import 'ai_coach_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    GoalsScreen(),
    ForecastScreen(),
    AnalyticsScreen(),
    InvestmentsScreen(),
    AiCoachScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // A free-tier backend sleeps when idle and takes ~1 minute to wake: start waking it now, quietly,
    // so it is usually ready by the time the user opens the Coach. Cheap no-op while it is awake.
    AgentWakeUp.ensureAwake();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          for (var i = 0; i < _screens.length; i++) _TabEntrance(active: i == _currentIndex, child: _screens[i]),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: context.border))),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            AgentWakeUp.ensureAwake(); // no-op while awake; re-wakes it if it slept while the app stayed open
            setState(() => _currentIndex = index);
          },
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.flag_outlined), activeIcon: Icon(Icons.flag), label: 'Goals'),
            BottomNavigationBarItem(icon: Icon(Icons.timeline_outlined), activeIcon: Icon(Icons.timeline), label: 'Forecast'),
            BottomNavigationBarItem(icon: Icon(Icons.pie_chart_outline), activeIcon: Icon(Icons.pie_chart), label: 'Analytics'),
            BottomNavigationBarItem(icon: Icon(Icons.candlestick_chart_outlined), activeIcon: Icon(Icons.candlestick_chart), label: 'Invest'),
            BottomNavigationBarItem(icon: Icon(Icons.auto_awesome_outlined), activeIcon: Icon(Icons.auto_awesome), label: 'Coach'),
          ],
        ),
      ),
    );
  }
}

/// Replays a rise-from-the-bottom entrance every time its tab becomes the
/// visible one. State of the tab itself is kept (it stays in the IndexedStack).
class _TabEntrance extends StatefulWidget {
  const _TabEntrance({required this.active, required this.child});
  final bool active;
  final Widget child;

  @override
  State<_TabEntrance> createState() => _TabEntranceState();
}

class _TabEntranceState extends State<_TabEntrance> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 520), value: 1);

  late final Animation<Offset> _slide =
      Tween(begin: const Offset(0, 0.07), end: Offset.zero).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
  late final Animation<double> _fade = CurvedAnimation(parent: _c, curve: const Interval(0, 0.7, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    if (widget.active) _c.forward(from: 0);
  }

  @override
  void didUpdateWidget(_TabEntrance old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _fade, child: SlideTransition(position: _slide, child: widget.child));
  }
}
