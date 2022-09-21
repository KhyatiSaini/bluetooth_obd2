library bluetooth_obd2;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bluetooth_obd2/enums.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:fluttertoast/fluttertoast.dart';

class BluetoothObd extends ChangeNotifier {
  /// creating an instance of [FlutterBlue]
  late FlutterBlue _flutterBlue;

  /// list of nearby and scanned [BluetoothDevice]
  late List<BluetoothDevice> _detectedDevices;

  /// connected [BluetoothDevice] OBD-II
  BluetoothDevice? _connectedDevice;

  /// list of the services advertised by the connected bluetooth device
  late List<BluetoothService> _services;

  /// stores the length of the services of the connected obd-ii adapter discovered
  late int totalServicesCounter;

  /// this keeps a track of the examined services
  late int examinedServiceCounter;

  late int commandsExecutedCounter;

  bool scanningBeginOnce = false;

  List<String> commands = [
    commandsList[Factors.intakeTemperature]!,
    commandsList[Factors.engineLoad]!,
    commandsList[Factors.calculatedMaf]!,
    commandsList[Factors.rpm]!,
    commandsList[Factors.speed]!,
    commandsList[Factors.intakePressure]!
  ];

  /// bluetooth characteristic for requesting and receiving data [this is the one which has the write as well as notify ability]
  BluetoothCharacteristic? requestCharacteristic;
  BluetoothCharacteristic? testReader;
  BluetoothCharacteristic? testWriter;
  late BluetoothCharacteristic _rxReadCharacteristic;
  late BluetoothCharacteristic _rxWriteCharacteristic;

  /// singleton class instantiation declaration
  factory BluetoothObd() => _bluetoothObd;

  BluetoothObd._() {
    _flutterBlue = FlutterBlue.instance;
    _detectedDevices = [];
    _services = [];
    totalServicesCounter = 0;
    examinedServiceCounter = 0;
    commandsExecutedCounter = 0;
  }

  static final BluetoothObd _bluetoothObd = BluetoothObd._();

  /// function that returns the status of Bluetooth
  Future<bool> bluetoothStatus() async {
    bool status = await _flutterBlue.isOn;
    return status;
  }

  /// function to scan and populate [_detectedDevices] list if Bluetooth is active
  Future startScan() async {
    bool status = await bluetoothStatus();
    if (status) {
      scanAndPopulateList();
    }
  }

  /// function to populate the scanned devices to [_detectedDevices] list
  void scanAndPopulateList() {
    _flutterBlue.connectedDevices.asStream().listen(addConnectedDevices);
    _flutterBlue.scanResults.listen(addScannedDevices);
    _flutterBlue.startScan(scanMode: ScanMode.lowLatency);
  }

  /// callback function to add [connectedDevices] to [_detectedDevices] list
  void addConnectedDevices(List<BluetoothDevice> devices) {
    for (final BluetoothDevice bluetoothDevice in devices) {
      addDeviceToList(bluetoothDevice);
      debugPrint(bluetoothDevice.toString());
    }
  }

  /// callback function to add [scannedDevices] to [_detectedDevices] list
  void addScannedDevices(List<ScanResult> scanResults) {
    for (final ScanResult scanResult in scanResults) {
      addDeviceToList(scanResult.device);
      debugPrint(scanResult.device.toString());
    }
  }

  /// function to add distinct [bluetoothDevice] to the [_detectedDevices]
  void addDeviceToList(BluetoothDevice bluetoothDevice) {
    if (!_detectedDevices.contains(bluetoothDevice)) {
      _detectedDevices.add(bluetoothDevice);
      notifyListeners();
    }
  }

  /// function to connect to [selectedBluetoothDevice]
  Future<bool> connectToDevice(BluetoothDevice selectedBluetoothDevice) async {
    Future<bool>? returnValue;
    String deviceDisplayName;

    if (selectedBluetoothDevice.name.trim().isNotEmpty) {
      deviceDisplayName = selectedBluetoothDevice.name;
    } else {
      deviceDisplayName = selectedBluetoothDevice.id.toString();
    }

    try {
      await selectedBluetoothDevice
          .connect(
        autoConnect: true,
      )
          .timeout(
        const Duration(
          seconds: 30,
        ),
        onTimeout: () {
          debugPrint('timeout occurred');
          returnValue = Future.value(false);
          disconnectDevice();
        },
      ).then((value) {
        if (returnValue == null) {
          debugPrint('connection successful');
          Fluttertoast.showToast(
            msg: 'Connected successfully to $deviceDisplayName',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.CENTER,
            timeInSecForIosWeb: 1,
            backgroundColor: Colors.red,
            textColor: Colors.white,
            fontSize: 16.0,
          );

          _connectedDevice = selectedBluetoothDevice;
          discoverServices();
          notifyListeners();
        }
      });
    } on PlatformException catch (e) {
      if (e.code == 'already connected') {
        debugPrint('already connected to $deviceDisplayName');
        Fluttertoast.showToast(
          msg: 'Already connected to $deviceDisplayName',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0,
        );

        _connectedDevice = selectedBluetoothDevice;
        discoverServices();
        notifyListeners();
      } else {
        rethrow;
      }
    } catch (e) {
      debugPrint(e.toString());
      Fluttertoast.showToast(
        msg: 'Connection Unsuccessful',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }

    return _connectedDevice == null ? false : true;
  }

  /// function to discover services
  Future discoverServices() async {
    if (_connectedDevice == null) {
      _services = await _connectedDevice!.discoverServices();
      examineServicesForConnection();
    }
  }

  void examineServicesForConnection() {
    if (examinedServiceCounter < totalServicesCounter) {
      final BluetoothService currentExaminingBluetoothService =
          _services[examinedServiceCounter];
      final List<BluetoothCharacteristic>
          currentExaminingBluetoothCharacteristicsArray =
          currentExaminingBluetoothService.characteristics;

      if (currentExaminingBluetoothCharacteristicsArray.isNotEmpty) {
        /// characteristics are present in service, so trying to identify the read and write characteristics
        testReaderWriterCharacteristics(
            currentExaminingBluetoothCharacteristicsArray);
      } else {
        /// characteristics are not present in service
        examinedServiceCounter++;
        examineServicesForConnection();
      }
    } else if (totalServicesCounter > 0 &&
        examinedServiceCounter == totalServicesCounter) {
      debugPrint('device is not compatible for communication');
    } else {
      debugPrint('check required');
    }
  }

  void testReaderWriterCharacteristics(
      List<BluetoothCharacteristic> examiningCharacteristics) {
    for (BluetoothCharacteristic characteristic in examiningCharacteristics) {
      if (characteristic.properties.notify) {
        testReader = characteristic;
      }
      if (characteristic.properties.write) {
        testWriter = characteristic;
      }

      if (testReader != null && testWriter != null) {
        /// start writing test command
        performDeviceConnectionTest();
      } else {
        examinedServiceCounter++;
        examineServicesForConnection();
      }
    }
  }

  void performDeviceConnectionTest() async {
    const testCommand = "AT Z\r";
    final convertedTestCommand = utf8.encode(testCommand);
    await testReader?.setNotifyValue(true);
    testReader?.value.listen((response) {
      // TODO: parse the value for a given command correctly
      _parseValueReceived(response, commands[commandsExecutedCounter]);
      var responseReceived = utf8.decode(response);

      if (responseReceived.contains("ELM")) {
        scanningBeginOnce = true;
        debugPrint("device is compatible");
        //stop the test scanning and continue to actual scan.
        testReader?.setNotifyValue(false);

        /// disconnecting the connected device for actual scanning
        disconnectDevice();
        _rxReadCharacteristic = testReader!;
        _rxWriteCharacteristic = testWriter!;
        _prepareForScanning();
      } else {
        debugPrint("obd device is not found. continuing scanning");
        //continue to test scanning.
        examinedServiceCounter = examinedServiceCounter + 1;
        examineServicesForConnection();
      }
    });

    await testWriter?.write(convertedTestCommand);
  }

  /// parse the value received from obd2 using the conversion formula
  void _parseValueReceived(List<int> response, String command) {
    num res = 0;

    debugPrint(response.toString());

    // parse intake temperature
    if (command == commandsList[Factors.intakeTemperature]) {
      res = response[0] - 40;
    }
    // parse engine load
    else if (command == commandsList[Factors.engineLoad]) {
      res = response[0] / 2.55;
    }
    // parse calculated maf
    else if (command == commandsList[Factors.calculatedMaf]) {
      res = (256 * response[0] + response[1]) / 100;
    }
    // parse rpm
    else if (command == commandsList[Factors.rpm]) {
      res = (256 * response[0] + response[1]) / 4;
    }
    // parse speed
    else if (command == commandsList[Factors.speed]) {
      res = response[0];
    }
    // parse intake pressure
    else if (command == commandsList[Factors.intakePressure]) {
      res = response[0];
    }

    debugPrint('$command = $res');
  }

  Future _prepareForScanning() async {
    /// set notifier for reader characteristic value
    _rxReadCharacteristic.setNotifyValue(true);
    _rxReadCharacteristic.value.transform(utf8.decoder).listen((response) {
      debugPrint('response is $response');

      if (response.isNotEmpty) {
        commandsExecutedCounter++;
        _writeCommandsToDevice();
      } else {
        debugPrint('commands response received is empty');
      }
    });
  }

  void _writeCommandsToDevice() async {
    if (commandsExecutedCounter < commands.length) {
      String currentCommand = commands[commandsExecutedCounter];
      List<int> convertedCommand = utf8.encode(currentCommand);
      await _rxWriteCharacteristic.write(convertedCommand);
    } else if (commandsExecutedCounter == commands.length) {
      debugPrint('Scan is completed');
      // TODO: call a function to return all the values of the parsed factors
    } else {
      debugPrint('some error occurred');
    }
  }

  /// function to disconnected [_connectedDevice]
  void disconnectDevice() async {
    if (_connectedDevice != null) {
      await _connectedDevice?.disconnect();
      _connectedDevice = null;
    }

    notifyListeners();
  }

  /// function to request speed
  Future<num> requestSpeed() async {
    List<int> request = [2, 1, 13, 170, 170, 170, 170, 170];
    if (requestCharacteristic != null) {
      writeCharacteristics(requestCharacteristic!, request);
    }

    List<int> response = await readCharacteristics(requestCharacteristic!);
    num speed = 0;
    if (response.isNotEmpty && response.length > 3) {
      speed = 0 + 1 * response[3];
    }

    return speed;
  }

  /// function to read data of a particular [characteristic]
  Future<List<int>> readCharacteristics(
      BluetoothCharacteristic characteristic) async {
    final List<int> readValue =
        await characteristic.read().onError((error, stackTrace) {
      debugPrint('error while read ${error.toString()}');
      return [];
    });

    if (readValue.isNotEmpty) {
      debugPrint(
          'read characteristic ${characteristic.uuid.toString()} value ${readValue.toString()}');
      return readValue;
    }

    return [];
  }

  /// function to write data to a [characteristic]
  Future writeCharacteristics(
      BluetoothCharacteristic characteristic, List<int> value) async {
    final String? response = await characteristic
        .write(
      value,
      withoutResponse: false,
    )
        .onError((error, stackTrace) {
      debugPrint('error is ${error.toString()}');
    });

    if (response != null) {
      debugPrint(
          'response after writing the characteristic ${characteristic.uuid.toString()} is $response');
    }
  }

  /// function to listen to the characteristic value updates
  Future<List<int>> notify(BluetoothCharacteristic characteristic) async {
    List<int> response = [];
    await characteristic.setNotifyValue(true).onError((error, stackTrace) {
      debugPrint('error is ${error.toString()}');
      return false;
    });

    characteristic.value.listen((event) {
      debugPrint(
          '${characteristic.uuid.toString()} value: ${event.toString()}');

      response = event;
    });

    return response;
  }

  /// function to stop the scan
  Future stopScan() async {
    await _flutterBlue.stopScan();
  }

  /// function to return a copy of [_detectedDevices]
  List<BluetoothDevice> get scannedBluetoothDevices {
    return [..._detectedDevices];
  }

  /// function to return [_connectedDevice]
  BluetoothDevice? get getConnectedDevice => _connectedDevice;

  /// function to check whether the device is connected to the OBD-II device
  bool isConnected() {
    return _connectedDevice == null ? false : true;
  }
}
