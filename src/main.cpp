#include <Arduino.h>
#include <TinyGPS++.h>
#include <RelayModule.cpp>
#include "CoreUnit.cpp"
#include "BrakingSensor.cpp"
// #include "DHT.h"
// #include "remote.cpp"



// define coreUnit object
TaskHandle_t coreUnitTaskHandle;
CoreUnit coreUnit (
  MPU6050 (0x68), 
  MPU6050 (0x69)
); // alamat I2C MPU6050 default 0x68, 0x69

// define braking sensor object
BrakingSensor brakingSensor;


// remote pins and configuration
// yk04 pinout
#define A_PIN  35   // YK04 D2
#define B_PIN  34   // YK04 D0
#define C_PIN  32   // YK04 D3
bool systemState = LOW;
bool alarmState  = LOW; // LOW = OFF, HIGH = ON
bool alarmTriggered = false;
// Separate button states
#define HOLD_THRESHOLD 1000 // ms
unsigned long btnA_PressStart = 0;
bool btnA_Held = false;
unsigned long btnB_PressStart = 0;
bool btnB_Held = false;

// relay pins 
#define RPIN_4 33
#define RPIN_3 25
#define RPIN_2 26
#define RPIN_1 27
// #define RPIN_4 27
// #define RPIN_3 26
// #define RPIN_2 25
// #define RPIN_1 33
RelayModule relay(RPIN_1, RPIN_2, RPIN_3, RPIN_4);


// define gps object and serial
// GPS serial connection (use UART2 on ESP32)
HardwareSerial gpsSerial(1);
TinyGPSPlus gps;
// Pin config (change if wired differently)
#define RXD2 16  // GPS TX -> ESP32 RX (GPIO16)
#define TXD2 17  // GPS RX -> ESP32 TX (GPIO17)
unsigned long lastGPSUpdate = 0;

// define vibration sensor pin and variables
#define VIBRATION_PIN 34   // Digital pin connected to vibration sensor
unsigned long lastTime = 0;
int vibrationCount = 0;


// // define MQ135 sensor pin and reference voltage
// #define MQ135_PIN 14    // ESP32 ADC pin
// #define VCC 3.3         // ESP32 ADC ref 

// // define DHT sensor pin and type
// #define DHTPIN 14       // ESP32 GPIO where the DHT sensor is connected
// #define DHTTYPE DHT11   // or DHT11
// DHT dht(DHTPIN, DHTTYPE);


// coreUnit task function to run on core 0
void coreUnitTask(void *parameter) {
  bool relayState = false;
  bool pulsing = false;
  unsigned long pulseStartTime = 0;
  unsigned long lastToggleTime = 0;

  static unsigned long lastSignalToggle = 0;
  static bool signalState = false;


  while (true) {
    int16_t ax, ay, az;
    float pitch, roll;
    float gforce = 0.0f;
    float intensity = 0.0f;
    
    coreUnit.update(systemState, ax, ay, az, pitch, roll, relay);

    // --- Calibration Phase ---
    if (!brakingSensor.isCalibrated()) {
      brakingSensor.calibrate(ax);
      Serial.println("Calibrating...");
      vTaskDelay(pdMS_TO_TICKS(50));
      continue;
    }

    // Serial.println(pitch);

    // --- Update Sensor Data ---
    brakingSensor.update(ax, ay, az, pitch * DEG_TO_RAD, roll * DEG_TO_RAD);
    intensity = brakingSensor.getBrakingIntensity();
    gforce = brakingSensor.getTotalGForce();
    

    // --- Braking Pulse Logic ---
    if (intensity > 50 && !pulsing && systemState == HIGH) {
      pulsing = true;
      pulseStartTime = millis();
      lastToggleTime = millis();
      relayState = false;
      Serial.println("Braking pulse started");
    }

    if (pulsing) {
      unsigned long now = millis();

      // Stop after 5 seconds
      if (now - pulseStartTime >= 3000) {
        pulsing = false;
        relay.signalOff();
        Serial.println("Braking pulse ended");
      }
      // Toggle every 100 ms
      else if (now - lastToggleTime >= 100) {
        lastToggleTime = now;
        relayState = !relayState;
        relayState ? relay.signalOn() : relay.signalOff();
      }
    }

    // --- Alarm Trigger Logic ---
    if (systemState == LOW && gforce > 1.4 && alarmState == HIGH) {
      Serial.println("G-Force threshold exceeded while system is OFF! Triggering alarm.");
      alarmTriggered = HIGH;
    }

    if (alarmTriggered == HIGH && alarmState == HIGH) {
      unsigned long now = millis();
      if (now - lastSignalToggle >= 100) {
        lastSignalToggle = now;
        signalState = !signalState;
        signalState ? relay.signalOn() : relay.signalOff();
      }
    }
    
    vTaskDelay(pdMS_TO_TICKS(10)); // update setiap 10ms
  }
}





void  readGPS() {
  // Continuously read from GPS
  while (gpsSerial.available() > 0) {
    gps.encode(gpsSerial.read());
  }

  // Update location every 1 second
  if (millis() - lastGPSUpdate >= 1000) {
    lastGPSUpdate = millis();

    if (gps.location.isValid()) {
        Serial.print("Latitude: ");
        Serial.println(gps.location.lat(), 6);
        Serial.print("Longitude: ");
        Serial.println(gps.location.lng(), 6);
        Serial.print("Altitude: ");
        Serial.println(gps.hdop.hdop());
        Serial.print("Speed: ");
        Serial.println(gps.speed.kmph());
    } else {
        Serial.println("Waiting for GPS signal...");
    }
  }
}


void readVibration() {
  // Read digital vibration signal
  int state = digitalRead(VIBRATION_PIN);

  // Count vibration events
  if (state == HIGH) {
    vibrationCount++;
    delay(10); // Debounce
  }

  // Print every 1 second
  if (millis() - lastTime >= 1000) {
    Serial.print("Vibration Intensity (count/s): ");
    Serial.println(vibrationCount);
    vibrationCount = 0;
    lastTime = millis();
  }
}



// // Function to read the sensor raw voltage
// float readMQ135Voltage() {
//   int rawADC = analogRead(MQ135_PIN);
//   return rawADC * (VCC / 4095.0);
// }

// void readMQ135() {
//   float vout = readMQ135Voltage();

//   // Scale voltage (0–3.3V) to AQI range (0–500)
//   int AQI = map(vout * 1000, 100, 2500, 0, 500); 
//   //   100mV ~ clean air (baseline)
//   //  2500mV ~ very polluted (alcohol, smoke, etc.)

//   if (AQI < 0) AQI = 0;
//   if (AQI > 500) AQI = 500;

//   Serial.print("Voltage: "); Serial.print(vout, 3); Serial.print(" V");
//   Serial.print("   AQI: "); Serial.print(AQI);

//   // Human readable category
//   if (AQI < 50) Serial.println("   Excellent 🍃");
//   else if (AQI < 100) Serial.println("   Good 🙂");
//   else if (AQI < 200) Serial.println("   Moderate 😐");
//   else if (AQI < 300) Serial.println("   Poor 😷");
//   else Serial.println("   Hazardous ☠️");
// }

// void readDHT() {
//   // Read temperature as Celsius
//   float temp = dht.readTemperature();
//   // Read humidity
//   float hum = dht.readHumidity();

//   // Check if any reads failed
//   if (isnan(temp) || isnan(hum)) {
//     Serial.println("Failed to read from DHT sensor!");
//     return;
//   }

//   Serial.print("Temperature: ");
//   Serial.print(temp);
//   Serial.println(" °C");

//   Serial.print("Humidity: ");
//   Serial.print(hum);
//   Serial.println(" %");
// }

void setup() {
  Serial.begin(115200);
  // initialize remote buttons
  pinMode(A_PIN, INPUT);
  pinMode(B_PIN, INPUT);
  pinMode(C_PIN, INPUT);
  // pinMode(D_PIN, INPUT);
    
  coreUnit.begin();
  // Jalankan task di Core 0
  xTaskCreatePinnedToCore(
    coreUnitTask, 
    "CoreUnit Task",
    8192,
    NULL,
    1,
    &coreUnitTaskHandle,
    0
  );

  relay.begin();

  // initialize GPS serial
  gpsSerial.begin(9600, SERIAL_8N1, RXD2, TXD2);
  // // Initialize DHT sensor
  // dht.begin();
  // // Initialize vibration sensor pin
  // pinMode(VIBRATION_PIN, INPUT);
  Serial.println("System Ready");
}

void loop() {
  // -------- BUTTON A: System ON / OFF --------
  if (digitalRead(A_PIN) == HIGH) {
    if (btnA_PressStart == 0) btnA_PressStart = millis();

    if (!btnA_Held && (millis() - btnA_PressStart >= HOLD_THRESHOLD)) {
      if(systemState == HIGH) {
        Serial.println("Button A held 1s - System OFF");
        systemState = LOW;
        btnA_Held = true;
        relay.setSystem(systemState);
        relay.singleStatusSignal();
        delay(500);
      } else {
        Serial.println("System already OFF");
        btnA_Held = true;
      }
    }
  } else {
    if (btnA_PressStart > 0 && !btnA_Held) {
      if (alarmTriggered == true) {
        alarmTriggered = false;
        relay.singleStatusSignal();
        delay(500);
      }

      Serial.println("Button A short press - System ON");
      systemState = HIGH;
      relay.setSystem(systemState);
      delay(500);
    }
    btnA_PressStart = 0;
    btnA_Held = false; 
  }

  // ------ BUTTON B: press to turn on "find signal", hold to turn on or off alarm --------
  if(digitalRead(B_PIN) == HIGH) {
    if (btnB_PressStart == 0) btnB_PressStart = millis();

    if (!btnB_Held && (millis() - btnB_PressStart >= HOLD_THRESHOLD) && alarmTriggered == false && systemState == LOW) {
      btnB_Held = true;
      alarmState = !alarmState;
      if (alarmState) {
        Serial.println("Alarm ON");
        relay.statusSignal();
        delay(500);
      } else {
        Serial.println("Alarm OFF");
        relay.singleStatusSignal();
        delay(500);
      }
    }
  } else {
    if (btnB_PressStart > 0 && !btnB_Held) {
      if (alarmTriggered == true) {
        alarmTriggered = false;
        relay.singleStatusSignal();
        delay(500);
      } else if(systemState != HIGH) {
        relay.statusSignal();
        delay(500);
      }
    }
    btnB_PressStart = 0;
    btnB_Held = false;
  }

  // -------- BUTTON C: activate engin if system ON --------
  if (digitalRead(C_PIN) == HIGH) {
    Serial.println("Button C pressed");
    if (systemState == HIGH) {
      relay.engineStart();
      Serial.println("Engine Started");
      delay(300);
    }
  }

  // -------- BUTTON D --------
  // if (digitalRead(D_PIN) == HIGH) {
  //   Serial.println("Button D pressed");
  //   delay(300);
  // }

  if (systemState == HIGH) {
    // readGPS();
    // readVibration();
  }
}