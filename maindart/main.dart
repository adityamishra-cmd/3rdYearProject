import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // HTTP requests ke liye
import 'package:uuid/uuid.dart'; // Unique ID generate karne ke liye
import 'package:shared_preferences/shared_preferences.dart'; // ID store karne ke liye
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NodeMCU Controller',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const ControlScreen(),
    );
  }
}

class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  // IMPORTANT: Yahan apne computer ki IP address daalein jahan server chal raha hai
  final String _serverIp = "192.168.1.10"; // Example: "192.168.1.5"
  late final String _serverUrl;
  
  String? _uniqueId;
  String _statusMessage = "Ready";
  bool _isPaired = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _serverUrl = "http://$_serverIp:3000";
    _loadUniqueId();
  }

  // App start hone par stored Unique ID load

  Future<void> _loadUniqueId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _uniqueId = prefs.getString('uniqueId');
    });
    // Agar ID pehle se hai, to pairing status check kar sakte hain (optional)
  }

  // Naya Unique ID generate aur store 
  Future<void> _generateAndStoreId() async {
    final prefs = await SharedPreferences.getInstance();
    String newId = const Uuid().v4(); // Ek naya unique ID banayein
    await prefs.setString('uniqueId', newId);
    setState(() {
      _uniqueId = newId;
      _isPaired = false; 
      _statusMessage = "Naya ID generate hua. Ab pair karein.";
    });
  }

  // Device ko server ke saath pair 
  Future<void> _pairDevice() async {
    if (_uniqueId == null) {
      _setStatus("Pehle 'Generate ID' button dabayein.", isError: true);
      return;
    }

    _setLoading(true);
    try {
      final response = await http.post(
        Uri.parse('$_serverUrl/pair'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'uniqueId': _uniqueId}),
      );

      if (response.statusCode == 200) {
        _setStatus("Device safaltapoorvak pair ho gaya!", isError: false);
        setState(() {
          _isPaired = true;
        });
      } else {
        _setStatus("Pairing fail hui: ${response.body}", isError: true);
        setState(() {
          _isPaired = false;
        });
      }
    } catch (e) {
      _setStatus("Error: Server se connect nahi ho pa raha. IP address check karein.", isError: true);
      setState(() {
        _isPaired = false;
      });
    } finally {
      _setLoading(false);
    }
  }

  // Server ko 'on', 'off' command 
  Future<void> _sendCommand(String command) async {
    if (_uniqueId == null || !_isPaired) {
      _setStatus("Kripya pehle device pair karein.", isError: true);
      return;
    }
    
    _setLoading(true);
    try {
      final response = await http.post(
        Uri.parse('$_serverUrl/command'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'command': command, 'uniqueId': _uniqueId}),
      );

      if (response.statusCode == 200) {
        _setStatus("Command '${command.toUpperCase()}' safaltapoorvak bheja gaya.", isError: false);
      } else {
        _setStatus("Command fail hua: ${response.body}", isError: true);
      }
    } catch (e) {
      _setStatus("Error: Server se connect nahi ho pa raha.", isError: true);
    } finally {
      _setLoading(false);
    }
  }
  
  void _setLoading(bool loading) {
      setState(() {
        _isLoading = loading;
      });
  }

  void _setStatus(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.redAccent : Colors.green,
    ));
    setState(() {
      _statusMessage = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NodeMCU Controller'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Unique ID display karne ke liye Card
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'Aapka Unique Device ID:',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        _uniqueId ?? "Abhi generate nahi hua",
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Buttons
              ElevatedButton.icon(
                icon: const Icon(Icons.vpn_key),
                label: const Text('Naya ID Generate Karein'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                onPressed: _isLoading ? null : _generateAndStoreId,
              ),
              const SizedBox(height: 10),
              
              ElevatedButton.icon(
                icon: const Icon(Icons.link),
                label: const Text('Device Pair Karein'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 12)),
                onPressed: _isLoading || _uniqueId == null ? null : _pairDevice,
              ),
              const SizedBox(height: 30),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildControlButton('ON', Icons.flash_on, Colors.teal),
                  _buildControlButton('OFF', Icons.flash_off, Colors.orange),
                ],
              ),
              
              const SizedBox(height: 20),
              if (_isLoading) const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton(String command, IconData icon, Color color) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 30),
      label: Text(command, style: const TextStyle(fontSize: 20)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: _isLoading || !_isPaired ? null : () => _sendCommand(command.toLowerCase()),
    );
  }
}