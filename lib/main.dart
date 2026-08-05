import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const ActivityReportApp());
}

class ActivityReportApp extends StatefulWidget {
  const ActivityReportApp({super.key});

  @override
  State<ActivityReportApp> createState() => _ActivityReportAppState();
}

class _ActivityReportAppState extends State<ActivityReportApp> {
  bool darkMode = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'گزارشات مدیریت بازرسی',
      locale: const Locale('fa', 'IR'),
      supportedLocales: const [
        Locale('fa', 'IR'),
        Locale('en', 'US'),
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF174A7E),
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF4F7FA),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF4F8CC9),
        brightness: Brightness.dark,
      ),
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
      home: LoginPage(
        onThemeChanged: (value) {
          setState(() {
            darkMode = value;
          });
        },
      ),
    );
  }
}

// ------------------------------------------------------------
// مدل گزارش
// ------------------------------------------------------------

class ActivityReport {
  final String id;
  final String expertName;
  final String nationalId;
  final String personnelCode;
  final String date;
  final String time;
  final String activity;
  final String description;
  final int minutes;

  ActivityReport({
    required this.id,
    required this.expertName,
    required this.nationalId,
    required this.personnelCode,
    required this.date,
    required this.time,
    required this.activity,
    required this.description,
    required this.minutes,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'expertName': expertName,
      'nationalId': nationalId,
      'personnelCode': personnelCode,
      'date': date,
      'time': time,
      'activity': activity,
      'description': description,
      'minutes': minutes,
    };
  }

  factory ActivityReport.fromJson(Map<String, dynamic> json) {
    return ActivityReport(
      id: json['id']?.toString() ?? '',
      expertName: json['expertName']?.toString() ?? '',
      nationalId: json['nationalId']?.toString() ?? '',
      personnelCode: json['personnelCode']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      time: json['time']?.toString() ?? '',
      activity: json['activity']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      minutes: int.tryParse(json['minutes'].toString()) ?? 0,
    );
  }
}

// ------------------------------------------------------------
// ابزارهای عمومی
// ------------------------------------------------------------

String twoDigits(int value) {
  return value.toString().padLeft(2, '0');
}

String gregorianToJalali(DateTime date) {
  int gy = date.year;
  int gm = date.month;
  int gd = date.day;

  final gDays = <int>[
    0,
    31,
    59,
    90,
    120,
    151,
    181,
    212,
    243,
    273,
    304,
    334,
  ];

  int gy2 = gm > 2 ? gy + 1 : gy;
  int days = 355666 +
      (365 * gy) +
      ((gy2 + 3) ~/ 4) -
      ((gy2 + 99) ~/ 100) +
      ((gy2 + 399) ~/ 400) +
      gd +
      gDays[gm - 1];

  int jy = -1595 + 33 * (days ~/ 12053);
  days %= 12053;

  jy += 4 * (days ~/ 1461);
  days %= 1461;

  if (days > 365) {
    jy += (days - 1) ~/ 365;
    days = (days - 1) % 365;
  }

  int jm;
  int jd;

  if (days < 186) {
    jm = 1 + (days ~/ 31);
    jd = 1 + (days % 31);
  } else {
    jm = 7 + ((days - 186) ~/ 30);
    jd = 1 + ((days - 186) % 30);
  }

  return '${jy.toString().padLeft(4, '0')}/${twoDigits(jm)}/${twoDigits(jd)}';
}

String jalaliMonth(DateTime date) {
  final value = gregorianToJalali(date);
  return value.substring(0, 7);
}

String makeReportId() {
  return 'R-${DateTime.now().millisecondsSinceEpoch}';
}

String makeExportCode() {
  final now = DateTime.now();
  return 'EXP-${now.year}${twoDigits(now.month)}'
      '${twoDigits(now.day)}-'
      '${now.millisecondsSinceEpoch.toString().substring(7)}';
}

// ------------------------------------------------------------
// صفحه ورود
// ------------------------------------------------------------

class LoginPage extends StatefulWidget {
  final ValueChanged<bool> onThemeChanged;

  const LoginPage({
    super.key,
    required this.onThemeChanged,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final passwordController = TextEditingController();

  String password = '1234';
  bool obscure = true;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadPassword();
  }

  Future<void> loadPassword() async {
    final prefs = await SharedPreferences.getInstance();
    password = prefs.getString('manager_password') ?? '1234';

    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  void login() {
    if (passwordController.text == password) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomePage(
            onThemeChanged: widget.onThemeChanged,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('رمز ورود صحیح نیست.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 42,
                      child: Icon(
                        Icons.assessment,
                        size: 44,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'گزارشات مدیریت بازرسی',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'ورود به سامانه',
                      style: TextStyle(fontSize: 15),
                    ),
                    const SizedBox(height: 28),
                    TextField(
                      controller: passwordController,
                      obscureText: obscure,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'رمز ورود',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              obscure = !obscure;
                            });
                          },
                          icon: Icon(
                            obscure
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => login(),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: login,
                        icon: const Icon(Icons.login),
                        label: const Text('ورود'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'رمز پیش‌فرض: 1234',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// صفحه اصلی
// ------------------------------------------------------------

class HomePage extends StatefulWidget {
  final ValueChanged<bool> onThemeChanged;

  const HomePage({
    super.key,
    required this.onThemeChanged,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int selectedIndex = 0;

  List<ActivityReport> reports = [];

  List<String> activities = [
    'بررسی پرونده',
    'تنظیم گزارش',
    'بازرسی',
    'بازدید',
    'مکاتبات اداری',
    'پاسخگویی',
    'جلسه',
    'پیگیری پرونده',
    'مطالعه و تحقیق',
    'سایر',
  ];

  String expertName = 'کارشناس نمونه';
  String nationalId = '';
  String personnelCode = '';

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();

    final reportStrings = prefs.getStringList('reports') ?? [];

    final activityList = prefs.getStringList('activities');

    setState(() {
      reports = reportStrings
          .map(
            (item) => ActivityReport.fromJson(
              jsonDecode(item),
            ),
          )
          .toList();

      if (activityList != null && activityList.isNotEmpty) {
        activities = activityList;
      }

      expertName = prefs.getString('expert_name') ?? 'کارشناس نمونه';
      nationalId = prefs.getString('national_id') ?? '';
      personnelCode = prefs.getString('personnel_code') ?? '';
    });
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList(
      'reports',
      reports.map((r) => jsonEncode(r.toJson())).toList(),
    );

    await prefs.setStringList('activities', activities);
    await prefs.setString('expert_name', expertName);
    await prefs.setString('national_id', nationalId);
    await prefs.setString('personnel_code', personnelCode);
  }

  void message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Widget currentPage() {
    if (selectedIndex == 0) {
      return DashboardPage(
        reports: reports,
        expertName: expertName,
        onAdd: addReport,
        onSearch: searchReports,
      );
    }

    if (selectedIndex == 1) {
      return ManagerPage(
        reports: reports,
        onImport: importReports,
        onExportExcel: exportExcel,
        onExportPdf: exportPdf,
        onMonthly: monthlyReport,
        onSearch: searchReports,
      );
    }

    return SettingsPage(
      expertName: expertName,
      nationalId: nationalId,
      personnelCode: personnelCode,
      activities: activities,
      onSaveExpert: saveExpertInfo,
      onManageActivities: manageActivities,
      onChangePassword: changePassword,
      onThemeChanged: widget.onThemeChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'گزارشات روزانه و تجمیعی مدیریت بازرسی',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: currentPage(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'داشبورد',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: 'مدیریت',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'تنظیمات',
          ),
        ],
      ),
    );
  }

  Future<void> saveExpertInfo(
    String name,
    String nid,
    String code,
  ) async {
    setState(() {
      expertName = name;
      nationalId = nid;
      personnelCode = code;
    });

    await saveData();
    message('اطلاعات کارشناس ذخیره شد.');
  }

  Future<void> addReport() async {
    String activity = activities.isNotEmpty ? activities.first : 'سایر';

    final descriptionController = TextEditingController();
    final minutesController = TextEditingController(text: '60');

    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('ثبت فعالیت جدید'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: activity,
                      decoration: const InputDecoration(
                        labelText: 'نوع فعالیت',
                        border: OutlineInputBorder(),
                      ),
                      items: activities
                          .map(
                            (item) => DropdownMenuItem<String>(
                              value: item,
                              child: Text(item),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            activity = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      title: const Text('تاریخ'),
                      subtitle: Text(
                        gregorianToJalali(selectedDate),
                      ),
                      leading: const Icon(Icons.calendar_month),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );

                        if (picked != null) {
                          setDialogState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                    ),
                    ListTile(
                      title: const Text('ساعت'),
                      subtitle: Text(
                        '${twoDigits(selectedTime.hour)}:${twoDigits(selectedTime.minute)}',
                      ),
                      leading: const Icon(Icons.access_time),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                        );

                        if (picked != null) {
                          setDialogState(() {
                            selectedTime = picked;
                          });
                        }
                      },
                    ),
                    TextField(
                      controller: minutesController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'مدت فعالیت به دقیقه',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'شرح فعالیت',
                        border: OutlineInputBorder(),
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
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(dialogContext, true);
                  },
                  icon: const Icon(Icons.save),
                  label: const Text('ثبت'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true) {
      return;
    }

    final report = ActivityReport(
      id: makeReportId(),
      expertName: expertName,
      nationalId: nationalId,
      personnelCode: personnelCode,
      date: DateFormat('yyyy-MM-dd').format(selectedDate),
      time:
          '${twoDigits(selectedTime.hour)}:${twoDigits(selectedTime.minute)}',
      activity: activity,
      description: descriptionController.text.trim(),
      minutes: int.tryParse(minutesController.text) ?? 0,
    );

    reports.add(report);

    await saveData();

    setState(() {});

    message('گزارش با کد ${report.id} ثبت شد.');
  }

  Future<void> searchReports() async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('جستجوی گزارش'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'نام، فعالیت یا کد گزارش',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('بستن'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                final q = controller.text.trim();

                if (q.isEmpty) {
                  return;
                }

                final result = reports.where((r) {
                  return r.id.contains(q) ||
                      r.expertName.contains(q) ||
                      r.activity.contains(q) ||
                      r.description.contains(q);
                }).toList();

                showSearchResult(result);
              },
              child: const Text('جستجو'),
            ),
          ],
        );
      },
    );
  }

  void showSearchResult(List<ActivityReport> result) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('نتایج جستجو: ${result.length} مورد'),
          content: SizedBox(
            width: 500,
            height: 450,
            child: result.isEmpty
                ? const Center(
                    child: Text('موردی پیدا نشد.'),
                  )
                : ListView.builder(
                    itemCount: result.length,
                    itemBuilder: (context, index) {
                      final r = result[index];

                      return Card(
                        child: ListTile(
                          title: Text(r.activity),
                          subtitle: Text(
                            '${r.expertName}\n'
                            '${r.date} - ${r.time}\n'
                            'کد: ${r.id}',
                          ),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('بستن'),
            ),
          ],
        );
      },
    );
  }

  Future<void> importReports() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result == null || result.files.single.path == null) {
      return;
    }

    final text = await File(
      result.files.single.path!,
    ).readAsString();

    try {
      final data = jsonDecode(text);

      final incoming = (data['reports'] as List)
          .map(
            (item) => ActivityReport.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();

      final ids = reports.map((r) => r.id).toSet();

      final fresh = incoming
          .where((r) => !ids.contains(r.id))
          .toList();

      reports.addAll(fresh);

      await saveData();

      setState(() {});

      message('${fresh.length} گزارش جدید وارد شد.');
    } catch (_) {
      message('فایل انتخاب‌شده معتبر نیست.');
    }
  }

  Future<void> exportExcel() async {
    if (reports.isEmpty) {
      message('هنوز گزارشی ثبت نشده است.');
      return;
    }

    final excel = Excel.createExcel();
    final sheet = excel['گزارشات'];

    sheet.appendRow([
      TextCellValue('کد گزارش'),
      TextCellValue('نام کارشناس'),
      TextCellValue('کد پرسنلی'),
      TextCellValue('کد ملی'),
      TextCellValue('تاریخ'),
      TextCellValue('ساعت'),
      TextCellValue('فعالیت'),
      TextCellValue('مدت دقیقه'),
      TextCellValue('شرح'),
    ]);

    for (final r in reports) {
      sheet.appendRow([
        TextCellValue(r.id),
        TextCellValue(r.expertName),
        TextCellValue(r.personnelCode),
        TextCellValue(r.nationalId),
        TextCellValue(r.date),
        TextCellValue(r.time),
        TextCellValue(r.activity),
        IntCellValue(r.minutes),
        TextCellValue(r.description),
      ]);
    }

    final bytes = excel.encode();

    if (bytes == null) {
      message('ساخت فایل Excel انجام نشد.');
      return;
    }

    final dir = await getApplicationDocumentsDirectory();

    final path =
        '${dir.path}/reports_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';

    final file = File(path);

    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'خروجی Excel گزارشات مدیریت بازرسی',
    );
  }

  Future<void> exportPdf() async {
    if (reports.isEmpty) {
      message('هنوز گزارشی ثبت نشده است.');
      return;
    }

    final document = pw.Document();

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (context) {
          return [
            pw.Text(
              'Activity Inspection Reports',
              style: pw.TextStyle(
                fontSize: 20,
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              'Export Code: ${makeExportCode()}',
            ),
            pw.SizedBox(height: 12),
            pw.Table.fromTextArray(
              headers: [
                'ID',
                'Expert',
                'Date',
                'Time',
                'Activity',
                'Minutes',
              ],
              data: reports.map((r) {
                return [
                  r.id,
                  r.expertName,
                  r.date,
                  r.time,
                  r.activity,
                  r.minutes.toString(),
                ];
              }).toList(),
            ),
          ];
        },
      ),
    );

    final bytes = await document.save();

    await Printing.sharePdf(
      bytes: bytes,
      filename:
          'inspection_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf',
    );
  }

  Future<void> monthlyReport() async {
    final now = DateTime.now();

    final currentMonth = DateFormat(
      'yyyy-MM',
    ).format(now);

    final filtered = reports.where(
      (r) => r.date.startsWith(currentMonth),
    ).toList();

    final totalMinutes = filtered.fold<int>(
      0,
      (sum, r) => sum + r.minutes,
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('گزارش ماه جاری'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.description),
                title: const Text('تعداد گزارش'),
                trailing: Text('${filtered.length}'),
              ),
              ListTile(
                leading: const Icon(Icons.timer),
                title: const Text('مجموع ساعات'),
                trailing: Text(
                  (totalMinutes / 60).toStringAsFixed(1),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.calendar_month),
                title: const Text('ماه'),
                trailing: Text(
                  jalaliMonth(now),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('بستن'),
            ),
          ],
        );
      },
    );
  }

  Future<void> changePassword() async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('تغییر رمز ورود'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'رمز جدید',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('انصراف'),
            ),
            FilledButton(
              onPressed: () async {
                if (controller.text.trim().length < 4) {
                  message('رمز باید حداقل ۴ رقم باشد.');
                  return;
                }

                final prefs = await SharedPreferences.getInstance();

                await prefs.setString(
                  'manager_password',
                  controller.text.trim(),
                );

                if (mounted) {
                  Navigator.pop(context);
                }

                message('رمز ورود تغییر کرد.');
              },
              child: const Text('ذخیره'),
            ),
          ],
        );
      },
    );
  }

  Future<void> manageActivities() async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('مدیریت فعالیت‌ها'),
              content: SizedBox(
                width: 450,
                height: 420,
                child: Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: activities.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            title: Text(activities[index]),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                              ),
                              onPressed: () {
                                setDialogState(() {
                                  activities.removeAt(index);
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        labelText: 'فعالیت جدید',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('بستن'),
                ),
                FilledButton(
                  onPressed: () {
                    final value = controller.text.trim();

                    if (value.isNotEmpty) {
                      setDialogState(() {
                        activities.add(value);
                        controller.clear();
                      });
                    }
                  },
                  child: const Text('افزودن'),
                ),
              ],
            );
          },
        );
      },
    );

    await saveData();

    setState(() {});
  }
}

// ------------------------------------------------------------
// داشبورد
// ------------------------------------------------------------

class DashboardPage extends StatelessWidget {
  final List<ActivityReport> reports;
  final String expertName;
  final VoidCallback onAdd;
  final VoidCallback onSearch;

  const DashboardPage({
    super.key,
    required this.reports,
    required this.expertName,
    required this.onAdd,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateFormat(
      'yyyy-MM-dd',
    ).format(DateTime.now());

    final todayReports = reports.where(
      (r) => r.date == today,
    ).toList();

    final todayMinutes = todayReports.fold<int>(
      0,
      (sum, r) => sum + r.minutes,
    );

    final totalMinutes = reports.fold<int>(
      0,
      (sum, r) => sum + r.minutes,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.verified_user,
                  size: 38,
                ),
                const SizedBox(height: 12),
                const Text(
                  'سامانه گزارشات روزانه و تجمیعی مدیریت بازرسی',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'کارشناس: $expertName',
                ),
                const SizedBox(height: 4),
                Text(
                  'امروز: ${gregorianToJalali(DateTime.now())}',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatCard(
                title: 'گزارش امروز',
                value: '${todayReports.length}',
                icon: Icons.today,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatCard(
                title: 'ساعت امروز',
                value: (todayMinutes / 60).toStringAsFixed(1),
                icon: Icons.timer,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        StatCard(
          title: 'کل ساعات ثبت‌شده',
          value: (totalMinutes / 60).toStringAsFixed(1),
          icon: Icons.analytics,
        ),
        const SizedBox(height: 16),
        ActionCard(
          title: 'ثبت فعالیت جدید',
          subtitle: 'ثبت فعالیت همراه با تاریخ، ساعت و شرح',
          icon: Icons.add_task,
          onTap: onAdd,
        ),
        ActionCard(
          title: 'جستجو در گزارشات',
          subtitle: 'جستجو بر اساس نام، فعالیت یا کد گزارش',
          icon: Icons.search,
          onTap: onSearch,
        ),
        const SizedBox(height: 12),
        const Text(
          'آخرین گزارشات',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        if (reports.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text('هنوز گزارشی ثبت نشده است.'),
              ),
            ),
          )
        else
          ...reports.reversed.take(10).map(
                (r) => Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.assignment),
                    ),
                    title: Text(r.activity),
                    subtitle: Text(
                      '${r.expertName} • ${r.date} • ${r.time}\n'
                      'کد: ${r.id}',
                    ),
                    trailing: Text(
                      '${r.minutes} دقیقه',
                    ),
                  ),
                ),
              ),
      ],
    );
  }
}

// ------------------------------------------------------------
// پنل مدیر
// ------------------------------------------------------------

class ManagerPage extends StatefulWidget {
  final List<ActivityReport> reports;
  final VoidCallback onImport;
  final VoidCallback onExportExcel;
  final VoidCallback onExportPdf;
  final VoidCallback onMonthly;
  final VoidCallback onSearch;

  const ManagerPage({
    super.key,
    required this.reports,
    required this.onImport,
    required this.onExportExcel,
    required this.onExportPdf,
    required this.onMonthly,
    required this.onSearch,
  });

  @override
  State<ManagerPage> createState() => _ManagerPageState();
}

class _ManagerPageState extends State<ManagerPage> {
  String search = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.reports.where((r) {
      if (search.isEmpty) return true;

      return r.expertName.contains(search) ||
          r.activity.contains(search) ||
          r.id.contains(search);
    }).toList();

    final totalMinutes = filtered.fold<int>(
      0,
      (sum, r) => sum + r.minutes,
    );

    final expertCount = filtered
        .map((r) => r.expertName)
        .toSet()
        .length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'داشبورد مدیریت',
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatCard(
                title: 'کل گزارشات',
                value: '${filtered.length}',
                icon: Icons.description,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatCard(
                title: 'کارشناسان',
                value: '$expertCount',
                icon: Icons.people,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        StatCard(
          title: 'مجموع ساعات فعالیت',
          value: (totalMinutes / 60).toStringAsFixed(1),
          icon: Icons.timer,
        ),
        const SizedBox(height: 16),
        TextField(
          decoration: const InputDecoration(
            labelText: 'جستجوی سریع',
            hintText: 'نام کارشناس، فعالیت یا کد گزارش',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            setState(() {
              search = value;
            });
          },
        ),
        const SizedBox(height: 16),
        ActionCard(
          title: 'ورود گزارش کارشناس',
          subtitle: 'دریافت فایل JSON گزارش کارشناس',
          icon: Icons.file_open,
          onTap: widget.onImport,
        ),
        ActionCard(
          title: 'خروجی Excel',
          subtitle: 'دریافت گزارشات در قالب Excel',
          icon: Icons.table_chart,
          onTap: widget.onExportExcel,
        ),
        ActionCard(
          title: 'خروجی PDF',
          subtitle: 'تهیه گزارش PDF',
          icon: Icons.picture_as_pdf,
          onTap: widget.onExportPdf,
        ),
        ActionCard(
          title: 'گزارش ماهانه',
          subtitle: 'خلاصه گزارشات ماه جاری',
          icon: Icons.calendar_month,
          onTap: widget.onMonthly,
        ),
        const SizedBox(height: 12),
        const Text(
          'نمودار فعالیت',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ActivityChart(
          reports: filtered,
        ),
        const SizedBox(height: 12),
        const Text(
          'گزارشات',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...filtered.reversed.map(
          (r) => Card(
            child: ListTile(
              title: Text(r.activity),
              subtitle: Text(
                '${r.expertName} • ${r.date} • ${r.time}\n'
                'کد گزارش: ${r.id}',
              ),
              trailing: Text(
                '${r.minutes} دقیقه',
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------
// تنظیمات
// ------------------------------------------------------------

class SettingsPage extends StatefulWidget {
  final String expertName;
  final String nationalId;
  final String personnelCode;
  final List<String> activities;
  final Future<void> Function(String, String, String) onSaveExpert;
  final VoidCallback onManageActivities;
  final VoidCallback onChangePassword;
  final ValueChanged<bool> onThemeChanged;

  const SettingsPage({
    super.key,
    required this.expertName,
    required this.nationalId,
    required this.personnelCode,
    required this.activities,
    required this.onSaveExpert,
    required this.onManageActivities,
    required this.onChangePassword,
    required this.onThemeChanged,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController nameController;
  late final TextEditingController nationalController;
  late final TextEditingController personnelController;

  bool darkMode = false;

  @override
  void initState() {
    super.initState();

    nameController = TextEditingController(
      text: widget.expertName,
    );

    nationalController = TextEditingController(
      text: widget.nationalId,
    );

    personnelController = TextEditingController(
      text: widget.personnelCode,
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    nationalController.dispose();
    personnelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'تنظیمات برنامه',
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'اطلاعات شناسایی کارشناس',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'نام و نام خانوادگی',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nationalController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'کد ملی',
                    prefixIcon: Icon(Icons.badge),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: personnelController,
                  decoration: const InputDecoration(
                    labelText: 'کد پرسنلی',
                    prefixIcon: Icon(Icons.work),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      widget.onSaveExpert(
                        nameController.text.trim(),
                        nationalController.text.trim(),
                        personnelController.text.trim(),
                      );
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('ذخیره اطلاعات'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: SwitchListTile(
            title: const Text('حالت تاریک'),
            subtitle: const Text('تغییر ظاهر برنامه'),
            value: darkMode,
            onChanged: (value) {
              setState(() {
                darkMode = value;
              });

              widget.onThemeChanged(value);
            },
          ),
        ),
        ActionCard(
          title: 'تغییر رمز ورود',
          subtitle: 'تغییر رمز ورود به سامانه',
          icon: Icons.lock_reset,
          onTap: widget.onChangePassword,
        ),
        ActionCard(
          title: 'مدیریت فعالیت‌ها',
          subtitle: 'افزودن یا حذف انواع فعالیت',
          icon: Icons.list_alt,
          onTap: widget.onManageActivities,
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('درباره برنامه'),
            subtitle: const Text(
              'سامانه گزارشات روزانه و تجمیعی مدیریت بازرسی',
            ),
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------
// نمودار
// ------------------------------------------------------------

class ActivityChart extends StatelessWidget {
  final List<ActivityReport> reports;

  const ActivityChart({
    super.key,
    required this.reports,
  });

  @override
  Widget build(BuildContext context) {
    final Map<String, int> data = {};

    for (final report in reports) {
      data[report.activity] =
          (data[report.activity] ?? 0) + report.minutes;
    }

    if (data.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(25),
          child: Center(
            child: Text('داده‌ای برای نمودار وجود ندارد.'),
          ),
        ),
      );
    }

    final sorted = data.entries.toList()
      ..sort(
        (a, b) => b.value.compareTo(a.value),
      );

    final maxValue = sorted.first.value;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: sorted.take(8).map((entry) {
            final percent =
                maxValue == 0 ? 0.0 : entry.value / maxValue;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          entry.key,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${(entry.value / 60).toStringAsFixed(1)} ساعت',
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  LinearProgressIndicator(
                    value: percent,
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// ویجت‌های ظاهری
// ------------------------------------------------------------

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              child: Icon(icon),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
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
          ],
        ),
      ),
    );
  }
}

class ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const ActionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
        trailing: const Icon(
          Icons.arrow_back_ios_new,
          size: 18,
        ),
        onTap: onTap,
      ),
    );
  }
}
