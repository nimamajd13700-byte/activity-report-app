import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:csv/csv.dart';

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
        colorSchemeSeed: const Color(0xFF1756A5),
        scaffoldBackgroundColor: const Color(0xFFF4F7FB),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 1,
          margin: const EdgeInsets.symmetric(vertical: 6),
        ),
      ),
      home: const LoginPage(),
    );
  }
}

// ============================================================
// MODELS
// ============================================================

class Expert {
  String id;
  String firstName;
  String lastName;
  String nationalCode;
  String personnelCode;
  String phone;
  String position;

  Expert({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.nationalCode,
    required this.personnelCode,
    required this.phone,
    required this.position,
  });

  String get fullName => '$firstName $lastName'.trim();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'nationalCode': nationalCode,
      'personnelCode': personnelCode,
      'phone': phone,
      'position': position,
    };
  }

  factory Expert.fromJson(Map<String, dynamic> json) {
    return Expert(
      id: '${json['id'] ?? ''}',
      firstName: '${json['firstName'] ?? ''}',
      lastName: '${json['lastName'] ?? ''}',
      nationalCode: '${json['nationalCode'] ?? ''}',
      personnelCode: '${json['personnelCode'] ?? ''}',
      phone: '${json['phone'] ?? ''}',
      position: '${json['position'] ?? ''}',
    );
  }
}

class ActivityReport {
  String id;
  String expertId;
  String expertName;
  String activity;
  String description;
  String date;
  String time;
  int minutes;

  ActivityReport({
    required this.id,
    required this.expertId,
    required this.expertName,
    required this.activity,
    required this.description,
    required this.date,
    required this.time,
    required this.minutes,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'expertId': expertId,
      'expertName': expertName,
      'activity': activity,
      'description': description,
      'date': date,
      'time': time,
      'minutes': minutes,
    };
  }

  factory ActivityReport.fromJson(Map<String, dynamic> json) {
    return ActivityReport(
      id: '${json['id'] ?? ''}',
      expertId: '${json['expertId'] ?? ''}',
      expertName: '${json['expertName'] ?? ''}',
      activity: '${json['activity'] ?? ''}',
      description: '${json['description'] ?? ''}',
      date: '${json['date'] ?? ''}',
      time: '${json['time'] ?? ''}',
      minutes: int.tryParse('${json['minutes'] ?? 0}') ?? 0,
    );
  }
}

// ============================================================
// JALALI DATE
// ============================================================

class JalaliDate {
  final int year;
  final int month;
  final int day;

  const JalaliDate(this.year, this.month, this.day);

  String get formatted {
    return '${year.toString().padLeft(4, '0')}/'
        '${month.toString().padLeft(2, '0')}/'
        '${day.toString().padLeft(2, '0')}';
  }

  static JalaliDate fromGregorian(DateTime date) {
    int gy = date.year;
    int gm = date.month;
    int gd = date.day;

    final gdm = <int>[
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
        gdm[gm - 1];

    int jy = -1595 + (33 * (days ~/ 12053));
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

    return JalaliDate(jy, jm, jd);
  }
}

// ============================================================
// LOGIN
// ============================================================

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController passwordController =
      TextEditingController();

  bool obscure = true;
  String error = '';

  Future<void> login() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPassword = prefs.getString('manager_password') ?? '1234';

    if (passwordController.text == savedPassword) {
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const DashboardPage(),
        ),
      );
    } else {
      setState(() {
        error = 'رمز عبور صحیح نیست.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 42,
                      child: Icon(
                        Icons.security,
                        size: 42,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'گزارشات مدیریت بازرسی',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('ورود به سامانه'),
                    const SizedBox(height: 28),
                    TextField(
                      controller: passwordController,
                      obscureText: obscure,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'رمز عبور',
                        prefixIcon: const Icon(Icons.lock),
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
                      ),
                      onSubmitted: (_) => login(),
                    ),
                    if (error.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        error,
                        style: const TextStyle(
                          color: Colors.red,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: login,
                        icon: const Icon(Icons.login),
                        label: const Text('ورود'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'رمز اولیه: 1234',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
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

// ============================================================
// DASHBOARD
// ============================================================

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int index = 0;

  List<Expert> experts = [];
  List<ActivityReport> reports = [];

  List<String> activities = [
    'بررسی پرونده',
    'تنظیم گزارش',
    'بازدید',
    'مکاتبات اداری',
    'پاسخگویی',
    'جلسه',
    'پیگیری پرونده',
    'مطالعه و تحقیق',
    'سایر',
  ];

  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();

    final expertData = prefs.getStringList('experts') ?? [];
    final reportData = prefs.getStringList('reports') ?? [];
    final activityData = prefs.getStringList('activities');

    setState(() {
      experts = expertData
          .map(
            (x) => Expert.fromJson(
              Map<String, dynamic>.from(jsonDecode(x)),
            ),
          )
          .toList();

      reports = reportData
          .map(
            (x) => ActivityReport.fromJson(
              Map<String, dynamic>.from(jsonDecode(x)),
            ),
          )
          .toList();

      if (activityData != null && activityData.isNotEmpty) {
        activities = activityData;
      }

      loading = false;
    });
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList(
      'experts',
      experts.map((e) => jsonEncode(e.toJson())).toList(),
    );

    await prefs.setStringList(
      'reports',
      reports.map((r) => jsonEncode(r.toJson())).toList(),
    );

    await prefs.setStringList(
      'activities',
      activities,
    );
  }

  String generateId() {
    return 'BR-${DateTime.now().millisecondsSinceEpoch}';
  }

  String currentJalali() {
    return JalaliDate.fromGregorian(DateTime.now()).formatted;
  }

  String currentTime() {
    return DateFormat('HH:mm').format(DateTime.now());
  }

  void message(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
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

    final pages = [
      buildHome(),
      buildReports(),
      buildExperts(),
      buildSettings(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('گزارشات مدیریت بازرسی'),
        actions: [
          IconButton(
            tooltip: 'تنظیمات',
            onPressed: () {
              setState(() {
                index = 3;
              });
            },
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) {
          setState(() {
            index = value;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'داشبورد',
          ),
          NavigationDestination(
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description),
            label: 'گزارش‌ها',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'کارشناسان',
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

  // ==========================================================
  // HOME
  // ==========================================================

  Widget buildHome() {
    final totalMinutes =
        reports.fold<int>(0, (sum, item) => sum + item.minutes);

    final today = JalaliDate.fromGregorian(DateTime.now()).formatted;

    final todayReports =
        reports.where((r) => r.date == today).toList();

    return RefreshIndicator(
      onRefresh: loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF1756A5),
                    Color(0xFF2879C7),
                  ],
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'سامانه گزارش فعالیت',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'مدیریت و پایش فعالیت‌های بازرسی',
                    style: TextStyle(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: statCard(
                  'کارشناسان',
                  '${experts.length}',
                  Icons.people,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: statCard(
                  'گزارش‌ها',
                  '${reports.length}',
                  Icons.description,
                ),
              ),
            ],
          ),

          Row(
            children: [
              Expanded(
                child: statCard(
                  'گزارش امروز',
                  '${todayReports.length}',
                  Icons.today,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: statCard(
                  'ساعات فعالیت',
                  (totalMinutes / 60).toStringAsFixed(1),
                  Icons.timer,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          actionCard(
            'ثبت فعالیت جدید',
            'ثبت سریع فعالیت کارشناس',
            Icons.add_task,
            addReport,
          ),

          actionCard(
            'ثبت کارشناس',
            'افزودن اطلاعات شناسایی کارشناس',
            Icons.person_add,
            addExpert,
          ),

          actionCard(
            'گزارش‌گیری',
            'گزارش ماهانه و بازه‌ای',
            Icons.analytics,
            showReports,
          ),

          actionCard(
            'خروجی Excel',
            'تهیه فایل قابل استفاده در Excel',
            Icons.table_chart,
            exportExcel,
          ),

          actionCard(
            'خروجی اطلاعات',
            'پشتیبان‌گیری و انتقال اطلاعات',
            Icons.import_export,
            exportJson,
          ),
        ],
      ),
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
            Icon(icon, size: 28),
            const SizedBox(height: 8),
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

  Widget actionCard(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback action,
  ) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
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

  // ==========================================================
  // REPORTS
  // ==========================================================

  Widget buildReports() {
    String search = '';
    String selectedExpert = 'همه';

    return StatefulBuilder(
      builder: (context, setLocal) {
        final expertsList = [
          'همه',
          ...experts.map((e) => e.fullName),
        ];

        final filtered = reports.where((r) {
          final matchesSearch =
              search.isEmpty ||
              r.activity.contains(search) ||
              r.description.contains(search) ||
              r.expertName.contains(search) ||
              r.id.contains(search);

          final matchesExpert =
              selectedExpert == 'همه' ||
              r.expertName == selectedExpert;

          return matchesSearch && matchesExpert;
        }).toList().reversed.toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                16,
                12,
                16,
                4,
              ),
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'جستجوی گزارش',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setLocal(() {
                    search = value;
                  });
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              child: DropdownButtonFormField<String>(
                initialValue: selectedExpert,
                decoration: const InputDecoration(
                  labelText: 'فیلتر کارشناس',
                  border: OutlineInputBorder(),
                ),
                items: expertsList
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(e),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setLocal(() {
                    selectedExpert = value;
                  });
                },
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text('گزارشی پیدا نشد.'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final report = filtered[i];

                        return Card(
                          child: ExpansionTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.assignment),
                            ),
                            title: Text(report.activity),
                            subtitle: Text(
                              '${report.expertName} • ${report.date} • ${report.time}',
                            ),
                            children: [
                              ListTile(
                                title: const Text('کد یکتا'),
                                subtitle: Text(report.id),
                              ),
                              ListTile(
                                title: const Text('مدت'),
                                subtitle:
                                    Text('${report.minutes} دقیقه'),
                              ),
                              ListTile(
                                title: const Text('شرح'),
                                subtitle: Text(
                                  report.description.isEmpty
                                      ? 'بدون شرح'
                                      : report.description,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  // ==========================================================
  // EXPERTS
  // ==========================================================

  Widget buildExperts() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FilledButton.icon(
          onPressed: addExpert,
          icon: const Icon(Icons.person_add),
          label: const Text('ثبت کارشناس جدید'),
        ),
        const SizedBox(height: 12),
        if (experts.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text('هنوز کارشناسی ثبت نشده است.'),
              ),
            ),
          ),
        ...experts.map(
          (expert) => Card(
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.person),
              ),
              title: Text(expert.fullName),
              subtitle: Text(
                'کد پرسنلی: ${expert.personnelCode}\n'
                'کد ملی: ${expert.nationalCode}\n'
                '${expert.position}',
              ),
              isThreeLine: true,
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => deleteExpert(expert),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // SETTINGS
  // ==========================================================

  Widget buildSettings() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.lock),
            title: const Text('تغییر رمز ورود'),
            subtitle: const Text('تغییر رمز مدیر'),
            trailing: const Icon(Icons.chevron_left),
            onTap: changePassword,
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.list_alt),
            title: const Text('مدیریت فعالیت‌ها'),
            subtitle: const Text(
              'افزودن یا حذف انواع فعالیت',
            ),
            trailing: const Icon(Icons.chevron_left),
            onTap: manageActivities,
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.backup),
            title: const Text('پشتیبان‌گیری'),
            subtitle: const Text(
              'ذخیره تمام اطلاعات برنامه',
            ),
            trailing: const Icon(Icons.chevron_left),
            onTap: exportJson,
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('بازیابی اطلاعات'),
            subtitle: const Text(
              'وارد کردن فایل پشتیبان',
            ),
            trailing: const Icon(Icons.chevron_left),
            onTap: importJson,
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('درباره برنامه'),
            subtitle: const Text(
              'سامانه گزارشات مدیریت بازرسی',
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // ADD EXPERT
  // ==========================================================

  Future<void> addExpert() async {
    final first = TextEditingController();
    final last = TextEditingController();
    final national = TextEditingController();
    final personnel = TextEditingController();
    final phone = TextEditingController();
    final position = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('ثبت اطلاعات کارشناس'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: first,
                  decoration: const InputDecoration(
                    labelText: 'نام',
                  ),
                ),
                TextField(
                  controller: last,
                  decoration: const InputDecoration(
                    labelText: 'نام خانوادگی',
                  ),
                ),
                TextField(
                  controller: national,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'کد ملی',
                  ),
                ),
                TextField(
                  controller: personnel,
                  decoration: const InputDecoration(
                    labelText: 'کد پرسنلی',
                  ),
                ),
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'شماره تماس',
                  ),
                ),
                TextField(
                  controller: position,
                  decoration: const InputDecoration(
                    labelText: 'سمت',
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

    if (result != true) return;

    if (first.text.trim().isEmpty ||
        last.text.trim().isEmpty) {
      message('نام و نام خانوادگی را وارد کنید.');
      return;
    }

    experts.add(
      Expert(
        id: generateId(),
        firstName: first.text.trim(),
        lastName: last.text.trim(),
        nationalCode: national.text.trim(),
        personnelCode: personnel.text.trim(),
        phone: phone.text.trim(),
        position: position.text.trim(),
      ),
    );

    await saveData();
    setState(() {});
    message('کارشناس با موفقیت ثبت شد.');
  }

  Future<void> deleteExpert(Expert expert) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('حذف کارشناس'),
          content: Text(
            'آیا از حذف ${expert.fullName} مطمئن هستید؟',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('خیر'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('حذف'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    experts.removeWhere((e) => e.id == expert.id);
    await saveData();
    setState(() {});
  }

  // ==========================================================
  // ADD REPORT
  // ==========================================================

  Future<void> addReport() async {
    if (experts.isEmpty) {
      message('ابتدا حداقل یک کارشناس ثبت کنید.');
      return;
    }

    Expert selectedExpert = experts.first;
    String selectedActivity = activities.first;

    final description = TextEditingController();
    final minutes = TextEditingController(text: '60');

    DateTime selectedDate = DateTime.now();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final jalali =
                JalaliDate.fromGregorian(selectedDate).formatted;

            final time =
                DateFormat('HH:mm').format(selectedDate);

            return AlertDialog(
              title: const Text('ثبت فعالیت'),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    DropdownButtonFormField<Expert>(
                      initialValue: selectedExpert,
                      decoration: const InputDecoration(
                        labelText: 'کارشناس',
                      ),
                      items: experts
                          .map(
                            (e) => DropdownMenuItem(
                              value: e,
                              child: Text(e.fullName),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          selectedExpert = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedActivity,
                      decoration: const InputDecoration(
                        labelText: 'نوع فعالیت',
                      ),
                      items: activities
                          .map(
                            (a) => DropdownMenuItem(
                              value: a,
                              child: Text(a),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          selectedActivity = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      title: const Text('تاریخ'),
                      subtitle: Text(jalali),
                      leading: const Icon(Icons.calendar_month),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                          initialDate: selectedDate,
                        );

                        if (date != null) {
                          setDialogState(() {
                            selectedDate = DateTime(
                              date.year,
                              date.month,
                              date.day,
                              selectedDate.hour,
                              selectedDate.minute,
                            );
                          });
                        }
                      },
                    ),
                    ListTile(
                      title: const Text('ساعت'),
                      subtitle: Text(time),
                      leading: const Icon(Icons.access_time),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(
                            selectedDate,
                          ),
                        );

                        if (picked != null) {
                          setDialogState(() {
                            selectedDate = DateTime(
                              selectedDate.year,
                              selectedDate.month,
                              selectedDate.day,
                              picked.hour,
                              picked.minute,
                            );
                          });
                        }
                      },
                    ),
                    TextField(
                      controller: minutes,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'مدت فعالیت به دقیقه',
                      ),
                    ),
                    TextField(
                      controller: description,
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
                  child: const Text('ثبت گزارش'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true) return;

    final id = generateId();

    reports.add(
      ActivityReport(
        id: id,
        expertId: selectedExpert.id,
        expertName: selectedExpert.fullName,
        activity: selectedActivity,
        description: description.text.trim(),
        date: JalaliDate.fromGregorian(selectedDate).formatted,
        time: DateFormat('HH:mm').format(selectedDate),
        minutes: int.tryParse(minutes.text) ?? 0,
      ),
    );

    await saveData();
    setState(() {});
    message('گزارش ثبت شد. کد: $id');
  }

  // ==========================================================
  // REPORTING
  // ==========================================================

  void showReports() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('گزارش‌گیری'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.calendar_month),
                title: const Text('گزارش ماه جاری'),
                onTap: () {
                  Navigator.pop(dialogContext);
                  monthlyReport();
                },
              ),
              ListTile(
                leading: const Icon(Icons.date_range),
                title: const Text('گزارش بازه دلخواه'),
                onTap: () {
                  Navigator.pop(dialogContext);
                  rangeReport();
                },
              ),
              ListTile(
                leading: const Icon(Icons.bar_chart),
                title: const Text('آمار فعالیت'),
                onTap: () {
                  Navigator.pop(dialogContext);
                  statistics();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> monthlyReport() async {
    final now = DateTime.now();
    final currentMonth =
        JalaliDate.fromGregorian(now).formatted.substring(0, 7);

    final list = reports
        .where((r) => r.date.startsWith(currentMonth))
        .toList();

    final minutes =
        list.fold<int>(0, (sum, r) => sum + r.minutes);

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('گزارش ماه جاری'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('تعداد گزارش'),
                trailing: Text('${list.length}'),
              ),
              ListTile(
                title: const Text('مجموع ساعات'),
                trailing:
                    Text((minutes / 60).toStringAsFixed(1)),
              ),
              const Divider(),
              ...list.take(10).map(
                    (r) => ListTile(
                      title: Text(r.activity),
                      subtitle: Text(
                        '${r.expertName} • ${r.minutes} دقیقه',
                      ),
                    ),
                  ),
            ],
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
  }

  Future<void> rangeReport() async {
    DateTime from =
        DateTime.now().subtract(const Duration(days: 30));
    DateTime to = DateTime.now();

    final result = await showDialog<List<ActivityReport>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final list = reports.where((r) {
              final parsed = parseJalali(r.date);

              if (parsed == null) return false;

              return !parsed.isBefore(
                    DateTime(
                      from.year,
                      from.month,
                      from.day,
                    ),
                  ) &&
                  !parsed.isAfter(
                    DateTime(
                      to.year,
                      to.month,
                      to.day,
                    ),
                  );
            }).toList();

            return AlertDialog(
              title: const Text('گزارش بازه دلخواه'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text('از تاریخ'),
                    subtitle: Text(
                      JalaliDate.fromGregorian(from).formatted,
                    ),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                        initialDate: from,
                      );

                      if (d != null) {
                        setDialogState(() {
                          from = d;
                        });
                      }
                    },
                  ),
                  ListTile(
                    title: const Text('تا تاریخ'),
                    subtitle: Text(
                      JalaliDate.fromGregorian(to).formatted,
                    ),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                        initialDate: to,
                      );

                      if (d != null) {
                        setDialogState(() {
                          to = d;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    title: const Text('تعداد گزارش'),
                    trailing: Text('${list.length}'),
                  ),
                ],
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

    result;
  }

  DateTime? parseJalali(String value) {
    final parts = value.split('/');

    if (parts.length != 3) return null;

    final jy = int.tryParse(parts[0]);
    final jm = int.tryParse(parts[1]);
    final jd = int.tryParse(parts[2]);

    if (jy == null || jm == null || jd == null) {
      return null;
    }

    // Approximate Gregorian equivalent sufficient for
    // local range filtering.
    final gy = jy + 621;

    return DateTime(
      gy,
      jm.clamp(1, 12),
      jd.clamp(1, 31),
    );
  }

  void statistics() {
    final Map<String, int> activityMinutes = {};

    for (final report in reports) {
      activityMinutes[report.activity] =
          (activityMinutes[report.activity] ?? 0) +
              report.minutes;
    }

    final entries = activityMinutes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('آمار فعالیت'),
          content: SizedBox(
            width: 420,
            child: entries.isEmpty
                ? const Text('اطلاعاتی وجود ندارد.')
                : ListView(
                    shrinkWrap: true,
                    children: entries
                        .map(
                          (e) => ListTile(
                            leading: const Icon(
                              Icons.analytics,
                            ),
                            title: Text(e.key),
                            trailing: Text(
                              '${(e.value / 60).toStringAsFixed(1)} ساعت',
                            ),
                          ),
                        )
                        .toList(),
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
  }

  // ==========================================================
  // ACTIVITIES
  // ==========================================================

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
                width: 420,
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

                    if (value.isNotEmpty &&
                        !activities.contains(value)) {
                      activities.add(value);
                      controller.clear();
                      setDialogState(() {});
                      await saveData();
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

    setState(() {});
  }

  // ==========================================================
  // PASSWORD
  // ==========================================================

  Future<void> changePassword() async {
    final controller = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('تغییر رمز ورود'),
          content: TextField(
            controller: controller,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'رمز جدید',
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
              child: const Text('ذخیره'),
            ),
          ],
        );
      },
    );

    if (result != true) return;

    if (controller.text.trim().length < 4) {
      message('رمز باید حداقل ۴ رقم باشد.');
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'manager_password',
      controller.text.trim(),
    );

    message('رمز ورود تغییر کرد.');
  }

  // ==========================================================
  // EXCEL / CSV
  // ==========================================================

  Future<void> exportExcel() async {
    final rows = <List<dynamic>>[
      [
        'کد یکتا',
        'کارشناس',
        'تاریخ',
        'ساعت',
        'فعالیت',
        'مدت دقیقه',
        'شرح',
      ],
      ...reports.map(
        (r) => [
          r.id,
          r.expertName,
          r.date,
          r.time,
          r.activity,
          r.minutes,
          r.description,
        ],
      ),
    ];

    final csv =
        const ListToCsvConverter().convert(rows);

    final dir =
        await getApplicationDocumentsDirectory();

    final file = File(
      '${dir.path}/inspection_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv',
    );

    await file.writeAsString(
      '\uFEFF$csv',
      encoding: utf8,
    );

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'گزارش مدیریت بازرسی',
    );
  }

  // ==========================================================
  // JSON BACKUP
  // ==========================================================

  Future<void> exportJson() async {
    final data = {
      'format': 'inspection_report_v2',
      'createdAt': DateTime.now().toIso8601String(),
      'experts':
          experts.map((e) => e.toJson()).toList(),
      'reports':
          reports.map((r) => r.toJson()).toList(),
      'activities': activities,
    };

    final dir =
        await getApplicationDocumentsDirectory();

    final file = File(
      '${dir.path}/inspection_backup_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.json',
    );

    await file.writeAsString(
      jsonEncode(data),
      encoding: utf8,
    );

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'پشتیبان اطلاعات گزارشات مدیریت بازرسی',
    );
  }

  Future<void> importJson() async {
    final result =
        await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result == null ||
        result.files.single.path == null) {
      return;
    }

    try {
      final file =
          File(result.files.single.path!);

      final content =
          await file.readAsString();

      final data =
          Map<String, dynamic>.from(
        jsonDecode(content),
      );

      if (data['format'] != 'inspection_report_v2') {
        message('فرمت فایل پشتیبان معتبر نیست.');
        return;
      }

      final expertData =
          (data['experts'] as List?) ?? [];

      final reportData =
          (data['reports'] as List?) ?? [];

      final activityData =
          (data['activities'] as List?) ?? [];

      experts = expertData
          .map(
            (x) => Expert.fromJson(
              Map<String, dynamic>.from(x),
            ),
          )
          .toList();

      reports = reportData
          .map(
            (x) => ActivityReport.fromJson(
              Map<String, dynamic>.from(x),
            ),
          )
          .toList();

      activities =
          activityData.map((x) => '$x').toList();

      await saveData();

      setState(() {});

      message('اطلاعات با موفقیت بازیابی شد.');
    } catch (_) {
      message('خواندن فایل پشتیبان با خطا مواجه شد.');
    }
  }
}
