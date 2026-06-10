// ╔══════════════════════════════════════════════════════════════╗
// ║    CLOTHING MANAGEMENT SYSTEM — UI + BACKEND CONNECTED       ║
// ║    Dono files ek folder mein rakho:  main.dart, backend.dart ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
        const SizedBox(height: 30),
        Text('v1.0 — Hybrid Mode', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
        const SizedBox(height: 30),
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
    final rets  = await ReturnService.instance.getTodayReturns();
    if (!mounted) return;
    setState(() { _items = inv.length; _revenue = rev; _workers = wrks.where((w)=>w.isActive).length; _returns = rets.length; _loading = false; });
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
                _sCard('Returns Today', '$_returns', Icons.assignment_return_rounded, const LinearGradient(colors: [Color(0xFFE65100), Color(0xFFFF9800)], begin: Alignment.topLeft, end: Alignment.bottomRight), '/return-inventory'),
              ]),
              const SizedBox(height: 22),
              const SectionTitle(text: 'Quick Actions'),
              const SizedBox(height: 14),
              GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 3, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.88, children: [
                _nCard('Worker\nKeys', Icons.vpn_key_rounded, AppColors.red, route: '/key-manage'),
                _nCard('Inventory\nSetup', Icons.add_box_rounded, AppColors.blue, route: '/inventory-setup'),
                _nCard('Inventory\nDetail', Icons.list_alt_rounded, const Color(0xFF2E7D32), route: '/inventory-detail'),
                _nCard('Total\nSell', Icons.bar_chart_rounded, const Color(0xFFF57C00), route: '/total-sell'),
                _nCard('Returns', Icons.assignment_return_rounded, const Color(0xFF6A1B9A), route: '/return-inventory'),
                _nCard('Export\nExcel', Icons.download_rounded, const Color(0xFF00838F), onTap: () async {
                  final r = await ExcelService.instance.exportInventory();
                  if (context.mounted) r.isSuccess ? showSnack(context, 'Saved: ${r.data}') : showSnack(context, r.error!, isError: true);
                }),
              ]),
            ]))),
        ]));
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
        Switch(value: k.isActive, onChanged: (_) => onToggle(), activeThumbColor: AppColors.success),
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
//  INVENTORY SETUP
// ══════════════════════
class InventorySetupScreen extends StatefulWidget {
  const InventorySetupScreen({super.key});
  @override State<InventorySetupScreen> createState() => _InventorySetupScreenState();
}
class _InventorySetupScreenState extends State<InventorySetupScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  // Unit fields
  final _uName = TextEditingController();
  final _uQty  = TextEditingController();
  List<InventoryUnit> _units = [];
  // Item fields
  final _iName  = TextEditingController();
  final _iCrn   = TextEditingController();
  final _iBrand = TextEditingController();
  final _iPrice = TextEditingController();
  final _iQty   = TextEditingController();
  String _gender = 'Men', _size = 'M', _unit = '';
  bool _saving = false;

  final _genders = ['Men','Women','Kids','Unisex'];
  final _sizes   = ['XS','S','M','L','XL','XXL','XXXL','Free Size'];

  @override void initState() { super.initState(); _tab = TabController(length: 2, vsync: this); _loadUnits(); }
  @override void dispose() { _tab.dispose(); _uName.dispose(); _uQty.dispose(); _iName.dispose(); _iCrn.dispose(); _iBrand.dispose(); _iPrice.dispose(); _iQty.dispose(); super.dispose(); }

  Future<void> _loadUnits() async {
    final u = await InventoryService.instance.getAllUnits();
    if (!mounted) return;
    setState(() { _units = u; if (u.isNotEmpty && _unit.isEmpty) _unit = u.first.name; });
  }

  Future<void> _saveUnit() async {
    if (_uName.text.trim().isEmpty || _uQty.text.trim().isEmpty) return;
    final r = await InventoryService.instance.addUnit(InventoryUnit(name: _uName.text.trim(), totalQuantity: int.tryParse(_uQty.text) ?? 0));
    if (!mounted) return;
    if (r.isSuccess) { showSnack(context, 'Unit saved!'); _uName.clear(); _uQty.clear(); _loadUnits(); }
    else { showSnack(context, r.error!, isError: true); }
  }

  Future<void> _saveItem() async {
    if (_iName.text.trim().isEmpty || _iCrn.text.trim().isEmpty || _iPrice.text.trim().isEmpty || _iQty.text.trim().isEmpty) {
      showSnack(context, 'Saari fields bharo!', isError: true); return;
    }
    if (_units.isEmpty) { showSnack(context, 'Pehle unit banao!', isError: true); return; }
    setState(() => _saving = true);
    final r = await InventoryService.instance.addItem(InventoryItem(
      crn: _iCrn.text.trim().toUpperCase(), name: _iName.text.trim(),
      gender: _gender, size: _size, unit: _unit, brand: _iBrand.text.trim(),
      price: double.tryParse(_iPrice.text) ?? 0, quantity: int.tryParse(_iQty.text) ?? 0));
    if (!mounted) return;
    setState(() => _saving = false);
    if (r.isSuccess) {
      showSnack(context, 'Item saved! Excel updated ✓');
      _iName.clear(); _iCrn.clear(); _iBrand.clear(); _iPrice.clear(); _iQty.clear();
    } else { showSnack(context, r.error!, isError: true); }
  }

  @override
  Widget build(BuildContext ctx) => Scaffold(
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      flexibleSpace: Container(decoration: const BoxDecoration(gradient: AppColors.gradientRB)),
      title: const Text('Inventory Setup'),
      leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white), onPressed: () => Navigator.pop(ctx)),
      bottom: TabBar(controller: _tab, indicatorColor: Colors.white, indicatorWeight: 3,
        labelColor: Colors.white, unselectedLabelColor: Colors.white70,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700),
        tabs: const [Tab(text: 'Unit Setup', icon: Icon(Icons.straighten_rounded, size: 18)), Tab(text: 'Add Item', icon: Icon(Icons.add_shopping_cart_rounded, size: 18))])),
    body: TabBarView(controller: _tab, children: [_unitTab(), _itemTab()]));

  Widget _unitTab() => ListView(padding: const EdgeInsets.all(16), children: [
    _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionTitle(text: 'Add Unit'), const SizedBox(height: 16),
      TextField(controller: _uName, decoration: const InputDecoration(labelText: 'Unit Name (Piece, Set...)', prefixIcon: Icon(Icons.category_rounded, color: AppColors.red))),
      const SizedBox(height: 12),
      TextField(controller: _uQty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Total Quantity', prefixIcon: Icon(Icons.numbers_rounded, color: AppColors.red))),
      const SizedBox(height: 16),
      SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _saveUnit, icon: const Icon(Icons.save_rounded), label: const Text('Save Unit'))),
    ])),
    const SizedBox(height: 16),
    const SectionTitle(text: 'All Units'), const SizedBox(height: 12),
    if (_units.isEmpty) buildEmpty('Koi unit nahi.\nAdd karo upar se.', Icons.straighten_rounded),
    ..._units.map((u) {
      final pct = u.totalQuantity == 0 ? 0.0 : u.usedQuantity / u.totalQuantity;
      return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.straighten_rounded, color: AppColors.red, size: 18)),
            const SizedBox(width: 10), Text(u.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const Spacer(), Text('${u.usedQuantity}/${u.totalQuantity}', style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
          ]),
          const SizedBox(height: 10),
          ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: pct, minHeight: 7, backgroundColor: Colors.grey.shade200, valueColor: AlwaysStoppedAnimation(pct > 0.8 ? AppColors.red : AppColors.blue))),
        ]));
    }),
  ]);

  Widget _itemTab() => ListView(padding: const EdgeInsets.all(16), children: [
    _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionTitle(text: 'Cloth Details'), const SizedBox(height: 16),
      TextField(controller: _iName, decoration: const InputDecoration(labelText: 'Cloth Name', prefixIcon: Icon(Icons.checkroom_rounded, color: AppColors.blue))),
      const SizedBox(height: 12),
      TextField(controller: _iCrn, textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(labelText: 'CRN Number', prefixIcon: Icon(Icons.qr_code_rounded, color: AppColors.blue), hintText: 'CLT-2024-001')),
      const SizedBox(height: 14),
      const Text('Gender', style: TextStyle(fontSize: 13, color: AppColors.textGrey, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, children: _genders.map((g) {
        final sel = _gender == g;
        return GestureDetector(onTap: () => setState(() => _gender = g),
          child: AnimatedContainer(duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: sel ? AppColors.blue : AppColors.bgLight, borderRadius: BorderRadius.circular(20), border: Border.all(color: sel ? AppColors.blue : Colors.grey.shade300)),
            child: Text(g, style: TextStyle(color: sel ? Colors.white : AppColors.textDark, fontWeight: sel ? FontWeight.w700 : FontWeight.w500, fontSize: 13))));
      }).toList()),
      const SizedBox(height: 14),
      const Text('Size', style: TextStyle(fontSize: 13, color: AppColors.textGrey, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: _sizes.map((s) {
        final sel = _size == s;
        return GestureDetector(onTap: () => setState(() => _size = s),
          child: AnimatedContainer(duration: const Duration(milliseconds: 200),
            width: 52, height: 36, alignment: Alignment.center,
            decoration: BoxDecoration(color: sel ? AppColors.red : AppColors.bgLight, borderRadius: BorderRadius.circular(8), border: Border.all(color: sel ? AppColors.red : Colors.grey.shade300)),
            child: Text(s, style: TextStyle(color: sel ? Colors.white : AppColors.textDark, fontWeight: sel ? FontWeight.w700 : FontWeight.w500, fontSize: 11))));
      }).toList()),
      const SizedBox(height: 14),
      if (_units.isNotEmpty)
        DropdownButtonFormField<String>(
          initialValue: _unit.isEmpty ? _units.first.name : _unit,
          decoration: const InputDecoration(labelText: 'Unit', prefixIcon: Icon(Icons.straighten_rounded, color: AppColors.blue)),
          items: _units.map((u) => DropdownMenuItem(value: u.name, child: Text(u.name))).toList(),
          onChanged: (v) => setState(() => _unit = v!))
      else Container(padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
        child: const Text('Pehle "Unit Setup" tab mein unit banao.', style: TextStyle(color: AppColors.warning, fontSize: 13))),
      const SizedBox(height: 12),
      TextField(controller: _iBrand, decoration: const InputDecoration(labelText: 'Brand', prefixIcon: Icon(Icons.branding_watermark_rounded, color: AppColors.blue))),
      const SizedBox(height: 12),
      TextField(controller: _iPrice, keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Price (₹)', prefixIcon: Icon(Icons.currency_rupee_rounded, color: AppColors.blue))),
      const SizedBox(height: 12),
      TextField(controller: _iQty, keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Quantity', prefixIcon: Icon(Icons.numbers_rounded, color: AppColors.blue))),
      const SizedBox(height: 20),
      SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(
        onPressed: _saving ? null : _saveItem,
        icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save_rounded),
        label: const Text('Save Item'))),
    ])),
    const SizedBox(height: 14),
    Row(children: [
      Expanded(child: _fileBtn(Icons.upload_file_rounded, 'Upload Excel', AppColors.success, () async {
        final r = await ExcelService.instance.importFromExcel();
        if (context.mounted) r.isSuccess ? showSnack(context, '${r.data} items imported!') : showSnack(context, r.error!, isError: true);
      })),
      const SizedBox(width: 12),
      Expanded(child: _fileBtn(Icons.download_rounded, 'Download Excel', AppColors.blue, () async {
        final r = await ExcelService.instance.exportInventory();
        if (context.mounted) r.isSuccess ? showSnack(context, 'Saved ✓') : showSnack(context, r.error!, isError: true);
      })),
    ]),
    const SizedBox(height: 20),
  ]);

  Widget _card(Widget child) => Container(padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10)]),
    child: child);

  Widget _fileBtn(IconData icon, String label, Color c, VoidCallback onTap) =>
    GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: c.withValues(alpha: 0.4))),
      child: Column(children: [Icon(icon, color: c, size: 26), const SizedBox(height: 6), Text(label, style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 13))])));
}

// ══════════════════════
//  INVENTORY DETAIL
// ══════════════════════
class InventoryDetailScreen extends StatefulWidget {
  const InventoryDetailScreen({super.key});
  @override State<InventoryDetailScreen> createState() => _InventoryDetailScreenState();
}
class _InventoryDetailScreenState extends State<InventoryDetailScreen> {
  List<InventoryItem> _items = [];
  bool _loading = true;
  final _search = TextEditingController();
  String _gender = 'All';
  final _genders = ['All','Men','Women','Kids','Unisex'];

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await InventoryService.instance.getAllItems(
      gender: _gender == 'All' ? null : _gender,
      searchQuery: _search.text.trim());
    if (!mounted) return;
    setState(() { _items = items; _loading = false; });
  }

  @override
  Widget build(BuildContext ctx) => Scaffold(
    appBar: const GradientAppBar(title: 'Inventory Detail'),
    body: Column(children: [
      Container(color: Colors.white, padding: const EdgeInsets.fromLTRB(16,12,16,8),
        child: TextField(controller: _search, onChanged: (_) => _load(),
          decoration: InputDecoration(hintText: 'Search by name, CRN, brand...',
            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.blue),
            suffixIcon: _search.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear_rounded), onPressed: () { _search.clear(); _load(); }) : null))),
      Container(color: Colors.white, height: 50,
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          children: _genders.map((g) {
            final sel = _gender == g;
            return GestureDetector(onTap: () { setState(() => _gender = g); _load(); },
              child: AnimatedContainer(duration: const Duration(milliseconds: 200), margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(color: sel ? AppColors.red : Colors.grey.shade100, borderRadius: BorderRadius.circular(20), border: Border.all(color: sel ? AppColors.red : Colors.grey.shade300)),
                child: Text(g, style: TextStyle(color: sel ? Colors.white : AppColors.textDark, fontWeight: sel ? FontWeight.w700 : FontWeight.w500, fontSize: 13))));
          }).toList())),
      Padding(padding: const EdgeInsets.fromLTRB(16,10,16,4),
        child: Row(children: [Text('${_items.length} items', style: const TextStyle(color: AppColors.textGrey, fontSize: 13))])),
      Expanded(child: _loading ? buildLoader() : _items.isEmpty
        ? buildEmpty('Koi item nahi mila.', Icons.inventory_2_rounded)
        : ListView.builder(
            padding: const EdgeInsets.fromLTRB(16,4,16,16),
            itemCount: _items.length,
            itemBuilder: (_, i) => _InvCard(item: _items[i], onDelete: () async {
              await InventoryService.instance.deleteItem(_items[i].id!); _load();
            }))),
    ]));
}

class _InvCard extends StatelessWidget {
  final InventoryItem item; final VoidCallback onDelete;
  const _InvCard({required this.item, required this.onDelete});
  Color get _gc { switch(item.gender) { case 'Women': return AppColors.red; case 'Kids': return const Color(0xFF6A1B9A); case 'Unisex': return const Color(0xFF00838F); default: return AppColors.blue; } }
  @override
  Widget build(BuildContext ctx) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10)]),
    child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
      Container(width: 48, height: 48, decoration: BoxDecoration(color: _gc.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.checkroom_rounded, color: _gc, size: 24)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 4),
        Wrap(spacing: 6, children: [chip(item.gender, _gc), chip(item.size, AppColors.textGrey), chip(item.unit, AppColors.blue)]),
        const SizedBox(height: 3),
        Text('${item.crn} • ${item.brand}', style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
      ])),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('₹${item.price.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.red)),
        Text('Qty: ${item.quantity}', style: TextStyle(fontSize: 12, color: item.quantity < 5 ? AppColors.red : AppColors.textGrey, fontWeight: item.quantity < 5 ? FontWeight.w700 : FontWeight.w400)),
        GestureDetector(
          onTap: () => showDialog(context: ctx, builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Delete?'), content: Text('"${item.name}" delete hoga.'),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(onPressed: () { Navigator.pop(ctx); onDelete(); }, style: ElevatedButton.styleFrom(backgroundColor: AppColors.red), child: const Text('Delete'))])),
          child: const Icon(Icons.delete_outline_rounded, color: AppColors.textGrey, size: 18)),
      ]),
    ])));
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
        ]));
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
//  WORKER SCANNER
// ══════════════════════
class WorkerScannerScreen extends StatelessWidget {
  const WorkerScannerScreen({super.key});
  @override
  Widget build(BuildContext ctx) {
    final ctrl = TextEditingController();
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white), onPressed: () => Navigator.pop(ctx)),
        title: const Text('Scan QR / CRN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        actions: [IconButton(icon: const Icon(Icons.flash_on_rounded, color: Colors.white), onPressed: () {})]),
      body: Stack(children: [
        Container(color: const Color(0xFF1A1A1A), child: const Center(child: Icon(Icons.camera_alt_rounded, size: 80, color: Colors.white10))),
        Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          SizedBox(width: 240, height: 240, child: Stack(children: [
            ..._corners(),
            TweenAnimationBuilder<double>(tween: Tween(begin: 0, end: 1), duration: const Duration(seconds: 2),
              builder: (_, v, __) => Positioned(top: v * 220, left: 10, right: 10,
                child: Container(height: 2, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Colors.transparent, AppColors.red, Colors.transparent]), borderRadius: BorderRadius.circular(2)))),
              onEnd: () {}),
          ])),
          const SizedBox(height: 20),
          const Text('QR ya CRN barcode dikhao', style: TextStyle(color: Colors.white60, fontSize: 13)),
          const SizedBox(height: 4),
          const Text('(mobile_scanner package se connect karo)', style: TextStyle(color: Colors.white30, fontSize: 11)),
        ])),
        Positioned(bottom: 0, left: 0, right: 0,
          child: Container(
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.85), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Ya CRN manually daalo:', style: TextStyle(color: Colors.white60, fontSize: 13)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextField(controller: ctrl, style: const TextStyle(color: Colors.white), textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(hintText: 'CRN...', hintStyle: const TextStyle(color: Colors.white38), fillColor: Colors.white12, filled: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)))),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () async {
                    final crn = ctrl.text.trim().toUpperCase();
                    if (crn.isEmpty) return;
                    final item = await InventoryService.instance.getItemByCrn(crn);
                    if (!ctx.mounted) return;
                    if (item != null) { Navigator.pushNamed(ctx, '/worker-sell', arguments: item); }
                    else { showSnack(ctx, 'CRN "$crn" nahi mila!', isError: true); }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18)),
                  child: const Icon(Icons.arrow_forward_rounded, color: Colors.white)),
              ]),
            ])));
      ]));
  }
  static List<Widget> _corners() {
    const c = AppColors.red; const w = 3.0; const l = 28.0;
    return [
      Positioned(top: 0, left: 0, child: Container(width: l, height: w, color: c)),
      Positioned(top: 0, left: 0, child: Container(width: w, height: l, color: c)),
      Positioned(top: 0, right: 0, child: Container(width: l, height: w, color: c)),
      Positioned(top: 0, right: 0, child: Container(width: w, height: l, color: c)),
      Positioned(bottom: 0, left: 0, child: Container(width: l, height: w, color: c)),
      Positioned(bottom: 0, left: 0, child: Container(width: w, height: l, color: c)),
      Positioned(bottom: 0, right: 0, child: Container(width: l, height: w, color: c)),
      Positioned(bottom: 0, right: 0, child: Container(width: w, height: l, color: c)),
    ];
  }
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
  bool _searched = false, _loading = false;

  Future<void> _search() async {
    if (_ctrl.text.trim().isEmpty) return;
    setState(() { _loading = true; _searched = true; });
    final items = await InventoryService.instance.getAllItems(searchQuery: _ctrl.text.trim());
    if (!mounted) return;
    setState(() { _results = items; _loading = false; });
  }

  @override
  Widget build(BuildContext ctx) => Scaffold(
    appBar: const GradientAppBar(title: 'Search Inventory'),
    body: Column(children: [
      Container(color: Colors.white, padding: const EdgeInsets.all(16),
        child: Row(children: [
          Expanded(child: TextField(controller: _ctrl, onSubmitted: (_) => _search(),
            decoration: const InputDecoration(hintText: 'Name ya CRN...', prefixIcon: Icon(Icons.search_rounded, color: AppColors.blue)))),
          const SizedBox(width: 10),
          ElevatedButton(onPressed: _search,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16)),
            child: const Text('Search')),
        ])),
      Expanded(child: !_searched
        ? buildEmpty('Cloth ka naam ya CRN search karo.', Icons.search_rounded)
        : _loading ? buildLoader()
        : _results.isEmpty ? buildEmpty('Koi item nahi mila.', Icons.search_off_rounded)
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _results.length,
            itemBuilder: (_, i) {
              final item = _results[i];
              return GestureDetector(
                onTap: item.quantity > 0 ? () => Navigator.pushNamed(ctx, '/worker-sell', arguments: item) : null,
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
//  WORKER SELL
// ══════════════════════
class WorkerSellScreen extends StatefulWidget {
  const WorkerSellScreen({super.key});
  @override State<WorkerSellScreen> createState() => _WorkerSellScreenState();
}
class _WorkerSellScreenState extends State<WorkerSellScreen> {
  InventoryItem? _item;
  int _qty = 1; double _disc = 0;
  final _discCtrl = TextEditingController();
  bool _selling = false;

  @override void didChangeDependencies() {
    super.didChangeDependencies();
    final a = ModalRoute.of(context)?.settings.arguments;
    if (a is InventoryItem) _item = a;
  }

  double get _sub   => (_item?.price ?? 0) * _qty;
  double get _total => _sub - _disc;

  Future<void> _sell() async {
    final session = AuthService.instance.currentSession;
    if (session == null || _item == null) return;
    setState(() => _selling = true);
    final r = await SalesService.instance.sellItem(crn: _item!.crn, quantity: _qty, discount: _disc, worker: session);
    if (!mounted) return;
    setState(() => _selling = false);
    if (r.isSuccess) {
      showDialog(context: context, barrierDismissible: false, builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 68, height: 68, decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle), child: const Icon(Icons.check_rounded, color: Colors.white, size: 38)),
          const SizedBox(height: 16),
          const Text('Sell Complete!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.success)),
          const SizedBox(height: 6),
          Text('₹${_total.toStringAsFixed(0)} collected', style: const TextStyle(fontSize: 16, color: AppColors.textGrey)),
        ]),
        actions: [Center(child: ElevatedButton(
          onPressed: () { Navigator.pop(context); Navigator.pop(context); },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.success), child: const Text('Done')))],
      ));
    } else { showSnack(context, r.error!, isError: true); }
  }

  @override
  Widget build(BuildContext ctx) {
    final item = _item;
    if (item == null) return Scaffold(appBar: const GradientAppBar(title: 'Sell'), body: buildEmpty('Item load nahi hua.', Icons.error_outline));
    return Scaffold(
      appBar: const GradientAppBar(title: 'Complete Sale'),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(gradient: AppColors.gradientBlue, borderRadius: BorderRadius.circular(18)),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.checkroom_rounded, color: Colors.white, size: 30)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
              Text('${item.brand} • ${item.gender} • ${item.size}', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
              Text('CRN: ${item.crn} • Stock: ${item.quantity}', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
            ])),
          ])),
        const SizedBox(height: 16),
        Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10)]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionTitle(text: 'Sale Details'), const SizedBox(height: 16),
            const Text('Quantity', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textGrey, fontSize: 13)), const SizedBox(height: 10),
            Row(children: [
              _qb(Icons.remove_rounded, () { if (_qty > 1) setState(() => _qty--); }),
              const SizedBox(width: 20),
              Text('$_qty', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              const SizedBox(width: 20),
              _qb(Icons.add_rounded, () { if (_qty < item.quantity) setState(() => _qty++); }),
              const Spacer(),
              Text('Max: ${item.quantity}', style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
            ]),
            const SizedBox(height: 16), const Divider(), const SizedBox(height: 14),
            TextField(controller: _discCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) => setState(() => _disc = double.tryParse(v) ?? 0),
              decoration: const InputDecoration(labelText: 'Discount (₹)', prefixIcon: Icon(Icons.discount_rounded, color: AppColors.red))),
            const SizedBox(height: 16),
            Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.bgLight, borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                _pr('Unit Price', '₹${item.price.toStringAsFixed(0)}'),
                const SizedBox(height: 7), _pr('Quantity', '× $_qty'),
                const SizedBox(height: 7), _pr('Subtotal', '₹${_sub.toStringAsFixed(0)}'),
                if (_disc > 0) ...[const SizedBox(height: 7), _pr('Discount', '-₹${_disc.toStringAsFixed(0)}', color: AppColors.red)],
                const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider()),
                _pr('Total', '₹${_total.toStringAsFixed(0)}', bold: true, color: AppColors.success),
              ])),
          ])),
        const SizedBox(height: 18),
        SizedBox(width: double.infinity, height: 54, child: ElevatedButton(
          onPressed: _selling ? null : _sell,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          child: _selling
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.point_of_sale_rounded, size: 22), SizedBox(width: 10), Text('Complete Sale', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700))]))),
        const SizedBox(height: 20),
      ])));
  }

  Widget _qb(IconData icon, VoidCallback fn) => GestureDetector(onTap: fn,
    child: Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.bgLight, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)), child: Icon(icon, color: AppColors.red, size: 20)));

  Widget _pr(String l, String v, {bool bold = false, Color? color}) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(l, style: TextStyle(fontSize: 13, color: AppColors.textGrey, fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
    Text(v, style: TextStyle(fontSize: bold ? 16 : 14, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: color ?? AppColors.textDark)),
  ]);
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
