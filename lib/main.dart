import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const InspectionReportApp());
}

class InspectionReportApp extends StatelessWidget {
  const InspectionReportApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'گزارشات مدیریت بازرسی',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF174A7E),
        scaffoldBackgroundColor: const Color(0xFFF4F7FA),
      ),
      home: const HomePage(),
    );
  }
}

class Report {
  final String id;
  final String expert;
  final String nationalId;
  final String activity;
  final String description;
  final String date;
  final String time;
  final int minutes;

  Report({
    required this.id,
    required this.expert,
    required this.nationalId,
    required this.activity,
    required this.description,
    required this.date,
    required this.time,
    required this.minutes,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'expert': expert,
      'nationalId': nationalId,
      'activity': activity,
      'description': description,
      'date': date,
      'time': time,
      'minutes': minutes,
    };
  }

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: json['id'] ?? '',
      expert: json['expert'] ?? '',
      nationalId: json['nationalId'] ?? '',
      activity: json['activity'] ?? '',
      description: json['description'] ?? '',
      date: json['date'] ?? '',
      time: json['time'] ?? '',
      minutes: json['minutes'] ?? 0,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int selectedPage = 0;

  String expertName = 'کارشناس نمونه';
  String nationalId = '';

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
    loadData();
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();

    final reportList = prefs.getStringList('reports') ?? [];
    final savedActivities = prefs.getStringList('activities');

    setState(() {
      reports = reportList
          .map((item) => Report.fromJson(jsonDecode(item)))
          .toList();

      if (savedActivities != null && savedActivities.isNotEmpty) {
        activities = savedActivities;
      }

      expertName = prefs.getString('expertName') ?? 'کارشناس نمونه';
      nationalId = prefs.getString('nationalId') ?? '';
    });
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList(
      'reports',
      reports.map((r) => jsonEncode(r.toJson())).toList(),
    );

    await prefs.setStringList('activities', activities);
    await prefs.setString('expertName', expertName);
    await prefs.setString('nationalId', nationalId);
  }

  String today() {
    return DateFormat('yyyy/MM/dd').format(DateTime.now());
  }

  String currentTime() {
    return DateFormat('HH:mm').format(DateTime.now());
  }

  void showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> addReport() async {
    String activity = activities.isNotEmpty ? activities.first : 'سایر';

    final descriptionController = TextEditingController();
    final minutesController = TextEditingController(text: '60');

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
                      value: activity,
                      decoration: const InputDecoration(
                        labelText: 'نوع فعالیت',
                        border: OutlineInputBorder(),
                      ),
                      items: activities
                          .map(
                            (item) => DropdownMenuItem(
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
      },
    );

    if (result != true) {
      return;
    }

    final report = Report(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      expert: expertName,
      nationalId: nationalId,
      activity: activity,
      description: descriptionController.text.trim(),
      date: today(),
      time: currentTime(),
      minutes: int.tryParse(minutesController.text) ?? 0,
    );

    setState(() {
      reports.add(report);
    });

    await saveData();

    showMessage('فعالیت با موفقیت ثبت شد.');
  }

  Future<void> editExpertInfo() async {
    final nameController = TextEditingController(text: expertName);
    final idController = TextEditingController(text: nationalId);

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('اطلاعات شناسایی کارشناس'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'نام و نام خانوادگی',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: idController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'کد ملی',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
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
              child: const Text('ذخیره'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      setState(() {
        expertName = nameController.text.trim().isEmpty
            ? 'کارشناس نمونه'
            : nameController.text.trim();

        nationalId = idController.text.trim();
      });

      await saveData();

      showMessage('اطلاعات کارشناس ذخیره شد.');
    }
  }

  Future<void> manageActivities() async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('مدیریت فعالیت‌ها'),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...activities.map(
                      (item) => ListTile(
                        title: Text(item),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () {
                            setDialogState(() {
                              activities.remove(item);
                            });
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

                    if (value.isNotEmpty && !activities.contains(value)) {
                      activities.add(value);
                    }

                    await saveData();

                    setDialogState(() {});
                    controller.clear();
                  },
                  child: const Text('افزودن'),
                ),
              ],
            );
          },
        );
      },
    );

    setState(() {});
  }

  Future<void> showReports() async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('گزارش فعالیت‌ها'),
          content: SizedBox(
            width: 500,
            height: 500,
            child: reports.isEmpty
                ? const Center(
                    child: Text('هنوز گزارشی ثبت نشده است.'),
                  )
                : ListView.builder(
                    itemCount: reports.length,
                    itemBuilder: (context, index) {
                      final report = reports[reports.length - index - 1];

                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.assignment),
                          ),
                          title: Text(report.activity),
                          subtitle: Text(
                            '${report.date} - ${report.time}\n'
                            '${report.expert} - ${report.minutes} دقیقه\n'
                            '${report.description}',
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('بستن'),
            ),
          ],
        );
      },
    );
  }

  void showStatistics() {
    final totalMinutes =
        reports.fold<int>(0, (sum, report) => sum + report.minutes);

    final totalHours = totalMinutes / 60;

    final Map<String, int> activityStats = {};

    for (final report in reports) {
      activityStats[report.activity] =
          (activityStats[report.activity] ?? 0) + report.minutes;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('آمار و گزارش تجمیعی'),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.description),
                    title: const Text('تعداد گزارش‌ها'),
                    trailing: Text('${reports.length}'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.timer),
                    title: const Text('مجموع ساعات فعالیت'),
                    trailing: Text(totalHours.toStringAsFixed(1)),
                  ),
                  const Divider(),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'تفکیک فعالیت‌ها',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ...activityStats.entries.map(
                    (item) => ListTile(
                      title: Text(item.key),
                      trailing: Text(
                        '${(item.value / 60).toStringAsFixed(1)} ساعت',
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
                Navigator.pop(context);
              },
              child: const Text('بستن'),
            ),
          ],
        );
      },
    );
  }

  Widget dashboard() {
    final totalMinutes =
        reports.fold<int>(0, (sum, report) => sum + report.minutes);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Icon(
                  Icons.admin_panel_settings,
                  size: 55,
                ),
                const SizedBox(height: 10),
                const Text(
                  'گزارشات مدیریت بازرسی',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  expertName,
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: statCard(
                'گزارش‌ها',
                '${reports.length}',
                Icons.description,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: statCard(
                'ساعات',
                (totalMinutes / 60).toStringAsFixed(1),
                Icons.timer,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        actionCard(
          'ثبت فعالیت جدید',
          'ثبت تاریخ، ساعت، نوع و شرح فعالیت',
          Icons.add_task,
          addReport,
        ),
        actionCard(
          'گزارش‌های ثبت‌شده',
          'مشاهده تمام فعالیت‌ها',
          Icons.assignment,
          showReports,
        ),
        actionCard(
          'اطلاعات کارشناس',
          'نام، نام خانوادگی و کد ملی',
          Icons.person,
          editExpertInfo,
        ),
        actionCard(
          'آمار و گزارش تجمیعی',
          'مشاهده آمار فعالیت‌ها',
          Icons.bar_chart,
          showStatistics,
        ),
        actionCard(
          'مدیریت فعالیت‌ها',
          'افزودن یا حذف انواع فعالیت',
          Icons.settings,
          manageActivities,
        ),
      ],
    );
  }

  Widget settingsPage() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'تنظیمات',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 15),
        actionCard(
          'اطلاعات کارشناس',
          'ویرایش اطلاعات شناسایی',
          Icons.person_outline,
          editExpertInfo,
        ),
        actionCard(
          'مدیریت فعالیت‌ها',
          'تنظیم فهرست فعالیت‌ها',
          Icons.list_alt,
          manageActivities,
        ),
      ],
    );
  }

  Widget reportsPage() {
    if (reports.isEmpty) {
      return const Center(
        child: Text(
          'هنوز گزارشی ثبت نشده است.',
          style: TextStyle(fontSize: 18),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: reports.length,
      itemBuilder: (context, index) {
        final report = reports[reports.length - index - 1];

        return Card(
          child: ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.assignment),
            ),
            title: Text(report.activity),
            subtitle: Text(
              '${report.date} - ${report.time}\n'
              '${report.expert} - ${report.minutes} دقیقه\n'
              '${report.description}',
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  Widget statCard(
    String title,
    String value,
    IconData icon,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 30),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(title),
          ],
        ),
      ),
    );
  }

  Widget actionCard(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback action,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.all(15),
        leading: CircleAvatar(
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
        onTap: action,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body;

    if (selectedPage == 0) {
      body = dashboard();
    } else if (selectedPage == 1) {
      body = reportsPage();
    } else {
      body = settingsPage();
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('گزارشات مدیریت بازرسی'),
          centerTitle: true,
        ),
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedPage,
          onDestinationSelected: (index) {
            setState(() {
              selectedPage = index;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'خانه',
            ),
            NavigationDestination(
              icon: Icon(Icons.description_outlined),
              selectedIcon: Icon(Icons.description),
              label: 'گزارش‌ها',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'تنظیمات',
            ),
          ],
        ),
      ),
    );
  }
}
