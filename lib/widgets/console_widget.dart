// lib/widgets/console_widget.dart
import 'package:flutter/material.dart';

class ConsoleWidget extends StatelessWidget {
  final List<String> lines;
  final VoidCallback onClear;
  final void Function(String) onSend;
  final bool enabled;

  const ConsoleWidget({
    super.key,
    required this.lines,
    required this.onClear,
    required this.onSend,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (enabled)
        Row(children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(hintText: 'Escribe y Enter para enviar'),
              onSubmitted: (t) {
                if (t.trim().isEmpty) return;
                onSend(t.trim());
                controller.clear();
              },
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              final t = controller.text.trim();
              if (t.isEmpty) return;
              onSend(t);
              controller.clear();
            },
            child: const Text('Enviar'),
          ),
        ]),
      const SizedBox(height: 8),
      Container(
        height: 220,
        decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)),
        child: ListView.builder(
          itemCount: lines.length,
          itemBuilder: (context, i) {
            final line = lines[i];
            Color color = Colors.white;
            if (line.contains('TX:')) color = Colors.blueAccent;
            if (line.contains('RX:')) color = Colors.greenAccent;
            if (line.contains('ERROR:')) color = Colors.redAccent;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Text(line, style: TextStyle(color: color, fontFamily: 'monospace', fontSize: 12)),
            );
          },
        ),
      ),
      const SizedBox(height: 6),
      Align(
        alignment: Alignment.centerLeft,
        child: ElevatedButton(onPressed: onClear, child: const Text('Limpiar')),
      ),
    ]);
  }
}
