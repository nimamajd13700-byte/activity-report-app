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
  runApp(const InspectionReportApp());
}

class InspectionReportApp extends StatefulWidget {
  const InspectionReportApp({super.key});

  @override
  State<InspectionReportApp> createState() => _InspectionReportAppState();
}

class _InspectionReportAppState extends State<InspectionReportApp> {
  bool darkMode = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'گزارشات مدیریت بازرسی',
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF2457A6),
        scaffoldBackgroundColor: const Color(0xFFF4F7FB),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF2457A6),
        brightness: Brightness.dark,
      ),
      home: HomePage(
        darkMode: darkMode,
        onDarkModeChanged: (value) {
          setState(() {
            darkMode = value;
          });
        },
      ),
    );
  }
}

class Report {
  final String id;
  final String expertName;
  final String personnelCode;
  final String activity;
  final String description;
  final String date;
  final String time;
  final int minutes;

  const Report({
    required this.id,
    required this.expertName,
    required this.personnelCode,
    required this.activity,
    required this.description,
    required this.date,
    required this.time,
    required this.minutes,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'expertName': expertName,
      'personnelCode': personnelCode,
      'activity': activity,
      'description': description,
      'date': date,
      'time': time,
      'minutes': minutes,
    };
  }

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: '${json['id'] ?? ''}',
      expertName: '${json['expertName'] ?? ''}',
      personnelCode: '${json['personnelCode'] ?? ''}',
      activity: '${json['activity'] ?? ''}',
      description: '${json['description'] ?? ''}',
      date: '${json['date'] ?? ''}',
      time: '${json['time'] ?? ''}',
      minutes: int.tryParse('${json['minutes'] ?? 0}') ?? 0,
    );
  }
}

class HomePage extends StatefulWidget {
  final bool darkMode;
  final ValueChanged<bool> onDarkModeChanged;

  const HomePage({
    super.key,
    required this.darkMode,
    required this.onDarkModeChanged,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int tab = 0;

  String expertName = 'کارشناس نمونه';
  String personnelCode = '';

  String expertPassword = '1234';
  String managerPassword = '1234';

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

  bool loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();

    final savedReports = prefs.getStringList('reports') ?? [];
    final savedActivities = prefs.getStringList('activities');

    setState(() {
      reports = savedReports
          .map((item) {
            try {
              return Report.fromJson(jsonDecode(item));
            } catch (_) {
              return null;
            }
          })
          .whereType<Report>()
          .toList();

      if (savedActivities != null && savedActivities.isNotEmpty) {
        activities = savedActivities;
      }

      expertName = prefs.getString('expertName') ?? 'کارشناس نمونه';
      personnelCode = prefs.getString('personnelCode') ?? '';
      expertPassword = prefs.getString('expertPassword') ?? '1234';
      managerPassword = prefs.getString('managerPassword') ?? '1234';

      loaded = true;
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList(
      'reports',
      reports.map((r) => jsonEncode(r.toJson())).toList(),
    );

    await prefs.setStringList('activities', activities);
    await prefs.setString('expertName', expertName);
    await prefs.setString('personnelCode', personnelCode);
    await prefs.setString('expertPassword', expertPassword);
    await prefs.setString('managerPassword', managerPassword);
  }

  String _dateNow() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  String _timeNow() {
    return DateFormat('HH:mm').format(DateTime.now());
  }

  String _uniqueId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${reports.length + 1}';
  }

  void _message(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<bool> _passwordDialog({
    required String title,
    required String correctPassword,
  }) async {
    final controller = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'رمز عبور',
              prefixIcon: Icon(Icons.lock_outline),
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
                Navigator.pop(
                  dialogContext,
                  controller.text == correctPassword,
                );
              },
              child: const Text('ورود'),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  Future<void> _changeTab(int index) async {
    if (index == 1) {
      final ok = await _passwordDialog(
        title: 'ورود به پنل مدیر',
        correctPassword: managerPassword,
      );

      if (!ok) {
        _message('رمز عبور مدیر صحیح نیست.');
        return;
      }
    }

    setState(() {
      tab = index;
    });
  }

  Future<void> addReport() async {
    if (activities.isEmpty) {
      _message('ابتدا حداقل یک عنوان فعالیت ایجاد کنید.');
      return;
    }

    String selectedActivity = activities.first;
    final descriptionController = TextEditingController();
    final minutesController = TextEditingController(text: '60');

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('ثبت فعالیت جدید'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedActivity,
                  decoration: const InputDecoration(
                    labelText: 'عنوان فعالیت',
                  ),
                  items: activities
                      .map(
                        (activity) => DropdownMenuItem<String>(
                          value: activity,
                          child: Text(activity),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      selectedActivity = value;
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: minutesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'مدت فعالیت به دقیقه',
                    prefixIcon: Icon(Icons.timer_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'شرح و جزئیات فعالیت',
                    prefixIcon: Icon(Icons.description_outlined),
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
              child: const Text('ثبت فعالیت'),
            ),
          ],
        );
      },
    );

    if (result != true) return;

    final minutes = int.tryParse(minutesController.text.trim()) ?? 0;

    if (minutes <= 0) {
      _message('مدت فعالیت باید بیشتر از صفر باشد.');
      return;
    }

    final report = Report(
      id: _uniqueId(),
      expertName: expertName,
      personnelCode: personnelCode,
      activity: selectedActivity,
      description: descriptionController.text.trim(),
      date: _dateNow(),
      time: _timeNow(),
      minutes: minutes,
    );

    setState(() {
      reports.add(report);
    });

    await _save();

    _message('فعالیت با موفقیت ثبت شد.');
  }

  Future<void> exportExpertExcel() async {
    if (reports.isEmpty) {
      _message('هنوز گزارشی برای خروجی وجود ندارد.');
      return;
    }

    final rows = <List<dynamic>>[
      [
        'کد یکتا',
        'نام کارشناس',
        'کد پرسنلی',
        'تاریخ',
        'ساعت',
        'عنوان فعالیت',
        'مدت (دقیقه)',
        'شرح و جزئیات',
      ],
      ...reports.map(
        (r) => [
          r.id,
          r.expertName,
          r.personnelCode,
          r.date,
          r.time,
          r.activity,
          r.minutes,
          r.description,
        ],
      ),
    ];

    final csv = const ListToCsvConverter().convert(rows);

    final directory = await getApplicationDocumentsDirectory();

    final fileName =
        'گزارش_${expertName}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';

    final file = File('${directory.path}/$fileName');

    await file.writeAsString(
      '\uFEFF$csv',
      encoding: utf8,
    );

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'گزارش فعالیت کارشناس $expertName',
    );
  }

  Future<void> importExpertExcel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result == null) return;

    final path = result.files.single.path;

    if (path == null) {
      _message('فایل انتخاب‌شده قابل دسترسی نیست.');
      return;
    }

    try {
      final text = await File(path).readAsString(
        encoding: utf8,
      );

      final rows = const CsvToListConverter().convert(text);

      if (rows.length < 2) {
        _message('فایل گزارش خالی است.');
        return;
      }

      int imported = 0;
      int duplicated = 0;

      final existingIds = reports.map((r) => r.id).toSet();

      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];

        if (row.length < 8) continue;

        final id = '${row[0]}';

        if (id.isEmpty) continue;

        if (existingIds.contains(id)) {
          duplicated++;
          continue;
        }

        final report = Report(
          id: id,
          expertName: '${row[1]}',
          personnelCode: '${row[2]}',
          date: '${row[3]}',
          time: '${row[4]}',
          activity: '${row[5]}',
          minutes: int.tryParse('${row[6]}') ?? 0,
          description: '${row[7]}',
        );

        reports.add(report);
        existingIds.add(id);
        imported++;
      }

      await _save();

      setState(() {});

      _message(
        '$imported فعالیت وارد شد. '
        '${duplicated > 0 ? '$duplicated مورد تکراری بود.' : ''}',
      );
    } catch (e) {
      _message('خطا در خواندن فایل گزارش.');
    }
  }

  Future<void> exportManagerExcel() async {
    if (reports.isEmpty) {
      _message('گزارشی برای خروجی وجود ندارد.');
      return;
    }

    final rows = <List<dynamic>>[
      [
        'کد یکتا',
        'نام کارشناس',
        'کد پرسنلی',
        'تاریخ',
        'ساعت',
        'عنوان فعالیت',
        'مدت (دقیقه)',
        'شرح و جزئیات',
      ],
      ...reports.map(
        (r) => [
          r.id,
          r.expertName,
          r.personnelCode,
          r.date,
          r.time,
          r.activity,
          r.minutes,
          r.description,
        ],
      ),
    ];

    final csv = const ListToCsvConverter().convert(rows);

    final directory = await getApplicationDocumentsDirectory();

    final file = File(
      '${directory.path}/گزارش_تجمیعی_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv',
    );

    await file.writeAsString(
      '\uFEFF$csv',
      encoding: utf8,
    );

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'گزارش تجمیعی مدیریت بازرسی',
    );
  }

  Future<void> editExpertInfo() async {
    final nameController = TextEditingController(text: expertName);
    final codeController = TextEditingController(text: personnelCode);

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('اطلاعات کارشناس'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'نام و نام خانوادگی',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: codeController,
                decoration: const InputDecoration(
                  labelText: 'کد پرسنلی',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('انصراف'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('ذخیره'),
            ),
          ],
        );
      },
    );

    if (result != true) return;

    setState(() {
      expertName = nameController.text.trim().isEmpty
          ? 'کارشناس نمونه'
          : nameController.text.trim();

      personnelCode = codeController.text.trim();
    });

    await _save();

    _message('اطلاعات کارشناس ذخیره شد.');
  }

  Future<void> manageActivities() async {
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final controller = TextEditingController();

            return AlertDialog(
              title: const Text('مدیریت عناوین فعالیت'),
              content: SizedBox(
                width: 450,
                height: 420,
                child: Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: activities.length,
                        itemBuilder: (_, index) {
                          final activity = activities[index];

                          return ListTile(
                            title: Text(activity),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () {
                                setDialogState(() {
                                  activities.removeAt(index);
                                });

                                setState(() {});
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        labelText: 'عنوان فعالیت جدید',
                      ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: () {
                        final value = controller.text.trim();

                        if (value.isEmpty) return;

                        if (activities.contains(value)) {
                          _message('این عنوان قبلاً وجود دارد.');
                          return;
                        }

                        setDialogState(() {
                          activities.add(value);
                        });

                        setState(() {});
                        controller.clear();
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('افزودن عنوان'),
                    ),
                  ],
                ),
              ),
              actions: [
                FilledButton(
                  onPressed: () async {
                    await _save();

                    if (mounted) {
                      Navigator.pop(dialogContext);
                    }
                  },
                  child: const Text('ذخیره و بستن'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> settingsPage() async {
    final managerController = TextEditingController(text: managerPassword);
    final expertController = TextEditingController(text: expertPassword);

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('تنظیمات'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('حالت تاریک'),
                  value: widget.darkMode,
                  onChanged: widget.onDarkModeChanged,
                ),
                const Divider(),
                TextField(
                  controller: managerController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'رمز مدیر',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: expertController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'رمز کارشناس',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('انصراف'),
            ),
            FilledButton(
              onPressed: () async {
                if (managerController.text.trim().isNotEmpty) {
                  managerPassword = managerController.text.trim();
                }

                if (expertController.text.trim().isNotEmpty) {
                  expertPassword = expertController.text.trim();
                }

                await _save();

                if (mounted) {
                  Navigator.pop(dialogContext);
                }

                _message('تنظیمات ذخیره شد.');
              },
              child: const Text('ذخیره'),
            ),
          ],
        );
      },
    );
  }

  Future<void> monthlyReport() async {
    final now = DateTime.now();
    final month = DateFormat('yyyy-MM').format(now);

    final selected = reports.where((r) => r.date.startsWith(month)).toList();

    final minutes = selected.fold<int>(
      0,
      (sum, item) => sum + item.minutes,
    );

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('گزارش ماه جاری'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.description),
                title: const Text('تعداد فعالیت'),
                trailing: Text('${selected.length}'),
              ),
              ListTile(
                leading: const Icon(Icons.timer),
                title: const Text('مجموع ساعات'),
                trailing: Text(
                  '${(minutes / 60).toStringAsFixed(1)} ساعت',
                ),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('بستن'),
            ),
          ],
        );
      },
    );
  }

  List<Report> _filteredReports({
    String search = '',
    String? activity,
  }) {
    final q = search.trim().toLowerCase();

    return reports.where((r) {
      final matchesSearch = q.isEmpty ||
          r.expertName.toLowerCase().contains(q) ||
          r.personnelCode.toLowerCase().contains(q) ||
          r.activity.toLowerCase().contains(q) ||
          r.description.toLowerCase().contains(q) ||
          r.id.toLowerCase().contains(q);

      final matchesActivity =
          activity == null || activity == 'همه' || r.activity == activity;

      return matchesSearch && matchesActivity;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('گزارشات مدیریت بازرسی'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'تنظیمات',
            onPressed: settingsPage,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: tab == 0
          ? ExpertPage(
              reports: reports,
              expertName: expertName,
              personnelCode: personnelCode,
              onAdd: addReport,
              onExport: exportExpertExcel,
              onInfo: editExpertInfo,
            )
          : ManagerPage(
              reports: reports,
              activities: activities,
              onImport: importExpertExcel,
              onExport: exportManagerExcel,
              onActivities: manageActivities,
              onMonthly: monthlyReport,
              filteredReports: _filteredReports,
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: _changeTab,
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
    );
  }
}

class ExpertPage extends StatelessWidget {
  final List<Report> reports;
  final String expertName;
  final String personnelCode;
  final VoidCallback onAdd;
  final VoidCallback onExport;
  final VoidCallback onInfo;

  const ExpertPage({
    super.key,
    required this.reports,
    required this.expertName,
    required this.personnelCode,
    required this.onAdd,
    required this.onExport,
    required this.onInfo,
  });

  @override
  Widget build(BuildContext context) {
    final totalMinutes = reports.fold<int>(
      0,
      (sum, item) => sum + item.minutes,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 30,
                  child: Icon(Icons.person),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expertName,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        personnelCode.isEmpty
                            ? 'کد پرسنلی ثبت نشده'
                            : 'کد پرسنلی: $personnelCode',
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onInfo,
                  icon: const Icon(Icons.edit),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _statCard(
                context,
                'فعالیت‌ها',
                '${reports.length}',
                Icons.assignment,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statCard(
                context,
                'ساعات',
                (totalMinutes / 60).toStringAsFixed(1),
                Icons.timer,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _actionCard(
          context,
          'ثبت فعالیت جدید',
          'ثبت فعالیت با تاریخ، ساعت، مدت و شرح',
          Icons.add_task,
          onAdd,
        ),
        _actionCard(
          context,
          'ارسال گزارش به مدیر',
          'خروجی Excel شامل تمام ردیف‌های فعالیت',
          Icons.send,
          onExport,
        ),
        const SizedBox(height: 16),
        Text(
          'گزارش‌های ثبت‌شده',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        if (reports.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text('هنوز فعالیتی ثبت نشده است.'),
              ),
            ),
          ),
        ...reports.reversed.map(
          (report) => Card(
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.assignment_outlined),
              ),
              title: Text(report.activity),
              subtitle: Text(
                '${report.date} - ${report.time}\n'
                '${report.minutes} دقیقه\n'
                '${report.description}',
              ),
              isThreeLine: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _statCard(
    BuildContext context,
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
          radius: 27,
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

class ManagerPage extends StatefulWidget {
  final List<Report> reports;
  final List<String> activities;
  final VoidCallback onImport;
  final VoidCallback onExport;
  final VoidCallback onActivities;
  final VoidCallback onMonthly;
  final List<Report> Function({
    String search,
    String? activity,
  }) filteredReports;

  const ManagerPage({
    super.key,
    required this.reports,
    required this.activities,
    required this.onImport,
    required this.onExport,
    required this.onActivities,
    required this.onMonthly,
    required this.filteredReports,
  });

  @override
  State<ManagerPage> createState() => _ManagerPageState();
}

class _ManagerPageState extends State<ManagerPage> {
  String search = '';
  String selectedActivity = 'همه';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.filteredReports(
      search: search,
      activity: selectedActivity,
    );

    final totalMinutes = filtered.fold<int>(
      0,
      (sum, item) => sum + item.minutes,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: _stat(
                context,
                'کل گزارش‌ها',
                '${widget.reports.length}',
                Icons.description,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _stat(
                context,
                'ساعات',
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
              child: Icon(Icons.file_open),
            ),
            title: const Text(
              'ورود گزارش کارشناسان',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              'فایل Excel/CSV ارسالی کارشناس را وارد کنید',
            ),
            trailing: const Icon(Icons.chevron_left),
            onTap: widget.onImport,
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.file_download),
            title: const Text('خروجی Excel تجمیعی'),
            subtitle: const Text(
              'تمام فعالیت‌های کارشناسان در چند ردیف',
            ),
            trailing: const Icon(Icons.chevron_left),
            onTap: widget.onExport,
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.bar_chart),
            title: const Text('گزارش ماهانه'),
            subtitle: const Text('خلاصه فعالیت‌های ماه جاری'),
            trailing: const Icon(Icons.chevron_left),
            onTap: widget.onMonthly,
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.library_books),
            title: const Text('مدیریت عناوین فعالیت'),
            subtitle: const Text(
              'افزودن یا حذف عناوین فعالیت',
            ),
            trailing: const Icon(Icons.chevron_left),
            onTap: widget.onActivities,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'جستجو و فیلتر',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        TextField(
          decoration: const InputDecoration(
            labelText: 'جستجو',
            hintText: 'نام، کد پرسنلی، فعالیت، شرح یا کد گزارش',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) {
            setState(() {
              search = value;
            });
          },
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: selectedActivity,
          decoration: const InputDecoration(
            labelText: 'فیلتر فعالیت',
          ),
          items: [
            const DropdownMenuItem(
              value: 'همه',
              child: Text('همه فعالیت‌ها'),
            ),
            ...widget.activities.map(
              (activity) => DropdownMenuItem(
                value: activity,
                child: Text(activity),
              ),
            ),
          ],
          onChanged: (value) {
            if (value == null) return;

            setState(() {
              selectedActivity = value;
            });
          },
        ),
        const SizedBox(height: 16),
        Text(
          'نتایج: ${filtered.length}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (filtered.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text('موردی پیدا نشد.'),
              ),
            ),
          ),
        ...filtered.reversed.map(
          (report) => Card(
            child: ExpansionTile(
              leading: const CircleAvatar(
                child: Icon(Icons.assignment),
              ),
              title: Text(report.activity),
              subtitle: Text(
                '${report.expertName} - ${report.date} - ${report.time}',
              ),
              children: [
                ListTile(
                  title: const Text('کد یکتا'),
                  subtitle: Text(report.id),
                ),
                ListTile(
                  title: const Text('کارشناس'),
                  subtitle: Text(report.expertName),
                ),
                ListTile(
                  title: const Text('کد پرسنلی'),
                  subtitle: Text(report.personnelCode),
                ),
                ListTile(
                  title: const Text('مدت'),
                  subtitle: Text('${report.minutes} دقیقه'),
                ),
                ListTile(
                  title: const Text('شرح و جزئیات'),
                  subtitle: Text(report.description),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _stat(
    BuildContext context,
    String title,
    String value,
    IconData icon,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Icon(icon),
            const SizedBox(height: 5),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(title),
          ],
        ),
      ),
    );
  }
}
