import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'XH-C2X Provisioner',
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData.dark(),
      home: const BleProvisioner(),
    );
  }
}

class BleProvisioner extends StatefulWidget {
  const BleProvisioner({super.key});
  @override
  State<BleProvisioner> createState() => _BleProvisionerState();
}

class _BleProvisionerState extends State<BleProvisioner> {
  List<ScanResult> scanResults = [];
  BluetoothDevice? selectedDevice;
  BluetoothCharacteristic? ssidChar;
  BluetoothCharacteristic? passChar;
  BluetoothCharacteristic? ipChar;
  BluetoothCharacteristic? portChar;
  final TextEditingController ssidController = TextEditingController();
  final TextEditingController passController = TextEditingController();
  final TextEditingController ipController = TextEditingController(text: '108.254.1.184');
  final TextEditingController portController = TextEditingController(text: '9019');
  bool isScanning = false;
  bool isConnected = false;
  bool isProvisioning = false;
  StreamSubscription<List<ScanResult>>? scanSubscription;
  static final serviceUuid = Guid('12345678-1234-1234-1234-123456789abc');
  static final ssidUuid = Guid('87654321-4321-4321-4321-cba987654321');
  static final passUuid = Guid('cba98765-4321-4321-4321-123456789abc');
  static final ipUuid = Guid('11111111-2222-3333-4444-555555555555');
  static final portUuid = Guid('99999999-8888-7777-6666-555555555555');

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  void _startScan() async {
    await scanSubscription?.cancel();
    setState(() {
      isScanning = true;
      scanResults.clear();
    });
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
    scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        scanResults = results.where((r) => r.device.name == 'XH-C2X').toList();
      });
    });
    await Future.delayed(const Duration(seconds: 15));
    FlutterBluePlus.stopScan();
    setState(() => isScanning = false);
  }

  void _connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect(timeout: const Duration(seconds: 10));
      setState(() => isConnected = true);
      final services = await device.discoverServices();
      for (final service in services) {
        if (service.uuid == serviceUuid) {
          for (final char in service.characteristics) {
            if (char.uuid == ssidUuid) ssidChar = char;
            if (char.uuid == passUuid) passChar = char;
            if (char.uuid == ipUuid) ipChar = char;
            if (char.uuid == portUuid) portChar = char;
          }
        }
      }
      if (ssidChar != null && passChar != null && ipChar != null && portChar != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connected! Ready to provision.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Characteristics missing.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection failed: $e')),
      );
    }
  }

  void _disconnectFromDevice() async {
    if (selectedDevice != null) {
      await selectedDevice!.disconnect();
      setState(() {
        isConnected = false;
        selectedDevice = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Disconnected.')),
      );
    }
  }

  void _provisionWiFi() async {
    if (!isConnected || ssidController.text.isEmpty || passController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fill SSID and password.')),
      );
      return;
    }
    setState(() => isProvisioning = true);
    try {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sending SSID...')));
      await ssidChar!.write(ssidController.text.codeUnits, withoutResponse: true);
      await Future.delayed(const Duration(seconds: 1));

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sending Password...')));
      await passChar!.write(passController.text.codeUnits, withoutResponse: true);
      await Future.delayed(const Duration(seconds: 1));

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sending Server IP...')));
      await ipChar!.write(ipController.text.codeUnits, withoutResponse: true);
      await Future.delayed(const Duration(seconds: 1));

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sending Server Port...')));
      await portChar!.write(portController.text.codeUnits, withoutResponse: true);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Provisioning complete! Device will connect and download code.')),
      );
      Timer(const Duration(seconds: 5), _disconnectFromDevice);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => isProvisioning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('XH-C2X Provisioner')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: isScanning ? null : _startScan,
              child: Text(isScanning ? 'Scanning...' : 'Scan for Devices',
              style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),
            if (scanResults.isNotEmpty) ...[
              const Text('Devices (Tap to Connect):'),
              Expanded(
                child: ListView.builder(
                  itemCount: scanResults.length,
                  itemBuilder: (context, index) {
                    final result = scanResults[index];
                    return Card(
                      child: ListTile(
                        title: Text(result.device.name ?? 'XH-C2X'),
                        subtitle: Text('MAC: ${result.device.remoteId.str}'),
                        trailing: ElevatedButton(
                          onPressed: () {
                            setState(() => selectedDevice = result.device);
                            _connectToDevice(result.device);
                          },
                          child: Text(isConnected && selectedDevice?.remoteId == result.device.remoteId ? 'Connected' : 'Connect'),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            if (isConnected) ...[
              const SizedBox(height: 20),
              Text('Provision (Connected to ${selectedDevice!.name ?? 'XH-C2X'}):'),
              TextField(controller: ssidController, decoration: const InputDecoration(labelText: 'WiFi SSID')),
              TextField(controller: passController, decoration: const InputDecoration(labelText: 'WiFi Password'), obscureText: true),
              TextField(controller: ipController, decoration: const InputDecoration(labelText: 'Server IP (default 108.254.1.184)')),
              TextField(controller: portController, decoration: const InputDecoration(labelText: 'Server Port (default 9019)')),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: isProvisioning ? null : _provisionWiFi,
                child: Text(isProvisioning ? 'Provisioning...' : 'Provision WiFi & Server'),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _disconnectFromDevice,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Disconnect'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    scanSubscription?.cancel();
    selectedDevice?.disconnect();
    ssidController.dispose();
    passController.dispose();
    ipController.dispose();
    portController.dispose();
    super.dispose();
  }
}
