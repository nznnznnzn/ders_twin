import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const DersTwinApp());

const yksSubjects = ['Matematik', 'Türkçe', 'Fizik', 'Kimya', 'Biyoloji', 'Tarih', 'Coğrafya', 'Felsefe', 'Din Kültürü', 'Edebiyat'];
const lgsSubjects = ['Türkçe', 'Matematik', 'Fen Bilimleri', 'T.C. İnkılap Tarihi', 'Din Kültürü', 'İngilizce'];

class DersTwinApp extends StatelessWidget {
  const DersTwinApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'DersTwin',
        theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo), useMaterial3: true),
        home: const StartPage(),
      );
}

class StudyRecord {
  StudyRecord({required this.exam, required this.date, required this.subject, required this.topicMinutes, required this.questionMinutes, required this.plannedQuestions, required this.solvedQuestions, required this.sleepHours, required this.energy, required this.understanding, required this.distractionMinutes, required this.note});
  final String exam, date, subject, note;
  final int topicMinutes, questionMinutes, plannedQuestions, solvedQuestions, energy, understanding, distractionMinutes;
  final double sleepHours;
  int get totalMinutes => topicMinutes + questionMinutes;
  double get completion => plannedQuestions == 0 ? 0 : solvedQuestions / plannedQuestions;
  Map<String, dynamic> toJson() => {'exam': exam, 'date': date, 'subject': subject, 'topicMinutes': topicMinutes, 'questionMinutes': questionMinutes, 'plannedQuestions': plannedQuestions, 'solvedQuestions': solvedQuestions, 'sleepHours': sleepHours, 'energy': energy, 'understanding': understanding, 'distractionMinutes': distractionMinutes, 'note': note};
  factory StudyRecord.fromJson(Map<String, dynamic> j) => StudyRecord(exam: j['exam'] ?? 'YKS', date: j['date'] ?? '', subject: j['subject'] ?? '', topicMinutes: j['topicMinutes'] ?? 0, questionMinutes: j['questionMinutes'] ?? 0, plannedQuestions: j['plannedQuestions'] ?? 0, solvedQuestions: j['solvedQuestions'] ?? 0, sleepHours: (j['sleepHours'] ?? 0).toDouble(), energy: j['energy'] ?? 0, understanding: j['understanding'] ?? 0, distractionMinutes: j['distractionMinutes'] ?? 0, note: j['note'] ?? '');
}

class StartPage extends StatefulWidget {
  const StartPage({super.key});
  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> {
  String? selectedExam;
  bool voiceMode = false;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(children: [
          const Icon(Icons.auto_graph, size: 72, color: Colors.indigo),
          const SizedBox(height: 14),
          Text('DersTwin', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Çalışma verilerini takip et, analizlerini gör.', textAlign: TextAlign.center),
          const SizedBox(height: 32),
          const Text('Hangi sınava hazırlanıyorsun?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _examButton('YKS', 'Lise son sınıf ve mezun öğrenciler', Icons.school),
          const SizedBox(height: 12),
          _examButton('LGS', 'Ortaokul son sınıf öğrencileri', Icons.menu_book),
          const SizedBox(height: 20),
          SwitchListTile(secondary: const Icon(Icons.volume_up), title: const Text('Sesli kullanım'), subtitle: const Text('Telefonu sallayınca sesli mod açılsın'), value: voiceMode, onChanged: (v) => setState(() => voiceMode = v)),
        ]))),
      ));

  Widget _examButton(String exam, String subtitle, IconData icon) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.tonalIcon(
        onPressed: () => Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomePage(exam: exam, voiceMode: voiceMode),
          ),
        ),
        icon: Icon(icon),
        label: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Text(exam, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              Text(subtitle),
            ],
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.exam, required this.voiceMode});
  final String exam;
  final bool voiceMode;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const key = 'derstwin_records_v2';
  final records = <StudyRecord>[];
  final tts = FlutterTts();
  StreamSubscription<AccelerometerEvent>? shakeSubscription;
  DateTime lastShake = DateTime.fromMillisecondsSinceEpoch(0);
  int tab = 0;
  List<String> get subjects => widget.exam == 'LGS' ? lgsSubjects : yksSubjects;
  @override
  void initState() { super.initState(); _load(); if (widget.voiceMode) _listenForShake(); }
  @override
  void dispose() { shakeSubscription?.cancel(); tts.stop(); super.dispose(); }
  Future<void> _load() async { final p = await SharedPreferences.getInstance(); final list = p.getStringList(key) ?? []; setState(() => records.addAll(list.map((x) => StudyRecord.fromJson(jsonDecode(x))))); }
  Future<void> _save() async { final p = await SharedPreferences.getInstance(); await p.setStringList(key, records.map((x) => jsonEncode(x.toJson())).toList()); }
  void _listenForShake() {
    shakeSubscription = accelerometerEventStream().listen((e) {
      final force = e.x.abs() + e.y.abs() + e.z.abs();
      final now = DateTime.now();
      if (force > 28 && now.difference(lastShake).inSeconds > 2) {
        lastShake = now;
        _speak('Sesli kullanım açık. Analiz ekranındasın.');
      }
    });
  }
  Future<void> _speak(String text) async { await tts.setLanguage('tr-TR'); await tts.setSpeechRate(.46); await tts.speak(text); }
  int get total => records.fold(0, (s, r) => s + r.totalMinutes);
  int get solved => records.fold(0, (s, r) => s + r.solvedQuestions);
  int get topic => records.fold(0, (s, r) => s + r.topicMinutes);
  int get questionsTime => records.fold(0, (s, r) => s + r.questionMinutes);
  double get avgSleep => records.isEmpty ? 0 : records.fold(0.0, (s, r) => s + r.sleepHours) / records.length;
  double get avgUnderstanding => records.isEmpty ? 0 : records.fold(0.0, (s, r) => s + r.understanding) / records.length;
  String get analysisText => records.isEmpty ? 'Henüz analiz oluşturmak için kayıt yok.' : '$exam öğrencisi olarak toplam $total dakika çalıştın. $solved soru çözdün. Konu çalışma süren $topic dakika, soru çözme süren $questionsTime dakika. Ortalama uyku süren ${avgSleep.toStringAsFixed(1)} saat, ortalama anlama puanın ${avgUnderstanding.toStringAsFixed(1)} üzerinden 5.';
  String get exam => widget.exam;
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text('DersTwin • $exam'), actions: [IconButton(onPressed: () => _speak(analysisText), icon: const Icon(Icons.volume_up), tooltip: 'Analizi dinle')]), body: tab == 0 ? _dashboard() : _records(), floatingActionButton: FloatingActionButton.extended(onPressed: _newRecord, icon: const Icon(Icons.add), label: const Text('Yeni kayıt')), bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (v) => setState(() => tab = v), destinations: const [NavigationDestination(icon: Icon(Icons.insights), label: 'Analiz'), NavigationDestination(icon: Icon(Icons.list_alt), label: 'Kayıtlar')]));
  Widget _dashboard() { final bySubject = <String, int>{}; for (final r in records) { bySubject[r.subject] = (bySubject[r.subject] ?? 0) + r.totalMinutes; } return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), children: [Text('$exam analizleri', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)), const SizedBox(height: 12), Card(child: ListTile(leading: const Icon(Icons.volume_up), title: const Text('Analizi dinle'), subtitle: const Text('Bu düğmeye basarak özetini sesli dinleyebilirsin.'), onTap: () => _speak(analysisText))), Wrap(spacing: 8, runSpacing: 8, children: [_card('Toplam süre', '$total dk'), _card('Çözülen soru', '$solved'), _card('Konu süresi', '$topic dk'), _card('Soru süresi', '$questionsTime dk'), _card('Ort. uyku', '${avgSleep.toStringAsFixed(1)} saat'), _card('Ort. anlama', '${avgUnderstanding.toStringAsFixed(1)}/5')]), const SizedBox(height: 22), const Text('Derslere göre süre', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 8), ...subjects.map((s) { final m = bySubject[s] ?? 0; final max = bySubject.values.isEmpty ? 1 : bySubject.values.reduce((a, b) => a > b ? a : b); return ListTile(leading: CircleAvatar(child: Text(s.substring(0, 1))), title: Text(s), subtitle: LinearProgressIndicator(value: m / max), trailing: Text('$m dk')); })]); }
  Widget _card(String title, String value) => SizedBox(width: 155, child: Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), Text(title)]))));
  Widget _records() => records.isEmpty ? const Center(child: Text('Henüz kayıt yok.')) : ListView.builder(padding: const EdgeInsets.only(bottom: 100), itemCount: records.length, itemBuilder: (_, i) { final r = records[i]; return Card(child: ListTile(title: Text(r.subject), subtitle: Text('${r.date} • ${r.totalMinutes} dk • ${r.solvedQuestions} soru'), trailing: Text(r.exam))); });
  Future<void> _newRecord() async { final r = await showModalBottomSheet<StudyRecord>(context: context, isScrollControlled: true, builder: (_) => RecordForm(exam: exam, subjects: subjects)); if (r != null) { setState(() => records.insert(0, r)); await _save(); setState(() => tab = 1); } }
}

class RecordForm extends StatefulWidget {
  const RecordForm({super.key, required this.exam, required this.subjects});
  final String exam; final List<String> subjects;
  @override State<RecordForm> createState() => _RecordFormState();
}
class _RecordFormState extends State<RecordForm> {
  String subject = ''; DateTime date = DateTime.now(); int energy = 3, understanding = 3;
  final topic = TextEditingController(), question = TextEditingController(), planned = TextEditingController(), solved = TextEditingController(), sleep = TextEditingController(), distraction = TextEditingController(), note = TextEditingController();
  @override void initState() { super.initState(); subject = widget.subjects.first; }
  @override void dispose() { for (final c in [topic, question, planned, solved, sleep, distraction, note]) { c.dispose(); } super.dispose(); }
  int n(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0; double d(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.').trim()) ?? 0;
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 12),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${widget.exam} çalışma kaydı', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: subject,
                decoration: const InputDecoration(labelText: 'Ders', border: OutlineInputBorder()),
                items: widget.subjects.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setState(() => subject = v!),
              ),
              ListTile(
                title: const Text('Tarih'),
                subtitle: Text('${date.day}.${date.month}.${date.year}'),
                trailing: TextButton(onPressed: _pickDate, child: const Text('Değiştir')),
              ),
              _field(topic, 'Konu çalışma süresi (dk)'),
              _field(question, 'Soru çözme süresi (dk)'),
              _field(planned, 'Planlanan soru sayısı'),
              _field(solved, 'Çözülen soru sayısı'),
              _field(sleep, 'Uyku süresi (saat)', decimal: true),
              _rating('Enerji', energy, (v) => setState(() => energy = v)),
              _rating('Konu anlama', understanding, (v) => setState(() => understanding = v)),
              _field(distraction, 'Dikkat dağılma süresi (dk)'),
              _field(note, 'Not', lines: 2),
              const SizedBox(height: 8),
              FilledButton.icon(onPressed: _submit, icon: const Icon(Icons.save), label: const Text('Kaydet')),
            ],
          ),
        ),
      ),
    );
  }
  Widget _field(TextEditingController c, String label, {bool decimal = false, int lines = 1}) => Padding(padding: const EdgeInsets.only(bottom: 10), child: TextField(controller: c, maxLines: lines, keyboardType: decimal ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.number, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder())));
  Widget _rating(String label, int value, ValueChanged<int> onChanged) => Row(children: [Expanded(child: Text('$label: $value/5')), for (var i = 1; i <= 5; i++) IconButton(onPressed: () => onChanged(i), icon: Icon(i <= value ? Icons.star : Icons.star_border, color: Colors.amber))]);
  Future<void> _pickDate() async { final p = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2035), initialDate: date); if (p != null) setState(() => date = p); }
  void _submit() => Navigator.pop(context, StudyRecord(exam: widget.exam, date: '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}', subject: subject, topicMinutes: n(topic), questionMinutes: n(question), plannedQuestions: n(planned), solvedQuestions: n(solved), sleepHours: d(sleep), energy: energy, understanding: understanding, distractionMinutes: n(distraction), note: note.text.trim()));
}
