#define HOLD_THRESHOLD 1500 // ms

// ======= BUTTON HANDLER CLASS =======
class RemoteHandler {
private:
  int pin;
  bool lastState;
  unsigned long pressStart;
  bool holdTriggered;

public:
  RemoteHandler(int p) {
    pin = p;
    lastState = false;
    pressStart = 0;
    holdTriggered = false;
  }

  void begin() {
    pinMode(pin, INPUT);
  }

  // return 1 = tap, 2 = hold, 0 = nothing
  int update() {
    bool current = digitalRead(pin);

    // Button just pressed
    if (current && !lastState) {
      pressStart = millis();
      holdTriggered = false;
    }

    // Button still pressed
    if (current && !holdTriggered && (millis() - pressStart >= HOLD_THRESHOLD)) {
      holdTriggered = true;
      lastState = current;
      return 2; // hold
    }

    // Button just released
    if (!current && lastState) {
      if (!holdTriggered && (millis() - pressStart < HOLD_THRESHOLD)) {
        lastState = current;
        return 1; // tap
      }
    }

    lastState = current;
    return 0; // no event
  }
};