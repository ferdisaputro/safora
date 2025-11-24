#include <Arduino.h>

class BrakingSensor {
private:
  float baseline = 0.0f;     // baseline acceleration when stationary
  bool calibrated = false;
  float brakingIntensity = 0.0f;
  const float sensitivity = 16384.0f; // for ±2g
  const float smoothingFactor = 0.1f; // low-pass filter (0.0–1.0)
  float totalGForce = 0.0f;   // total G-force magnitude

  // Low-pass filtered forward acceleration (g)
  float filteredAy = 0.0f;

public:
  // Call this repeatedly until calibration done (e.g., when stationary)
  void calibrate(float axRaw) {
    static float sum = 0;
    static int count = 0;

    sum += (axRaw / sensitivity);
    count++;

    if (count >= 50) { // average of 100 samples
      baseline = sum / count;
      calibrated = true;
      sum = 0;
      count = 0;
    }
  }

  // Update using existing MPU accel data (raw ax, ay, az) + orientation
  void update(float axRaw, float ayRaw, float azRaw, float pitchRad, float rollRad) {
    if (!calibrated) return; // skip until calibration done

    // Convert raw accel to g
    float ax_g = axRaw / sensitivity;
    float ay_g = ayRaw / sensitivity;
    float az_g = azRaw / sensitivity;

    // Gravity compensation (assuming forward = Ay)
    float gravityCompY = sin(pitchRad);  // remove gravity from Y-axis
    float accelY_corr = ay_g - gravityCompY;

    // Low-pass filter to reduce vibration noise
    filteredAy = filteredAy + (accelY_corr - filteredAy) * smoothingFactor;


    // Braking force (positive = braking)
    float brakingG = accelY_corr;
    if (brakingG < 0) brakingG = 0; // ignore forward acceleration

    // Serial.print(brakingG); Serial.print(" g, "); Serial.print(pitchRad); Serial.println(" rad");

    // Normalize braking intensity (0–100%)
    brakingIntensity = brakingG * 100.0f;
    if (brakingIntensity > 100) brakingIntensity = 100;

    // Total G-force magnitude (still useful for shock detection)
    totalGForce = sqrt(ax_g * ax_g + ay_g * ay_g + az_g * az_g);
  }



  float getBrakingIntensity() const {
    return brakingIntensity;
  }

  bool isCalibrated() const {
    return calibrated;
  }

  float getTotalGForce() {
    return totalGForce; // assuming accelerometer range is set to ±2g
  }
};
