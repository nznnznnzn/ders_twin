import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const DersTwinApp());
}

class DersTwinApp extends StatelessWidget {
  const DersTwinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DersTwin',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

const subjects = <String>[
  'Matematik',
  'Fizik',
  'Kimya',
  'Biyoloji',
  'Felsefe',
  'Coğrafya',
  'Edebiyat',
  'Tarih',
];

class StudyRecord {
  StudyRecord({
    required this.date,
    required this.subject,
    required this.topicMinutes,
    required this.questionMinutes,
    required this.plannedQuestions,
    required this.solvedQuestions,
    required this.sleepHours,
    required this.sleepQuality,
    required this.energy,
    required this.distractionCount,
    required this.distractionMinutes,
    required this.note,
  });

  final String date;
  final String subject;
  final int topicMinutes;
  final int questionMinutes;
  final int plannedQuestions;
  final int solvedQuestions;
  final double sleepHours;
  final int sleepQuality;
  final int energy;
  final int distractionCount;
  final int distractionMinutes;
  final String note;

  int get totalMinutes => topicMinutes + questionMinutes;

  Map<String, dynamic> toJson() => {
        'date': date,
        'subject': subject,
        'topicMinutes': topicMinutes,
        'questionMinutes': questionMinutes,
        'plannedQuestions': plannedQuestions,
        'solvedQuestions': solvedQuestions,
        'sleepHours': sleepHours,
        'sleepQuality': sleepQuality,
        'energy': energy,
        'distractionCount': distractionCount,
        'distractionMinutes': distractionMinutes,
        'note': note,
      };

  factory StudyRecord.fromJson(Map<String, dynamic> json) => StudyRecord(
        date: json['date'] as String? ?? '',
        subject: json['subject'] as String? ?? subjects.first,
        topicMinutes: (json['topicMinutes'] as num?)?.toInt() ?? 0,
        questionMinutes: (json['questionMinutes'] as num?)?.toInt() ?? 0,
        plannedQuestions: (json['plannedQuestions'] as num?)?.toInt() ?? 0,
        solvedQuestions: (json['solvedQuestions'] as num?)?.toInt() ?? 0,
        sleepHours: (json['sleepHours'] as num?)?.toDouble() ?? 0,
        sleepQuality: (json['sleepQuality'] as num?)?.toInt() ?? 0,
        energy: (json['energy'] as num?)?.toInt() ?? 0,
        distractionCount: (json['distractionCount'] as num?)?.toInt() ?? 0,
        distractionMinutes: (json['distractionMinutes'] as num?)?.toInt() ?? 0,
        note: json['note'] as String? ?? '',
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const storageKey = 'derstwin_records_v1';
  final records = <StudyRecord>[];
  int tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(storageKey) ?? [];
    setState(() {
      records
        ..clear()
        ..addAll(saved.map((item) => StudyRecord.fromJson(jsonDecode(item))));
    });
  }

  Future<void> _saveRecords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      storageKey,
      records.map((record) => jsonEncode(record.toJson())).toList(),
    );
  }

  int get totalMinutes => records.fold(0, (sum, r) => sum + r.totalMinutes);
  int get totalQuestions => records.fold(0, (sum, r) => sum + r.solvedQuestions);
  int get totalDistraction => records.fold(0, (sum, r) => sum + r.distractionMinutes);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DersTwin'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Tüm kayıtları sil',
            icon: const Icon(Icons.delete_outline),
            onPressed: records.isEmpty ? null : _deleteAll,
          ),
        ],
      ),
      body: tabIndex == 0 ? _buildDashboard() : _buildRecords(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openRecordForm,
        icon: const Icon(Icons.add),
        label: const Text('Yeni kayıt'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tabIndex,
        onDestinationSelected: (index) => setState(() => tabIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.insights), label: 'Özet'),
          NavigationDestination(icon: Icon(Icons.list_alt), label: 'Kayıtlar'),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    final bySubject = <String, int>{};
    for (final record in records) {
      bySubject[record.subject] = (bySubject[record.subject] ?? 0) + record.totalMinutes;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        Text('Çalışma özeti', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        Row(
          children: [
            _summaryCard('Toplam süre', '$totalMinutes dk', Icons.timer_outlined),
            const SizedBox(width: 10),
            _summaryCard('Çözülen soru', '$totalQuestions', Icons.quiz_outlined),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _summaryCard('Kayıt sayısı', '${records.length}', Icons.event_note_outlined),
            const SizedBox(width: 10),
            _summaryCard('Dikkat kaybı', '$totalDistraction dk', Icons.center_focus_weak),
          ],
        ),
        const SizedBox(height: 24),
        Text('Derslere göre çalışma', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...subjects.map((subject) {
          final minutes = bySubject[subject] ?? 0;
          final maximum = bySubject.values.isEmpty ? 1 : bySubject.values.reduce((a, b) => a > b ? a : b);
          return Card(
            child: ListTile(
              leading: CircleAvatar(child: Text(subject.substring(0, 1))),
              title: Text(subject),
              subtitle: LinearProgressIndicator(value: minutes / maximum),
              trailing: Text('$minutes dk'),
            ),
          );
        }),
      ],
    );
  }

  Widget _summaryCard(String title, String value, IconData icon) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text(title, style: TextStyle(color: Colors.grey.shade700)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecords() {
    if (records.isEmpty) {
      return const Center(child: Text('Henüz kayıt yok. Sağ alttaki Yeni kayıt düğmesine bas.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
      itemCount: records.length,
      itemBuilder: (context, index) {
        final record = records[index];
        return Card(
          child: ExpansionTile(
            title: Text(record.subject, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${record.date} · ${record.totalMinutes} dakika · ${record.solvedQuestions} soru'),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Konu: ${record.topicMinutes} dk\n'
                  'Soru çözümü: ${record.questionMinutes} dk\n'
                  'Planlanan / çözülen soru: ${record.plannedQuestions} / ${record.solvedQuestions}\n'
                  'Uyku: ${record.sleepHours} saat · Uyku kalitesi: ${record.sleepQuality}/5\n'
                  'Enerji: ${record.energy}/5\n'
                  'Dikkat dağılması: ${record.distractionCount} kez, ${record.distractionMinutes} dk',
                ),
              ),
              if (record.note.isNotEmpty) ...[
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerLeft, child: Text('Not: ${record.note}')),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: 'Kaydı sil',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _deleteRecord(index),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openRecordForm() async {
    final result = await showModalBottomSheet<StudyRecord>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const RecordForm(),
    );
    if (result == null) return;
    setState(() => records.insert(0, result));
    await _saveRecords();
    if (mounted) setState(() => tabIndex = 1);
  }

  Future<void> _deleteRecord(int index) async {
    setState(() => records.removeAt(index));
    await _saveRecords();
  }

  Future<void> _deleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tüm kayıtları sil?'),
        content: const Text('Bu işlem geri alınamaz.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sil')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => records.clear());
    await _saveRecords();
  }
}

class RecordForm extends StatefulWidget {
  const RecordForm({super.key});

  @override
  State<RecordForm> createState() => _RecordFormState();
}

class _RecordFormState extends State<RecordForm> {
  final formKey = GlobalKey<FormState>();
  String subject = subjects.first;
  DateTime date = DateTime.now();
  final topicMinutes = TextEditingController();
  final questionMinutes = TextEditingController();
  final plannedQuestions = TextEditingController();
  final solvedQuestions = TextEditingController();
  final sleepHours = TextEditingController();
  final distractionCount = TextEditingController();
  final distractionMinutes = TextEditingController();
  final note = TextEditingController();
  int sleepQuality = 3;
  int energy = 3;

  @override
  void dispose() {
    for (final controller in [topicMinutes, questionMinutes, plannedQuestions, solvedQuestions, sleepHours, distractionCount, distractionMinutes, note]) {
      controller.dispose();
    }
    super.dispose();
  }

  int number(TextEditingController controller) => int.tryParse(controller.text.trim()) ?? 0;
  double decimal(TextEditingController controller) => double.tryParse(controller.text.replaceAll(',', '.').trim()) ?? 0;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.of(context).viewInsets.bottom + 16),
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Yeni çalışma kaydı', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: subject,
                  decoration: const InputDecoration(labelText: 'Ders', border: OutlineInputBorder()),
                  items: subjects.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
                  onChanged: (value) => setState(() => subject = value ?? subjects.first),
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tarih'),
                  subtitle: Text('${date.day}.${date.month}.${date.year}'),
                  trailing: OutlinedButton(
                    onPressed: _pickDate,
                    child: const Text('Değiştir'),
                  ),
                ),
                const Divider(),
                _numberField(topicMinutes, 'Konu çalışma süresi (dakika)'),
                _numberField(questionMinutes, 'Soru çözme süresi (dakika)'),
                _numberField(plannedQuestions, 'Planlanan soru sayısı'),
                _numberField(solvedQuestions, 'Çözülen soru sayısı'),
                const SizedBox(height: 8),
                _numberField(sleepHours, 'Uyku süresi (saat)', decimalInput: true),
                _rating('Uyku kalitesi', sleepQuality, (value) => setState(() => sleepQuality = value)),
                _rating('Enerji', energy, (value) => setState(() => energy = value)),
                _numberField(distractionCount, 'Dikkat dağılma sayısı'),
                _numberField(distractionMinutes, 'Dikkat dağılma süresi (dakika)'),
                TextFormField(
                  controller: note,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Not', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Kaydet'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _numberField(TextEditingController controller, String label, {bool decimalInput = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(decimal: decimalInput),
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      ),
    );
  }

  Widget _rating(String label, int value, ValueChanged<int> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text('$label: $value/5')),
          for (var i = 1; i <= 5; i++)
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => onChanged(i),
              icon: Icon(i <= value ? Icons.star : Icons.star_border, color: Colors.amber),
            ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDate: date,
    );
    if (picked != null) setState(() => date = picked);
  }

  void _submit() {
    final record = StudyRecord(
      date: '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}',
      subject: subject,
      topicMinutes: number(topicMinutes),
      questionMinutes: number(questionMinutes),
      plannedQuestions: number(plannedQuestions),
      solvedQuestions: number(solvedQuestions),
      sleepHours: decimal(sleepHours),
      sleepQuality: sleepQuality,
      energy: energy,
      distractionCount: number(distractionCount),
      distractionMinutes: number(distractionMinutes),
      note: note.text.trim(),
    );
    Navigator.pop(context, record);
  }
}
