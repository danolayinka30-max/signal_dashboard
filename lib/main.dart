import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

void main() {
  runApp(const SignalDashboardApp());
}

class SignalDashboardApp extends StatelessWidget {
  const SignalDashboardApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IKSRR Signal Engine',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        cardColor: const Color(0xFF1E293B),
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: const Color(0xFF38BDF8),
          secondary: const Color(0xFF22C55E),
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}

class Signal {
  final String symbol;
  final String type; // BUY or SELL
  final double entry;
  final double stopLoss;
  final double takeProfit;
  final String timestamp;
  final String session;

  Signal({
    required this.symbol,
    required this.type,
    required this.entry,
    required this.stopLoss,
    required this.takeProfit,
    required this.timestamp,
    required this.session,
  });

  factory Signal.fromJson(Map<String, dynamic> json) {
    return Signal(
      symbol: json['symbol'] ?? 'XAUUSD',
      type: json['type'] ?? 'BUY',
      entry: (json['entry'] as num).toDouble(),
      stopLoss: (json['sl'] as num).toDouble(),
      takeProfit: (json['tp'] as num).toDouble(),
      timestamp: json['time'] ?? DateFormat('HH:mm:ss').format(DateTime.now()),
      session: json['session'] ?? 'Killzone',
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _botTokenController = TextEditingController();
  
  bool _isListening = false;
  Timer? _pollingTimer;
  List<Signal> _signals = [];
  int _lastUpdateId = 0;
  String _statusMessage = 'System Idle. Enter Bot Token to connect.';

  void _toggleListening() {
    if (_isListening) {
      _pollingTimer?.cancel();
      setState(() {
        _isListening = false;
        _statusMessage = 'Polling stopped.';
      });
    } else {
      if (_botTokenController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter Telegram Bot Token')),
        );
        return;
      }
      setState(() {
        _isListening = true;
        _statusMessage = 'Listening for incoming signals...';
      });
      _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) => _fetchTelegramUpdates());
    }
  }

  Future<void> _fetchTelegramUpdates() async {
    final token = _botTokenController.text.trim();
    if (token.isEmpty) return;

    final url = 'https://api.telegram.org/bot$token/getUpdates?offset=${_lastUpdateId + 1}';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['ok'] == true) {
          final results = data['result'] as List;
          for (var item in results) {
            _lastUpdateId = item['update_id'];
            if (item['message'] != null && item['message']['text'] != null) {
              String text = item['message']['text'];
              if (text.contains('XAUUSD') || text.contains('IKSRR')) {
                _parseAndAddSignal(text);
              }
            }
          }
        }
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Connection error: $e';
      });
    }
  }

  void _parseAndAddSignal(String rawText) {
    try {
      String type = rawText.contains('BUY') ? 'BUY' : 'SELL';

      // 🔥 Robust Regex to match exact fields sent by Python script regardless of backticks 🔥
      final entryMatch = RegExp(r'Entry:\s*[`\*]?([0-9\.]+)[`\*]?').firstMatch(rawText);
      final slMatch = RegExp(r'Stop Loss:\s*[`\*]?([0-9\.]+)[`\*]?').firstMatch(rawText);
      final tpMatch = RegExp(r'Take Profit:\s*[`\*]?([0-9\.]+)[`\*]?').firstMatch(rawText);

      double entry = entryMatch != null ? double.parse(entryMatch.group(1)!) : 0.0;
      double sl = slMatch != null ? double.parse(slMatch.group(1)!) : 0.0;
      double tp = tpMatch != null ? double.parse(tpMatch.group(1)!) : 0.0;

      final signal = Signal(
        symbol: 'XAUUSD',
        type: type,
        entry: entry,
        stopLoss: sl,
        takeProfit: tp,
        timestamp: DateFormat('HH:mm:ss').format(DateTime.now()),
        session: 'IKSRR Killzone',
      );

      setState(() {
        _signals.insert(0, signal);
        _statusMessage = 'New Signal Received at ${signal.timestamp}!';
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _botTokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('IKSRR Automated Trading Terminal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
        actions: [
          IconButton(
            icon: Icon(_isListening ? Icons.stop_circle : Icons.play_circle, color: _isListening ? Colors.redAccent : Colors.greenAccent),
            onPressed: _toggleListening,
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Free Telegram Listener Setup', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _botTokenController,
                        decoration: const InputDecoration(
                          labelText: 'Telegram Bot Token',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(_isListening ? Icons.circle : Icons.circle_outlined, color: _isListening ? Colors.green : Colors.grey, size: 14),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_statusMessage, style: TextStyle(color: Colors.grey[400], fontSize: 13))),
                        ],
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Live Trade Feed', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Chip(
                    label: Text('${_signals.length} Signals'),
                    backgroundColor: const Color(0xFF334155),
                  )
                ],
              ),
              const SizedBox(height: 10),
              _signals.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40.0),
                        child: Text('No trade signals generated yet.', style: TextStyle(color: Colors.grey[500])),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _signals.length,
                      itemBuilder: (context, index) {
                        final sig = _signals[index];
                        final isBuy = sig.type == 'BUY';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isBuy ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                sig.type,
                                style: TextStyle(
                                  color: isBuy ? Colors.greenAccent : Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text('${sig.symbol} @${sig.entry}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('SL: ${sig.stopLoss} \vert{} TP:${sig.takeProfit}'),
                            trailing: Text(sig.timestamp, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                          ),
                        );
                      },
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
