import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:csv/csv.dart';

void main() => runApp(const ActivityReportApp());

class ActivityReportApp extends StatelessWidget {
  const ActivityReportApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'گزارش فعالیت',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'sans',
        colorSchemeSeed: const Color(0xFF2457A6),
        scaffoldBackgroundColor: const Color(0xFFF5F7FB),
      ),
      home: const HomePage(),
    );
  }
}

class Report {
  final String id, expert, date, activity, description;
  final int minutes;

  Report({
    required this.id,
    required this.expert,
    required this.date,
    required this.activity,
    required this.description,
    required this.minutes,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'expert': expert,
        'date': date,
        'activity': activity,
        'description': description,
        'minutes': minutes,
      };

  factory Report.fromJson(Map<String, dynamic> j) => Report(
        id: j['id'] ?? '',
        expert: j['expert'] ?? '',
        date: j['date'] ?? '',
        activity: j['activity'] ?? '',
        description: j['description'] ?? '',
        minutes: j['minutes'] ?? 0,
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int tab = 0;
  String expert = 'کارشناس نمونه';
  List<String> activities = [
    'بررسی پرونده',
    'تنظیم گزارش',
    'مکاتبات اداری',
    'پاسخگویی',
    'جلسه',
    'بازدید',
    'پیگیری پرونده',
    'مطالعه و تحقیق',
    'سایر',
  ];
  List<Report> reports = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final r = p.getStringList('reports') ?? [];
    final a = p.getStringList('activities');
    setState(() {
      reports = r.map((x) => Report.fromJson(jsonDecode(x))).toList();
      if (a != null && a.isNotEmpty) activities = a;
    });
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList('reports', reports.map((x) => jsonEncode(x.toJson())).toList());
    await p.setStringList('activities', activities);
  }

  void addReport() async {
    String activity = activities.first;
    final desc = TextEditingController();
    final mins = TextEditingController(text: '60');

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ثبت فعالیت'),
        content: StatefulBuilder(
          builder: (context, setD) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: activity,
                decoration: const InputDecoration(labelText: 'نوع فعالیت'),
                items: activities.map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
                onChanged: (v) => setD(() => activity = v!),
              ),
              TextField(controller: mins, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'مدت (دقیقه)')),
              TextField(controller: desc, maxLines: 3, decoration: const InputDecoration(labelText: 'شرح فعالیت')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('ثبت')),
        ],
      ),
    );

    if (ok == true) {
      reports.add(Report(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        expert: expert,
        date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
        activity: activity,
        description: desc.text,
        minutes: int.tryParse(mins.text) ?? 0,
      ));
      await _save();
      setState(() {});
    }
  }

  Future<void> exportReports() async {
    final data = {
      'format': 'activity_report_v1',
      'expert': expert,
      'createdAt': DateTime.now().toIso8601String(),
      'reports': reports.map((x) => x.toJson()).toList(),
    };
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.json');
    await file.writeAsString(jsonEncode(data));
    await Share.shareXFiles([XFile(file.path)], text: 'گزارش فعالیت $expert');
  }

  Future<void> importReports() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
    if (result == null || result.files.single.path == null) return;
    final text = await File(result.files.single.path!).readAsString();
    final data = jsonDecode(text);
    if (data['format'] != 'activity_report_v1') {
      _msg('فرمت فایل معتبر نیست.');
      return;
    }
    final incoming = (data['reports'] as List).map((x) => Report.fromJson(x)).toList();
    final ids = reports.map((x) => x.id).toSet();
    final fresh = incoming.where((x) => !ids.contains(x.id)).toList();
    reports.addAll(fresh);
    await _save();
    setState(() {});
    _msg('${fresh.length} گزارش جدید وارد شد.');
  }


  Future<void> exportManagerCsv() async {
    final rows = <List<dynamic>>[
      ['کارشناس', 'تاریخ', 'فعالیت', 'مدت (دقیقه)', 'شرح'],
      ...reports.map((r) => [r.expert, r.date, r.activity, r.minutes, r.description]),
    ];
    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/manager_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv');
    await file.writeAsString('\uFEFF$csv');
    await Share.shareXFiles([XFile(file.path)], text: 'گزارش تجمیعی');
  }

  Future<void> showMonthlyReport() async {
    String selectedMonth = DateFormat('yyyy-MM').format(DateTime.now());
    String selectedExpert = 'همه';
    final months = <String>{...reports.map((r) => r.date.substring(0, 7)), selectedMonth}.toList()..sort();
    final experts = <String>{'همه', ...reports.map((r) => r.expert)}.toList();

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setD) {
          final filtered = reports.where((r) =>
              r.date.startsWith(selectedMonth) &&
              (selectedExpert == 'همه' || r.expert == selectedExpert)).toList();
          final total = filtered.fold<int>(0, (a, r) => a + r.minutes);
          final byActivity = <String, int>{};
          final byExpert = <String, int>{};
          for (final r in filtered) {
            byActivity[r.activity] = (byActivity[r.activity] ?? 0) + r.minutes;
            byExpert[r.expert] = (byExpert[r.expert] ?? 0) + r.minutes;
          }
          return AlertDialog(
            title: const Text('گزارش ماهانه و تجمیعی'),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedMonth,
                      decoration: const InputDecoration(labelText: 'ماه'),
                      items: months.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                      onChanged: (v) => setD(() => selectedMonth = v!),
                    ),
                    DropdownButtonFormField<String>(
                      value: selectedExpert,
                      decoration: const InputDecoration(labelText: 'کارشناس'),
                      items: experts.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (v) => setD(() => selectedExpert = v!),
                    ),
                    const SizedBox(height: 12),
                    ListTile(title: const Text('تعداد فعالیت'), trailing: Text('${filtered.length}')),
                    ListTile(title: const Text('مجموع ساعات'), trailing: Text('${(total / 60).toStringAsFixed(1)}')),
                    const Divider(),
                    const Align(alignment: Alignment.centerRight, child: Text('تفکیک بر اساس کارشناس', style: TextStyle(fontWeight: FontWeight.bold))),
                    ...byExpert.entries.map((e) => ListTile(dense: true, title: Text(e.key), trailing: Text('${(e.value / 60).toStringAsFixed(1)} ساعت'))),
                    const Divider(),
                    const Align(alignment: Alignment.centerRight, child: Text('تفکیک بر اساس فعالیت', style: TextStyle(fontWeight: FontWeight.bold))),
                    ...byActivity.entries.map((e) => ListTile(dense: true, title: Text(e.key), trailing: Text('${(e.value / 60).toStringAsFixed(1)} ساعت'))),
                  ],
                ),
              ),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('بستن'))],
          );
        },
      ),
    );
  }

  Future<void> showRangeReport() async {
    DateTime from = DateTime.now().subtract(const Duration(days: 30));
    DateTime to = DateTime.now();
    String expert = 'همه';
    final experts = <String>{'همه', ...reports.map((r) => r.expert)}.toList();

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (context, setD) {
        final filtered = reports.where((r) {
          final d = DateTime.tryParse(r.date);
          return d != null &&
              !d.isBefore(DateTime(from.year, from.month, from.day)) &&
              !d.isAfter(DateTime(to.year, to.month, to.day)) &&
              (expert == 'همه' || r.expert == expert);
        }).toList();
        final total = filtered.fold<int>(0, (a, r) => a + r.minutes);
        return AlertDialog(
          title: const Text('گزارش بازه دلخواه'),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                title: const Text('از تاریخ'),
                subtitle: Text(DateFormat('yyyy-MM-dd').format(from)),
                trailing: const Icon(Icons.calendar_month),
                onTap: () async {
                  final d = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: from);
                  if (d != null) setD(() => from = d);
                },
              ),
              ListTile(
                title: const Text('تا تاریخ'),
                subtitle: Text(DateFormat('yyyy-MM-dd').format(to)),
                trailing: const Icon(Icons.calendar_month),
                onTap: () async {
                  final d = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: to);
                  if (d != null) setD(() => to = d);
                },
              ),
              DropdownButtonFormField<String>(
                value: expert,
                decoration: const InputDecoration(labelText: 'کارشناس'),
                items: experts.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setD(() => expert = v!),
              ),
              const SizedBox(height: 12),
              ListTile(title: const Text('تعداد فعالیت'), trailing: Text('${filtered.length}')),
              ListTile(title: const Text('مجموع ساعات'), trailing: Text('${(total / 60).toStringAsFixed(1)}')),
            ]),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('بستن'))],
        );
      }),
    );
  }

    final now = DateTime.now();
    final month = DateFormat('yyyy-MM').format(now);
    final monthly = reports.where((r) => r.date.startsWith(month)).toList();
    final total = monthly.fold<int>(0, (a, r) => a + r.minutes);
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('گزارش ماه ${month.replaceAll('-', '/')}'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(title: const Text('تعداد فعالیت'), trailing: Text('${monthly.length}')),
              ListTile(title: const Text('مجموع ساعات'), trailing: Text('${(total / 60).toStringAsFixed(1)}')),
              const Divider(),
              ...monthly.take(12).map((r) => ListTile(
                dense: true,
                title: Text(r.activity),
                subtitle: Text('${r.expert} • ${r.minutes} دقیقه'),
              )),
              if (monthly.length > 12) Text('و ${monthly.length - 12} مورد دیگر...')
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('بستن'))],
      ),
    );
  }

  void _msg(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  @override
  Widget build(BuildContext context) {
    final manager = tab == 1;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(manager ? 'پنل مدیر' : 'پنل کارشناس'),
          centerTitle: true,
        ),
        body: manager ? ManagerPage(reports: reports, onImport: importReports, onActivities: _editActivities, onMonthly: showMonthlyReport, onRange: showRangeReport, onExport: exportManagerCsv) : ExpertPage(reports: reports, onAdd: addReport, onExport: exportReports),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (i) => setState(() => tab = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'کارشناس'),
            NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'مدیر'),
          ],
        ),
      ),
    );
  }

  Future<void> _editActivities() async {
    final c = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('دیکشنری فعالیت‌ها'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...activities.map((a) => ListTile(
                    title: Text(a),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () {
                        setState(() => activities.remove(a));
                        Navigator.pop(context);
                        _editActivities();
                      },
                    ),
                  )),
              TextField(controller: c, decoration: const InputDecoration(labelText: 'فعالیت جدید')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('بستن')),
          FilledButton(
            onPressed: () async {
              if (c.text.trim().isNotEmpty) activities.add(c.text.trim());
              await _save();
              if (mounted) Navigator.pop(context);
              setState(() {});
            },
            child: const Text('افزودن'),
          ),
        ],
      ),
    );
  }
}

class ExpertPage extends StatelessWidget {
  final List<Report> reports;
  final VoidCallback onAdd, onExport;
  const ExpertPage({super.key, required this.reports, required this.onAdd, required this.onExport});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _card(context, 'ثبت فعالیت جدید', 'فعالیت روزانه را ثبت کنید', Icons.add_task, onAdd),
        _card(context, 'خروجی گزارش', 'فایل گزارش را برای مدیر ارسال کنید', Icons.upload_file, onExport),
        const SizedBox(height: 12),
        Text('فعالیت‌های ثبت‌شده', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        ...reports.reversed.map((r) => Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.assignment)),
                title: Text(r.activity),
                subtitle: Text('${r.date} • ${r.minutes} دقیقه\n${r.description}'),
                isThreeLine: true,
              ),
            )),
      ],
    );
  }

  Widget _card(BuildContext c, String title, String sub, IconData icon, VoidCallback fn) => Card(
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: CircleAvatar(radius: 26, child: Icon(icon)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(sub),
          trailing: const Icon(Icons.chevron_left),
          onTap: fn,
        ),
      );
}

class ManagerPage extends StatelessWidget {
  final List<Report> reports;
  final VoidCallback onImport, onActivities, onMonthly, onRange, onExport;
  const ManagerPage({super.key, required this.reports, required this.onImport, required this.onActivities, required this.onMonthly, required this.onRange, required this.onExport});

  @override
  Widget build(BuildContext context) {
    final minutes = reports.fold<int>(0, (s, r) => s + r.minutes);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(child: _stat('گزارش‌ها', '${reports.length}', Icons.description)),
            const SizedBox(width: 8),
            Expanded(child: _stat('ساعت فعالیت', (minutes / 60).toStringAsFixed(1), Icons.timer)),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(18),
            leading: const CircleAvatar(radius: 28, child: Icon(Icons.file_download)),
            title: const Text('دریافت / ورود گزارش کارشناسان', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('فایل JSON ارسالی کارشناس را انتخاب و وارد سیستم کنید'),
            trailing: const Icon(Icons.chevron_left),
            onTap: onImport,
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.bar_chart),
            title: const Text('گزارش ماهانه'),
            subtitle: const Text('مشاهده خلاصه فعالیت‌های ماه جاری'),
            trailing: const Icon(Icons.chevron_left),
            onTap: onMonthly,
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.date_range),
            title: const Text('گزارش بازه دلخواه'),
            subtitle: const Text('انتخاب تاریخ شروع، پایان و کارشناس'),
            trailing: const Icon(Icons.chevron_left),
            onTap: onRange,
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.table_view),
            title: const Text('خروجی تجمیعی'),
            subtitle: const Text('خروجی فایل قابل باز شدن در Excel'),
            trailing: const Icon(Icons.chevron_left),
            onTap: onExport,
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.library_books),
            title: const Text('مدیریت دیکشنری فعالیت‌ها'),
            subtitle: const Text('افزودن یا حذف فعالیت‌های پیش‌فرض'),
            trailing: const Icon(Icons.chevron_left),
            onTap: onActivities,
          ),
        ),
        const SizedBox(height: 12),
        Text('گزارش‌های واردشده', style: Theme.of(context).textTheme.titleLarge),
        ...reports.reversed.map((r) => Card(
              child: ListTile(
                title: Text(r.activity),
                subtitle: Text('${r.expert} • ${r.date} • ${r.minutes} دقیقه'),
              ),
            )),
      ],
    );
  }

  Widget _stat(String title, String value, IconData icon) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Icon(icon, size: 28),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text(title),
          ]),
        ),
      );
}
