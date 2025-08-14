// lib/screens/control_panel_screen.dart
// v3a control panel UI

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';

class ControlPanelScreen extends StatelessWidget {
  const ControlPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(builder: (context, app, _) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Arduino Controller v3a'),
          actions: [
            PopupMenuButton<TransportMode>(
              initialValue: app.mode,
              onSelected: (m) => app.setMode(m),
              itemBuilder: (context) => const [
                PopupMenuItem(value: TransportMode.ble, child: Text('BLE')),
                PopupMenuItem(value: TransportMode.classic, child: Text('Classic (Android)')),
              ],
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(12),
          child: ListView(
            children: [
              _buildConnectionBar(context, app),
              const SizedBox(height: 12),
              _buildDigitalGrid(context, app),
              const SizedBox(height: 12),
              _buildSendGet(context, app),
              const SizedBox(height: 12),
              _buildAnalogSection(context, app),
              const SizedBox(height: 12),
              _buildConsole(context, app),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildConnectionBar(BuildContext context, AppState app) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Estado: ${app.status}', style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 6),
          Row(
            children: [
              ElevatedButton(
                onPressed: app.isInitialized && !app.isScanning
                    ? () => app.scan()
                    : null,
                child: Text(app.isScanning ? 'Escaneando...' : 'Escanear'),
              ),
              const SizedBox(width: 8),
              if (app.isConnected)
                ElevatedButton(
                  onPressed: app.disconnect,
                  child: const Text('Desconectar'),
                ),
              const Spacer(),
              Text(app.isConnected ? 'Conectado' : 'Desconectado',
                  style: TextStyle(
                    color: app.isConnected ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  )),
            ],
          ),
          if (app.scanResults.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 150,
              child: ListView.builder(
                itemCount: app.scanResults.length,
                itemBuilder: (context, i) {
                  final d = app.scanResults[i];
                  return ListTile(
                    dense: true,
                    title: Text(d.name, overflow: TextOverflow.ellipsis),
                    subtitle: Text(d.id),
                    trailing: ElevatedButton(
                      onPressed: app.isConnected ? null : () => app.connect(d),
                      child: const Text('Conectar'),
                    ),
                  );
                },
              ),
            )
          ],
        ]),
      ),
    );
  }

  Widget _buildDigitalGrid(BuildContext context, AppState app) {
    final pins = const [13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2];
    final isEnabled = app.isConnected;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Digital D13..D02 (pulsador)', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 1.3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: pins.length,
            itemBuilder: (context, i) {
              final pin = pins[i];
              final active = app.getDigitalState(pin);
              return GestureDetector(
                onTapDown: isEnabled ? (_) => app.digitalMomentary(pin, true) : null,
                onTapUp: isEnabled ? (_) => app.digitalMomentary(pin, false) : null,
                onTapCancel: isEnabled ? () => app.digitalMomentary(pin, false) : null,
                child: Container(
                  decoration: BoxDecoration(
                    color: active ? Colors.green : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: active ? Colors.green.shade700 : Colors.grey.shade400,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('D$pin',
                            style: TextStyle(
                              color: active ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                            )),
                        Text(active ? 'ON' : 'OFF',
                            style: TextStyle(
                              color: active ? Colors.white : Colors.black54,
                              fontSize: 12,
                            )),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ]),
      ),
    );
  }

  Widget _buildSendGet(BuildContext context, AppState app) {
    final controller = TextEditingController();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('SEND / GET ARDUINO DATA', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: app.isConnected,
                decoration: const InputDecoration(hintText: 'Texto a enviar'),
                onSubmitted: (t) {
                  if (t.trim().isEmpty) return;
                  app.sendText(t.trim());
                  controller.clear();
                },
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: app.isConnected
                  ? () {
                      final t = controller.text.trim();
                      if (t.isEmpty) return;
                      app.sendText(t);
                      controller.clear();
                    }
                  : null,
              child: const Text('SEND DATA'),
            ),
          ]),
          const SizedBox(height: 8),
          Text('GET DATA: ${app.lastRxLine}',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton(
              onPressed: app.isConnected ? app.requestRead : null,
              child: const Text('READ'),
            ),
          )
        ]),
      ),
    );
  }

  Widget _buildAnalogSection(BuildContext context, AppState app) {
    final pins = const [11, 10, 9, 6];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('ANALOGWRITE 0–255', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          for (final pin in pins)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pin $pin: ${app.getPwmValue(pin)}'),
                Slider(
                  value: app.getPwmValue(pin).toDouble(),
                  min: 0,
                  max: 255,
                  divisions: 255,
                  onChanged: app.isConnected ? (v) => app.setAnalogWrite(pin, v.toInt()) : null,
                ),
              ],
            ),
        ]),
      ),
    );
  }

  Widget _buildConsole(BuildContext context, AppState app) {
    final quickController = TextEditingController();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Consola Serial', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (app.isConnected)
            Row(children: [
              Expanded(
                child: TextField(
                  controller: quickController,
                  decoration: const InputDecoration(hintText: 'Escribir y Enter para enviar'),
                  onSubmitted: (t) {
                    if (t.trim().isEmpty) return;
                    app.sendText(t.trim());
                    quickController.clear();
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  final t = quickController.text.trim();
                  if (t.isEmpty) return;
                  app.sendText(t);
                  quickController.clear();
                },
                child: const Text('Enviar'),
              ),
            ]),
          const SizedBox(height: 8),
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              itemCount: app.console.length,
              itemBuilder: (context, i) {
                final line = app.console[i];
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
            child: ElevatedButton(
              onPressed: app.clearConsole,
              child: const Text('Limpiar'),
            ),
          )
        ]),
      ),
    );
  }
}
