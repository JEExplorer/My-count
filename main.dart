import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ShopDb.instance.database;
  runApp(const AfghanBusinessPro());
}

const green = Color(0xFF087F5B);
const ink = Color(0xFF17352D);
const bg = Color(0xFFF4F7F5);

class AfghanBusinessPro extends StatelessWidget {
  const AfghanBusinessPro({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'افغان بیزنس پرو',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        scaffoldBackgroundColor: bg,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: ink,
          centerTitle: false,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF6F8F7),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFE8EEEA)),
          ),
        ),
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: HomePage(),
      ),
    );
  }
}

String afn(num value) => '${value.toStringAsFixed(0)} افغانی';
String dateText(int millis) =>
    '${DateTime.fromMillisecondsSinceEpoch(millis).year}/${DateTime.fromMillisecondsSinceEpoch(millis).month.toString().padLeft(2, '0')}/${DateTime.fromMillisecondsSinceEpoch(millis).day.toString().padLeft(2, '0')}';

class ShopDb {
  ShopDb._();
  static final ShopDb instance = ShopDb._();
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final root = await getDatabasesPath();
    _db = await openDatabase(
      p.join(root, 'afghan_business_pro.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE products(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            category TEXT NOT NULL DEFAULT '',
            buyPrice REAL NOT NULL DEFAULT 0,
            sellPrice REAL NOT NULL DEFAULT 0,
            stock INTEGER NOT NULL DEFAULT 0,
            minStock INTEGER NOT NULL DEFAULT 3,
            createdAt INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE sales(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            productId INTEGER NOT NULL,
            productName TEXT NOT NULL,
            quantity INTEGER NOT NULL,
            unitPrice REAL NOT NULL,
            total REAL NOT NULL,
            customer TEXT NOT NULL DEFAULT '',
            createdAt INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          mainAxisAlignment: MainAxisAlignment.center,
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            customer TEXT NOT NULL,
            phone TEXT NOT NULL DEFAULT '',
            note TEXT NOT NULL DEFAULT '',
            original REAL NOT NULL,
            paid REAL NOT NULL DEFAULT 0,
            createdAt INTEGER NOT NULL
          )
        ''');
      },
    );
    return _db!;
  }

  Future<List<Map<String, Object?>>> products({String search = ''}) async {
    final db = await database;
    if (search.trim().isEmpty) {
      return db.query('products', orderBy: 'name COLLATE NOCASE');
    }
    return db.query('products',
        where: 'name LIKE ? OR category LIKE ?',
        whereArgs: ['%${search.trim()}%', '%${search.trim()}%'],
        orderBy: 'name COLLATE NOCASE');
  }

  Future<int> saveProduct(Map<String, Object?> values, {int? id}) async {
    final db = await database;
    if (id == null) {
      return db.insert('products', {...values, 'createdAt': DateTime.now().millisecondsSinceEpoch});
    }
    return db.update('products', values, where: 'id=?', whereArgs: [id]);
  }

  Future<int> deleteProduct(int id) async {
    final db = await database;
    final used = await db.query('sales', columns: ['id'], where: 'productId=?', whereArgs: [id], limit: 1);
    if (used.isNotEmpty) throw Exception('برای این جنس فروش ثبت شده؛ حذف آن مجاز نیست.');
    return db.delete('products', where: 'id=?', whereArgs: [id]);
  }

  Future<void> makeSale({
    required int productId,
    required String productName,
    required int quantity,
    required double unitPrice,
    required String customer,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query('products', where: 'id=?', whereArgs: [productId], limit: 1);
      if (rows.isEmpty) throw Exception('جنس پیدا نشد.');
      final current = rows.first['stock'] as int;
      if (quantity <= 0 || quantity > current) throw Exception('تعداد فروش از موجودی بیشتر است.');
      await txn.update('products', {'stock': current - quantity}, where: 'id=?', whereArgs: [productId]);
      await txn.insert('sales', {
        'productId': productId,
        'productName': productName,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'total': quantity * unitPrice,
        'customer': customer.trim(),
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
    });
  }

  Future<List<Map<String, Object?>>> sales() async =>
      (await database).query('sales', orderBy: 'createdAt DESC');

  Future<List<Map<String, Object?>>> debts() async =>
      (await database).query('debts', orderBy: 'createdAt DESC');

  Future<int> addDebt({
    required String customer,
    required String phone,
    required String note,
    required double amount,
  }) async {
    return (await database).insert('debts', {
      'customer': customer.trim(),
      'phone': phone.trim(),
      'note': note.trim(),
      'original': amount,
      'paid': 0.0,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> repayDebt(int id, double amount) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query('debts', where: 'id=?', whereArgs: [id], limit: 1);
      if (rows.isEmpty) throw Exception('قرض پیدا نشد.');
      final original = (rows.first['original'] as num).toDouble();
      final paid = (rows.first['paid'] as num).toDouble();
      if (amount <= 0 || paid + amount > original) throw Exception('مبلغ پرداخت درست نیست.');
      await txn.update('debts', {'paid': paid + amount}, where: 'id=?', whereArgs: [id]);
    });
  }

  Future<Map<String, num>> stats() async {
    final db = await database;
    final prod = await db.rawQuery('SELECT COUNT(*) c, COALESCE(SUM(stock*buyPrice),0) v FROM products');
    final sale = await db.rawQuery('SELECT COALESCE(SUM(total),0) total FROM sales');
    final debt = await db.rawQuery('SELECT COALESCE(SUM(original-paid),0) total FROM debts');
    final low = await db.rawQuery('SELECT COUNT(*) c FROM products WHERE stock<=minStock');
    return {
      'productCount': (prod.first['c'] as num),
      'stockValue': (prod.first['v'] as num),
      'salesTotal': (sale.first['total'] as num),
      'debtTotal': (debt.first['total'] as num),
      'lowCount': (low.first['c'] as num),
    };
  }

  Future<void> exportCsv(String table, List<String> columns, String fileName) async {
    const allowed = {'products', 'sales', 'debts'};
    if (!allowed.contains(table)) throw Exception('نوع فایل معتبر نیست.');
    final db = await database;
    final rows = await db.query(table, orderBy: 'id DESC');
    final csvRows = <List<dynamic>>[columns];
    for (final row in rows) {
      csvRows.add(columns.map((key) => row[key] ?? '').toList());
    }
    final content = '\uFEFF${const ListToCsvConverter().convert(csvRows)}';
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, fileName));
    await file.writeAsString(content, encoding: utf8);
    await Share.shareXFiles([XFile(file.path)], text: 'گزارش افغان بیزنس پرو');
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int index = 0;
  int refreshKey = 0;
  void refresh() => setState(() => refreshKey++);

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(key: ValueKey('d$refreshKey'), onRefresh: refresh, onNavigate: (i) => setState(() => index = i)),
      ProductsPage(key: ValueKey('p$refreshKey'), onChanged: refresh),
      SalesPage(key: ValueKey('s$refreshKey'), onChanged: refresh),
      DebtsPage(key: ValueKey('b$refreshKey'), onChanged: refresh),
      ReportsPage(key: ValueKey('r$refreshKey')),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('افغان بیزنس پرو', style: TextStyle(fontWeight: FontWeight.w900)),
          Text('مدیریت هوشمند دکان', style: TextStyle(fontSize: 12, color: Colors.black54)),
        ]),
        actions: [
          IconButton(
            tooltip: 'تازه‌سازی',
            onPressed: refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (v) => setState(() => index = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.space_dashboard_outlined), selectedIcon: Icon(Icons.space_dashboard), label: 'خانه'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'اجناس'),
          NavigationDestination(icon: Icon(Icons.point_of_sale_outlined), selectedIcon: Icon(Icons.point_of_sale), label: 'فروش'),
          NavigationDestination(icon: Icon(Icons.people_alt_outlined), selectedIcon: Icon(Icons.people_alt), label: 'قرض‌ها'),
          NavigationDestination(icon: Icon(Icons.analytics_outlined), selectedIcon: Icon(Icons.analytics), label: 'گزارش'),
        ],
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  final VoidCallback onRefresh;
  final ValueChanged<int> onNavigate;
  const DashboardPage({super.key, required this.onRefresh, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, num>>(
      future: ShopDb.instance.stats(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final s = snap.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF087F5B), Color(0xFF0CA678)]),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.storefront_rounded, color: Colors.white, size: 34),
                SizedBox(height: 14),
                Text('دکان خود را آسان مدیریت کنید', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.bold)),
                SizedBox(height: 6),
                Text('فروش، موجودی، قرض مشتریان و گزارش‌ها در یک‌جا', style: TextStyle(color: Colors.white70)),
              ]),
            ),
            const SizedBox(height: 16),
            Wrap(spacing: 12, runSpacing: 12, children: [
              StatCard(title: 'تعداد اجناس', value: '${s['productCount']}', icon: Icons.inventory_2, color: const Color(0xFF1971C2)),
              StatCard(title: 'ارزش موجودی', value: afn(s['stockValue']!), icon: Icons.account_balance_wallet, color: green),
              StatCard(title: 'مجموع فروش', value: afn(s['salesTotal']!), icon: Icons.trending_up, color: const Color(0xFF7048E8)),
              StatCard(title: 'قرض باقی‌مانده', value: afn(s['debtTotal']!), icon: Icons.people, color: const Color(0xFFE67700)),
            ]),
            const SizedBox(height: 12),
            Card(child: ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFFFFF3BF), child: Icon(Icons.warning_amber_rounded, color: Color(0xFFE67700))),
              title: const Text('اجناس کم‌موجود', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${s['lowCount']} جنس در حداقل موجودی یا کمتر قرار دارد.'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => onNavigate(1),
            )),
            const SizedBox(height: 12),
            const Text('دسترسی سریع', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: QuickAction(icon: Icons.add_box_outlined, label: 'افزودن جنس', onTap: () => onNavigate(1))),
              const SizedBox(width: 10),
              Expanded(child: QuickAction(icon: Icons.point_of_sale, label: 'ثبت فروش', onTap: () => onNavigate(2))),
              const SizedBox(width: 10),
              Expanded(child: QuickAction(icon: Icons.person_add_alt, label: 'ثبت قرض', onTap: () => onNavigate(3))),
            ]),
            const SizedBox(height: 12),
            const Text('نکته: از بخش گزارش می‌توانید اطلاعات را به فایل CSV صادر کنید.', style: TextStyle(color: Colors.black54)),
          ],
        );
      },
    );
  }
}

class StatCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;
  const StatCard({super.key, required this.title, required this.value, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: (MediaQuery.of(context).size.width - 44) / 2,
    child: Card(child: Padding(
      padding: const EdgeInsets.all(15),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(backgroundColor: color.withValues(alpha: .12), child: Icon(icon, color: color)),
        const SizedBox(height: 13),
        Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: ink)),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(color: Colors.black54, fontSize: 12)),
      ]),
    )),
  );
}

class QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const QuickAction({super.key, required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE8EEEA))),
        child: Column(children: [Icon(icon, color: green), const SizedBox(height: 8), Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))]),
      ),
    ),
  );
}

class ProductsPage extends StatefulWidget {
  final VoidCallback onChanged;
  const ProductsPage({super.key, required this.onChanged});
  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  String search = '';
  Future<void> productDialog({Map<String, Object?>? product}) async {
    final name = TextEditingController(text: product?['name'] as String? ?? '');
    final category = TextEditingController(text: product?['category'] as String? ?? '');
    final buy = TextEditingController(text: product?['buyPrice']?.toString() ?? '');
    final sell = TextEditingController(text: product?['sellPrice']?.toString() ?? '');
    final stock = TextEditingController(text: product?['stock']?.toString() ?? '0');
    final min = TextEditingController(text: product?['minStock']?.toString() ?? '3');
    final formKey = GlobalKey<FormState>();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(product == null ? 'افزودن جنس جدید' : 'ویرایش جنس'),
      content: SizedBox(width: 420, child: Form(key: formKey, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        _field(name, 'نام جنس', requiredField: true),
        _field(category, 'دسته‌بندی'),
        _field(buy, 'قیمت خرید (افغانی)', numeric: true, requiredField: true),
        _field(sell, 'قیمت فروش (افغانی)', numeric: true, requiredField: true),
        _field(stock, 'موجودی فعلی', numeric: true, requiredField: true),
        _field(min, 'حداقل موجودی برای هشدار', numeric: true, requiredField: true),
      ])))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('لغو')),
        FilledButton(onPressed: () {
          if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
        }, child: const Text('ذخیره')),
      ],
    ));
    if (ok == true) {
      await ShopDb.instance.saveProduct({
        'name': name.text.trim(),
        'category': category.text.trim(),
        'buyPrice': double.parse(buy.text),
        'sellPrice': double.parse(sell.text),
        'stock': int.parse(stock.text),
        'minStock': int.parse(min.text),
      }, id: product?['id'] as int?);
      if (mounted) setState(() {});
      widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: bg,
    floatingActionButton: FloatingActionButton.extended(onPressed: () => productDialog(), icon: const Icon(Icons.add), label: const Text('جنس جدید')),
    body: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 8), child: TextField(
        onChanged: (v) => setState(() => search = v),
        decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'جست‌وجوی نام یا دسته‌بندی...'),
      )),
      Expanded(child: FutureBuilder<List<Map<String, Object?>>>(
        future: ShopDb.instance.products(search: search),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final items = snap.data!;
          if (items.isEmpty) return const EmptyState(icon: Icons.inventory_2_outlined, title: 'هنوز جنسی ثبت نشده', subtitle: 'برای شروع، جنس جدید اضافه کنید.');
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final x = items[i];
              final low = (x['stock'] as int) <= (x['minStock'] as int);
              return Card(child: ListTile(
                leading: CircleAvatar(backgroundColor: low ? const Color(0xFFFFF3BF) : const Color(0xFFD3F9D8), child: Icon(low ? Icons.warning_amber_rounded : Icons.inventory_2_outlined, color: low ? const Color(0xFFE67700) : green)),
                title: Text(x['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${x['category']}  •  موجودی: ${x['stock']}  •  فروش: ${afn(x['sellPrice'] as num)}'),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'edit') await productDialog(product: x);
                    if (v == 'delete') {
                      final yes = await confirm(context, 'حذف جنس', 'آیا می‌خواهید این جنس حذف شود؟');
                      if (yes) {
                        try { await ShopDb.instance.deleteProduct(x['id'] as int); }
                        catch (e) { if (context.mounted) showMsg(context, e.toString().replaceFirst('Exception: ', '')); }
                        if (mounted) setState(() {});
                        widget.onChanged();
                      }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('ویرایش')),
                    PopupMenuItem(value: 'delete', child: Text('حذف')),
                  ],
                ),
              ));
            },
          );
        },
      )),
    ]),
  );
}

class SalesPage extends StatefulWidget {
  final VoidCallback onChanged;
  const SalesPage({super.key, required this.onChanged});
  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  Future<void> saleDialog() async {
    final products = await ShopDb.instance.products();
    if (!mounted) return;
    if (products.isEmpty) { showMsg(context, 'ابتدا یک جنس ثبت کنید.'); return; }
    Map<String, Object?> selected = products.first;
    final qty = TextEditingController(text: '1');
    final customer = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) => AlertDialog(
      title: const Text('ثبت فروش'),
      content: SizedBox(width: 420, child: Form(key: formKey, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<int>(
          value: selected['id'] as int,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'انتخاب جنس'),
          items: products.map((p) => DropdownMenuItem<int>(value: p['id'] as int, child: Text('${p['name']} (موجودی: ${p['stock']})', overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (id) { if (id != null) setLocal(() => selected = products.firstWhere((e) => e['id'] == id)); },
        ),
        const SizedBox(height: 12),
        _field(qty, 'تعداد', numeric: true, requiredField: true),
        _field(customer, 'نام مشتری (اختیاری)'),
        const SizedBox(height: 8),
        Align(alignment: Alignment.centerRight, child: Text('قیمت واحد: ${afn(selected['sellPrice'] as num)}')),
      ])))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('لغو')),
        FilledButton(onPressed: () { if (formKey.currentState!.validate()) Navigator.pop(ctx, true); }, child: const Text('ثبت')),
      ],
    )));
    if (ok == true) {
      try {
        await ShopDb.instance.makeSale(
          productId: selected['id'] as int,
          productName: selected['name'] as String,
          quantity: int.parse(qty.text),
          unitPrice: (selected['sellPrice'] as num).toDouble(),
          customer: customer.text,
        );
        if (mounted) showMsg(context, 'فروش با موفقیت ثبت شد.');
      } catch (e) { if (mounted) showMsg(context, e.toString().replaceFirst('Exception: ', '')); }
      if (mounted) setState(() {});
      widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    floatingActionButton: FloatingActionButton.extended(onPressed: saleDialog, icon: const Icon(Icons.add_shopping_cart), label: const Text('ثبت فروش')),
    body: FutureBuilder<List<Map<String, Object?>>>(
      future: ShopDb.instance.sales(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final rows = snap.data!;
        if (rows.isEmpty) return const EmptyState(icon: Icons.point_of_sale, title: 'فروشی ثبت نشده', subtitle: 'برای ثبت نخستین فروش، دکمه پایین را بزنید.');
        final total = rows.fold<double>(0, (sum, x) => sum + (x['total'] as num).toDouble());
        return ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 90), children: [
          Card(child: ListTile(title: const Text('مجموع تمام فروش‌ها'), subtitle: Text('${rows.length} فروش ثبت شده'), trailing: Text(afn(total), style: const TextStyle(fontWeight: FontWeight.bold, color: green)))),
          ...rows.map((x) => Card(child: ListTile(
            leading: const CircleAvatar(backgroundColor: Color(0xFFD3F9D8), child: Icon(Icons.receipt_long, color: green)),
            title: Text(x['productName'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${x['quantity']} عدد • ${dateText(x['createdAt'] as int)}${(x['customer'] as String).isEmpty ? '' : ' • ${x['customer']}'}'),
            trailing: Text(afn(x['total'] as num), style: const TextStyle(fontWeight: FontWeight.bold)),
          ))),
        ]);
      },
    ),
  );
}

class DebtsPage extends StatefulWidget {
  final VoidCallback onChanged;
  const DebtsPage({super.key, required this.onChanged});
  @override
  State<DebtsPage> createState() => _DebtsPageState();
}

class _DebtsPageState extends State<DebtsPage> {
  Future<void> debtDialog() async {
    final customer = TextEditingController();
    final phone = TextEditingController();
    final note = TextEditingController();
    final amount = TextEditingController();
    final key = GlobalKey<FormState>();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('ثبت قرض مشتری'),
      content: SizedBox(width: 420, child: Form(key: key, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        _field(customer, 'نام مشتری', requiredField: true),
        _field(phone, 'شماره تماس'),
        _field(amount, 'مبلغ قرض (افغانی)', numeric: true, requiredField: true),
        _field(note, 'یادداشت'),
      ])))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('لغو')),
        FilledButton(onPressed: () { if (key.currentState!.validate()) Navigator.pop(ctx, true); }, child: const Text('ذخیره')),
      ],
    ));
    if (ok == true) {
      await ShopDb.instance.addDebt(customer: customer.text, phone: phone.text, note: note.text, amount: double.parse(amount.text));
      if (mounted) setState(() {});
      widget.onChanged();
    }
  }

  Future<void> repay(Map<String, Object?> debt) async {
    final amount = TextEditingController();
    final remaining = (debt['original'] as num).toDouble() - (debt['paid'] as num).toDouble();
    final key = GlobalKey<FormState>();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('ثبت پرداخت قرض'),
      content: Form(key: key, child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('باقی‌مانده: ${afn(remaining)}'),
        const SizedBox(height: 12),
        _field(amount, 'مبلغ پرداخت (افغانی)', numeric: true, requiredField: true),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('لغو')),
        FilledButton(onPressed: () { if (key.currentState!.validate()) Navigator.pop(ctx, true); }, child: const Text('ثبت پرداخت')),
      ],
    ));
    if (ok == true) {
      try {
        await ShopDb.instance.repayDebt(debt['id'] as int, double.parse(amount.text));
        if (mounted) showMsg(context, 'پرداخت ثبت شد.');
      } catch (e) { if (mounted) showMsg(context, e.toString().replaceFirst('Exception: ', '')); }
      if (mounted) setState(() {});
      widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    floatingActionButton: FloatingActionButton.extended(onPressed: debtDialog, icon: const Icon(Icons.person_add_alt), label: const Text('ثبت قرض')),
    body: FutureBuilder<List<Map<String, Object?>>>(
      future: ShopDb.instance.debts(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final rows = snap.data!;
        final outstanding = rows.fold<double>(0, (sum, x) => sum + (x['original'] as num).toDouble() - (x['paid'] as num).toDouble());
        if (rows.isEmpty) return const EmptyState(icon: Icons.people_alt_outlined, title: 'قرضی ثبت نشده', subtitle: 'قرض مشتریان را اینجا مدیریت کنید.');
        return ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 90), children: [
          Card(child: ListTile(title: const Text('مجموع قرض باقی‌مانده'), trailing: Text(afn(outstanding), style: const TextStyle(fontWeight: FontWeight.bold, color: green)))),
          ...rows.map((x) {
            final remain = (x['original'] as num).toDouble() - (x['paid'] as num).toDouble();
            return Card(child: ListTile(
              leading: CircleAvatar(backgroundColor: remain == 0 ? const Color(0xFFD3F9D8) : const Color(0xFFFFF3BF), child: Icon(remain == 0 ? Icons.check : Icons.person_outline, color: remain == 0 ? green : const Color(0xFFE67700))),
              title: Text(x['customer'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${x['phone']} ${x['note'] == '' ? '' : '• ${x['note']}'}\nاصل قرض: ${afn(x['original'] as num)} • پرداخت: ${afn(x['paid'] as num)}'),
              isThreeLine: true,
              trailing: remain > 0 ? IconButton(tooltip: 'ثبت پرداخت', onPressed: () => repay(x), icon: const Icon(Icons.payments_outlined, color: green)) : const Text('تصفیه شد', style: TextStyle(color: green)),
            ));
          }),
        ]);
      },
    ),
  );
}

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  Future<void> export(BuildContext context, String table, List<String> columns, String name) async {
    try {
      await ShopDb.instance.exportCsv(table, columns, name);
    } catch (e) {
      if (context.mounted) showMsg(context, 'صدور فایل انجام نشد: $e');
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const Text('گزارش‌ها و خروجی', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: ink)),
      const SizedBox(height: 6),
      const Text('اطلاعات را به فایل CSV صادر کنید؛ این فایل را می‌توانید در Excel باز کنید.', style: TextStyle(color: Colors.black54)),
      const SizedBox(height: 18),
      ExportCard(title: 'گزارش اجناس', subtitle: 'نام، دسته، قیمت‌ها و موجودی', icon: Icons.inventory_2, onTap: () => export(context, 'products', ['id','name','category','buyPrice','sellPrice','stock','minStock','createdAt'], 'products.csv')),
      ExportCard(title: 'گزارش فروش‌ها', subtitle: 'جنس، تعداد، قیمت، مشتری و تاریخ', icon: Icons.point_of_sale, onTap: () => export(context, 'sales', ['id','productName','quantity','unitPrice','total','customer','createdAt'], 'sales.csv')),
      ExportCard(title: 'گزارش قرض‌ها', subtitle: 'مشتری، تماس، اصل قرض، پرداخت و باقی‌مانده', icon: Icons.people_alt, onTap: () => export(context, 'debts', ['id','customer','phone','note','original','paid','createdAt'], 'debts.csv')),
      const SizedBox(height: 12),
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
        Text('مهم', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE67700))),
        SizedBox(height: 6),
        Text('اطلاعات در همین موبایل ذخیره می‌شود. اگر برنامه حذف شود یا موبایل خراب گردد، ممکن است اطلاعات از بین برود. برای استفاده تجارتی، نسخهٔ پشتیبان و بازیابی را اضافه و آزمایش کنید.'),
      ]))),
    ],
  );
}

class ExportCard extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final VoidCallback onTap;
  const ExportCard({super.key, required this.title, required this.subtitle, required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => Card(child: ListTile(
    leading: CircleAvatar(backgroundColor: const Color(0xFFD3F9D8), child: Icon(icon, color: green)),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.ios_share),
    onTap: onTap,
  ));
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  const EmptyState({super.key, required this.icon, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      CircleAvatar(radius: 34, backgroundColor: const Color(0xFFD3F9D8), child: Icon(icon, size: 32, color: green)),
      const SizedBox(height: 16),
      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
    ]),
  ));
}

Widget _field(TextEditingController controller, String label, {bool numeric = false, bool requiredField = false}) => Padding(
  padding: const EdgeInsets.only(bottom: 10),
  child: TextFormField(
    controller: controller,
    keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
    decoration: InputDecoration(labelText: label),
    validator: (value) {
      final v = value?.trim() ?? '';
      if (requiredField && v.isEmpty) return 'این بخش ضروری است.';
      if (numeric && v.isNotEmpty) {
        final n = num.tryParse(v);
        if (n == null || n < 0) return 'یک عدد معتبر وارد کنید.';
        if (label.contains('تعداد') && n != n.roundToDouble()) return 'تعداد باید عدد صحیح باشد.';
      }
      return null;
    },
  ),
);

Future<bool> confirm(BuildContext context, String title, String body) async {
  return await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
    title: Text(title),
    content: Text(body),
    actions: [
      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('لغو')),
      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('بله، حذف شود')),
    ],
  )) ?? false;
}

void showMsg(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
}
