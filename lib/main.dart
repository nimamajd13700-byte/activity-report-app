import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const ActivityReportApp());
}

class ActivityReportApp extends StatelessWidget {
  const ActivityReportApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'گزارش فعالیت',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF2457A6),
        scaffoldBackgroundColor: const Color(0xFFF5F7FB),
      ),
      home: const HomePage(),
    );
  }
}

// =====================
// مدل گزارش
// =====================

class Report {
  final String id;
  final String expert;
  final String date;
  final String activity;
  final String description;
  final int minutes;

  Report({
    required this.id,
    required this.expert,
    required this.date,
    required this.activity,
    required this.description,
    required this.minutes,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'expert': expert,
      'date': date,
      'activity': activity,
      'description': description,
      'minutes': minutes,
    };
  }

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: json['id']?.toString() ?? '',
      expert: json['expert']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      activity: json['activity']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      minutes: int.tryParse(json['minutes'].toString()) ?? 0,
    );
  }
}

// =====================
// صفحه اصلی
// =====================

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

  // =====================
  // ذخیره و بارگذاری
  // =====================

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();

    final savedReports = prefs.getStringList('reports') ?? [];
    final savedActivities = prefs.getStringList('activities');

    final loadedReports = <Report>[];

    for (final item in savedReports) {
      try {
        loadedReports.add(
          Report.fromJson(jsonDecode(item)),
        );
      } catch (_) {}
    }

    if (!mounted) return;

    setState(() {
      reports = loadedReports;

      if (savedActivities != null && savedActivities.isNotEmpty) {
        activities = savedActivities;
      }
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList(
      'reports',
      reports.map((r) => jsonEncode(r.toJson())).toList(),
    );

    await prefs.setStringList(
      'activities',
      activities,
    );
  }

  // =====================
  // پیام
  // =====================

  void _msg(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  // =====================
  // ثبت فعالیت
  // =====================

  Future<void> addReport() async {
    if (activities.isEmpty) {
      _msg('ابتدا حداقل یک فعالیت تعریف کنید.');
      return;
    }

    String selectedActivity = activities.first;

    final descriptionController = TextEditingController();
    final minutesController = TextEditingController(text: '60');

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('ثبت فعالیت'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedActivity,
                      decoration: const InputDecoration(
                        labelText: 'نوع فعالیت',
                      ),
                      items: activities.map((activity) {
                        return DropdownMenuItem<String>(
                          value: activity,
                          child: Text(activity),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value == null) return;

                        setDialogState(() {
                          selectedActivity = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: minutesController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'مدت فعالیت (دقیقه)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'شرح فعالیت',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, false);
                  },
                  child: const Text('انصراف'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, true);
                  },
                  child: const Text('ثبت'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true) {
      descriptionController.dispose();
      minutesController.dispose();
      return;
    }

    final minutes = int.tryParse(minutesController.text.trim()) ?? 0;

    if (minutes <= 0) {
      _msg('مدت فعالیت را صحیح وارد کنید.');
      descriptionController.dispose();
      minutesController.dispose();
      return;
    }

    final report = Report(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      expert: expert,
      date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
      activity: selectedActivity,
      description: descriptionController.text.trim(),
      minutes: minutes,
    );

    reports.add(report);

    await _save();

    descriptionController.dispose();
    minutesController.dispose();

    if (!mounted) return;

    setState(() {});

    _msg('فعالیت با موفقیت ثبت شد.');
  }

  // =====================
  // خروجی گزارش کارشناس
  // =====================

  Future<void> exportReports() async {
    if (reports.isEmpty) {
      _msg('هنوز گزارشی ثبت نشده است.');
      return;
    }

    final data = {
      'format': 'activity_report_v1',
      'expert': expert,
      'createdAt': DateTime.now().toIso8601String(),
      'reports': reports.map((r) => r.toJson()).toList(),
    };

    final directory = await getApplicationDocumentsDirectory();

    final file = File(
      '${directory.path}/report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.json',
    );

    await file.writeAsString(
      jsonEncode(data),
      encoding: utf8,
    );

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'گزارش فعالیت $expert',
    );
  }

  // =====================
  // ورود گزارش مدیر
  // =====================

  Future<void> importReports() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result == null) return;

    final path = result.files.single.path;

    if (path == null) {
      _msg('امکان خواندن فایل وجود ندارد.');
      return;
    }

    try {
      final text = await File(path).readAsString(
        encoding: utf8,
      );

      final data = jsonDecode(text);

      if (data is! Map<String, dynamic>) {
        _msg('فرمت فایل صحیح نیست.');
        return;
      }

      if (data['format'] != 'activity_report_v1') {
        _msg('این فایل گزارش فعالیت معتبر نیست.');
        return;
      }

      final list = data['reports'];

      if (list is! List) {
        _msg('گزارشی داخل فایل پیدا نشد.');
        return;
      }

      final incoming = <Report>[];

      for (final item in list) {
        try {
          incoming.add(
            Report.fromJson(
              Map<String, dynamic>.from(item),
            ),
          );
        } catch (_) {}
      }

      final existingIds = reports.map((r) => r.id).toSet();

      final fresh = incoming.where(
        (r) => !existingIds.contains(r.id),
      );

      reports.addAll(fresh);

      await _save();

      if (!mounted) return;

      setState(() {});

      _msg('${fresh.length} گزارش جدید وارد شد.');
    } catch (_) {
      _msg('خواندن فایل با خطا مواجه شد.');
    }
  }

  // =====================
  // خروجی CSV مدیر
  // =====================

  Future<void> exportManagerCsv() async {
    if (reports.isEmpty) {
      _msg('هنوز گزارشی وجود ندارد.');
      return;
    }

    final rows = <List<dynamic>>[
      [
        'کارشناس',
        'تاریخ',
        'فعالیت',
        'مدت (دقیقه)',
        'شرح',
      ],
      ...reports.map(
        (r) => [
          r.expert,
          r.date,
          r.activity,
          r.minutes,
          r.description,
        ],
      ),
    ];

    final csv = const ListToCsvConverter().convert(rows);

    final directory = await getApplicationDocumentsDirectory();

    final file = File(
      '${directory.path}/manager_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv',
    );

    await file.writeAsString(
      '\uFEFF$csv',
      encoding: utf8,
    );

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'گزارش تجمیعی',
    );
  }

  // =====================
  // گزارش ماهانه
  // =====================

  Future<void> showMonthlyReport() async {
    String selectedMonth =
        DateFormat('yyyy-MM').format(DateTime.now());

    String selectedExpert = 'همه';

    final monthSet = <String>{
      selectedMonth,
      ...reports.map(
        (r) {
          if (r.date.length >= 7) {
            return r.date.substring(0, 7);
          }
          return selectedMonth;
        },
      ),
    };

    final months = monthSet.toList()..sort();

    final experts = <String>{
      'همه',
      ...reports.map((r) => r.expert),
    }.toList();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filtered = reports.where((r) {
              return r.date.startsWith(selectedMonth) &&
                  (selectedExpert == 'همه' ||
                      r.expert == selectedExpert);
            }).toList();

            final total = filtered.fold<int>(
              0,
              (sum, r) => sum + r.minutes,
            );

            final byActivity = <String, int>{};
            final byExpert = <String, int>{};

            for (final report in filtered) {
              byActivity[report.activity] =
                  (byActivity[report.activity] ?? 0) +
                      report.minutes;

              byExpert[report.expert] =
                  (byExpert[report.expert] ?? 0) +
                      report.minutes;
            }

            return AlertDialog(
              title: const Text('گزارش ماهانه'),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        value: selectedMonth,
                        decoration: const InputDecoration(
                          labelText: 'ماه',
                        ),
                        items: months.map((month) {
                          return DropdownMenuItem<String>(
                            value: month,
                            child: Text(month),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value == null) return;

                          setDialogState(() {
                            selectedMonth = value;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: selectedExpert,
                        decoration: const InputDecoration(
                          labelText: 'کارشناس',
                        ),
                        items: experts.map((item) {
                          return DropdownMenuItem<String>(
                            value: item,
                            child: Text(item),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value == null) return;

                          setDialogState(() {
                            selectedExpert = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        title: const Text('تعداد فعالیت'),
                        trailing: Text('${filtered.length}'),
                      ),
                      ListTile(
                        title: const Text('مجموع ساعات'),
                        trailing: Text(
                          (total / 60).toStringAsFixed(1),
                        ),
                      ),
                      const Divider(),
                      const Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'تفکیک بر اساس کارشناس',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ...byExpert.entries.map(
                        (entry) => ListTile(
                          dense: true,
                          title: Text(entry.key),
                          trailing: Text(
                            '${(entry.value / 60).toStringAsFixed(1)} ساعت',
                          ),
                        ),
                      ),
                      const Divider(),
                      const Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'تفکیک بر اساس فعالیت',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ...byActivity.entries.map(
                        (entry) => ListTile(
                          dense: true,
                          title: Text(entry.key),
                          trailing: Text(
                            '${(entry.value / 60).toStringAsFixed(1)} ساعت',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('بستن'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // =====================
  // گزارش بازه
  // =====================

  Future<void> showRangeReport() async {
    DateTime from =
        DateTime.now().subtract(const Duration(days: 30));

    DateTime to = DateTime.now();

    String selectedExpert = 'همه';

    final experts = <String>{
      'همه',
      ...reports.map((r) => r.expert),
    }.toList();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filtered = reports.where((r) {
              final date = DateTime.tryParse(r.date);

              if (date == null) return false;

              final start = DateTime(
                from.year,
                from.month,
                from.day,
              );

              final end = DateTime(
                to.year,
                to.month,
                to.day,
              );

              return !date.isBefore(start) &&
                  !date.isAfter(end) &&
                  (selectedExpert == 'همه' ||
                      r.expert == selectedExpert);
            }).toList();

            final total = filtered.fold<int>(
              0,
              (sum, r) => sum + r.minutes,
            );

            return AlertDialog(
              title: const Text('گزارش بازه دلخواه'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        title: const Text('از تاریخ'),
                        subtitle: Text(
                          DateFormat('yyyy-MM-dd').format(from),
                        ),
                        trailing: const Icon(
                          Icons.calendar_month,
                        ),
                        onTap: () async {
                          final selected =
                              await showDatePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                            initialDate: from,
                          );

                          if (selected != null) {
                            setDialogState(() {
                              from = selected;
                            });
                          }
                        },
                      ),
                      ListTile(
                        title: const Text('تا تاریخ'),
                        subtitle: Text(
                          DateFormat('yyyy-MM-dd').format(to),
                        ),
                        trailing: const Icon(
                          Icons.calendar_month,
                        ),
                        onTap: () async {
                          final selected =
                              await showDatePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                            initialDate: to,
                          );

                          if (selected != null) {
                            setDialogState(() {
                              to = selected;
                            });
                          }
                        },
                      ),
                      DropdownButtonFormField<String>(
                        value: selectedExpert,
                        decoration: const InputDecoration(
                          labelText: 'کارشناس',
                        ),
                        items: experts.map((item) {
                          return DropdownMenuItem<String>(
                            value: item,
                            child: Text(item),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value == null) return;

                          setDialogState(() {
                            selectedExpert = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        title: const Text('تعداد فعالیت'),
                        trailing: Text('${filtered.length}'),
                      ),
                      ListTile(
                        title: const Text('مجموع ساعات'),
                        trailing: Text(
                          (total / 60).toStringAsFixed(1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('بستن'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // =====================
  // مدیریت فعالیت‌ها
  // =====================

  Future<void> editActivities() async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('مدیریت فعالیت‌ها'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...activities.map(
                        (activity) => ListTile(
                          title: Text(activity),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                            ),
                            onPressed: () {
                              setDialogState(() {
                                activities.remove(activity);
                              });

                              _save();

                              setState(() {});
                            },
                          ),
                        ),
                      ),
                      TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                          labelText: 'فعالیت جدید',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('بستن'),
                ),
                FilledButton(
                  onPressed: () async {
                    final value = controller.text.trim();

                    if (value.isEmpty) return;

                    if (!activities.contains(value)) {
                      activities.add(value);
                    }

                    await _save();

                    if (!mounted) return;

                    setState(() {});

                    controller.clear();

                    setDialogState(() {});
                  },
                  child: const Text('افزودن'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
  }

  // =====================
  // رابط کاربری
  // =====================

  @override
  Widget build(BuildContext context) {
    final manager = tab == 1;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            manager ? 'پنل مدیر' : 'پنل کارشناس',
          ),
          centerTitle: true,
        ),
        body: manager
            ? ManagerPage(
                reports: reports,
                onImport: importReports,
                onActivities: editActivities,
                onMonthly: showMonthlyReport,
                onRange: showRangeReport,
                onExport: exportManagerCsv,
              )
            : ExpertPage(
                reports: reports,
                onAdd: addReport,
                onExport: exportReports,
              ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (index) {
            setState(() {
              tab = index;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'کارشناس',
            ),
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'مدیر',
            ),
          ],
        ),
      ),
    );
  }
}

// =====================
// صفحه کارشناس
// =====================

class ExpertPage extends StatelessWidget {
  final List<Report> reports;
  final VoidCallback onAdd;
  final VoidCallback onExport;

  const ExpertPage({
    super.key,
    required this.reports,
    required this.onAdd,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _menuCard(
          context,
          'ثبت فعالیت جدید',
          'فعالیت روزانه را ثبت کنید',
          Icons.add_task,
          onAdd,
        ),
        _menuCard(
          context,
          'خروجی گزارش',
          'فایل گزارش را برای مدیر ارسال کنید',
          Icons.upload_file,
          onExport,
        ),
        const SizedBox(height: 16),
        Text(
          'فعالیت‌های ثبت‌شده',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        if (reports.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'هنوز فعالیتی ثبت نشده است.',
                ),
              ),
            ),
          ),
        ...reports.reversed.map(
          (report) => Card(
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.assignment),
              ),
              title: Text(report.activity),
              subtitle: Text(
                '${report.date} • ${report.minutes} دقیقه\n'
                '${report.description}',
              ),
              isThreeLine: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _menuCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          radius: 26,
          child: Icon(icon),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_left),
        onTap: onTap,
      ),
    );
  }
}

// =====================
// صفحه مدیر
// =====================

class ManagerPage extends StatelessWidget {
  final List<Report> reports;

  final VoidCallback onImport;
  final VoidCallback onActivities;
  final VoidCallback onMonthly;
  final VoidCallback onRange;
  final VoidCallback onExport;

  const ManagerPage({
    super.key,
    required this.reports,
    required this.onImport,
    required this.onActivities,
    required this.onMonthly,
    required this.onRange,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final totalMinutes = reports.fold<int>(
      0,
      (sum, report) => sum + report.minutes,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: _statCard(
                'گزارش‌ها',
                '${reports.length}',
                Icons.description,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _statCard(
                'ساعت فعالیت',
                (totalMinutes / 60).toStringAsFixed(1),
                Icons.timer,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(18),
            leading: const CircleAvatar(
              radius: 28,
              child: Icon(Icons.file_download),
            ),
            title: const Text(
              'دریافت / ورود گزارش کارشناسان',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: const Text(
              'فایل JSON ارسالی کارشناس را وارد کنید',
            ),
            trailing: const Icon(Icons.chevron_left),
            onTap: onImport,
          ),
        ),
        _actionCard(
          'گزارش ماهانه',
          'مشاهده خلاصه فعالیت‌های ماه جاری',
          Icons.bar_chart,
          onMonthly,
        ),
        _actionCard(
          'گزارش بازه دلخواه',
          'انتخاب تاریخ شروع، پایان و کارشناس',
          Icons.date_range,
          onRange,
        ),
        _actionCard(
          'خروجی تجمیعی',
          'خروجی فایل قابل باز شدن در Excel',
          Icons.table_view,
          onExport,
        ),
        _actionCard(
          'مدیریت فعالیت‌ها',
          'افزودن یا حذف فعالیت‌های پیش‌فرض',
          Icons.library_books,
          onActivities,
        ),
        const SizedBox(height: 16),
        Text(
          'گزارش‌های واردشده',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        if (reports.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'هنوز گزارشی وارد نشده است.',
                ),
              ),
            ),
          ),
        ...reports.reversed.map(
          (report) => Card(
            child: ListTile(
              title: Text(report.activity),
              subtitle: Text(
                '${report.expert} • '
                '${report.date} • '
                '${report.minutes} دقیقه',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _statCard(
    String title,
    String value,
    IconData icon,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 28),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(title),
          ],
        ),
      ),
    );
  }

  Widget _actionCard(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_left),
        onTap: onTap,
      ),
    );
  }
}
