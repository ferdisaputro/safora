import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';
import 'package:safora_app/dashboard/connect_devices.dart';

class BluetoothScreen extends StatelessWidget {
  const BluetoothScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const BluetoothLists();
  }
}

class BluetoothLists extends StatefulWidget {
  const BluetoothLists({super.key});

  @override
  State<BluetoothLists> createState() => _BluetoothListsState();
}

class _BluetoothListsState extends State<BluetoothLists> {
  List<ScanResult> _devices = [];
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;
  StreamSubscription<List<ScanResult>>? _scanResultsSubscription;

  _BluetoothListsState() {
    _scanBluetooth();
  }

  @override
  void dispose() {
    _adapterStateSubscription?.cancel();
    _scanResultsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _scanBluetooth() async {
    FlutterBluePlus.setLogLevel(LogLevel.verbose, color: false);

    // Check if Bluetooth is supported
    if (!await FlutterBluePlus.isSupported) {
      print("Bluetooth not supported by this device");
      return;
    }

    // Listen to Bluetooth adapter state changes
    _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) async {
      print('Adapter state: $state');

      if (state == BluetoothAdapterState.on) {
        await _startScan();
      } else {
        print('Bluetooth is not enabled. Please enable it to continue.');
      }
    });
  }

  Future<void> _startScan() async {
    print('Starting scan...');

    // Start scanning
    FlutterBluePlus.startScan(timeout: Duration(seconds: 4), androidUsesFineLocation: true);

    // Listen to scan results
    _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
      if (results.isEmpty) {
        print("No Device Found...");
      } else {
        setState(() {
          _devices = results;
        });
      }
    });

    // Wait until scanning completes
    await Future.delayed(Duration(seconds: 4));

    print('Scan completed.');

    // Stop scanning and clean up
    await FlutterBluePlus.stopScan();
    await _scanResultsSubscription?.cancel();
  }

  void _connectDevice(BuildContext context, BluetoothDevice device) {
    Provider.of<ConnectedDevice>(context, listen: false).connectDevice(device);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Bluetooth Devices'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _devices.isEmpty
            ? const Center(
          child: Text(
            'No devices found.\nTap the button to scan.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
        )
            : ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: _devices.length,
          itemBuilder: (context, index) {
            final device = _devices[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 3,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                leading: Icon(
                  device.device.isConnected
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth,
                  color: device.device.isConnected
                      ? Colors.green
                      : Colors.blueGrey,
                  size: 30,
                ),
                title: Text(
                  device.device.name.isEmpty
                      ? device.device.remoteId.toString()
                      : device.device.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  'RSSI: ${device.rssi} | ${device.device.isConnected ? 'Connected' : 'Not Connected'}',
                  style: TextStyle(
                    fontSize: 13,
                    color: device.device.isConnected
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
                onTap: () => _connectDevice(context, device.device),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _scanBluetooth,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
