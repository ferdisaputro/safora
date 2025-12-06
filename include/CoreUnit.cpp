#include <Arduino.h>
#include <Wire.h>
#include <ESP32Servo.h>
#include <MPU6050.h>
#include <ArduinoJson.h>

#define RAD_TO_DEG (180.0f / PI)

enum ConfigurationKey {
  PITCH_CENTER,
  ROLL_CENTER,
  AUTO_LEVELING
};

class CoreUnit {
private:
  MPU6050 mpu1;
	MPU6050 mpu2; 

	// // Dua sensor MPU
  // MPU6050 mpu1{0x68}; // Pitch 
  // MPU6050 mpu2{0x69}; // Roll 

  // Servo
  Servo servoRoll;    
  Servo servoPitch;  

  // Pin servo
  int servoRollPin = 13;
  int servoPitchPin = 14;

  // Batas servo Roll
  int servoMinRoll = -35;
  int servoMaxRoll = 35;
  int rollCenter = 10;

  // Batas Servo Pitch
  int servoMinPitch = -35;
  int servoMaxPitch = 35;
  int pitchCenter = 2;

  // Batas engine cutoff threshold
  int ECThreshold = 55;

  // Filter EMA
  float filteredPitch = 0;
  float filteredRoll = 0;
  float alphaPitch = 0.4;
  float alphaRoll = 0.2;

  // offset kalibrasi
  float offSetPitch = 0.0f;
  float offSetRoll = 0.0f;

  unsigned long lastPrint = 0;
  
  bool autoLeveling = true;

public:
	CoreUnit(MPU6050 mpu1Address, MPU6050 mpu2Address) {
		mpu1 = mpu1Address;
		mpu2 = mpu2Address;
	}

  // ==== INIT ====
  void begin() {
    Serial.begin(115200);
    Wire.begin(21, 22);

    mpu1.initialize();
    if (!mpu1.testConnection()) {
      Serial.println("MPU6050 #1 tidak terdeteksi!");
      while (1);
    }

    mpu2.initialize();
    if (!mpu2.testConnection()) {
      Serial.println("MPU6050 #2 tidak terdeteksi!");
      while (1);
    }

    servoRoll.attach(servoRollPin);
    servoPitch.attach(servoPitchPin);

    delay(500);
    calibrateSensors();
    Serial.println("CoreUnit Ready");
  }

  // ==== KALIBRASI ====
  void calibrateSensors(int samples = 200, int delayMs = 10) {
    Serial.println("\nKalibrasi - Tahan perangkat diam...");
    float sumRoll = 0.0f;
    float sumPitch = 0.0f;

    for (int i = 0; i < samples; ++i) {
      int16_t ax1, ay1, az1;
      int16_t ax2, ay2, az2;

      getAccelData(mpu1, ax1, ay1, az1);
      getAccelData(mpu2, ax2, ay2, az2);

      float r = computeRoll(ax1, ay1, az1);
      float p = computePitch(ax2, ay2, az2);

      sumRoll += r;
      sumPitch += p;
      delay(delayMs);
    }

    offSetRoll = sumRoll / samples;
    offSetPitch = sumPitch / samples;

    filteredRoll = 0;
    filteredPitch = 0;

    // Serial.print("Kalibrasi selesai -> offSetRoll: ");
    // Serial.print(offSetRoll, 3);
    // Serial.print("  offSetPitch: ");
    // Serial.println(offSetPitch, 3);
  }

  void setConfiguration(ConfigurationKey key, int value) {
    Serial.println("Setting configuration: " + String(key) + " to " + String(value));
    if (key == ConfigurationKey::PITCH_CENTER) {
      pitchCenter = value;
    } else if (key == ConfigurationKey::ROLL_CENTER) {
      rollCenter = value;
    } else if (key == ConfigurationKey::AUTO_LEVELING) {
      autoLeveling = value == 0? false : true;
    }
  }

	// float getGForce(int16_t ax, int16_t ay, int16_t az) {
	// 	return sqrtf(ax*ax + ay*ay + az*az) / 16384.0f; // assuming accelerometer range is set to ±2g
	// }

  void resetHeadlampPos() {
    servoRoll.write(90 + rollCenter);
    servoPitch.write(90 + pitchCenter);
  }

  // ==== UPDATE ====
  void update(bool &systemState, int16_t &ax, int16_t &ay, int16_t &az, float &roll, float &pitch, RelayModule relay) {
    if (Serial.available()) {
      char c = Serial.read();
      if (c == 'r' || c == 'R') {
        calibrateSensors();
      }
    }

    int16_t ax1, ay1, az1;
    int16_t ax2, ay2, az2;
    getAccelData(mpu1, ax1, ay1, az1);
    getAccelData(mpu2, ax2, ay2, az2);

    ax = ax1; ay = ay1; az = az1; // output data dari MPU1

		// float g1 = getGForce(ax1, ay1, az1);
		// float g2 = getGForce(ax2, ay2, az2);
		// float gTotal = (g1 + g2) / 2.0f;

    if (!systemState || !autoLeveling) {
      resetHeadlampPos();
      return;
    }

    float rawRoll = computeRoll(ax1, ay1, az1) - offSetRoll;
    float rawPitch = computePitch(ax2, ay2, az2) - offSetPitch;

    filteredRoll = alphaRoll * rawRoll + (1.0f - alphaRoll) * filteredRoll;
    filteredPitch = alphaPitch * rawPitch + (1.0f - alphaPitch) * filteredPitch;

    int servoPosRoll = roundf(map(roundf(filteredRoll), servoMinRoll, servoMaxRoll, 90 + servoMinRoll, 90 + servoMaxRoll));
    int servoPosPitch = roundf(map(roundf(filteredPitch), servoMinPitch, servoMaxPitch, 90 + servoMinPitch, 90 + servoMaxPitch));

    servoPosRoll = constrain(servoPosRoll + rollCenter, 90 + servoMinRoll, 90 + servoMaxRoll);
    servoPosPitch = constrain(servoPosPitch + pitchCenter, 90 + servoMinPitch, 90 + servoMaxPitch);

    if (
      filteredRoll > ECThreshold || 
      filteredRoll < -ECThreshold
    ) {
      systemState = LOW;
      servoPosRoll = 90 + rollCenter;
      servoPosPitch = 90 + pitchCenter;
      relay.setSystem(systemState);
    }

    roll = servoPosRoll;
    pitch = servoPosPitch;

    // Serial.print("Roll: "); Serial.print(filteredRoll, 2); Serial.print(" | Pitch: "); Serial.println(filteredPitch, 2);

    servoRoll.write(servoPosRoll);
    servoPitch.write(servoPosPitch);

    // unsigned long now = millis();
    // if (now - lastPrint > 200) {
    //   lastPrint = now;
		// 	// Serial.print("G-Force: "); Serial.println(gTotal, 2);
    //   Serial.print("rawRoll:"); Serial.print(rawRoll,2);
    //   Serial.print(" filtRoll:"); Serial.print(filteredRoll,2);
    //   Serial.print(" | rawPitch:"); Serial.print(rawPitch,2);
    //   Serial.print(" filtPitch:"); Serial.print(filteredPitch,2);
    //   Serial.print(" | sRoll:"); Serial.print(servoPosRoll);
    //   Serial.print(" | sPitch:"); Serial.println(servoPosPitch);
    // }
  }

private:
  void getAccelData(MPU6050 &mpu, int16_t &ax, int16_t &ay, int16_t &az) {
    int16_t gx, gy, gz;
    mpu.getMotion6(&ax, &ay, &az, &gx, &gy, &gz);
  }

  float computePitch(int16_t ax, int16_t ay, int16_t az) {
    return atan2f((float)ax, sqrtf((float)ay * (float)ay + (float)az * (float)az)) * RAD_TO_DEG;
  }

  float computeRoll(int16_t ax, int16_t ay, int16_t az) {
    return atan2f(-(float)ax, (float)az) * RAD_TO_DEG;
  }
};

// // buat objek global agar bisa dipanggil dari main.cpp
// CoreUnit coreUnit;
