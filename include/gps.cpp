#include <Arduino.h>
#include <TinyGPS++.h>
#include <HardwareSerial.h>

// GPS serial connection (use UART2 on ESP32)
HardwareSerial gpsSerial(1);
TinyGPSPlus gps;

// Pin config (change if wired differently)
#define RXD2 16  // GPS TX -> ESP32 RX (GPIO16)
#define TXD2 17  // GPS RX -> ESP32 TX (GPIO17)

unsigned long lastUpdate = 0;

void setup() {
   Serial.begin(115200);
   gpsSerial.begin(9600, SERIAL_8N1, RXD2, TXD2);

   Serial.println("GPS Location Tracker Starting...");
}

void loop() {
   // Continuously read from GPS
   while (gpsSerial.available() > 0) {
      gps.encode(gpsSerial.read());
   }

   // Update location every 1 second
   if (millis() - lastUpdate >= 1000) {
      lastUpdate = millis();

      if (gps.location.isValid()) {
         Serial.print("Latitude: ");
         Serial.println(gps.location.lat(), 6);
         Serial.print("Longitude: ");
         Serial.println(gps.location.lng(), 6);
         Serial.print("Satellites: ");
         Serial.println(gps.satellites.value());
         Serial.print("Altitude: ");
         Serial.println(gps.altitude.meters());
         Serial.print("HDOP: ");
         Serial.println(gps.hdop.hdop());
         Serial.print("Speed: ");
         Serial.println(gps.speed.kmph());
      } else {
         Serial.println("Waiting for GPS signal...");
      }

      Serial.println("----------------------");
   }
}
