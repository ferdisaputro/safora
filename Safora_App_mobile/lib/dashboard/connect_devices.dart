import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';


class ConnectedDevice with ChangeNotifier {
  String? _name;
  bool _isConnected = false;
  BluetoothDevice? _device;
  List<BluetoothService>? _services;

  String? get name => _name;
  bool get isConnected => _isConnected;
  BluetoothDevice? get device => _device;

  // ConnectedDevice() {
  //   autoConnect();
  // }

  void autoConnect() async {
    final String remoteId = await File('/remoteId.txt').readAsString();
    var device = BluetoothDevice.fromId(remoteId);
    print("connecting to device: $device");
    notifyListeners();
  }

  void connectDevice(BluetoothDevice device) async {
    _name = device.platformName;
    _device = device;

    device.connectionState.listen((state) {
      if(state == BluetoothConnectionState.connected) {
        _isConnected = true;
        device.discoverServices().then((services) {
          _services = services;
        });
        File('/remoteId.txt').writeAsString(_device!.remoteId.toString());
      }
      else {
        _isConnected = false;
      }
      notifyListeners();
    });
    device.connect();
  }

  void disconnectDevice() {
    if (_device != null) {
      _device!.disconnect();
      _isConnected = false;
      notifyListeners();
    }
  }

  void sendData(String data) async {
    if (device != null) {
      _services!.forEach((service) async {
        List<BluetoothCharacteristic> characteristics = service.characteristics;
        for (BluetoothCharacteristic c in characteristics) {
          if (c.properties.write) {
            await c.write(utf8.encode(data));
            print("Data sent: $data");
          }
        }
      });
    } else {
      print("Device is not connected");
    }
  }
}