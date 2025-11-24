#include <Arduino.h>

#define MQ135_PIN 34    // ESP32 ADC pin
#define VCC 3.3         // ESP32 ADC ref voltage

// Function to read the sensor raw voltage
float readVoltage() {
  int rawADC = analogRead(MQ135_PIN);
  return rawADC * (VCC / 4095.0);
}

void setup() {
  Serial.begin(115200);
}

void loop() {
  float vout = readVoltage();

  // Scale voltage (0–3.3V) to AQI range (0–500)
  int AQI = map(vout * 1000, 100, 2500, 0, 500); 
  //   100mV ~ clean air (baseline)
  //  2500mV ~ very polluted (alcohol, smoke, etc.)

  if (AQI < 0) AQI = 0;
  if (AQI > 500) AQI = 500;

  Serial.print("Voltage: "); Serial.print(vout, 3); Serial.print(" V");
  Serial.print("   AQI: "); Serial.print(AQI);

  // Human readable category
  if (AQI < 50) Serial.println("   Excellent 🍃");
  else if (AQI < 100) Serial.println("   Good 🙂");
  else if (AQI < 200) Serial.println("   Moderate 😐");
  else if (AQI < 300) Serial.println("   Poor 😷");
  else Serial.println("   Hazardous ☠️");

  delay(1000);
}
