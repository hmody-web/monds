import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/mundas_colors.dart';
import '../../core/nav.dart';
import '../../services/multiplayer_service.dart';
import '../../widgets/mundas_button.dart';
import '../../widgets/mundas_card.dart';
import '../../widgets/mundas_scaffold.dart';
import 'multiplayer_lobby_screen.dart';

class MultiplayerEntryScreen extends StatefulWidget {
  const MultiplayerEntryScreen({super.key});
  @override
  State<MultiplayerEntryScreen> createState() => _MultiplayerEntryScreenState();
}

class _MultiplayerEntryScreenState extends State<MultiplayerEntryScreen> {
  final service = MultiplayerService();
  final name = TextEditingController();
  final code = TextEditingController();
  int avatar = 0;
  bool loading = false;
  bool joining = false;
  static const avatars = ['🕵️','🦊','🐼','🐯','🐸','🦝','🐧','🐻'];

  Future<void> _go(bool host) async {
    if (name.text.trim().length < 2) return _toast('اكتب اسمك أولاً');
    if (!host && code.text.trim().length < 4) return _toast('اكتب رمز الغرفة');
    setState(() => loading = true);
    try {
      final id = host
          ? await service.createRoom(name: name.text.trim(), avatar: avatar)
          : await service.joinRoom(code: code.text, name: name.text.trim(), avatar: avatar);
      if (!mounted) return;
      Navigator.pushReplacement(context, mundasRoute(MultiplayerLobbyScreen(identity: id)));
    } catch (e) {
      _toast('$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _toast(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    return MundasScaffold(
      title: 'اللعب الجماعي',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
        children: [
          const MundasCard(
            color: MundasColors.primaryLight,
            child: Row(children: [
              Icon(Icons.wifi_tethering_rounded, color: MundasColors.primary, size: 34),
              SizedBox(width: 12),
              Expanded(child: Text('كل لاعب يستخدم جهازه، والرسم والتصويت يتزامنان مع الغرفة مباشرة.', style: TextStyle(height: 1.5))),
            ]),
          ),
          const SizedBox(height: 18),
          const Text('اسمك', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          TextField(controller: name, maxLength: 18, decoration: const InputDecoration(counterText: '', hintText: 'مثلاً: عمر')),
          const SizedBox(height: 16),
          const Text('اختر شخصيتك', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: List.generate(avatars.length, (i) => InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => setState(() => avatar = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 58,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: avatar == i ? MundasColors.primaryLight : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: avatar == i ? MundasColors.primary : MundasColors.line, width: avatar == i ? 2.5 : 1.3),
                ),
                child: Text(avatars[i], style: const TextStyle(fontSize: 28)),
              ),
            )),
          ),
          const SizedBox(height: 24),
          SegmentedButton<bool>(
            segments: const [ButtonSegment(value: false, label: Text('إنشاء غرفة'), icon: Icon(Icons.add_circle_outline_rounded)), ButtonSegment(value: true, label: Text('انضمام'), icon: Icon(Icons.login_rounded))],
            selected: {joining},
            onSelectionChanged: (s) => setState(() => joining = s.first),
          ),
          if (joining) ...[
            const SizedBox(height: 18),
            TextField(
              controller: code,
              textCapitalization: TextCapitalization.characters,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 26, letterSpacing: 4),
              decoration: InputDecoration(
                hintText: 'ABCDE',
                suffixIcon: IconButton(icon: const Icon(Icons.qr_code_scanner_rounded), onPressed: () async {
                  final result = await Navigator.push<String>(context, mundasRoute(const _QrScanScreen()));
                  if (result != null) code.text = result;
                }),
              ),
            ),
          ],
          const SizedBox(height: 20),
          MundasButton(
            label: loading ? 'لحظة...' : (joining ? 'دخول الغرفة' : 'إنشاء غرفة جديدة'),
            icon: joining ? Icons.meeting_room_rounded : Icons.rocket_launch_rounded,
            onPressed: loading ? null : () => _go(!joining),
          ),
          const SizedBox(height: 12),
          const Text('اللعب الجماعي يحتاج اتصال إنترنت فقط أثناء المباراة.', textAlign: TextAlign.center, style: TextStyle(color: MundasColors.muted, fontSize: 12.5)),
        ],
      ),
    );
  }
}

class _QrScanScreen extends StatefulWidget {
  const _QrScanScreen();
  @override
  State<_QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<_QrScanScreen> {
  bool done = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Stack(children: [
      MobileScanner(onDetect: (capture) {
        if (done || capture.barcodes.isEmpty) return;
        final raw = capture.barcodes.first.rawValue ?? '';
        final match = RegExp(r'(?:room=|/)([A-Z0-9]{5,8})$', caseSensitive: false).firstMatch(raw);
        final value = (match?.group(1) ?? raw).trim().toUpperCase();
        if (RegExp(r'^[A-Z0-9]{5,8}$').hasMatch(value)) {
          done = true;
          Navigator.pop(context, value);
        }
      }),
      SafeArea(child: Align(alignment: Alignment.topRight, child: Padding(padding: const EdgeInsets.all(14), child: IconButton.filled(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded))))),
      const Center(
        child: SizedBox(
          width: 245,
          height: 245,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.fromBorderSide(
                BorderSide(color: Colors.white, width: 3),
              ),
              borderRadius: BorderRadius.all(Radius.circular(28)),
            ),
          ),
        ),
      ),
    ]),
  );
}
