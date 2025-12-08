#include <Arduino.h> // arduino core library\

class BrakingSensor { //fungsi kelas untuk mendeteksi pengereman menggunakan data akselerometer dari MPU6050
private:
  float baseline = 0.0f;     // nilai percepatan saat kondisi diam
  bool calibrated = false;   // sensor kalibrasi selesai atau belum
  float brakingIntensity = 0.0f; // nilai intensitas pengeraman (0-100)
  const float sensitivity = 16384.0f; // konversi raw accelerometer mpu6050 ±2g. raw / 16384 = nilai dalam g
  const float smoothingFactor = 0.1f; // faktor smoothing untuk low-pass filter
  float totalGForce = 0.0f;   // besar total gaya g terukur

  // Low-pass filtered forward acceleration (g)
  float filteredAy = 0.0f; // variabel untuk menyimpan nilai Ay yang telah difilter

public:
  // Call this repeatedly until calibration done (e.g., when stationary)
  void calibrate(float axRaw) {
    static float sum = 0; //menampung jumlah total pembacaan
    static int count = 0; // menghitung jumlah pembacaan

    sum += (axRaw / sensitivity); // konversi ke g
    count++; // hitung jumlah sampel

    if (count >= 100) { // setelah 100 sampel, hitung rata-rata
      baseline = sum / count; // simpan nilai baseline
      calibrated = true; // tandai kalibrasi selesai
      sum = 0; // reset untuk kalibrasi berikutnya
      count = 0; // reset untuk kalibrasi berikutnya 
    }
  }

  // Update using existing MPU accel data (raw ax, ay, az) + orientation
  void update(float axRaw, float ayRaw, float azRaw, float pitchRad, float rollRad) { 
    if (!calibrated) return; // berhenti jika belum kalibrasi
    // Convert raw accel to g
    float ax_g = axRaw / sensitivity; // konversi ke g
    float ay_g = ayRaw / sensitivity; // konversi ke g
    float az_g = azRaw / sensitivity; // konversi ke g

    // Gravity compensation (assuming forward = Ay)
    float gravityCompY = sin(pitchRad);  
    // komponen gravitasi pada sumbu Y 
    // sin(pitch) karena pitch adalah sudut elevasi dari horizontal ke vertikal 
    //jika motor sedang miring ke depan, komponen gravitasi pada Y akan positif,
    // jika miring ke belakang, komponen gravitasi pada Y akan negatif
    // sehingga perlu dikurangi dari percepatan Y terukur untuk mendapatkan percepatan sebenarnya akibat pengereman
    float accelY_corr = ay_g - gravityCompY; 
    // koreksi percepatan Y dengan mengurangi komponen gravitasi
    // kemudian gunakan nilai ini untuk deteksi pengereman


    // Low-pass filter to reduce vibration noise
    filteredAy = filteredAy + (accelY_corr - filteredAy) * smoothingFactor; 
    // menerapkan filter low-pass 
    // memperhalus sinyal percepatan Y yang telah dikoreksi 
    //mengurangi noise getaran
    // gunakan filteredAy untuk deteksi pengereman selanjutnya


    // Braking force (positive = braking)
    float brakingG = accelY_corr; // gunakan accelY_corr untuk deteksi pengereman
    if (brakingG < 0) brakingG = 0; // hanya pertimbangkan percepatan positif sebagai pengereman 
    //jika negatif, artinya akselerasi maju, bukan pengereman

    // Serial.print(brakingG); Serial.print(" g, "); Serial.print(pitchRad); Serial.println(" rad");

    // Normalize braking intensity (0–100%)
    brakingIntensity = brakingG * 100.0f; // skala 0-100
    if (brakingIntensity > 100) brakingIntensity = 100; // batasi maksimum 100%

    // Total G-force magnitude (still useful for shock detection)
    totalGForce = sqrt(ax_g * ax_g + ay_g * ay_g + az_g * az_g); // hitung besar total gaya g terukur //untuk deteksi benturan
  }



  float getBrakingIntensity() const { // Fungsi untuk mendapatkan intensitas pengereman // mengembalikan nilai intensitas pengereman sebagai float // dalam rentang 0-100
    return brakingIntensity; // mengembalikan nilai intensitas pengereman
  }

  bool isCalibrated() const { // Fungsi untuk memeriksa status kalibrasi // mengembalikan true jika kalibrasi selesai, false jika belum
    return calibrated; // mengembalikan status kalibrasi
  }

  float getTotalGForce() { // Fungsi untuk mendapatkan besar total gaya g terukur // mengembalikan nilai total gaya g sebagai float
    return totalGForce; // assuming accelerometer range is set to ±2g
  }
};
