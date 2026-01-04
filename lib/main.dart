import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import 'dart:io' show Platform;

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'XH-C2X Provisioner',
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData.dark().copyWith(
        primaryColor: Colors.blueAccent,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(fontSize: 18),
          ),
        ),
      ),
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
  final TextEditingController ipController = TextEditingController(
    text: '108.254.1.184',
  );
  final TextEditingController portController = TextEditingController(
    text: '9019',
  );
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

    // Prime scan for iOS reliability
    if (Platform.isIOS) {
      FlutterBluePlus.startScan(timeout: const Duration(seconds: 1));
      await Future.delayed(const Duration(seconds: 1));
      FlutterBluePlus.stopScan();
      await Future.delayed(const Duration(milliseconds: 500));
    }

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
      await device.connect(
        timeout: const Duration(seconds: 10),
        license: License.free,
      );
      setState(() => isConnected = true);
      selectedDevice = device;
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
      if (ssidChar != null &&
          passChar != null &&
          ipChar != null &&
          portChar != null) {
        _showSnackBar('Connected successfully! Ready to provision.');
      } else {
        _showSnackBar(
          'Connected, but some characteristics missing.',
          isError: true,
        );
      }
    } catch (e) {
      _showSnackBar('Connection failed: $e', isError: true);
    }
  }

  void _disconnectFromDevice() async {
    if (selectedDevice != null) {
      await selectedDevice!.disconnect();
      setState(() {
        isConnected = false;
        selectedDevice = null;
      });
      _showSnackBar('Disconnected.');
    }
  }

  void _provisionWiFi() async {
    if (ssidController.text.isEmpty || passController.text.isEmpty) {
      _showSnackBar('Please enter SSID and password.', isError: true);
      return;
    }
    setState(() => isProvisioning = true);
    try {
      await ssidChar!.write(
        ssidController.text.codeUnits,
        withoutResponse: true,
      );
      await Future.delayed(const Duration(seconds: 1));
      await passChar!.write(
        passController.text.codeUnits,
        withoutResponse: true,
      );
      await Future.delayed(const Duration(seconds: 1));
      await ipChar!.write(ipController.text.codeUnits, withoutResponse: true);
      await Future.delayed(const Duration(seconds: 1));
      await portChar!.write(
        portController.text.codeUnits,
        withoutResponse: true,
      );

      _showSnackBar('Provisioning complete! Device will reboot and connect.');
      Timer(const Duration(seconds: 5), () {
        _disconnectFromDevice();
        ssidController.clear();
        passController.clear();
      });
    } catch (e) {
      _showSnackBar('Provisioning error: $e', isError: true);
    } finally {
      setState(() => isProvisioning = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('XH-C2X Provisioner'),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Scan Button - Prominent
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isScanning
                    ? null
                    : () async {
                        if (Platform.isIOS) {
                          await FlutterBluePlus.turnOff();
                          await Future.delayed(
                            const Duration(milliseconds: 500),
                          );
                          await FlutterBluePlus.turnOn();
                          await Future.delayed(const Duration(seconds: 1));
                        }
                        _startScan();
                      },
                icon: isScanning
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.refresh),
                label: Text(
                  isScanning
                      ? 'Scanning for devices...'
                      : 'Scan for XH-C2X Devices',
                ),
              ),
            ),
            const SizedBox(height: 30),

            // Device List
            if (scanResults.isNotEmpty) ...[
              const Text(
                'Found Devices',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: scanResults.length,
                  itemBuilder: (context, index) {
                    final result = scanResults[index];
                    final isThisConnected =
                        isConnected &&
                        selectedDevice?.remoteId == result.device.remoteId;
                    return Card(
                      elevation: 4,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        leading: Icon(
                          isThisConnected
                              ? Icons.bluetooth_connected
                              : Icons.bluetooth_searching,
                          color: isThisConnected ? Colors.green : Colors.blue,
                        ),
                        title: Text(result.device.name ?? 'XH-C2X'),
                        subtitle: Text(
                          'ID: ${result.device.remoteId.str}\nRSSI: ${result.rssi} dBm',
                        ),
                        trailing: ElevatedButton(
                          onPressed: isThisConnected
                              ? null
                              : () => _connectToDevice(result.device),
                          child: Text(
                            isThisConnected ? 'Connected' : 'Connect',
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ] else if (!isScanning && scanResults.isEmpty && !isConnected) ...[
              const Icon(
                Icons.bluetooth_disabled,
                size: 80,
                color: Colors.grey,
              ),
              const SizedBox(height: 20),
              const Text(
                'No devices found.\nPress Scan to search.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            ],

            // Provisioning Form (only when connected)
            if (isConnected) ...[
              const Divider(height: 40, thickness: 2),
              const Text(
                'WiFi & Server Setup',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: ssidController,
                decoration: const InputDecoration(
                  labelText: 'WiFi SSID',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'WiFi Password',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ipController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Server IP',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: portController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Server Port',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isProvisioning ? null : _provisionWiFi,
                  icon: isProvisioning
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Icon(Icons.send),
                  label: Text(
                    isProvisioning ? 'Provisioning...' : 'Send Configuration',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _disconnectFromDevice,
                  icon: const Icon(Icons.bluetooth_disabled),
                  label: const Text('Disconnect'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                  ),
                ),
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
