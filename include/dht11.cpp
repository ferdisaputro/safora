#include <Arduino.h>
#include "DHT.h"

#define DHTPIN 14       // ESP32 GPIO where the DHT sensor is connected
#define DHTTYPE DHT11   // or DHT11

DHT dht(DHTPIN, DHTTYPE);

void setup() {
  Serial.begin(115200);
  dht.begin();   // Initialize DHT sensor
}

void loop() {
  // Read temperature as Celsius
  float temp = dht.readTemperature();
  // Read humidity
  float hum = dht.readHumidity();

  // Check if any reads failed
  if (isnan(temp) || isnan(hum)) {
    Serial.println("Failed to read from DHT sensor!");
    return;
  }

  Serial.print("Temperature: ");
  Serial.print(temp);
  Serial.println(" °C");

  Serial.print("Humidity: ");
  Serial.print(hum);
  Serial.println(" %");

  delay(2000);  // DHT needs 2s delay between reads
}
