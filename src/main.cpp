#include <Arduino.h> // arduino core library
#include <TinyGPS++.h> // GPS library
#include <RelayModule.cpp> // Relay module control
#include "CoreUnit.cpp" // Core unit control
#include "BrakingSensor.cpp" // Braking sensor

#include <BLEDevice.h> // Bluetooth Low Energy (BLE) library
#include <BLEServer.h> // BLE Server
#include <BLEUtils.h> // BLE Utils
#include <BLE2902.h> // BLE Descriptor
#include <ArduinoJson.h> // JSON library

// #include "DHT.h" // DHT sensor library


// define coreUnit object
TaskHandle_t coreUnitTaskHandle; // untuk menyimpan handle task coreUnit // agar dapat diakses dari luar // misalnya untuk menghentikan atau menjeda task jika diperlukan
CoreUnit coreUnit ( //inisialisasi objek coreUnit dengan dua sensor
  MPU6050 (0x68), // alamat I2C 
  MPU6050 (0x69) // alamat I2C
); // alamat I2C MPU6050 default 0x68, 0x69

// define braking sensor object
BrakingSensor brakingSensor; // objek sensor pengereman

// define bluetooth
BLEServer *pServer = nullptr; //petunjuk ke server BLE // untuk mengelola koneksi BLE // dan layanan // karakteristik
BLECharacteristic *pCharacteristic = nullptr; // petunjuk ke karakteristik BLE // untuk komunikasi data // antara server dan klien

// Define a custom service and characteristic UUIDs
const char *SERVICE_UUID = "f069f452-031a-4572-ba01-5748e749498e"; // UUID layanan khusus // untuk identifikasi unik layanan BLE // misalnya layanan kontrol jarak jauh
const char *CHARACTERISTIC_UUID = "75930062-af64-45eb-8397-8bffacd95516"; // UUID karakteristik khusus // untuk identifikasi unik karakteristik BLE // misalnya karakteristik data kontrol jarak jauh

bool deviceConnected = false;

// remote pins and configuration
// yk04 pinout
#define A_PIN  35   // YK04 D2 // hazard button
#define B_PIN  34   // YK04 D0 // lampu senja / alarm button
#define C_PIN  32   // YK04 D3 //tida fungsi //
bool systemState = LOW; // LOW = OFF, HIGH = ON // sistem utama // misalnya lampu utama mesin atau sirine
bool alarmState  = LOW; // LOW = OFF, HIGH = ON // sistem alarm // misalnya lampu senja atau sirine
bool alarmTriggered = false; // status trigger alarm // untuk mendeteksi perubahan status tombol alarm // agar tidak terus-menerus toggle saat tombol ditekan lama // hanya toggle sekali saat tombol ditekan
// Separate button states
#define HOLD_THRESHOLD 1000 // ms // threshold waktu untuk deteksi tombol ditekan lama
unsigned long btnA_PressStart = 0; // waktu saat tombol A mulai ditekan // untuk deteksi tekan lama
bool btnA_Held = false; // status tekan lama tombol A // untuk mencegah multiple trigger pada satu kali tekan lama
unsigned long btnB_PressStart = 0; // waktu saat tombol B mulai ditekan // untuk deteksi tekan lama
bool btnB_Held = false; // status tekan lama tombol B // untuk mencegah multiple trigger pada satu kali tekan lama

// relay pins 
#define RPIN_4 33 // Relay pin 4 // engine start // relay untuk menghidupkan mesin
#define RPIN_3 25 // Relay pin 3 // system on/off // relay untuk mengaktifkan atau menonaktifkan sistem utama
#define RPIN_2 26 // Relay pin 2 // status signal // relay untuk sinyal status
#define RPIN_1 27 // Relay pin 1 // single status signal // relay untuk sinyal status tunggal
// #define RPIN_4 27
// #define RPIN_3 26
// #define RPIN_2 25
// #define RPIN_1 33
RelayModule relay(RPIN_1, RPIN_2, RPIN_3, RPIN_4); // inisialisasi objek relay module dengan pin-pin relay // pin 1-4


// define gps object and serial
// GPS serial connection (use UART2 on ESP32)
HardwareSerial gpsSerial(1); // gunakan UART2 (Serial1) untuk komunikasi GPS
TinyGPSPlus gps;
// Pin config (change if wired differently)
#define RXD2 16  // GPS TX -> ESP32 RX (GPIO16)
#define TXD2 17  // GPS RX -> ESP32 TX (GPIO17)
unsigned long lastGPSUpdate = 0;

// define vibration sensor pin and variables
#define VIBRATION_PIN 34   // koneksi sensor getaran ke pin GPIO34 // YK04 D0
unsigned long lastTime = 0; // waktu terakhir sensor getaran terpicu // untuk debounce // menghindari multiple trigger
int vibrationCount = 0; // jumlah getaran terdeteksi // untuk analisis getaran jika diperlukan


// hazard auto level
int hazardAutoLevel = 0; // 0 = low, 1 = medium, 2 = high // level otomatis hazard berdasarkan intensitas pengereman
bool autoHazardState = true; // status fitur hazard otomatis // true = aktif, false = nonaktif
int hazardDuration = 300; // durasi nyala/mati hazard dalam ms // default 300 ms


// // define MQ135 sensor pin and reference voltage
// #define MQ135_PIN 14    // ESP32 ADC pin
// #define VCC 3.3         // ESP32 ADC ref 

// // define DHT sensor pin and type
// #define DHTPIN 14       // ESP32 GPIO where the DHT sensor is connected
// #define DHTTYPE DHT11   // or DHT11
// DHT dht(DHTPIN, DHTTYPE);


class MyServerCallbacks : public BLEServerCallbacks { //panggilan balik server BLE khusus // untuk menangani peristiwa koneksi dan pemutusan
  void onConnect(BLEServer* pServer) { // saat perangkat klien terhubung ke server BLE
    deviceConnected = true; // perbarui status koneksi // menandakan bahwa perangkat terhubung
    Serial.println("Device connected"); // cetak pesan ke serial monitor // untuk debugging
  }

  void onDisconnect(BLEServer* pServer) { // saat perangkat klien terputus dari server BLE 
    deviceConnected = false; // perbarui status koneksi // menandakan bahwa perangkat terputus
    Serial.println("Device disconnected"); // cetak pesan ke serial monitor // untuk debugging
    pServer->startAdvertising();  // Restart advertising after disconnect
  }
};


class MyCharacteristicCallbacks : public BLECharacteristicCallbacks { // panggilan balik karakteristik BLE khusus // untuk menangani peristiwa penulisan data
  void onWrite(BLECharacteristic *pCharacteristic) { // saat data ditulis ke karakteristik BLE // dari perangkat klien
    const String value = pCharacteristic->getValue().c_str(); // dapatkan nilai yang ditulis ke karakteristik // sebagai string
    // const char* value = "{\"hello\":\"world\"}";
    Serial.print("Received data: "); // cetak pesan ke serial monitor // untuk debugging
    Serial.print(value); // cetak data yang diterima ke serial monitor // untuk debugging // data dalam format JSON
    Serial.println(); // baris baru // untuk keterbacaan di serial monitor
    if (value.length() > 0) { // jika ada data yang diterima // pastikan string tidak kosong
      JsonDocument doc1, doc2; // buat dokumen JSON untuk parsing data // doc1 untuk data masuk, doc2 untuk data keluar jika diperlukan

      DeserializationError error = deserializeJson(doc1, value); // parsing data JSON dari string yang diterima // simpan hasilnya di doc1
      if (error) { // jika terjadi kesalahan saat parsing JSON
        Serial.print("JSON parsing failed: "); // cetak pesan kesalahan ke serial monitor // untuk debugging
        Serial.println(error.c_str()); // cetak detail kesalahan ke serial monitor // untuk debugging
        // return;
      }

      if (!doc1["vertical"].isNull()) { // jika ada kunci "vertical" dalam data JSON //
        coreUnit.setConfiguration(ConfigurationKey::PITCH_CENTER, doc1["vertical"].as<int>()); // atur konfigurasi pusat pitch pada coreUnit // berdasarkan nilai yang diterima dari JSON
      } // jika ada kunci "vertical" dalam data JSON
      if (!doc1["horizontal"].isNull()) { // jika ada kunci "horizontal" dalam data JSON
        coreUnit.setConfiguration(ConfigurationKey::ROLL_CENTER, doc1["horizontal"].as<int>());  // atur konfigurasi pusat roll pada coreUnit // berdasarkan nilai yang diterima dari JSON
      } // jika ada kunci "horizontal" dalam data JSON
      if (!doc1["auto_leveling"].isNull()) { // jika ada kunci "auto_leveling" dalam data JSON
        coreUnit.setConfiguration(ConfigurationKey::AUTO_LEVELING, doc1["auto_leveling"].as<int>()); // atur konfigurasi auto leveling pada coreUnit // berdasarkan nilai yang diterima dari JSON
      } // jika ada kunci "auto_leveling" dalam data JSON
      if (!doc1["auto_hazard_level"].isNull()) { // jika ada kunci "auto_hazard_level" dalam data JSON
        hazardAutoLevel = doc1["auto_hazard_level"].as<int>(); // perbarui level otomatis hazard berdasarkan nilai yang diterima dari JSON
        if (hazardAutoLevel == 0) { // low level
          hazardDuration = 200; // durasi 200 ms
        } else if (hazardAutoLevel == 1) { // medium level
          hazardDuration = 100; // durasi 100 ms
        } else { // high level
          hazardDuration = 50; // durasi 50 ms
        } // atur durasi berdasarkan level

        Serial.print("Set hazard auto level to "); // cetak pesan ke serial monitor // untuk debugging
        Serial.println(hazardAutoLevel); // cetak level yang diset ke serial monitor // untuk debugging
        Serial.println("Hazard duration: " + String(hazardDuration) + " ms"); // cetak durasi hazard ke serial monitor // untuk debugging
      } // jika ada kunci "auto_hazard_level" dalam data JSON
      if (!doc1["auto_hazard"].isNull()) { // jika ada kunci "auto_hazard" dalam data JSON
        autoHazardState = doc1["auto_hazard"].as<int>() == 0? false : true; // perbarui status fitur hazard otomatis // berdasarkan nilai yang diterima dari JSON
      }
      
    }
  }
};

void initializeBluetooth() { // fungsi untuk inisialisasi Bluetooth Low Energy (BLE)
  // Initialize BLE
  BLEDevice::init("SAFORA"); // inisialisasi perangkat BLE dengan nama "SAFORA"

  // Create BLE Server
  pServer = BLEDevice::createServer();// buat server BLE baru
  pServer->setCallbacks(new MyServerCallbacks()); // atur callback server dengan instance MyServerCallbacks // untuk menangani peristiwa koneksi dan pemutusan

  // Create BLE Service
  BLEService *pService = pServer->createService(SERVICE_UUID); // buat layanan BLE baru dengan UUID khusus

  // Create a writable characteristic
  pCharacteristic = pService->createCharacteristic( // buat karakteristik BLE baru dengan UUID khusus // properti tulis
    CHARACTERISTIC_UUID, // UUID karakteristik
    BLECharacteristic::PROPERTY_WRITE // properti tulis // memungkinkan perangkat klien menulis data ke karakteristik
  );

  pCharacteristic->setCallbacks(new MyCharacteristicCallbacks()); // atur callback karakteristik dengan instance MyCharacteristicCallbacks // untuk menangani peristiwa penulisan data

  // Start the service
  pService->start(); // mulai layanan BLE // membuatnya tersedia untuk perangkat klien

  // Start advertising
  pServer->getAdvertising()->start(); // mulai iklan BLE // memungkinkan perangkat klien menemukan server BLE // dan terhubung ke layanan yang tersedia

  Serial.println("Waiting for a connection..."); // cetak pesan ke serial monitor // untuk debugging
}

// coreUnit task function to run on core 0
void coreUnitTask(void *parameter) { // fungsi task untuk mengelola coreUnit // berjalan pada core 0
  bool relayState = false; // status relay untuk hazard // untuk mengontrol nyala/mati relay hazard
  bool pulsing = false; // status pulse hazard // menandakan apakah pulse hazard sedang aktif
  unsigned long pulseStartTime = 0; // waktu mulai pulse hazard // untuk menghitung durasi pulse
  unsigned long lastToggleTime = 0; // waktu toggle terakhir // untuk mengontrol interval toggle relay hazard

  static unsigned long lastSignalToggle = 0; // waktu toggle sinyal terakhir // untuk mengontrol frekuensi sinyal alarm
  static bool signalState = false; // status sinyal alarm // untuk mengontrol nyala/mati sinyal alarm


  while (true) { // loop utama task coreUnit // berjalan terus-menerus
    int16_t ax, ay, az; // variabel untuk data akselerometer // dari MPU6050
    float pitch, roll; // variabel untuk sudut pitch dan roll // dihitung dari data akselerometer
    float gforce = 0.0f; // variabel untuk gaya g total // dari sensor pengereman
    float intensity = 0.0f; // variabel untuk intensitas pengereman // dari sensor pengereman
    
    coreUnit.update(systemState, ax, ay, az, pitch, roll, relay); // perbarui data coreUnit // dapatkan data akselerometer dan sudut // perbarui status sistem // kirim referensi relay untuk kontrol

    // --- Calibration Phase ---
    if (!brakingSensor.isCalibrated()) { // jika sensor pengereman belum dikalibrasi
      brakingSensor.calibrate(ax); // lakukan kalibrasi sensor pengereman // menggunakan data akselerometer sumbu X
      // Serial.println("Calibrating...");
      vTaskDelay(pdMS_TO_TICKS(50)); // tunggu sebentar sebelum iterasi berikutnya // untuk stabilisasi data
      continue; // lanjutkan ke iterasi berikutnya dari loop utama // lewati sisa kode di bawah ini selama kalibrasi
    }

    // Serial.println(pitch);

    // --- Update Sensor Data ---
    brakingSensor.update(ax, ay, az, pitch * DEG_TO_RAD, roll * DEG_TO_RAD); // perbarui data sensor pengereman // dengan data akselerometer dan sudut dalam radian
    intensity = brakingSensor.getBrakingIntensity(); // dapatkan intensitas pengereman // dari sensor pengereman
    gforce = brakingSensor.getTotalGForce(); // dapatkan gaya g total // dari sensor pengereman
    

    // --- Braking Pulse Logic ---
    if (intensity > 50 && !pulsing && systemState == HIGH) { // jika intensitas pengereman melebihi 50% // dan tidak sedang dalam mode pulse // dan sistem utama aktif
      if (autoHazardState) { // jika fitur hazard otomatis aktif
        pulsing = true; // mulai mode pulse hazard
        pulseStartTime = millis(); // catat waktu mulai pulse
        lastToggleTime = millis(); // inisialisasi waktu toggle terakhir
        relayState = false; // mulai dengan relay mati
        Serial.println("Braking pulse started"); // cetak pesan ke serial monitor // untuk debugging
      }
    }

    if (pulsing) { // jika sedang dalam mode pulse hazard // kontrol nyala/mati relay berdasarkan durasi dan interval
      unsigned long now = millis(); // waktu saat ini
      if (now - pulseStartTime >= 3000) { // jika sudah 3 detik sejak pulse dimulai // hentikan pulse
        pulsing = false;// hentikan mode pulse hazard
        relay.signalOff(); // matikan relay
        Serial.println("Braking pulse ended"); // cetak pesan ke serial monitor // untuk debugging
      }

      // Toggle every 100 ms
      else if (now - lastToggleTime >= hazardDuration) { // jika sudah melewati durasi toggle // nyalakan/matikan relay 
        lastToggleTime = now; // perbarui waktu toggle terakhir 
        relayState = !relayState;  // toggle status relay // nyala menjadi mati atau sebaliknya // misalnya dari LOW ke HIGH atau sebaliknya
        relayState ? relay.signalOn() : relay.signalOff(); // kontrol relay berdasarkan status relay // nyalakan atau matikan relay
      }
    }

    // --- Alarm Trigger Logic ---
    if (systemState == LOW && gforce > 1.4 && alarmState == HIGH) { // jika sistem utama mati // dan gaya g melebihi threshold 1.4g // dan sistem alarm aktif
      Serial.println("G-Force threshold exceeded while system is OFF! Triggering alarm."); // cetak pesan peringatan ke serial monitor // untuk debugging
      alarmTriggered = HIGH; // set status alarm terpicu // untuk memulai sinyal alarm
    }

    if (alarmTriggered == HIGH && alarmState == HIGH) { // jika alarm terpicu // dan sistem alarm aktif // kirim sinyal alarm dengan frekuensi 5Hz (on-off setiap 100ms) //misalnya nyalakan/matikan sinyal alarm
      unsigned long now = millis(); // waktu saat ini // untuk mengontrol frekuensi sinyal
      if (now - lastSignalToggle >= 100) { // jika sudah 100ms sejak toggle terakhir // toggle status sinyal alarm
        lastSignalToggle = now; // perbarui waktu toggle terakhir // untuk pengukuran berikutnya  
        signalState = !signalState; // toggle status sinyal alarm // nyala menjadi mati atau sebaliknya // misalnya dari LOW ke HIGH atau sebaliknya
        signalState ? relay.signalOn() : relay.signalOff(); // kontrol relay berdasarkan status sinyal alarm // nyalakan atau matikan relay
      }
    }
    
    vTaskDelay(pdMS_TO_TICKS(10)); // update setiap 10ms // untuk responsifitas tinggi // konversi ms ke ticks FreeRTOS
  }
}





void  readGPS() { // fungsi untuk membaca data GPS dan menampilkan informasi lokasi
  // Continuously read from GPS
  while (gpsSerial.available() > 0) { // selama ada data yang tersedia dari modul GPS
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


void readVibration() { // fungsi untuk membaca data dari sensor getaran dan menampilkan intensitas getaran
  // Read digital vibration signal
  int state = digitalRead(VIBRATION_PIN); // baca status pin sensor getaran

  // Count vibration events
  if (state == HIGH) { //jika sensor getaran terpicu
    vibrationCount++; // tambahkan 1 ke penghitung getaran
    delay(10); // Debounce delay to avoid multiple counts
  }

  // Print every 1 second
  if (millis() - lastTime >= 1000) { //jika sudah 1 detik sejak pembacaan terakhir
    Serial.print("Vibration Intensity (count/s): "); //cetak pesan ke serial monitor
    Serial.println(vibrationCount); //cetak jumlah getaran yang terdeteksi dalam 1 detik
    vibrationCount = 0; //reset penghitung getaran
    lastTime = millis();//perbarui waktu terakhir pembacaan
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

void setup() { // fungsi setup utama // dijalankan sekali saat perangkat dinyalakan atau direset
  Serial.begin(115200); // inisialisasi komunikasi serial dengan baud rate 115200
  initializeBluetooth(); // inisialisasi Bluetooth Low Energy (BLE)
  // initialize remote buttons
  pinMode(A_PIN, INPUT); // tombol A sebagai input // hazard button
  pinMode(B_PIN, INPUT); // tombol B sebagai input // alarm button
  pinMode(C_PIN, INPUT); // tombol C sebagai input // tidak berfungsi
  // pinMode(D_PIN, INPUT);
    
  coreUnit.begin(); // inisialisasi coreUnit // setup sensor MPU6050 dan servos
  // Jalankan task di Core 0
  xTaskCreatePinnedToCore( // buat task FreeRTOS untuk coreUnit // berjalan pada core 0
    coreUnitTask, // fungsi task coreUnit
    "CoreUnit Task", // nama task untuk debugging
    8192, // ukuran stack dalam byte // alokasikan 8KB untuk stack task
    NULL, // parameter task (tidak digunakan)
    1,// prioritas task // prioritas rendah // artinya task ini dapat ditunda oleh task dengan prioritas lebih tinggi
    &coreUnitTaskHandle, // simpan handle task // agar dapat diakses dari luar
    0 // jalankan pada core 0 //core 0 untuk performa maksimal
  );

  relay.begin(); // inisialisasi relay module // setup pin-pin relay

  // initialize GPS serial
  gpsSerial.begin(9600, SERIAL_8N1, RXD2, TXD2); //
  // // Initialize DHT sensor
  // dht.begin();
  // // Initialize vibration sensor pin
  // pinMode(VIBRATION_PIN, INPUT);
  Serial.println("System Ready");// cetak pesan ke serial monitor // untuk debugging //siap ketika setup selesai
}

void loop() { //fungsi perulangan utama // dijalankan berulang kali setelah setup selesai
  // -------- BUTTON A: System ON / OFF --------
  if (digitalRead(A_PIN) == HIGH) { // jika tombol A ditekan
    if (btnA_PressStart == 0) btnA_PressStart = millis(); //jika ini adalah kali pertama tombol ditekan //maka catat waktu tekan awal

    if (!btnA_Held && (millis() - btnA_PressStart >= HOLD_THRESHOLD)) { // jika tombol belum dianggap ditekan lama // dan sudah melewati threshold tekan lama
      if(systemState == HIGH) { // jika sistem utama sedang ON
        Serial.println("Button A held 1s - System OFF"); // cetak pesan ke serial monitor // untuk debugging
        systemState = LOW; // set sistem utama ke OFF
        btnA_Held = true; // set status tombol A sudah ditekan lama // untuk mencegah multiple trigger //nyalakan hanya sekali
        relay.setSystem(systemState); // kontrol relay untuk mengatur sistem utama // berdasarkan status sistem
        relay.singleStatusSignal(); // beri sinyal status tunggal // misalnya nyalakan/matikan lampu indikator
        delay(500); // delay sebentar untuk stabilisasi
      } else { // jika sistem utama sudah OFF
        Serial.println("System already OFF"); // cetak pesan ke serial monitor // untuk debugging
        btnA_Held = true; // set status tombol A sudah ditekan lama // untuk mencegah multiple trigger // nyalakan hanya sekali
      }
    }
  } else { // jika tombol A dilepas
    if (btnA_PressStart > 0 && !btnA_Held) { // jika tombol pernah ditekan // dan belum dianggap ditekan lama
      if (alarmTriggered == true) { // jika alarm sedang terpicu
        alarmTriggered = false; // reset status alarm terpicu // matikan alarm
        relay.singleStatusSignal(); // beri sinyal status tunggal // misalnya nyalakan/matikan lampu indikator
        delay(500); // delay sebentar untuk stabilisasi
      }

      Serial.println("Button A short press - System ON"); // cetak pesan ke serial monitor // untuk debugging
      systemState = HIGH; // set sistem utama ke ON
      relay.setSystem(systemState); // kontrol relay untuk mengatur sistem utama // berdasarkan status sistem
      delay(500); // delay sebentar untuk stabilisasi
    }
    btnA_PressStart = 0; // reset waktu tekan awal tombol A
    btnA_Held = false;  // reset status tombol A sudah ditekan lama
  }

  // ------ BUTTON B: press to turn on "find signal", hold to turn on or off alarm --------
  if(digitalRead(B_PIN) == HIGH) { // jika tombol B ditekan
    if (btnB_PressStart == 0) btnB_PressStart = millis(); // jika ini adalah kali pertama tombol ditekan // maka catat waktu tekan awal

    if (!btnB_Held && (millis() - btnB_PressStart >= HOLD_THRESHOLD) && alarmTriggered == false && systemState == LOW) { // jika tombol belum dianggap ditekan lama // dan sudah melewati threshold tekan lama // dan alarm tidak sedang terpicu // dan sistem utama OFF
      btnB_Held = true; // set status tombol B sudah ditekan lama // untuk mencegah multiple trigger // nyalakan hanya sekali
      alarmState = !alarmState; // toggle status alarm // nyalakan atau matikan alarm
      if (alarmState) { // jika alarm diaktifkan
        Serial.println("Alarm ON"); // cetak pesan ke serial monitor // untuk debugging
        relay.statusSignal(); // beri sinyal status // misalnya nyalakan/matikan lampu indikator
        delay(500); // delay sebentar untuk stabilisasi
      } else { // jika alarm dimatikan
        Serial.println("Alarm OFF"); // cetak pesan ke serial monitor // untuk debugging
        relay.singleStatusSignal(); // beri sinyal status tunggal // misalnya nyalakan/matikan lampu indikator
        delay(500); // delay sebentar untuk stabilisasi
      }
    }
  } else { // jika tombol B dilepas
    if (btnB_PressStart > 0 && !btnB_Held) { // jika tombol pernah ditekan // dan belum dianggap ditekan lama
      if (alarmTriggered == true) { // jika alarm sedang terpicu
        alarmTriggered = false; // reset status alarm terpicu // matikan alarm
        relay.singleStatusSignal(); // beri sinyal status tunggal // misalnya nyalakan/matikan lampu indikator
        delay(500); // delay sebentar untuk stabilisasi
      } else if(systemState != HIGH) { // jika sistem utama tidak ON
        relay.statusSignal(); // beri sinyal status // misalnya nyalakan/matikan lampu indikator
        delay(500); // delay sebentar untuk stabilisasi
      }
    }
    btnB_PressStart = 0; // reset waktu tekan awal tombol B
    btnB_Held = false; // reset status tombol B sudah ditekan lama
  }

  // -------- BUTTON C: activate engin if system ON --------
  if (digitalRead(C_PIN) == HIGH) { // jika tombol C ditekan
    Serial.println("Button C pressed"); // cetak pesan ke serial monitor // untuk debugging
    if (systemState == HIGH) { // jika sistem utama ON
      relay.engineStart(); // aktifkan relay untuk menghidupkan mesin
      Serial.println("Engine Started"); // cetak pesan ke serial monitor // untuk debugging
      delay(300); // delay sebentar untuk stabilisasi
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