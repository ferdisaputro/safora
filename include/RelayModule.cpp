#include <Arduino.h>

// ===== Relay Module Class =====
class RelayModule {
private:
  int r1, r2, r3, r4; //pin relay

public:
  RelayModule(int rp1, int rp2, int rp3, int rp4) { //konstruktor kelas relay module
    r1 = rp1; //inisialisasi pin relay 1
    r2 = rp2;//inisialisasi pin relay 2
    r3 = rp3;//inisialisasi pin relay 3
    r4 = rp4;//inisialisasi pin relay 4
  }

  void begin() {
    pinMode(r1, OUTPUT);//set pin relay 1 sebagai output
    pinMode(r2, OUTPUT);//set pin relay 2 sebagai output
    pinMode(r3, OUTPUT);//set pin relay 3 sebagai output
    pinMode(r4, OUTPUT);//set pin relay 4 sebagai output
    // default all HIGH (inactive)
    digitalWrite(r1, HIGH);//set pin relay 1 ke HIGH (nonaktif)
    digitalWrite(r2, HIGH);//set pin relay 2 ke HIGH (nonaktif)
    digitalWrite(r3, HIGH);//set pin relay 3 ke HIGH (nonaktif)
    digitalWrite(r4, HIGH);//set pin relay 4 ke HIGH (nonaktif)
  }

  void singleStatusSignal() { //sinyal status tunggal //fungsi untuk memberikan sinyal status tunggal melalui relay
    digitalWrite(r1, LOW);//set pin relay 1 ke LOW (aktif) //low untuk aktif karena menggunakan relay module tipe active low
    digitalWrite(r2, LOW); //set pin relay 2 ke LOW (aktif) //low untuk aktif karena menggunakan relay module tipe active low
    delay(230);//tunda selama 230 ms
    digitalWrite(r1, HIGH);//set pin relay 1 ke HIGH (nonaktif) //high untuk nonaktif karena menggunakan relay module tipe active low
    digitalWrite(r2, HIGH);// set pin relay 2 ke HIGH (nonaktif) //high untuk nonaktif karena menggunakan relay module tipe active low
  }

  void statusSignal() { //sinyal status //fungsi untuk memberikan sinyal status melalui relay
    digitalWrite(r1, LOW); //aktifkan relay 1 dan 2 secara bergantian dengan delay
    digitalWrite(r2, LOW);
    delay(230); //tunda selama 230 ms
    digitalWrite(r1, HIGH); //nonaktifkan relay 1 dan 2 secara bergantian dengan delay
    digitalWrite(r2, HIGH);
    delay(230); //tunda selama 230 ms
    digitalWrite(r1, LOW); //aktifkan relay 1 dan 2 secara bergantian dengan delay
    digitalWrite(r2, LOW);
    delay(230); //tunda selama 230 ms
    digitalWrite(r1, HIGH); //nonaktifkan relay 1 dan 2 secara bergantian dengan delay
    digitalWrite(r2, HIGH);
  }

  void signalOn() { //fungsi untuk mengaktifkan sinyal melalui relay
    GPIO.out_w1tc = (1 << r1); // set LOW fast //untuk mengaktifkan sinyal, set pin relay 1 dan 2 ke LOW dengan cepat menggunakan register GPIO
    GPIO.out_w1tc = (1 << r2); // set LOW fast  //untuk mengaktifkan sinyal, set pin relay 1 dan 2 ke LOW dengan cepat menggunakan register GPIO
  }

  void signalOff() { //fungsi untuk menonaktifkan sinyal melalui relay
    GPIO.out_w1ts = (1 << r1); // set HIGH fast //untuk menonaktifkan sinyal, set pin relay 1 dan 2 ke HIGH dengan cepat menggunakan register GPIO
    GPIO.out_w1ts = (1 << r2); // set HIGH fast
  }

  void engineStart() { //fungsi untuk menghidupkan mesin melalui relay
    digitalWrite(r4, LOW); // activate relay 4 to start engine //aktifkan relay 4 untuk menghidupkan mesin
    delay(2000); // hold for 2 seconds //tahan selama 2 detik
    digitalWrite(r4, HIGH); // deactivate relay 4 //nonaktifkan relay 4
  }

  void setSystem(bool on) { //fungsi untuk mengatur sistem utama melalui relay
    digitalWrite(r3, on ? LOW : HIGH); // set relay 3 berdasarkan status sistem //misalnya, jika on true maka set ke LOW (aktif), jika false maka set ke HIGH (nonaktif)
  }
};

// // ===== Pins =====
// #define D0_PIN  11
// #define D1_PIN  10
// #define D2_PIN  9
// #define D3_PIN  8

// bool systemState = LOW;
// bool alarmState  = LOW;

// unsigned long btnA_PressStart = 0;
// bool btnA_Held = false;
// unsigned long btnB_PressStart = 0;
// bool btnB_Held = false;

// // ===== Instantiate Relay Class =====
// RelayModule relay(2, 3, 4, 5);

// void setup() {
//   Serial.begin(115200);

//   pinMode(D0_PIN, INPUT);
//   pinMode(D1_PIN, INPUT);
//   pinMode(D2_PIN, INPUT);
//   pinMode(D3_PIN, INPUT);

//   relay.begin();
//   Serial.println("YK04 Remote Test - Press a button...");
// }

// void loop() {
//   // -------- BUTTON A --------
//   if (digitalRead(D1_PIN) == HIGH) {
//     if (btnA_PressStart == 0) btnA_PressStart = millis();
//     if (!btnA_Held && (millis() - btnA_PressStart >= 1500)) {
//       if (systemState == HIGH) {
//         Serial.println("Button A held 2s - System OFF");
//         relay.setSystem(false);
//         systemState = LOW;
//         btnA_Held = true;
//         relay.singleStatusSignal();
//       } else {
//         Serial.println("System already OFF");
//         btnA_Held = true;
//       }
//     }
//   } else {
//     if (btnA_PressStart > 0 && !btnA_Held) {
//       Serial.println("Button A short press - System ON");
//       relay.setSystem(true);
//       systemState = HIGH;
//     }
//     btnA_PressStart = 0;
//     btnA_Held = false;
//   }

//   // -------- BUTTON B --------
//   if (digitalRead(D3_PIN) == HIGH) {
//     if (btnB_PressStart == 0) btnB_PressStart = millis();
//     if (!btnB_Held && (millis() - btnB_PressStart >= 1500)) {
//       btnB_Held = true;
//       alarmState = !alarmState;
//       if (alarmState) {
//         Serial.println("Alarm ON");
//         relay.statusSignal();
//       } else {
//         Serial.println("Alarm OFF");
//         relay.singleStatusSignal();
//         delay(700);
//       }
//     }
//   } else {
//     if (btnB_PressStart > 0 && !btnB_Held) {
//       if (systemState != HIGH) {
//         relay.statusSignal();
//       }
//     }
//     btnB_PressStart = 0;
//     btnB_Held = false;
//   }

//   // -------- BUTTON C --------
//   if (digitalRead(D0_PIN) == HIGH) {
//     Serial.println("Button C pressed");
//     if (systemState == HIGH) {
//       relay.engineStart();
//       delay(300);
//     }
//   }

//   // -------- BUTTON D --------
//   if (digitalRead(D2_PIN) == HIGH) {
//     Serial.println("Button D pressed");
//     delay(300);
//   }
// }
