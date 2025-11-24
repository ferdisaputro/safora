#include <Arduino.h>

// ===== Relay Module Class =====
class RelayModule {
private:
  int r1, r2, r3, r4;

public:
  RelayModule(int rp1, int rp2, int rp3, int rp4) {
    r1 = rp1;
    r2 = rp2;
    r3 = rp3;
    r4 = rp4;
  }

  void begin() {
    pinMode(r1, OUTPUT);
    pinMode(r2, OUTPUT);
    pinMode(r3, OUTPUT);
    pinMode(r4, OUTPUT);
    // default all HIGH (inactive)
    digitalWrite(r1, HIGH);
    digitalWrite(r2, HIGH);
    digitalWrite(r3, HIGH);
    digitalWrite(r4, HIGH);
  }

  void singleStatusSignal() {
    digitalWrite(r1, LOW);
    digitalWrite(r2, LOW);
    delay(230);
    digitalWrite(r1, HIGH);
    digitalWrite(r2, HIGH);
  }

  void statusSignal() {
    digitalWrite(r1, LOW);
    digitalWrite(r2, LOW);
    delay(230);
    digitalWrite(r1, HIGH);
    digitalWrite(r2, HIGH);
    delay(230);
    digitalWrite(r1, LOW);
    digitalWrite(r2, LOW);
    delay(230);
    digitalWrite(r1, HIGH);
    digitalWrite(r2, HIGH);
  }

  void signalOn() {
    GPIO.out_w1tc = (1 << r1); // set LOW fast
    GPIO.out_w1tc = (1 << r2); // set LOW fast
  }

  void signalOff() {
    GPIO.out_w1ts = (1 << r1); // set HIGH fast
    GPIO.out_w1ts = (1 << r2); // set HIGH fast
  }

  void engineStart() {
    digitalWrite(r4, LOW);
    delay(2000);
    digitalWrite(r4, HIGH);
  }

  void setSystem(bool on) {
    digitalWrite(r3, on ? LOW : HIGH);
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
