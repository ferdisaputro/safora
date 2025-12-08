#include <Arduino.h>
#include <Wire.h>
#include <ESP32Servo.h>
#include <MPU6050.h>
#include <ArduinoJson.h>

#define RAD_TO_DEG (180.0f / PI) // konversi radian ke derajat

enum ConfigurationKey {
  PITCH_CENTER, // key untuk mengatur pitch center
  ROLL_CENTER, // key untuk mengatur roll center
  AUTO_LEVELING // key untuk mengatur auto leveling
};

class CoreUnit {
private:
  MPU6050 mpu1; // Pitch
	MPU6050 mpu2; // Roll

  // Fungsi untuk mendapatkan data akselerometer dari MPU6050
  void getAccelData(MPU6050 &mpu, int16_t &ax, int16_t &ay, int16_t &az) {
    mpu.getAcceleration(&ax, &ay, &az); // mendapatkan data akselerometer
  }

  // Fungsi untuk menghitung sudut roll dari data akselerometer
  float computeRoll(int16_t ax, int16_t ay, int16_t az) {
    return atan2f(ay, az) * RAD_TO_DEG; // konversi ke derajat // menghitung roll // gunakan sqrt untuk menghindari pembagian dengan nol 
  }

  // Fungsi untuk menghitung sudut pitch dari data akselerometer
  float computePitch(int16_t ax, int16_t ay, int16_t az) {
    return atan2f(-ax, sqrtf(ay * ay + az * az)) * RAD_TO_DEG; // konversi ke derajat // gunakan sqrt untuk menghindari pembagian dengan nol // menghitung pitch
  }

	// // Dua sensor MPU
  // MPU6050 mpu1{0x68}; // Pitch 
  // MPU6050 mpu2{0x69}; // Roll 

  // Servo
  Servo servoRoll;    // Roll
  Servo servoPitch;  // Pitch 

  // Pin servo
  int servoRollPin = 13; // Pin servo Roll
  int servoPitchPin = 14; // Pin servo Pitch

  // Batas servo Roll
  int servoMinRoll = -35; // batas minimum servo Roll // nilai ini dapat diubah melalui konfigurasi // misalnya untuk menyesuaikan sudut kemiringan maksimum
  int servoMaxRoll = 35; // batas maksimum servo Roll // nilai ini dapat diubah melalui konfigurasi // misalnya untuk menyesuaikan sudut kemiringan maksimum
  int rollCenter = 10; // pusat servo Roll // offset tengah servo Roll // nilai ini dapat diubah melalui konfigurasi // misalnya untuk menyesuaikan posisi netral servo

  // Batas Servo Pitch
  int servoMinPitch = -35; // batas minimum servo Pitch // nilai ini dapat diubah melalui konfigurasi // misalnya untuk menyesuaikan sudut elevasi maksimum
  int servoMaxPitch = 35; // batas maksimum servo Pitch // nilai ini dapat diubah melalui konfigurasi // misalnya untuk menyesuaikan sudut elevasi maksimum
  int pitchCenter = 2; // pusat servo Pitch // offset tengah servo Pitch // nilai ini dapat diubah melalui konfigurasi // misalnya untuk menyesuaikan posisi netral servo

  // Batas engine cutoff threshold
  int ECThreshold = 55; // threshold cutoff engine berdasarkan sudut pitch // misalnya jika pitch melebihi 55 derajat, engine akan dipotong

  // Filter EMA
  float filteredPitch = 0; // nilai pitch yang telah difilter // untuk mengurangi noise getaran // menggunakan filter eksponensial bergerak (EMA)
  float filteredRoll = 0; // nilai roll yang telah difilter // untuk mengurangi noise getaran // menggunakan filter eksponensial bergerak (EMA)
  float alphaPitch = 0.4; // koefisien filter EMA untuk pitch // nilai antara 0-1, semakin besar nilai, semakin responsif namun lebih berisik
  float alphaRoll = 0.2; // koefisien filter EMA untuk roll // nilai antara 0-1, semakin besar nilai, semakin responsif namun lebih berisik

  // offset kalibrasi
  float offSetPitch = 0.0f; // offset kalibrasi untuk pitch // nilai ini diukur saat kalibrasi // digunakan untuk mengoreksi drift atau kesalahan pemasangan sensor // sehingga pitch 0 derajat benar-benar horizontal // dihitung dari data akselerometer // saat perangkat dalam posisi diam dan datar // selama kalibrasi // nilai ini dapat disimpan dalam memori non-volatile jika diperlukan // untuk digunakan pada startup berikutnya // agar tidak perlu kalibrasi ulang setiap kali dinyalakan //
  float offSetRoll = 0.0f; // offset kalibrasi untuk roll // nilai ini diukur saat kalibrasi // digunakan untuk mengoreksi drift atau kesalahan pemasangan sensor // sehingga roll 0 derajat benar-benar sejajar dengan horizon // dihitung dari data akselerometer // saat perangkat dalam posisi diam dan datar // selama kalibrasi // nilai ini dapat disimpan dalam memori non-volatile jika diperlukan // untuk digunakan pada startup berikutnya // agar tidak perlu kalibrasi ulang setiap kali dinyalakan //

  unsigned long lastPrint = 0; // waktu terakhir data dicetak ke serial monitor // untuk debugging // mengatur interval pencetakan data // misalnya setiap 500 ms // agar tidak membanjiri serial monitor dengan data // hanya mencetak data secara periodik
  
  bool autoLeveling = true; // mode auto-leveling aktif atau tidak // jika true, headlamp akan menyesuaikan posisinya secara otomatis berdasarkan sudut pitch dan roll // jika false, headlamp tetap pada posisi netral

public:
	CoreUnit(MPU6050 mpu1Address, MPU6050 mpu2Address) { // Konstruktor CoreUnit dengan alamat MPU6050 // untuk inisialisasi dua sensor MPU6050
		mpu1 = mpu1Address; // inisialisasi MPU1 dengan alamat yang diberikan // Pitch
		mpu2 = mpu2Address; // inisialisasi MPU2 dengan alamat yang diberikan // Roll
	}

  // ==== INIT ====
  void begin() { // Inisialisasi CoreUnit
    Serial.begin(115200); // Inisialisasi komunikasi serial pada baud rate 115200
    Wire.begin(21, 22); // Inisialisasi I2C dengan pin SDA=21 dan SCL=22 

    mpu1.initialize(); // Inisialisasi MPU1 
    if (!mpu1.testConnection()) { // Cek koneksi MPU1
      Serial.println("MPU6050 #1 tidak terdeteksi!"); // Jika gagal, cetak pesan error
      while (1); // Hentikan program
    }

    mpu2.initialize(); // Inisialisasi MPU2
    if (!mpu2.testConnection()) { // Cek koneksi MPU2
      Serial.println("MPU6050 #2 tidak terdeteksi!"); // Jika gagal, cetak pesan error
      while (1); // Hentikan program
    }

    servoRoll.attach(servoRollPin); // Pasang servo Roll ke pin yang ditentukan
    servoPitch.attach(servoPitchPin); // Pasang servo Pitch ke pin yang ditentukan

    delay(500); // Tunggu sebentar agar sensor stabil // sebelum kalibrasi
    calibrateSensors(); // Lakukan kalibrasi sensor // mengukur offset pitch dan roll
    Serial.println("CoreUnit Ready"); // Tampilkan pesan siap
  }

  // ==== KALIBRASI ====
  void calibrateSensors(int samples = 200, int delayMs = 10) { // Fungsi kalibrasi sensor // dengan jumlah sampel dan delay antar sampel // default 200 sampel, 10 ms delay
    Serial.println("\nKalibrasi - Tahan perangkat diam..."); // Instruksi kalibrasi
    float sumRoll = 0.0f; // Variabel untuk menjumlahkan nilai roll
    float sumPitch = 0.0f; // Variabel untuk menjumlahkan nilai pitch

    for (int i = 0; i < samples; ++i) { // Ambil sampel sesuai jumlah yang ditentukan // untuk menghitung rata-rata // offset
      int16_t ax1, ay1, az1; // Variabel untuk data akselerometer MPU1 // Roll
      int16_t ax2, ay2, az2; // Variabel untuk data akselerometer MPU2 // Pitch

      getAccelData(mpu1, ax1, ay1, az1);// Dapatkan data akselerometer dari MPU1 // Roll
      getAccelData(mpu2, ax2, ay2, az2); // Dapatkan data akselerometer dari MPU2 // Pitch

      float r = computeRoll(ax1, ay1, az1); // Hitung sudut roll dari data akselerometer MPU1 // Roll
      float p = computePitch(ax2, ay2, az2); // Hitung sudut pitch dari data akselerometer MPU2 // Pitch

      sumRoll += r;// Jumlahkan nilai roll
      sumPitch += p; // Jumlahkan nilai pitch
      delay(delayMs);// Tunggu sebentar sebelum mengambil sampel berikutnya
    }

    offSetRoll = sumRoll / samples; // Hitung rata-rata roll sebagai offset kalibrasi // simpan di variabel offSetRoll
    offSetPitch = sumPitch / samples; // Hitung rata-rata pitch sebagai offset kalibrasi // simpan di variabel offSetPitch

    filteredRoll = 0; // reset filteredRoll setelah kalibrasi // agar tidak ada nilai sisa dari sebelum kalibrasi // yang dapat mempengaruhi hasil filter selanjutnya 
    filteredPitch = 0; // reset filteredPitch setelah kalibrasi // agar tidak ada nilai sisa dari sebelum kalibrasi // yang dapat mempengaruhi hasil filter selanjutnya

    // Serial.print("Kalibrasi selesai -> offSetRoll: ");
    // Serial.print(offSetRoll, 3);
    // Serial.print("  offSetPitch: ");
    // Serial.println(offSetPitch, 3);
  }

  void setConfiguration(ConfigurationKey key, int value) { // Fungsi untuk mengatur konfigurasi CoreUnit // berdasarkan key dan nilai yang diberikan 
    Serial.println("Setting configuration: " + String(key) + " to " + String(value)); // Tampilkan pesan konfigurasi yang diatur // untuk debugging // monitoring // verifikasi 
    if (key == ConfigurationKey::PITCH_CENTER) { // Jika key adalah PITCH_CENTER //
      pitchCenter = value; // atur pitchCenter ke nilai yang diberikan // mengubah offset tengah servo Pitch // menyesuaikan posisi netral servo Pitch // misalnya untuk menyesuaikan posisi horizontal headlamp
    } else if (key == ConfigurationKey::ROLL_CENTER) { // Jika key adalah ROLL_CENTER 
      rollCenter = value; // atur rollCenter ke nilai yang diberikan // mengubah offset tengah servo Roll // menyesuaikan posisi netral servo Roll // misalnya untuk menyesuaikan posisi sejajar horizon headlamp
    } else if (key == ConfigurationKey::AUTO_LEVELING) { // Jika key adalah AUTO_LEVELING
      autoLeveling = value == 0? false : true; // atur autoLeveling berdasarkan nilai yang diberikan // jika 0 maka nonaktif, selain itu aktif
    }
  }

	// float getGForce(int16_t ax, int16_t ay, int16_t az) {
	// 	return sqrtf(ax*ax + ay*ay + az*az) / 16384.0f; // assuming accelerometer range is set to ±2g
	// }

  void resetHeadlampPos() { // Fungsi untuk mereset posisi headlamp ke tengah // posisi netral // 90 derajat + offset center
    servoRoll.write(90 + rollCenter); // Atur servo Roll ke posisi tengah dengan offset rollCenter // menyesuaikan posisi netral servo Roll
    servoPitch.write(90 + pitchCenter); // Atur servo Pitch ke posisi tengah dengan offset pitchCenter // menyesuaikan posisi netral servo Pitch
  }

  // ==== UPDATE ====
  void update(bool &systemState, int16_t &ax, int16_t &ay, int16_t &az, float &roll, float &pitch, RelayModule relay) { // Fungsi update CoreUnit // membaca sensor, menghitung sudut, mengatur servo // menerima referensi ke systemState, akselerasi, roll, pitch, dan relay module
    if (Serial.available()) { // Cek jika ada data masuk di serial monitor // untuk perintah kalibrasi ulang
      char c = Serial.read(); // Baca karakter dari serial 
      if (c == 'r' || c == 'R') { // Jika karakter adalah 'r' atau 'R' // perintah kalibrasi ulang
        calibrateSensors(); // Lakukan kalibrasi ulang sensor
      }
    }

    int16_t ax1, ay1, az1; // data akselerometer MPU1 // Roll
    int16_t ax2, ay2, az2; // data akselerometer MPU2 // Pitch
    getAccelData(mpu1, ax1, ay1, az1); // dapatkan data akselerometer dari MPU1 // Roll
    getAccelData(mpu2, ax2, ay2, az2); // dapatkan data akselerometer dari MPU2 // Pitch

    ax = ax1; ay = ay1; az = az1; // output data dari MPU1

		// float g1 = getGForce(ax1, ay1, az1);
		// float g2 = getGForce(ax2, ay2, az2);
		// float gTotal = (g1 + g2) / 2.0f;

    if (!systemState || !autoLeveling) { // Jika sistem mati atau auto-leveling nonaktif
      resetHeadlampPos(); // reset posisi headlamp ke tengah // posisi netral
      return; // keluar dari fungsi update
    }

    float rawRoll = computeRoll(ax1, ay1, az1) - offSetRoll; // hitung roll mentah dari data akselerometer MPU1 // Roll // kurangi dengan offset kalibrasi
    float rawPitch = computePitch(ax2, ay2, az2) - offSetPitch; // hitung pitch mentah dari data akselerometer MPU2 // Pitch // kurangi dengan offset kalibrasi

    filteredRoll = alphaRoll * rawRoll + (1.0f - alphaRoll) * filteredRoll; // terapkan filter EMA pada roll // untuk mengurangi noise getaran
    filteredPitch = alphaPitch * rawPitch + (1.0f - alphaPitch) * filteredPitch; // terapkan filter EMA pada pitch // untuk mengurangi noise getaran

    int servoPosRoll = roundf(map(roundf(filteredRoll), servoMinRoll, servoMaxRoll, 90 + servoMinRoll, 90 + servoMaxRoll)); // hitung posisi servo Roll berdasarkan filteredRoll // konversi sudut ke posisi servo // gunakan fungsi map untuk memetakan sudut ke rentang posisi servo
    int servoPosPitch = roundf(map(roundf(filteredPitch), servoMinPitch, servoMaxPitch, 90 + servoMinPitch, 90 + servoMaxPitch)); // hitung posisi servo Pitch berdasarkan filteredPitch // konversi sudut ke posisi servo // gunakan fungsi map untuk memetakan sudut ke rentang posisi servo

    servoPosRoll = constrain(servoPosRoll + rollCenter, 90 + servoMinRoll, 90 + servoMaxRoll); // sesuaikan dengan rollCenter dan batasi dalam rentang yang diizinkan // gunakan fungsi constrain untuk memastikan posisi servo tetap dalam batas yang diizinkan
    servoPosPitch = constrain(servoPosPitch + pitchCenter, 90 + servoMinPitch, 90 + servoMaxPitch); // sesuaikan dengan pitchCenter dan batasi dalam rentang yang diizinkan // gunakan fungsi constrain untuk memastikan posisi servo tetap dalam batas yang diizinkan

    // Cek apakah pitch melebihi threshold untuk engine cutoff

    if (
      filteredRoll > ECThreshold || // jika roll melebihi threshold
      filteredRoll < -ECThreshold
    ) {
      systemState = LOW; // matikan sistem jika melebihi threshold
      servoPosRoll = 90 + rollCenter; // kembalikan servo Roll ke posisi tengah
      servoPosPitch = 90 + pitchCenter; // kembalikan servo Pitch ke posisi tengah
      relay.setSystem(systemState); // perbarui status sistem pada modul relay
    }

    roll = servoPosRoll; // output posisi servo Roll
    pitch = servoPosPitch; // output posisi servo Pitch

    // Serial.print("Roll: "); Serial.print(filteredRoll, 2); Serial.print(" | Pitch: "); Serial.println(filteredPitch, 2);

    servoRoll.write(servoPosRoll); // atur posisi servo Roll // berdasarkan perhitungan // filteredRoll
    servoPitch.write(servoPosPitch); // atur posisi servo Pitch // berdasarkan perhitungan // filteredPitch

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
  void getAccelData(MPU6050 &mpu, int16_t &ax, int16_t &ay, int16_t &az) { // Fungsi untuk mendapatkan data akselerometer dari MPU6050
    int16_t gx, gy, gz; // Variabel untuk data gyroscope (tidak digunakan di sini)
    mpu.getMotion6(&ax, &ay, &az, &gx, &gy, &gz); // mendapatkan data akselerometer dan gyroscope
  }

  float computePitch(int16_t ax, int16_t ay, int16_t az) { // Fungsi untuk menghitung sudut pitch dari data akselerometer // menggunakan rumus atan2 // untuk mendapatkan sudut dalam derajat
    return atan2f((float)ax, sqrtf((float)ay * (float)ay + (float)az * (float)az)) * RAD_TO_DEG; // konversi ke derajat // gunakan sqrt untuk menghindari pembagian dengan nol
  }

  float computeRoll(int16_t ax, int16_t ay, int16_t az) { // Fungsi untuk menghitung sudut roll dari data akselerometer // menggunakan rumus atan2 // untuk mendapatkan sudut dalam derajat
    return atan2f(-(float)ax, (float)az) * RAD_TO_DEG; // konversi ke derajat // menghitung roll // gunakan sqrt untuk menghindari pembagian dengan nol
  }
};

// // buat objek global agar bisa dipanggil dari main.cpp
// CoreUnit coreUnit;
