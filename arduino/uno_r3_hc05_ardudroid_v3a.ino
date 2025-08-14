// uno_r3_hc05_ardudroid_v3a.ino
// ArduDroid-compatible parser over HC-05 @9600
// Protocol: *<cmd>|<pin>|<value>#
// cmd: 10=DIGITALWRITE (2=LOW, 3=HIGH), 11=ANALOGWRITE 0-255, 12=TEXT, 13=READ

const char START_CMD_CHAR = '*';
const char END_CMD_CHAR = '#';
const char DIV_CMD_CHAR = '|';

const int DIGITALWRITE = 10;
const int ANALOGWRITE = 11;
const int TEXT = 12;
const int READ = 13;

// Pins of interest
const int DIGITAL_PINS[] = {13,12,11,10,9,8,7,6,5,4,3,2};
const int PWM_PINS[] = {11,10,9,6};

String rxBuffer = "";

void setup() {
  Serial.begin(9600);
  // Configure pins as outputs
  for (unsigned int i = 0; i < sizeof(DIGITAL_PINS)/sizeof(int); i++) {
    pinMode(DIGITAL_PINS[i], OUTPUT);
    digitalWrite(DIGITAL_PINS[i], LOW);
  }
  // Builtin LED mirror for D13
  pinMode(LED_BUILTIN, OUTPUT);
  digitalWrite(LED_BUILTIN, LOW);

  Serial.println("READY v3a");
}

void loop() {
  readSerial();
}

void readSerial() {
  while (Serial.available() > 0) {
    char c = (char)Serial.read();
    if (c == START_CMD_CHAR) {
      rxBuffer = "";
    } else if (c == END_CMD_CHAR) {
      handleCommand(rxBuffer);
      rxBuffer = "";
    } else {
      rxBuffer += c;
    }
  }
}

void handleCommand(const String &payload) {
  int first = payload.indexOf(DIV_CMD_CHAR);
  int second = payload.indexOf(DIV_CMD_CHAR, first + 1);
  if (first < 0 || second < 0) return;

  int cmd = payload.substring(0, first).toInt();
  int pin = payload.substring(first + 1, second).toInt();
  int value = payload.substring(second + 1).toInt();

  switch (cmd) {
    case DIGITALWRITE: {
      bool high = (value == 3);
      digitalWrite(pin, high ? HIGH : LOW);
      if (pin == 13) digitalWrite(LED_BUILTIN, high ? HIGH : LOW);
      // USER MOD HERE: Add side effects for each pin if needed
      Serial.print("OK DW "); Serial.print(pin); Serial.print(" "); Serial.println(high ? "HIGH" : "LOW");
      break;
    }
    case ANALOGWRITE: {
      int pwm = constrain(value, 0, 255);
      analogWrite(pin, pwm);
      // USER MOD HERE: Hook PWM changes if needed
      Serial.print("OK AW "); Serial.print(pin); Serial.print(" "); Serial.println(pwm);
      break;
    }
    case TEXT: {
      // Echo text as diagnostic
      Serial.print("TXT ");
      Serial.println(payload.substring(second + 1));
      break;
    }
    case READ: {
      // Report a brief diagnostic including analogs
      Serial.println("READ BEGIN");
      for (unsigned int i = 0; i < sizeof(DIGITAL_PINS)/sizeof(int); i++) {
        int p = DIGITAL_PINS[i];
        Serial.print("D"); Serial.print(p); Serial.print("="); Serial.println(digitalRead(p));
      }
      for (int a = 0; a <= 5; a++) {
        int v = analogRead(a);
        Serial.print("A"); Serial.print(a); Serial.print("="); Serial.println(v);
      }
      Serial.println("READ END");
      break;
    }
    default:
      Serial.print("ERR CMD "); Serial.println(cmd);
  }
}
