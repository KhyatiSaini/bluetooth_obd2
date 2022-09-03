export 'package:bluetooth_obd2/enums.dart';

Map<Factors, String> commandsList = {
  Factors.intakeTemperature: '01 0F\r',
  Factors.engineLoad: '01 04\r',
  Factors.calculatedMaf: '01 10\r',
  Factors.rpm: '01 0C\r',
  Factors.speed: '01 0D\r',
  Factors.intakePressure: '01 0B\r',
};

enum Factors {
  intakeTemperature,
  engineLoad,
  calculatedMaf,
  rpm,
  speed,
  intakePressure,
}

Map<Factors, String> commandName = {
  Factors.intakeTemperature: 'Intake Temperature',
  Factors.engineLoad: 'Engine Load',
  Factors.calculatedMaf: 'Calculated MAF',
  Factors.rpm: 'rpm',
  Factors.speed: 'Speed',
  Factors.intakePressure: 'Intake Pressure',
};
