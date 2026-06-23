// ╔══════════════════════════════════════════════════════════════╗
// ║    CLOTHING MANAGEMENT SYSTEM — UI + BACKEND CONNECTED       ║
// ║    Dono files ek folder mein rakho:  main.dart, backend.dart ║
// ╚══════════════════════════════════════════════════════════════╝

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'backend.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppInitializer.initialize(); // DB + session + auto-sync
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light),
  );
  runApp(const ClothingApp());
}

// ══════════════════════
//  COLORS
// ══════════════════════
class AppColors {
  static const red      = Color(0xFFD32F2F);
  static const redDark  = Color(0xFFB71C1C);
  static const blue     = Color(0xFF1565C0);
  static const bgLight  = Color(0xFFF5F7FA);
  static const textDark = Color(0xFF1A1A2E);
  static const textGrey = Color(0xFF6B7280);
  static const success  = Color(0xFF2E7D32);
  static const warning  = Color(0xFFF57C00);

  static const gradientRB  = LinearGradient(colors: [Color(0xFFD32F2F), Color(0xFF1565C0)], begin: Alignment.topLeft, end: Alignment.bottomRight);
  static const gradientRed = LinearGradient(colors: [Color(0xFFB71C1C), Color(0xFFEF5350)], begin: Alignment.topLeft, end: Alignment.bottomRight);
  static const gradientBlue= LinearGradient(colors: [Color(0xFF0D47A1), Color(0xFF42A5F5)], begin: Alignment.topLeft, end: Alignment.bottomRight);
}

// ══════════════════════
//  APP
// ══════════════════════
class ClothingApp extends StatelessWidget {
  const ClothingApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clothing Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: AppColors.red,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.red, primary: AppColors.red, secondary: AppColors.blue),
        scaffoldBackgroundColor: AppColors.bgLight,
        appBarTheme: const AppBarTheme(elevation: 0, backgroundColor: Colors.transparent, foregroundColor: Colors.white, centerTitle: true,
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.red, foregroundColor: Colors.white, elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
        inputDecorationTheme: InputDecorationTheme(
          filled: true, fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.blue, width: 2)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          labelStyle: const TextStyle(color: AppColors.textGrey)),
        cardTheme: CardThemeData(elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), color: Colors.white),
      ),
      initialRoute: '/',
      routes: {
        '/':                     (c) => const SplashScreen(),
        '/login':                (c) => const LoginScreen(),
        '/admin-home':           (c) => const AdminHomeScreen(),
        '/key-manage':           (c) => const KeyManageScreen(),
        '/inventory-setup':      (c) => const InventorySetupScreen(),
        '/inventory-detail':     (c) => const InventoryDetailScreen(),
        '/total-sell':           (c) => const TotalSellScreen(),
        '/return-inventory':     (c) => const ReturnInventoryScreen(),
        '/worker-home':          (c) => const WorkerHomeScreen(),
        '/worker-scanner':       (c) => const WorkerScannerScreen(),
        '/worker-manual-search': (c) => const WorkerManualSearchScreen(),
        '/worker-sell':          (c) => const WorkerSellScreen(),
        '/worker-history':       (c) => const WorkerHistoryScreen(),
        '/create-account':       (c) => const CreateAccountScreen(),
        '/inventory-alert':      (c) => const InventoryAlertScreen(),
      },
    );
  }
}

// ══════════════════════
//  SHARED HELPERS
// ══════════════════════
class GradientAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title; final List<Widget>? actions; final bool showBack;
  const GradientAppBar({super.key, required this.title, this.actions, this.showBack = true});
  @override Size get preferredSize => const Size.fromHeight(60);
  @override
  Widget build(BuildContext ctx) => Container(
    decoration: const BoxDecoration(gradient: AppColors.gradientRB),
    child: AppBar(backgroundColor: Colors.transparent, title: Text(title),
      leading: showBack ? IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white), onPressed: () => Navigator.pop(ctx)) : null,
      automaticallyImplyLeading: showBack, actions: actions));
}

class SectionTitle extends StatelessWidget {
  final String text; final Widget? trailing;
  const SectionTitle({super.key, required this.text, this.trailing});
  @override
  Widget build(BuildContext ctx) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Row(children: [
      Container(width: 4, height: 20, decoration: BoxDecoration(gradient: AppColors.gradientRB, borderRadius: BorderRadius.circular(4))),
      const SizedBox(width: 10),
      Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
    ]),
    if (trailing != null) trailing!,
  ]);
}

Widget buildLoader() => const Center(child: CircularProgressIndicator(color: AppColors.red));

Widget buildEmpty(String msg, IconData icon) => Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
  Icon(icon, size: 60, color: Colors.grey.shade300), const SizedBox(height: 14),
  Text(msg, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
])));

void showSnack(BuildContext ctx, String msg, {bool isError = false}) =>
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Row(children: [Icon(isError ? Icons.error_outline : Icons.check_circle, color: Colors.white, size: 18), const SizedBox(width: 8), Expanded(child: Text(msg))]),
      backgroundColor: isError ? AppColors.red : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));

Widget chip(String l, Color c) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
  decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
  child: Text(l, style: TextStyle(fontSize: 10, color: c, fontWeight: FontWeight.w600)));

// ══════════════════════
//  SPLASH — session check
// ══════════════════════
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override State<SplashScreen> createState() => _SplashScreenState();
}
class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _s;
  @override void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _s = CurvedAnimation(parent: _c, curve: Curves.elasticOut);
    _c.forward();
    _route();
  }
  Future<void> _route() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    final s = AuthService.instance.currentSession;
    if (s != null) {
      Navigator.pushReplacementNamed(context, s.isAdmin ? '/admin-home' : '/worker-home');
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext ctx) => Scaffold(
    body: Container(decoration: const BoxDecoration(gradient: AppColors.gradientRB),
      child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        ScaleTransition(scale: _s, child: Container(width: 110, height: 110,
          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 30, offset: const Offset(0, 10))]),
          child: const Icon(Icons.checkroom_rounded, size: 60, color: AppColors.red))),
        const SizedBox(height: 28),
        const Text('CLOTHING MANAGER', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 3)),
        const SizedBox(height: 6),
        Text('Smart Inventory Control', style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 14)),
        const SizedBox(height: 60),
        SizedBox(width: 36, height: 36, child: CircularProgressIndicator(color: Colors.white.withValues(alpha: 0.7), strokeWidth: 2.5)),
      ]))));
}

// ══════════════════════
//  LOGIN SCREEN
// ══════════════════════
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}
class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  bool _isAdmin = true;
  final _f1 = TextEditingController(); // username / worker-key
  final _f2 = TextEditingController(); // password
  bool _obs = true, _loading = false;
  String? _err;
  late AnimationController _sc;
  late Animation<Offset> _sa;
  @override void initState() {
    super.initState();
    _sc = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _sa = Tween<Offset>(begin: const Offset(0,.3), end: Offset.zero).animate(CurvedAnimation(parent: _sc, curve: Curves.easeOut));
    _sc.forward();
  }
  @override void dispose() { _sc.dispose(); _f1.dispose(); _f2.dispose(); super.dispose(); }

  void _switchRole(bool isAdmin) {
    setState(() { _isAdmin = isAdmin; _err = null; _f1.clear(); _f2.clear(); });
    _sc.reset(); _sc.forward();
  }

  Future<void> _login() async {
    if (_f1.text.trim().isEmpty) { setState(() => _err = _isAdmin ? 'Username daalo.' : 'Worker key daalo.'); return; }
    setState(() { _loading = true; _err = null; });
    Result<UserSession> res;
    if (_isAdmin) {
      res = await AuthService.instance.loginAdmin(username: _f1.text.trim(), password: _f2.text);
    } else {
      res = await AuthService.instance.loginWorker(workerKey: _f1.text.trim().toUpperCase());
    }
    if (!mounted) return;
    setState(() => _loading = false);
    if (res.isSuccess) {
      Navigator.pushReplacementNamed(context, res.data!.isAdmin ? '/admin-home' : '/worker-home');
    } else {
      setState(() => _err = res.error);
    }
  }

  @override
  Widget build(BuildContext ctx) => Scaffold(
    body: Container(height: double.infinity, decoration: const BoxDecoration(gradient: AppColors.gradientRB),
      child: SingleChildScrollView(child: Column(children: [
        const SizedBox(height: 80),
        Container(width: 86, height: 86, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0,8))]),
          child: const Icon(Icons.checkroom_rounded, size: 48, color: AppColors.red)),
        const SizedBox(height: 14),
        const Text('CLOTHING MANAGER', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 2.5)),
        const SizedBox(height: 28),
        SlideTransition(position: _sa, child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 30, offset: const Offset(0,12))]),
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // Role toggle
            Container(decoration: BoxDecoration(color: AppColors.bgLight, borderRadius: BorderRadius.circular(14)), padding: const EdgeInsets.all(4),
              child: Row(children: [_rb('Admin', Icons.admin_panel_settings_rounded, true), _rb('Worker', Icons.person_rounded, false)])),
            const SizedBox(height: 22),
            Text(_isAdmin ? 'Admin Login' : 'Worker Login', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark)),
            const SizedBox(height: 16),
            TextField(controller: _f1, textCapitalization: _isAdmin ? TextCapitalization.none : TextCapitalization.characters,
              decoration: InputDecoration(labelText: _isAdmin ? 'Username' : 'Worker Key',
                prefixIcon: Icon(_isAdmin ? Icons.person_outline_rounded : Icons.vpn_key_rounded, color: _isAdmin ? AppColors.blue : AppColors.red))),
            if (_isAdmin) ...[
              const SizedBox(height: 12),
              TextField(controller: _f2, obscureText: _obs, decoration: InputDecoration(labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.blue),
                suffixIcon: IconButton(icon: Icon(_obs ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.textGrey), onPressed: () => setState(() => _obs = !_obs)))),
            ] else ...[
              const SizedBox(height: 10),
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.blue.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.blue.withValues(alpha: 0.2))),
                child: Row(children: [const Icon(Icons.info_outline_rounded, color: AppColors.blue, size: 16), const SizedBox(width: 8),
                  Expanded(child: Text('Key admin se milegi.', style: TextStyle(fontSize: 12, color: AppColors.blue.withValues(alpha: 0.85))))])),
            ],
            if (_err != null) ...[
              const SizedBox(height: 12),
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.red.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.red.withValues(alpha: 0.3))),
                child: Row(children: [const Icon(Icons.error_outline, color: AppColors.red, size: 16), const SizedBox(width: 8),
                  Expanded(child: Text(_err!, style: const TextStyle(fontSize: 12, color: AppColors.red)))])),
            ],
            const SizedBox(height: 22),
            SizedBox(height: 52, child: ElevatedButton(
              onPressed: _loading ? null : _login,
              style: ElevatedButton.styleFrom(backgroundColor: _isAdmin ? AppColors.red : AppColors.blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: _loading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(_isAdmin ? Icons.login_rounded : Icons.key_rounded, size: 20), const SizedBox(width: 8),
                      Text(_isAdmin ? 'Login as Admin' : 'Enter with Key')]))),
          ]))),
        const SizedBox(height: 16),
        Text('v1.0 — Google Sheet Connected', style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 11)),
        const SizedBox(height: 24),
      ]))));

  Widget _rb(String label, IconData icon, bool isAdmin) {
    final sel = _isAdmin == isAdmin;
    return Expanded(child: GestureDetector(onTap: () => _switchRole(isAdmin),
      child: AnimatedContainer(duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: sel ? (isAdmin ? AppColors.red : AppColors.blue) : Colors.transparent, borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 18, color: sel ? Colors.white : AppColors.textGrey), const SizedBox(width: 6),
          Text(label, style: TextStyle(color: sel ? Colors.white : AppColors.textGrey, fontWeight: sel ? FontWeight.w700 : FontWeight.w500))]))));
  }
}

// ══════════════════════
//  ADMIN HOME
// ══════════════════════
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});
  @override State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}
class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _items=0; double _revenue=0; int _workers=0; int _returns=0;
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final inv   = await InventoryService.instance.getAllItems();
    final rev   = await SalesService.instance.getTodayRevenue();
    final wrks  = await WorkerKeyService.instance.getAllKeys();
    final lowStock = inv.where((i) => i.quantity <= 5).length;
    if (!mounted) return;
    setState(() { _items = inv.length; _revenue = rev; _workers = wrks.where((w)=>w.isActive).length; _returns = lowStock; _loading = false; });
  }

  Future<void> _logout() async {
    setState(()=>_loading=true);
    final r = await AuthService.instance.logout();
    if (!mounted) return;
    setState(()=>_loading=false);
    if (r.isSuccess) { Navigator.pushReplacementNamed(context, '/login'); }
    else { showSnack(context, r.error!, isError: true); }
  }

  @override
  Widget build(BuildContext ctx) {
    final name = AuthService.instance.currentSession?.name ?? 'Admin';
    return Scaffold(
      body: RefreshIndicator(onRefresh: _load, color: AppColors.red,
        child: CustomScrollView(slivers: [
          SliverAppBar(expandedHeight: 185, pinned: true, automaticallyImplyLeading: false, backgroundColor: AppColors.red,
            flexibleSpace: FlexibleSpaceBar(background: Container(decoration: const BoxDecoration(gradient: AppColors.gradientRB),
              child: Stack(children: [
                Positioned(top: -30, right: -30, child: Container(width: 150, height: 150, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.07), shape: BoxShape.circle))),
                Padding(padding: const EdgeInsets.fromLTRB(20, 60, 20, 20), child: Column(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(width: 46, height: 46, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), shape: BoxShape.circle), child: const Icon(Icons.person_rounded, color: Colors.white, size: 24)),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Namaskar, $name 👋', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
                      const Text('Dashboard', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                    ]),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.logout_rounded, color: Colors.white), onPressed: _logout),
                  ]),
                ])),
              ])))),
          SliverToBoxAdapter(child: _loading ? const Padding(padding: EdgeInsets.only(top:60), child: Center(child: CircularProgressIndicator(color: AppColors.red)))
            : Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.3, children: [
                _sCard('Total Items', '$_items', Icons.inventory_2_rounded, AppColors.gradientRed, '/inventory-detail'),
                _sCard("Today's Sell", '₹${_revenue.toStringAsFixed(0)}', Icons.point_of_sale_rounded, AppColors.gradientBlue, '/total-sell'),
                _sCard('Active Workers', '$_workers', Icons.people_rounded, const LinearGradient(colors: [Color(0xFF1B5E20), Color(0xFF4CAF50)], begin: Alignment.topLeft, end: Alignment.bottomRight), '/key-manage'),
                _sCard('Low Stock', '$_returns', Icons.notification_important_rounded, const LinearGradient(colors: [Color(0xFF6A1B9A), Color(0xFFAB47BC)], begin: Alignment.topLeft, end: Alignment.bottomRight), '/inventory-alert'),
              ]),
              const SizedBox(height: 22),
              const SectionTitle(text: 'Quick Actions'),
              const SizedBox(height: 14),
              GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 3, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.88, children: [
                _nCard('Worker\nKeys', Icons.vpn_key_rounded, AppColors.red, route: '/key-manage'),
                _nCard('Inventory\nSetup', Icons.add_box_rounded, AppColors.blue, route: '/inventory-setup'),
                _nCard('Inventory\nDetail', Icons.list_alt_rounded, const Color(0xFF2E7D32), route: '/inventory-detail'),
                _nCard('Total\nSell', Icons.bar_chart_rounded, const Color(0xFFF57C00), route: '/total-sell'),
                _nCard('Inventory\nAlert', Icons.notification_important_rounded, const Color(0xFF6A1B9A), route: '/inventory-alert'),
                _nCard('Export\nExcel', Icons.download_rounded, const Color(0xFF00838F), onTap: () async {
                  final r = await ExcelService.instance.exportInventory();
                  if (context.mounted) r.isSuccess ? showSnack(context, 'Saved: ${r.data}') : showSnack(context, r.error!, isError: true);
                }),
              ]),
            ]))),
        ])));
  }

  Widget _sCard(String t, String v, IconData icon, LinearGradient g, String route) =>
    GestureDetector(onTap: () => Navigator.pushNamed(context, route).then((_) => _load()),
      child: Container(decoration: BoxDecoration(gradient: g, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 12, offset: const Offset(0,4))]),
        padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: Colors.white, size: 24)),
          const SizedBox(height: 12),
          Text(v, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
          Text(t, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11)),
        ])));

  Widget _nCard(String l, IconData icon, Color c, {String? route, VoidCallback? onTap}) =>
    GestureDetector(onTap: onTap ?? (route != null ? () => Navigator.pushNamed(context, route).then((_) => _load()) : null),
      child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 10)]),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: c, size: 24)),
          const SizedBox(height: 8),
          Text(l, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
        ])));
}

// ══════════════════════
//  KEY MANAGE
// ══════════════════════
class KeyManageScreen extends StatefulWidget {
  const KeyManageScreen({super.key});
  @override State<KeyManageScreen> createState() => _KeyManageScreenState();
}
class _KeyManageScreenState extends State<KeyManageScreen> {
  List<WorkerKey> _keys = [];
  bool _loading = true;
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _saving = false;

  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _name.dispose(); _phone.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final keys = await WorkerKeyService.instance.getAllKeys();
    if (!mounted) return;
    setState(() { _keys = keys; _loading = false; });
  }

  Future<void> _create() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final r = await WorkerKeyService.instance.createKey(name: _name.text.trim(), phone: _phone.text.trim());
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pop(context);
    if (r.isSuccess) { showSnack(context, 'Key banaya: ${r.data!.key}'); _load(); }
    else { showSnack(context, r.error!, isError: true); }
  }

  void _showDialog() {
    _name.clear(); _phone.clear();
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)))),
          const SizedBox(height: 18),
          const Text('New Worker Key', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 18),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Worker Name', prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.red))),
          const SizedBox(height: 12),
          TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone (optional)', prefixIcon: Icon(Icons.phone_outlined, color: AppColors.red))),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _saving ? null : _create,
            icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.vpn_key_rounded),
            label: const Text('Generate Key')),
        ])));
  }

  @override
  Widget build(BuildContext ctx) => Scaffold(
    appBar: const GradientAppBar(title: 'Worker Keys'),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _showDialog, backgroundColor: AppColors.red,
      icon: const Icon(Icons.add_rounded, color: Colors.white),
      label: const Text('New Key', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
    body: _loading ? buildLoader() : _keys.isEmpty
      ? buildEmpty('Koi worker key nahi hai.', Icons.vpn_key_off_rounded)
      : ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          itemCount: _keys.length,
          itemBuilder: (_, i) => _KeyCard(k: _keys[i], onToggle: () async {
            await WorkerKeyService.instance.toggleKey(_keys[i].id!, !_keys[i].isActive);
            _load();
          })));
}

class _KeyCard extends StatelessWidget {
  final WorkerKey k; final VoidCallback onToggle;
  const _KeyCard({required this.k, required this.onToggle});
  @override
  Widget build(BuildContext ctx) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: k.isActive ? AppColors.success.withValues(alpha: 0.3) : Colors.grey.shade200),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10)]),
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        CircleAvatar(backgroundColor: (k.isActive ? AppColors.success : AppColors.textGrey).withValues(alpha: 0.15),
          child: Text(k.name[0].toUpperCase(), style: TextStyle(color: k.isActive ? AppColors.success : AppColors.textGrey, fontWeight: FontWeight.w700))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          if (k.phone.isNotEmpty) Text(k.phone, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
        ])),
        Switch(value: k.isActive, onChanged: (_) => onToggle(), activeColor: AppColors.success),
      ]),
      const SizedBox(height: 12),
      Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: AppColors.bgLight, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          const Icon(Icons.vpn_key_rounded, color: AppColors.red, size: 18), const SizedBox(width: 10),
          Expanded(child: Text(k.key, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 1.5))),
          GestureDetector(
            onTap: () { Clipboard.setData(ClipboardData(text: k.key)); showSnack(ctx, 'Key copied!'); },
            child: const Icon(Icons.copy_rounded, color: AppColors.blue, size: 18)),
        ])),
      const SizedBox(height: 8),
      Row(children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: (k.isActive ? AppColors.success : AppColors.textGrey).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
          child: Text(k.isActive ? '● Active' : '○ Inactive',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: k.isActive ? AppColors.success : AppColors.textGrey))),
        const Spacer(),
        Text('${k.createdAt.day}/${k.createdAt.month}/${k.createdAt.year}', style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
      ]),
    ]));
}

// ══════════════════════
//  INVENTORY SETUP — Simple
// ══════════════════════
class InventorySetupScreen extends StatefulWidget {
  const InventorySetupScreen({super.key});
  @override State<InventorySetupScreen> createState() => _InventorySetupScreenState();
}
class _InventorySetupScreenState extends State<InventorySetupScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;

  // Unit fields
  final _uName  = TextEditingController();
  final _uSizes = TextEditingController(text: 'S,M,L,XL');
  String _uGender = 'Men';
  List<InventoryUnit> _units = [];

  // Item fields
  final _iName = TextEditingController();
  final _iCrn  = TextEditingController();
  final _iPrice = TextEditingController();
  final _iQty   = TextEditingController(text: '1');
  String _selUnit = '';
  bool _saving = false;

  final _genders = ['Men', 'Women', 'Kids', 'Unisex'];

  @override void initState() { super.initState(); _tab = TabController(length: 2, vsync: this); _loadUnits(); }
  @override void dispose() { _tab.dispose(); _uName.dispose(); _uSizes.dispose(); _iName.dispose(); _iCrn.dispose(); _iPrice.dispose(); _iQty.dispose(); super.dispose(); }

  Future<void> _loadUnits() async {
    final u = await InventoryService.instance.getAllUnits();
    if (!mounted) return;
    setState(() { _units = u; if (u.isNotEmpty && _selUnit.isEmpty) _selUnit = u.first.name; });
  }

  Future<void> _saveUnit() async {
    if (_uName.text.trim().isEmpty) { showSnack(context, 'Unit naam daalo!', isError: true); return; }
    final r = await InventoryService.instance.addUnit(InventoryUnit(
      name: _uName.text.trim(), gender: _uGender,
      sizes: _uSizes.text.trim().isEmpty ? 'Free Size' : _uSizes.text.trim(),
      totalQuantity: 0));
    if (!mounted) return;
    if (r.isSuccess) { showSnack(context, 'Unit saved!'); _uName.clear(); _loadUnits(); }
    else { showSnack(context, r.error!, isError: true); }
  }

  Future<void> _saveItem() async {
    if (_iName.text.trim().isEmpty || _iCrn.text.trim().isEmpty) {
      showSnack(context, 'Naam aur barcode daalo!', isError: true); return;
    }
    if (_units.isEmpty) { showSnack(context, 'Pehle unit banao!', isError: true); return; }
    setState(() => _saving = true);
    final unit = _units.firstWhere((u) => u.name == _selUnit, orElse: () => _units.first);
    final r = await InventoryService.instance.addItem(InventoryItem(
      crn: _iCrn.text.trim().toUpperCase(), name: _iName.text.trim(),
      gender: unit.gender, size: unit.sizes.split(',').first.trim(),
      unit: unit.name, brand: '-',
      price: double.tryParse(_iPrice.text) ?? 0,
      quantity: int.tryParse(_iQty.text) ?? 1));
    if (!mounted) return;
    setState(() => _saving = false);
    if (r.isSuccess) { showSnack(context, 'Item saved! ✓'); _iName.clear(); _iCrn.clear(); _iPrice.clear(); _iQty.text = '1'; }
    else { showSnack(context, r.error!, isError: true); }
  }

  @override
  Widget build(BuildContext ctx) => Scaffold(
    appBar: AppBar(backgroundColor: Colors.transparent,
      flexibleSpace: Container(decoration: const BoxDecoration(gradient: AppColors.gradientRB)),
      title: const Text('Inventory Setup'),
      leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white), onPressed: () => Navigator.pop(ctx)),
      bottom: TabBar(controller: _tab, indicatorColor: Colors.white, indicatorWeight: 3,
        labelColor: Colors.white, unselectedLabelColor: Colors.white70,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700),
        tabs: const [Tab(text: 'Unit Banao', icon: Icon(Icons.category_rounded, size: 18)),
                     Tab(text: 'Item Add Karo', icon: Icon(Icons.add_shopping_cart_rounded, size: 18))])),
    body: TabBarView(controller: _tab, children: [_unitTab(), _itemTab()]));

  Widget _unitTab() => ListView(padding: const EdgeInsets.all(16), children: [
    _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionTitle(text: 'Naya Unit Banao'),
      const SizedBox(height: 16),
      TextField(controller: _uName, decoration: const InputDecoration(labelText: 'Unit naam (jaise: Jeans, T-Shirt)', prefixIcon: Icon(Icons.category_rounded, color: AppColors.red))),
      const SizedBox(height: 14),
      const Text('Gender', style: TextStyle(fontSize: 13, color: AppColors.textGrey, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, children: _genders.map((g) {
        final sel = _uGender == g;
        return GestureDetector(onTap: () => setState(() => _uGender = g),
          child: AnimatedContainer(duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: sel ? AppColors.blue : AppColors.bgLight, borderRadius: BorderRadius.circular(20), border: Border.all(color: sel ? AppColors.blue : Colors.grey.shade300)),
            child: Text(g, style: TextStyle(color: sel ? Colors.white : AppColors.textDark, fontWeight: sel ? FontWeight.w700 : FontWeight.w500, fontSize: 13))));
      }).toList()),
      const SizedBox(height: 14),
      TextField(controller: _uSizes, decoration: const InputDecoration(labelText: 'Sizes (comma se alag karo)', hintText: 'S,M,L,XL  ya  28,30,32,34', prefixIcon: Icon(Icons.straighten_rounded, color: AppColors.red))),
      const SizedBox(height: 16),
      SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _saveUnit, icon: const Icon(Icons.save_rounded), label: const Text('Unit Save Karo'))),
    ])),
    const SizedBox(height: 16),
    const SectionTitle(text: 'Existing Units'),
    const SizedBox(height: 12),
    if (_units.isEmpty) buildEmpty('Koi unit nahi.\nUpar se banao.', Icons.category_outlined),
    ..._units.map((u) => Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)]),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.category_rounded, color: AppColors.red, size: 20)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(u.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          Text('${u.gender} • Sizes: ${u.sizes}', style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
        ])),
        chip(u.gender, AppColors.blue),
      ]))),
  ]);

  Widget _itemTab() => ListView(padding: const EdgeInsets.all(16), children: [
    _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionTitle(text: 'Naya Item Add Karo'),
      const SizedBox(height: 16),
      TextField(controller: _iName, decoration: const InputDecoration(labelText: 'Kapde ka naam', prefixIcon: Icon(Icons.checkroom_rounded, color: AppColors.blue))),
      const SizedBox(height: 12),
      TextField(controller: _iCrn, textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(labelText: '1D Barcode / QR Number', hintText: 'Barcode no. daalo ya scan karo', prefixIcon: Icon(Icons.qr_code_rounded, color: AppColors.blue))),
      const SizedBox(height: 12),
      if (_units.isEmpty)
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
          child: const Text('Pehle "Unit Banao" tab mein unit create karo.', style: TextStyle(color: AppColors.warning)))
      else
        DropdownButtonFormField<String>(
          value: _selUnit.isEmpty ? _units.first.name : _selUnit,
          decoration: const InputDecoration(labelText: 'Unit Select Karo', prefixIcon: Icon(Icons.category_rounded, color: AppColors.blue)),
          items: _units.map((u) => DropdownMenuItem(value: u.name, child: Text('${u.name} (${u.gender})'))).toList(),
          onChanged: (v) => setState(() => _selUnit = v!)),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: TextField(controller: _iPrice, keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Price ₹', prefixIcon: Icon(Icons.currency_rupee_rounded, color: AppColors.blue)))),
        const SizedBox(width: 12),
        SizedBox(width: 100, child: TextField(controller: _iQty, keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Qty', prefixIcon: Icon(Icons.numbers_rounded, color: AppColors.blue)))),
      ]),
      const SizedBox(height: 20),
      SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(
        onPressed: _saving ? null : _saveItem,
        icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save_rounded),
        label: const Text('Item Save Karo'))),
    ])),
    const SizedBox(height: 14),
    Row(children: [
      Expanded(child: _fileBtn(Icons.upload_file_rounded, 'Excel Upload', AppColors.success, () async {
        final r = await ExcelService.instance.importFromExcel();
        if (context.mounted) r.isSuccess ? showSnack(context, '${r.data} items import hue!') : showSnack(context, r.error!, isError: true);
      })),
      const SizedBox(width: 12),
      Expanded(child: _fileBtn(Icons.download_rounded, 'Excel Download', AppColors.blue, () async {
        final r = await ExcelService.instance.exportInventory();
        if (context.mounted) r.isSuccess ? showSnack(context, 'Saved!') : showSnack(context, r.error!, isError: true);
      })),
    ]),
    const SizedBox(height: 20),
  ]);

  Widget _card(Widget c) => Container(padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10)]), child: c);

  Widget _fileBtn(IconData icon, String label, Color c, VoidCallback onTap) =>
    GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: c.withValues(alpha: 0.4))),
      child: Column(children: [Icon(icon, color: c, size: 24), const SizedBox(height: 6), Text(label, style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 13))])));
}

// ══════════════════════
//  INVENTORY DETAIL — Unit Wise
// ══════════════════════
class InventoryDetailScreen extends StatefulWidget {
  const InventoryDetailScreen({super.key});
  @override State<InventoryDetailScreen> createState() => _InventoryDetailScreenState();
}
class _InventoryDetailScreenState extends State<InventoryDetailScreen> {
  List<InventoryUnit> _units = [];
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final units = await InventoryService.instance.getAllUnits();
    if (!mounted) return;
    setState(() { _units = units; _loading = false; });
  }

  @override
  Widget build(BuildContext ctx) => Scaffold(
    appBar: const GradientAppBar(title: 'Inventory Detail'),
    body: _loading ? buildLoader() : _units.isEmpty
      ? buildEmpty('Koi unit nahi.\nInventory Setup se banao.', Icons.inventory_2_rounded)
      : RefreshIndicator(onRefresh: _load, color: AppColors.red,
          child: ListView.builder(padding: const EdgeInsets.all(16), itemCount: _units.length,
            itemBuilder: (_, i) => _UnitCard(unit: _units[i]))));
}

class _UnitCard extends StatelessWidget {
  final InventoryUnit unit;
  const _UnitCard({required this.unit});

  Color get _gColor {
    switch (unit.gender) {
      case 'Women': return AppColors.red;
      case 'Kids':  return const Color(0xFF6A1B9A);
      case 'Unisex':return const Color(0xFF00838F);
      default:      return AppColors.blue;
    }
  }

  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => UnitItemsScreen(unit: unit))),
    child: Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 10)]),
      child: Row(children: [
        Container(width: 50, height: 50,
          decoration: BoxDecoration(color: _gColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.checkroom_rounded, color: _gColor, size: 26)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(unit.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 4),
          Text('${unit.gender} • Sizes: ${unit.sizes}', style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
        ])),
        const Icon(Icons.chevron_right_rounded, color: AppColors.textGrey),
      ])));
}

// Unit ke items dikhane ki screen
class UnitItemsScreen extends StatefulWidget {
  final InventoryUnit unit;
  const UnitItemsScreen({super.key, required this.unit});
  @override State<UnitItemsScreen> createState() => _UnitItemsScreenState();
}
class _UnitItemsScreenState extends State<UnitItemsScreen> {
  List<InventoryItem> _items = [];
  bool _loading = true;
  final _search = TextEditingController();

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await InventoryService.instance.getAllItems(
      unit: widget.unit.name, searchQuery: _search.text.trim());
    if (!mounted) return;
    setState(() { _items = items; _loading = false; });
  }

  @override
  Widget build(BuildContext ctx) => Scaffold(
    appBar: GradientAppBar(title: widget.unit.name),
    body: Column(children: [
      Container(color: Colors.white, padding: const EdgeInsets.all(12),
        child: TextField(controller: _search, onChanged: (_) => _load(),
          decoration: InputDecoration(hintText: 'Search...', prefixIcon: const Icon(Icons.search_rounded, color: AppColors.blue),
            suffixIcon: _search.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear_rounded), onPressed: () { _search.clear(); _load(); }) : null))),
      Padding(padding: const EdgeInsets.fromLTRB(16,8,16,4),
        child: Row(children: [Text('${_items.length} items', style: const TextStyle(color: AppColors.textGrey, fontSize: 13))])),
      Expanded(child: _loading ? buildLoader() : _items.isEmpty
        ? buildEmpty('Koi item nahi.', Icons.inventory_2_rounded)
        : ListView.builder(padding: const EdgeInsets.fromLTRB(16,4,16,16), itemCount: _items.length,
            itemBuilder: (_, i) {
              final item = _items[i];
              return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: item.quantity <= 0 ? AppColors.red.withValues(alpha: 0.4) : item.quantity <= 5 ? AppColors.warning.withValues(alpha: 0.4) : Colors.grey.shade200),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)]),
                child: Row(children: [
                  const Icon(Icons.checkroom_rounded, color: AppColors.blue, size: 22),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    Text('CRN: ${item.crn}', style: const TextStyle(fontSize: 11, color: AppColors.textGrey, fontFamily: 'monospace')),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('₹${item.price.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.red)),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: item.quantity <= 0 ? AppColors.red : item.quantity <= 5 ? AppColors.warning : AppColors.success,
                        borderRadius: BorderRadius.circular(10)),
                      child: Text(item.quantity <= 0 ? 'OUT' : 'Qty: ${item.quantity}',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
                  ]),
                ]));
            })),
    ]));
}

// ══════════════════════
//  TOTAL SELL
// ══════════════════════
class TotalSellScreen extends StatefulWidget {
  const TotalSellScreen({super.key});
  @override State<TotalSellScreen> createState() => _TotalSellScreenState();
}
class _TotalSellScreenState extends State<TotalSellScreen> {
  List<SaleRecord> _sales = [];
  bool _loading = true;
  DateTime _date = DateTime.now();
  double _total  = 0;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final sales = await SalesService.instance.getSalesByDate(_date);
    final rev   = await SalesService.instance.getTodayRevenue();
    if (!mounted) return;
    setState(() { _sales = sales; _total = rev; _loading = false; });
  }

  @override
  Widget build(BuildContext ctx) => Scaffold(
    appBar: const GradientAppBar(title: 'Sell History'),
    body: Column(children: [
      Container(margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(gradient: AppColors.gradientBlue, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("Today's Total", style: TextStyle(color: Colors.white70, fontSize: 12)),
            Text('₹${_total.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
            Text('${_sales.length} transactions', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ])),
          GestureDetector(
            onTap: () async {
              final p = await showDatePicker(context: ctx, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime.now());
              if (p != null) { setState(() => _date = p); _load(); }
            },
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
              child: const Row(children: [Icon(Icons.calendar_today_rounded, color: Colors.white, size: 16), SizedBox(width: 6), Text('Date', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))]))),
        ])),
      Expanded(child: _loading ? buildLoader() : _sales.isEmpty
        ? buildEmpty('Is din koi sell nahi hua.', Icons.point_of_sale_rounded)
        : ListView.builder(
            padding: const EdgeInsets.fromLTRB(16,0,16,16),
            itemCount: _sales.length,
            itemBuilder: (_, i) {
              final s = _sales[i];
              return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)]),
                child: Row(children: [
                  Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                    child: Center(child: Text('${i+1}', style: const TextStyle(color: AppColors.blue, fontWeight: FontWeight.w800)))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.itemName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    Text('CRN: ${s.crn} • Qty: ${s.quantity} • ${s.workerName}', style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                    if (s.discount > 0) Text('Disc: ₹${s.discount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: AppColors.red)),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('₹${s.totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.success)),
                    Text('${s.soldAt.hour}:${s.soldAt.minute.toString().padLeft(2,'0')}', style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                    if (!s.isSynced) Container(margin: const EdgeInsets.only(top: 2), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                      child: const Text('pending', style: TextStyle(fontSize: 9, color: AppColors.warning, fontWeight: FontWeight.w600))),
                  ]),
                ]));
            })),
    ]));
}

// ══════════════════════
//  RETURN INVENTORY
// ══════════════════════
class ReturnInventoryScreen extends StatefulWidget {
  const ReturnInventoryScreen({super.key});
  @override State<ReturnInventoryScreen> createState() => _ReturnInventoryScreenState();
}
class _ReturnInventoryScreenState extends State<ReturnInventoryScreen> {
  List<ReturnRecord> _returns = [];
  bool _loading = true;
  final _crn    = TextEditingController();
  final _qty    = TextEditingController();
  final _reason = TextEditingController();
  final _refund = TextEditingController();
  bool _saving  = false;

  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _crn.dispose(); _qty.dispose(); _reason.dispose(); _refund.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final r = await ReturnService.instance.getTodayReturns();
    if (!mounted) return;
    setState(() { _returns = r; _loading = false; });
  }

  Future<void> _addReturn() async {
    final session = AuthService.instance.currentSession;
    if (session == null) return;
    if (_crn.text.trim().isEmpty || _qty.text.trim().isEmpty) { showSnack(context, 'CRN aur qty daalo!', isError: true); return; }
    setState(() => _saving = true);
    final r = await ReturnService.instance.returnItem(
      crn: _crn.text.trim().toUpperCase(),
      quantity: int.tryParse(_qty.text) ?? 1,
      reason: _reason.text.trim().isEmpty ? 'Not specified' : _reason.text.trim(),
      worker: session,
      refundAmount: double.tryParse(_refund.text) ?? 0);
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pop(context);
    if (r.isSuccess) { showSnack(context, 'Return added! Inventory updated ✓'); _load(); }
    else { showSnack(context, r.error!, isError: true); }
  }

  void _showDialog() {
    _crn.clear(); _qty.clear(); _reason.clear(); _refund.clear();
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)))),
          const SizedBox(height: 18),
          const Text('Return Item', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 18),
          TextField(controller: _crn, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'CRN Number', prefixIcon: Icon(Icons.qr_code_rounded, color: AppColors.red))),
          const SizedBox(height: 12),
          TextField(controller: _qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity', prefixIcon: Icon(Icons.numbers_rounded, color: AppColors.red))),
          const SizedBox(height: 12),
          TextField(controller: _reason, decoration: const InputDecoration(labelText: 'Reason', prefixIcon: Icon(Icons.rate_review_rounded, color: AppColors.red))),
          const SizedBox(height: 12),
          TextField(controller: _refund, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Refund ₹ (optional)', prefixIcon: Icon(Icons.currency_rupee_rounded, color: AppColors.red))),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _saving ? null : _addReturn,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
            icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.assignment_return_rounded),
            label: const Text('Add Return')),
        ])));
  }

  @override
  Widget build(BuildContext ctx) => Scaffold(
    appBar: const GradientAppBar(title: 'Return Inventory'),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _showDialog, backgroundColor: AppColors.warning,
      icon: const Icon(Icons.add_rounded, color: Colors.white),
      label: const Text('Add Return', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
    body: Column(children: [
      Container(margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFE65100), Color(0xFFFF9800)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          const Icon(Icons.assignment_return_rounded, color: Colors.white, size: 26), const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Today Returns', style: TextStyle(color: Colors.white70, fontSize: 12)),
            Text('${_returns.length} items', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
          ]),
        ])),
      Expanded(child: _loading ? buildLoader() : _returns.isEmpty
        ? buildEmpty('Aaj koi return nahi.', Icons.assignment_return_rounded)
        : ListView.builder(
            padding: const EdgeInsets.fromLTRB(16,0,16,80),
            itemCount: _returns.length,
            itemBuilder: (_, i) {
              final r = _returns[i];
              return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)]),
                child: Row(children: [
                  Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.assignment_return_rounded, color: AppColors.warning, size: 20)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(r.itemName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    Text('CRN: ${r.crn} • Qty: ${r.quantity}', style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                    Text('Reason: ${r.reason}', style: const TextStyle(fontSize: 11, color: AppColors.red)),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    if (r.refundAmount > 0) Text('-₹${r.refundAmount.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.w700)),
                    Text('${r.returnedAt.hour}:${r.returnedAt.minute.toString().padLeft(2,'0')}', style: const TextStyle(fontSize: 10, color: AppColors.textGrey)),
                  ]),
                ]));
            })),
    ]));
}

// ══════════════════════
//  WORKER HOME
// ══════════════════════
class WorkerHomeScreen extends StatefulWidget {
  const WorkerHomeScreen({super.key});
  @override State<WorkerHomeScreen> createState() => _WorkerHomeScreenState();
}
class _WorkerHomeScreenState extends State<WorkerHomeScreen> {
  List<SaleRecord> _sales = [];
  int _returns = 0, _pending = 0;
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final s = AuthService.instance.currentSession;
    if (s == null) return;
    setState(() => _loading = true);
    final sales   = await SalesService.instance.getTodaySales(workerId: s.userId);
    final rets    = await ReturnService.instance.getTodayReturns(workerId: s.userId);
    final pending = await SyncService.instance.getPendingSyncCount(s.userId);
    if (!mounted) return;
    setState(() { _sales = sales; _returns = rets.length; _pending = pending; _loading = false; });
  }

  Future<void> _logout() async {
    final r = await AuthService.instance.logout();
    if (!mounted) return;
    if (r.isSuccess) { Navigator.pushReplacementNamed(context, '/login'); }
    else { showSnack(context, r.error!, isError: true); }
  }

  @override
  Widget build(BuildContext ctx) {
    final name   = AuthService.instance.currentSession?.name ?? '';
    final earned = _sales.fold<double>(0, (s, i) => s + i.totalAmount);
    return Scaffold(
      body: RefreshIndicator(onRefresh: _load, color: AppColors.red,
        child: CustomScrollView(slivers: [
          SliverAppBar(expandedHeight: 175, pinned: true, automaticallyImplyLeading: false, backgroundColor: AppColors.red,
            flexibleSpace: FlexibleSpaceBar(background: Container(decoration: const BoxDecoration(gradient: AppColors.gradientRB),
              child: Stack(children: [
                Positioned(top: -30, right: -30, child: Container(width: 150, height: 150, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.07), shape: BoxShape.circle))),
                Padding(padding: const EdgeInsets.fromLTRB(20, 60, 20, 20), child: Column(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle), child: const Icon(Icons.person_rounded, color: Colors.white, size: 22)),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Worker: $name', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
                      const Text('Sell Dashboard', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
                    ]),
                    const Spacer(),
                    if (_pending > 0)
                      Container(margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.warning, borderRadius: BorderRadius.circular(20)),
                        child: Text('$_pending pending', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
                    IconButton(icon: const Icon(Icons.logout_rounded, color: Colors.white), onPressed: _logout),
                  ]),
                ])),
              ])))),
          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
            Row(children: [
              Expanded(child: _bigBtn('Scan QR/CRN', Icons.qr_code_scanner_rounded, AppColors.gradientRed, '/worker-scanner')),
              const SizedBox(width: 14),
              Expanded(child: _bigBtn('Manual Search', Icons.search_rounded, AppColors.gradientBlue, '/worker-manual-search')),
            ]),
            const SizedBox(height: 18),
            if (!_loading) Row(children: [
              Expanded(child: _mini('Sold Today', '${_sales.length}', Icons.shopping_bag_rounded, AppColors.success)),
              const SizedBox(width: 10),
              Expanded(child: _mini('Earned', '₹${earned.toStringAsFixed(0)}', Icons.currency_rupee_rounded, AppColors.blue)),
              const SizedBox(width: 10),
              Expanded(child: _mini('Returns', '$_returns', Icons.assignment_return_rounded, AppColors.warning)),
            ]),
            const SizedBox(height: 20),
            SectionTitle(text: "Today's Sales",
              trailing: TextButton(onPressed: () => Navigator.pushNamed(context, '/worker-history').then((_)=>_load()), child: const Text('See All', style: TextStyle(color: AppColors.blue)))),
            const SizedBox(height: 10),
            if (_loading) buildLoader()
            else if (_sales.isEmpty) buildEmpty('Abhi tak koi sell nahi.', Icons.shopping_bag_rounded)
            else ..._sales.take(5).map((s) => _SaleTile(s: s)),
          ]))),
        ])));
  }

  Widget _bigBtn(String lbl, IconData icon, LinearGradient g, String route) =>
    GestureDetector(onTap: () => Navigator.pushNamed(context, route).then((_) => _load()),
      child: Container(height: 105, decoration: BoxDecoration(gradient: g, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 12, offset: const Offset(0,5))]),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: Colors.white, size: 36), const SizedBox(height: 8), Text(lbl, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14))])));

  Widget _mini(String lbl, String val, IconData icon, Color c) => Container(
    padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)]),
    child: Column(children: [Icon(icon, color: c, size: 20), const SizedBox(height: 6), Text(val, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: c)), Text(lbl, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: AppColors.textGrey))]));
}

class _SaleTile extends StatelessWidget {
  final SaleRecord s;
  const _SaleTile({required this.s});
  @override
  Widget build(BuildContext ctx) => Container(
    margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)]),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.shopping_bag_rounded, color: AppColors.success, size: 18)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(s.itemName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        Text('CRN: ${s.crn} • Qty: ${s.quantity}', style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
      ])),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('₹${s.totalAmount.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w800, fontSize: 13)),
        Text('${s.soldAt.hour}:${s.soldAt.minute.toString().padLeft(2,'0')}', style: const TextStyle(fontSize: 10, color: AppColors.textGrey)),
      ]),
    ]));
}

// ══════════════════════
//  WORKER SCANNER — 1D Barcode
// ══════════════════════
class WorkerScannerScreen extends StatefulWidget {
  const WorkerScannerScreen({super.key});
  @override State<WorkerScannerScreen> createState() => _WorkerScannerScreenState();
}
class _WorkerScannerScreenState extends State<WorkerScannerScreen> with SingleTickerProviderStateMixin {
  final _ctrl     = TextEditingController();
  late MobileScannerController _scanCtrl;
  bool _torchOn   = false;
  bool _scanned   = false;
  List<InventoryItem> _suggestions = [];
  Timer? _debounce;
  // Animated scan line
  late AnimationController _lineCtrl;
  late Animation<double> _lineAnim;

  @override
  void initState() {
    super.initState();
    _scanCtrl = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      formats: [BarcodeFormat.all],
    );
    _lineCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _lineAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _lineCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scanCtrl.dispose();
    _lineCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_scanned) return;
    final code = capture.barcodes.firstOrNull?.rawValue ?? '';
    if (code.isEmpty) return;
    setState(() => _scanned = true);
    await _scanCtrl.stop();
    final item = await InventoryService.instance.getItemByCrn(code.toUpperCase());
    if (!mounted) return;
    if (item != null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args == 'add_more') {
        Navigator.pop(context, item);
      } else {
        Navigator.pushNamed(context, '/worker-sell', arguments: [item]).then((_) {
          setState(() => _scanned = false);
          _scanCtrl.start();
        });
      }
    } else {
      showSnack(context, 'Item nahi mila: $code', isError: true);
      setState(() => _scanned = false);
      _scanCtrl.start();
    }
  }

  void _onType(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (q.trim().isEmpty) { setState(() => _suggestions = []); return; }
      final r = await InventoryService.instance.getAllItems(searchQuery: q.trim());
      if (mounted) setState(() => _suggestions = r.take(5).toList());
    });
  }

  void _select(InventoryItem item) {
    _ctrl.clear();
    setState(() => _suggestions = []);
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args == 'add_more') {
      Navigator.pop(context, item);
    } else {
      Navigator.pushNamed(context, '/worker-sell', arguments: [item]);
    }
  }

  @override
  Widget build(BuildContext ctx) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white), onPressed: () => Navigator.pop(ctx)),
      title: const Text('1D Barcode Scan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      actions: [
        IconButton(icon: Icon(_torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded, color: Colors.white),
          onPressed: () { setState(() => _torchOn = !_torchOn); _scanCtrl.toggleTorch(); }),
        IconButton(icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white), onPressed: () => _scanCtrl.switchCamera()),
      ]),
    body: Stack(children: [
      // Real camera
      MobileScanner(controller: _scanCtrl, onDetect: _onDetect),

      // 1D scan overlay — full width line
      Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: double.infinity, height: 120,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.red, width: 2),
            borderRadius: BorderRadius.circular(8)),
          child: Stack(children: [
            // Overlay dim
            Container(decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.0),
              borderRadius: BorderRadius.circular(8))),
            // Moving scan line
            AnimatedBuilder(
              animation: _lineAnim,
              builder: (_, __) => Positioned(
                top: _lineAnim.value * 110,
                left: 0, right: 0,
                child: Container(height: 2,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, AppColors.red, AppColors.red, Colors.transparent],
                      stops: [0.0, 0.2, 0.8, 1.0]))))),
          ])),
        const SizedBox(height: 12),
        const Text('1D barcode scanner ke saamne rakho', style: TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 4),
        const Text('Laal line bar bar chalegi jab tak scan na ho', style: TextStyle(color: Colors.white38, fontSize: 11)),
      ])),

      // Bottom search
      Positioned(bottom: 0, left: 0, right: 0,
        child: Container(
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.92), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (_suggestions.isNotEmpty)
              Container(constraints: const BoxConstraints(maxHeight: 180),
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(12)),
                child: ListView.builder(shrinkWrap: true, itemCount: _suggestions.length, itemBuilder: (_, i) {
                  final it = _suggestions[i];
                  return ListTile(dense: true,
                    leading: const Icon(Icons.checkroom_rounded, color: AppColors.red, size: 18),
                    title: Text(it.name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: Text('${it.crn} • ₹${it.price.toStringAsFixed(0)} • Qty:${it.quantity}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                    onTap: () => _select(it));
                })),
            Padding(padding: const EdgeInsets.all(16), child: Column(children: [
              const Text('Ya naam/barcode type karo:', style: TextStyle(color: Colors.white60, fontSize: 12)),
              const SizedBox(height: 8),
              TextField(controller: _ctrl, style: const TextStyle(color: Colors.white),
                textCapitalization: TextCapitalization.characters, onChanged: _onType,
                decoration: InputDecoration(
                  hintText: 'Type karo — live results...',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                  fillColor: Colors.white12, filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  suffixIcon: IconButton(icon: const Icon(Icons.search_rounded, color: AppColors.red), onPressed: () => _onType(_ctrl.text)))),
            ])),
          ])));
    ]));
}

// ══════════════════════
//  WORKER MANUAL SEARCH
// ══════════════════════
class WorkerManualSearchScreen extends StatefulWidget {
  const WorkerManualSearchScreen({super.key});
  @override State<WorkerManualSearchScreen> createState() => _WorkerManualSearchScreenState();
}
class _WorkerManualSearchScreenState extends State<WorkerManualSearchScreen> {
  final _ctrl = TextEditingController();
  List<InventoryItem> _results = [];
  bool _loading = false;
  Timer? _debounce;

  @override void dispose() { _ctrl.dispose(); _debounce?.cancel(); super.dispose(); }

  void _onType(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (q.trim().isEmpty) { setState(() => _results = []); return; }
      setState(() => _loading = true);
      final r = await InventoryService.instance.getAllItems(searchQuery: q.trim());
      if (mounted) setState(() { _results = r; _loading = false; });
    });
  }

  @override
  Widget build(BuildContext ctx) => Scaffold(
    appBar: const GradientAppBar(title: 'Search Inventory'),
    body: Column(children: [
      Container(color: Colors.white, padding: const EdgeInsets.all(16),
        child: TextField(controller: _ctrl, onChanged: _onType,
          decoration: const InputDecoration(
            hintText: 'Naam ya CRN type karo — live results...',
            prefixIcon: Icon(Icons.search_rounded, color: AppColors.blue)))),
      Expanded(child: _ctrl.text.isEmpty
        ? buildEmpty('Kuch type karo — items aayenge!', Icons.search_rounded)
        : _loading ? buildLoader()
        : _results.isEmpty ? buildEmpty('Koi item nahi mila.', Icons.search_off_rounded)
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _results.length,
            itemBuilder: (_, i) {
              final item = _results[i];
              return GestureDetector(
                onTap: item.quantity > 0 ? () {
                  // Agar cart se "Add More" aaya hai to pop with result
                  // Warna directly sell screen pe jao
                  if (Navigator.canPop(ctx)) {
                    Navigator.pop(ctx, item);
                  } else {
                    Navigator.pushNamed(ctx, '/worker-sell', arguments: [item]);
                  }
                } : null,
                child: Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: item.quantity > 0 ? Colors.white : Colors.grey.shade50, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10)]),
                  child: Row(children: [
                    Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                      child: Icon(Icons.checkroom_rounded, color: item.quantity > 0 ? AppColors.blue : AppColors.textGrey, size: 24)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(item.name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: item.quantity > 0 ? AppColors.textDark : AppColors.textGrey)),
                      Text('${item.crn} • ${item.brand} • ${item.size}', style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                      Text('Available: ${item.quantity}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: item.quantity > 0 ? AppColors.success : AppColors.red)),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('₹${item.price.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.red, fontSize: 15)),
                      const SizedBox(height: 4),
                      item.quantity > 0
                        ? Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: AppColors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)), child: const Text('Select', style: TextStyle(color: AppColors.blue, fontSize: 11, fontWeight: FontWeight.w700)))
                        : Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)), child: const Text('Out of Stock', style: TextStyle(color: AppColors.textGrey, fontSize: 10))),
                    ]),
                  ])));
            })),
    ]));
  }

// ══════════════════════
//  WORKER SELL — Cart System
// ══════════════════════

class CartItem {
  final InventoryItem item;
  double discount;
  CartItem({required this.item, this.discount = 0});
  double get total => item.price - discount;
}

class WorkerSellScreen extends StatefulWidget {
  const WorkerSellScreen({super.key});
  @override State<WorkerSellScreen> createState() => _WorkerSellScreenState();
}
class _WorkerSellScreenState extends State<WorkerSellScreen> {
  final List<CartItem> _cart = [];
  bool _selling = false;
  bool _loaded  = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is List) {
        for (final a in args) {
          if (a is InventoryItem && !_cart.any((c) => c.item.crn == a.crn)) {
            _cart.add(CartItem(item: a));
          }
        }
      } else if (args is InventoryItem) {
        _cart.add(CartItem(item: args));
      }
    }
  }

  double get _grandTotal => _cart.fold(0.0, (s, c) => s + c.total);

  Future<void> _addMore() async {
    // Scanner kholo "add_more" mode mein
    final result = await Navigator.pushNamed(
      context, '/worker-scanner', arguments: 'add_more');
    if (result is InventoryItem) {
      if (_cart.any((c) => c.item.crn == result.crn)) {
        showSnack(context, 'Ye item pehle se cart mein hai!', isError: true);
      } else {
        setState(() => _cart.add(CartItem(item: result)));
      }
    }
  }

  Future<void> _completeSell() async {
    final session = AuthService.instance.currentSession;
    if (session == null || _cart.isEmpty) return;
    setState(() => _selling = true);
    double totalCollected = 0;
    final errors = <String>[];
    for (final ci in _cart) {
      final r = await SalesService.instance.sellItem(
        crn: ci.item.crn, quantity: 1,
        discount: ci.discount, worker: session);
      if (r.isSuccess) { totalCollected += ci.total; }
      else { errors.add('${ci.item.name}: ${r.error}'); }
    }
    if (!mounted) return;
    setState(() => _selling = false);
    if (errors.isEmpty) {
      showDialog(
        context: context, barrierDismissible: false,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 68, height: 68,
              decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 38)),
            const SizedBox(height: 16),
            const Text('Sell Complete!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.success)),
            const SizedBox(height: 8),
            Text('${_cart.length} items sold', style: const TextStyle(color: AppColors.textGrey, fontSize: 14)),
            Text('\u20b9${totalCollected.toStringAsFixed(0)} collected',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.success)),
          ]),
          actions: [Center(child: ElevatedButton(
            onPressed: () { Navigator.pop(context); Navigator.pop(context); },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Done')))],
        ));
    } else {
      showSnack(context, 'Errors: ${errors.join(", ")}', isError: true);
    }
  }

  @override
  Widget build(BuildContext ctx) => Scaffold(
    appBar: const GradientAppBar(title: 'Customer Cart'),
    body: _cart.isEmpty
      ? buildEmpty('Koi item nahi.\nScan ya search karke add karo.', Icons.shopping_cart_outlined)
      : Column(children: [
          // Cart items
          Expanded(child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16,16,16,0),
            itemCount: _cart.length,
            itemBuilder: (_, i) {
              final ci = _cart[i];
              final dc = TextEditingController(
                text: ci.discount > 0 ? ci.discount.toStringAsFixed(0) : '');
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10)]),
                child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [
                  // Item row
                  Row(children: [
                    Container(padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.checkroom_rounded, color: AppColors.blue, size: 22)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(ci.item.name,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      Text('${ci.item.crn} \u2022 ${ci.item.brand} \u2022 ${ci.item.size}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                      Text('\u20b9${ci.item.price.toStringAsFixed(0)} • Stock: ${ci.item.quantity}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                    ])),
                    // Remove
                    GestureDetector(
                      onTap: () => setState(() => _cart.removeAt(i)),
                      child: Container(padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.close_rounded, color: AppColors.red, size: 18))),
                  ]),
                  const SizedBox(height: 10),
                  // Discount + total row
                  Row(children: [
                    Expanded(child: TextField(controller: dc,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (v) => setState(() => ci.discount = double.tryParse(v) ?? 0),
                      decoration: InputDecoration(
                        labelText: 'Discount \u20b9',
                        labelStyle: const TextStyle(fontSize: 12),
                        prefixIcon: const Icon(Icons.discount_rounded, color: AppColors.red, size: 18),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300))))),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('MRP: \u20b9${ci.item.price.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textGrey,
                          decoration: TextDecoration.lineThrough)),
                      Text('\u20b9${ci.total.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.w800,
                          fontSize: 16, color: AppColors.success)),
                    ]),
                  ]),
                ])));
            })),

          // Bottom bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12, offset: const Offset(0,-3))]),
            child: Column(children: [
              // Add more
              SizedBox(width: double.infinity, height: 46,
                child: OutlinedButton.icon(
                  onPressed: _addMore,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.blue, width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  icon: const Icon(Icons.add_shopping_cart_rounded, color: AppColors.blue),
                  label: const Text('+ Add More Item',
                    style: TextStyle(color: AppColors.blue,
                      fontWeight: FontWeight.w700, fontSize: 15)))),
              const SizedBox(height: 10),
              // Grand total
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.3))),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('${_cart.length} item${_cart.length > 1 ? "s" : ""} • Grand Total',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                      color: AppColors.textGrey)),
                  Text('\u20b9${_grandTotal.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 22,
                      fontWeight: FontWeight.w900, color: AppColors.success)),
                ])),
              const SizedBox(height: 10),
              // Complete sale
              SizedBox(width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: _selling ? null : _completeSell,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  child: _selling
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.point_of_sale_rounded, size: 22),
                        SizedBox(width: 10),
                        Text('Complete Sale',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700))]))),
            ])),
        ]));
}

// ══════════════════════
//  WORKER HISTORY
// ══════════════════════
class WorkerHistoryScreen extends StatefulWidget {
  const WorkerHistoryScreen({super.key});
  @override State<WorkerHistoryScreen> createState() => _WorkerHistoryScreenState();
}
class _WorkerHistoryScreenState extends State<WorkerHistoryScreen> {
  List<SaleRecord> _sales = [];
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final s = AuthService.instance.currentSession;
    if (s == null) return;
    setState(() => _loading = true);
    final sales = await SalesService.instance.getTodaySales(workerId: s.userId);
    if (!mounted) return;
    setState(() { _sales = sales; _loading = false; });
  }

  @override
  Widget build(BuildContext ctx) {
    final total = _sales.fold<double>(0, (s, i) => s + i.totalAmount);
    return Scaffold(
      appBar: const GradientAppBar(title: "Today's History"),
      body: Column(children: [
        Container(margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(gradient: AppColors.gradientRed, borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Total Earned', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text('₹${total.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 26)),
            ]),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Text('Items Sold', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text('${_sales.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 26)),
            ]),
          ])),
        Expanded(child: _loading ? buildLoader() : _sales.isEmpty
          ? buildEmpty('Aaj koi sell nahi ki.', Icons.history_rounded)
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16,0,16,16),
              itemCount: _sales.length,
              itemBuilder: (_, i) {
                final s = _sales[i];
                return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)]),
                  child: Row(children: [
                    Container(width: 38, height: 38, decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                      child: Center(child: Text('${i+1}', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w800)))),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.itemName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text('${s.crn} • Qty: ${s.quantity}${s.discount > 0 ? " • Disc: ₹${s.discount.toStringAsFixed(0)}" : ""}', style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('₹${s.totalAmount.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w800, fontSize: 13)),
                      Text('${s.soldAt.hour}:${s.soldAt.minute.toString().padLeft(2,'0')}', style: const TextStyle(fontSize: 10, color: AppColors.textGrey)),
                      if (!s.isSynced) const Text('● unsync', style: TextStyle(fontSize: 9, color: AppColors.warning, fontWeight: FontWeight.w600)),
                    ]),
                  ]));
              })),
      ]));
  }
}

// ══════════════════════
//  CREATE ACCOUNT SCREEN
// ══════════════════════
class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});
  @override State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}
class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _name     = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _wKey     = TextEditingController();
  String _role    = 'admin';
  bool _obs       = true;
  bool _saving    = false;

  @override void dispose() { _name.dispose(); _username.dispose(); _password.dispose(); _wKey.dispose(); super.dispose(); }

  Future<void> _create() async {
    if (_name.text.trim().isEmpty || _username.text.trim().isEmpty || _password.text.trim().isEmpty) {
      showSnack(context, 'Saari fields bharo!', isError: true); return;
    }
    if (_role == 'worker' && _wKey.text.trim().isEmpty) {
      showSnack(context, 'Worker key daalo!', isError: true); return;
    }
    setState(() => _saving = true);
    final r = await AuthService.instance.createAccount(
      username:  _username.text.trim(),
      password:  _password.text.trim(),
      name:      _name.text.trim(),
      role:      _role,
      workerKey: _role == 'worker' ? _wKey.text.trim() : '',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (r.isSuccess) {
      showSnack(context, 'Account ban gaya! Ab login karo.');
      Navigator.pop(context);
    } else {
      showSnack(context, r.error!, isError: true);
    }
  }

  @override
  Widget build(BuildContext ctx) => Scaffold(
    appBar: const GradientAppBar(title: 'Naya Account'),
    body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
      // Info banner
      Container(padding: const EdgeInsets.all(14), margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(gradient: AppColors.gradientRB, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          const Icon(Icons.cloud_done_rounded, color: Colors.white, size: 22), const SizedBox(width: 10),
          Expanded(child: Text('Account seedha Google Sheet mein save hoga.\nDuplicate account nahi banega.', style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13))),
        ])),

      Container(padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10)]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionTitle(text: 'Account Details'),
          const SizedBox(height: 16),

          // Role selector
          const Text('Role', style: TextStyle(fontSize: 13, color: AppColors.textGrey, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: GestureDetector(onTap: () => setState(() => _role = 'admin'),
              child: AnimatedContainer(duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: _role == 'admin' ? AppColors.red : AppColors.bgLight, borderRadius: BorderRadius.circular(10), border: Border.all(color: _role == 'admin' ? AppColors.red : Colors.grey.shade300)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.admin_panel_settings_rounded, size: 18, color: _role == 'admin' ? Colors.white : AppColors.textGrey), const SizedBox(width: 6),
                  Text('Admin', style: TextStyle(color: _role == 'admin' ? Colors.white : AppColors.textGrey, fontWeight: FontWeight.w600))])))),
            const SizedBox(width: 10),
            Expanded(child: GestureDetector(onTap: () => setState(() => _role = 'worker'),
              child: AnimatedContainer(duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: _role == 'worker' ? AppColors.blue : AppColors.bgLight, borderRadius: BorderRadius.circular(10), border: Border.all(color: _role == 'worker' ? AppColors.blue : Colors.grey.shade300)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.person_rounded, size: 18, color: _role == 'worker' ? Colors.white : AppColors.textGrey), const SizedBox(width: 6),
                  Text('Worker', style: TextStyle(color: _role == 'worker' ? Colors.white : AppColors.textGrey, fontWeight: FontWeight.w600))])))),
          ]),

          const SizedBox(height: 16),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.badge_rounded, color: AppColors.red))),
          const SizedBox(height: 12),
          TextField(controller: _username, decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.red))),
          const SizedBox(height: 12),
          TextField(controller: _password, obscureText: _obs,
            decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.red),
              suffixIcon: IconButton(icon: Icon(_obs ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.textGrey), onPressed: () => setState(() => _obs = !_obs)))),

          if (_role == 'worker') ...[
            const SizedBox(height: 12),
            TextField(controller: _wKey, textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Worker Key (e.g. WRK-2024-RAM)', prefixIcon: Icon(Icons.vpn_key_rounded, color: AppColors.blue))),
            const SizedBox(height: 8),
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.blue.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(10)),
              child: const Text('Worker key unique honi chahiye. Format: WRK-YEAR-NAME', style: TextStyle(fontSize: 12, color: AppColors.blue))),
          ],

          const SizedBox(height: 20),
          SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
            onPressed: _saving ? null : _create,
            style: ElevatedButton.styleFrom(backgroundColor: _role == 'admin' ? AppColors.red : AppColors.blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            child: _saving
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
              : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.cloud_upload_rounded, size: 20), SizedBox(width: 8),
                  Text('Account Banao & Sheet mein Save karo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700))]),
          )),
        ])),
    ])));
}

// ══════════════════════
//  INVENTORY ALERT — Unit → Items
// ══════════════════════
class InventoryAlertScreen extends StatefulWidget {
  const InventoryAlertScreen({super.key});
  @override State<InventoryAlertScreen> createState() => _InventoryAlertScreenState();
}
class _InventoryAlertScreenState extends State<InventoryAlertScreen> {
  // unit → items map
  Map<String, List<InventoryItem>> _outMap  = {};
  Map<String, List<InventoryItem>> _lowMap  = {};
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final all   = await InventoryService.instance.getAllItems();
    final units = await InventoryService.instance.getAllUnits();

    final Map<String, List<InventoryItem>> outMap = {};
    final Map<String, List<InventoryItem>> lowMap = {};

    for (final u in units) {
      final uItems = all.where((i) => i.unit == u.name).toList();
      final out = uItems.where((i) => i.quantity == 0).toList();
      final low = uItems.where((i) => i.quantity > 0 && i.quantity <= 5).toList();
      if (out.isNotEmpty) outMap[u.name] = out;
      if (low.isNotEmpty) lowMap[u.name] = low;
    }

    if (!mounted) return;
    setState(() { _outMap = outMap; _lowMap = lowMap; _loading = false; });
  }

  @override
  Widget build(BuildContext ctx) => Scaffold(
    appBar: GradientAppBar(title: 'Inventory Alert',
      actions: [IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white), onPressed: _load)]),
    body: _loading ? buildLoader()
      : (_outMap.isEmpty && _lowMap.isEmpty)
        ? buildEmpty('Sab theek hai! ✅\nKoi low stock nahi.', Icons.check_circle_rounded)
        : RefreshIndicator(onRefresh: _load, color: AppColors.red,
            child: ListView(padding: const EdgeInsets.all(16), children: [

              // Summary row
              Row(children: [
                Expanded(child: _statBox('Out of Stock', _outMap.values.fold(0, (s,l) => s+l.length), AppColors.red, Icons.remove_shopping_cart_rounded)),
                const SizedBox(width: 12),
                Expanded(child: _statBox('Low Stock (≤5)', _lowMap.values.fold(0, (s,l) => s+l.length), AppColors.warning, Icons.warning_rounded)),
              ]),
              const SizedBox(height: 20),

              if (_outMap.isNotEmpty) ...[
                _sectionHdr('🔴 Out of Stock', AppColors.red),
                const SizedBox(height: 10),
                ..._outMap.entries.map((e) => _UnitAlertGroup(unitName: e.key, items: e.value, color: AppColors.red)),
                const SizedBox(height: 16),
              ],

              if (_lowMap.isNotEmpty) ...[
                _sectionHdr('🟡 Low Stock (5 ya kam)', AppColors.warning),
                const SizedBox(height: 10),
                ..._lowMap.entries.map((e) => _UnitAlertGroup(unitName: e.key, items: e.value, color: AppColors.warning)),
              ],
            ])));

  Widget _statBox(String l, int v, Color c, IconData icon) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: c.withValues(alpha: 0.3))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: c, size: 22), const SizedBox(height: 8),
      Text('$v', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: c)),
      Text(l, style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w600)),
    ]));

  Widget _sectionHdr(String t, Color c) => Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: c.withValues(alpha: 0.3))),
    child: Text(t, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: c)));
}

class _UnitAlertGroup extends StatelessWidget {
  final String unitName;
  final List<InventoryItem> items;
  final Color color;
  const _UnitAlertGroup({required this.unitName, required this.items, required this.color});

  @override
  Widget build(BuildContext ctx) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Unit header
      Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.08),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14))),
        child: Row(children: [
          Icon(Icons.folder_rounded, color: color, size: 18),
          const SizedBox(width: 8),
          Text(unitName, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: color)),
          const Spacer(),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
            child: Text('${items.length} items', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
        ])),
      // Items list
      ...items.map((item) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
        child: Row(children: [
          const SizedBox(width: 4),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            Text('CRN: ${item.crn}', style: const TextStyle(fontSize: 11, color: AppColors.textGrey, fontFamily: 'monospace')),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
            child: Text(item.quantity == 0 ? 'OUT' : 'Qty: ${item.quantity}',
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
        ]))),
    ]));
}
