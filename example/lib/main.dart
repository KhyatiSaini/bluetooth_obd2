import 'package:bluetooth_obd2/bluetooth_obd2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => BluetoothObd(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late BluetoothObd bluetoothObd;
  late int selected;
  late BluetoothDevice selectedBluetoothDevice;

  @override
  void didChangeDependencies() {
    bluetoothObd = Provider.of<BluetoothObd>(context, listen: false);
    super.didChangeDependencies();
  }

  @override
  void initState() {
    selected = -1;
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();

    // Stops any running scan before closing the screen
    bluetoothObd.stopScan();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth OBD2'),
      ),
      body: Consumer<BluetoothObd>(
        builder: (context, bluetoothObdProvider, child) {
          final List<BluetoothDevice> detectedBluetoothDevices =
              bluetoothObd.scannedBluetoothDevices;

          return ListView.builder(
            itemBuilder: (BuildContext context, index) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                ),
                child: ListTile(
                  title: InkWell(
                    onTap: () async {
                      if (selected == index) {
                       await bluetoothObdProvider.discoverServices();
                      }
                    },
                    child: Text(
                      (detectedBluetoothDevices[index].name == null ||
                              detectedBluetoothDevices[index].name.trim().isEmpty)
                          ? 'Unknown Device'
                          : detectedBluetoothDevices[index].name,
                    ),
                  ),
                  subtitle: Text(
                    detectedBluetoothDevices[index].id.toString(),
                  ),
                  trailing: Radio(
                    value: index,
                    groupValue: selected,
                    onChanged: (int? value) async {
                      if (selected != -1) {
                        print(
                          'Disconnect from previously connected device before connecting to new one.',
                        );
                        bluetoothObdProvider.disconnectDevice();
                      }
                      setState(() {
                        selected = value!;
                        selectedBluetoothDevice =
                            detectedBluetoothDevices[value];
                      });
                      final bool connectionStatus = await bluetoothObdProvider
                          .connectToDevice(selectedBluetoothDevice);
                      debugPrint('connection status $connectionStatus');
                      if (!connectionStatus && mounted) {
                        setState(() {
                          selected = -1;
                        });
                      } else {
                        print(
                          'Connected successfully to the ${detectedBluetoothDevices[index].name} ${detectedBluetoothDevices[index].id}',
                        );
                      }
                    },
                  ),
                ),
              );
            },
            itemCount: detectedBluetoothDevices.length,
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          bool status = await bluetoothObd.bluetoothStatus();

          if (status) {
            await bluetoothObd.startScan();
          } else {
            Fluttertoast.showToast(
              msg: 'Please turn on Bluetooth',
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.CENTER,
              timeInSecForIosWeb: 1,
              backgroundColor: Colors.red,
              textColor: Colors.white,
              fontSize: 16.0,
            );
          }
        },
        tooltip: 'Scan',
        child: const Icon(
          Icons.search,
        ),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
