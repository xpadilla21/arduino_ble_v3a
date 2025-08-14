// uno_r4_ble_uart_v3a.ino
// BLE UART service using ArduinoBLE; ArduDroid-compatible parser
// UUIDs editable below to match the app constants

#include <ArduinoBLE.h>

// Default Nordic UART Service UUIDs (change as needed)
const char* UART_SERVICE_UUID = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E";
const char* UART_RX_UUID = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"; // Write
const char* UART_TX_UUID = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"; // Notify

BLEService uartService(UART_SERVICE_UUID);
BLECharacteristic rxChar(UART_RX_UUID, BLEWrite | BLEWriteWithoutResponse, 128);
BLECharacteristic txChar(UART_TX_UUID, BLENotify, 128);

const char START_CMD_CHAR = '*';
const char END_CMD_CHAR = '#';
const char DIV_CMD_CHAR = '|';

const int DIGITALWRITE = 10;
const int ANALOGWRITE = 11;
const int TEXT = 12;
const int READ = 13;

const int DIGITAL_PINS[] = {13,12,11,10,9,8,7,6,5,4,3,2};
const int PWM_PINS[] = {11,10,9,6};

String rxBuffer = "";

void setup() {
  for (unsigned int i = 0; i < sizeof(DIGITAL_PINS)/sizeof(int); i++) {
    pinMode(DIGITAL_PINS[i], OUTPUT);
    digitalWrite(DIGITAL_PINS[i], LOW);
  }
  pinMode(LED_BUILTIN, OUTPUT);
  digitalWrite(LED_BUILTIN, LOW);

  if (!BLE.begin()) {
    // Can't print to Serial if not available; attempt LED blink
    while (1) {
      digitalWrite(LED_BUILTIN, HIGH); delay(200);
      digitalWrite(LED_BUILTIN, LOW); delay(200);
    }
  }

  BLE.setLocalName("UNO R4 UART");
  BLE.setDeviceName("UNO R4 UART");
  BLE.setAdvertisedService(uartService);

  uartService.addCharacteristic(rxChar);
  uartService.addCharacteristic(txChar);
  BLE.addService(uartService);
  BLE.advertise();
}

void loop() {
  BLEDevice central = BLE.central();
  if (central) {
    while (central.connected()) {
      if (rxChar.written()) {
        int len = rxChar.valueLength();
        uint8_t buf[128];
        len = rxChar.readValue(buf, sizeof(buf));
        for (int i = 0; i < len; i++) {
          char c = (char)buf[i];
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
      delay(1);
    }
  }
}

void notifyLine(const String &line) {
  txChar.setValue((const unsigned char*)line.c_str(), line.length());
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
      // USER MOD HERE: custom actions per pin
      notifyLine(String("OK DW ") + pin + " " + (high ? "HIGH" : "LOW"));
      break;
    }
    case ANALOGWRITE: {
      int pwm = constrain(value, 0, 255);
      analogWrite(pin, pwm);
      // USER MOD HERE
      notifyLine(String("OK AW ") + pin + " " + pwm);
      break;
    }
    case TEXT: {
      notifyLine(String("TXT ") + payload.substring(second + 1));
      break;
    }
    case READ: {
      notifyLine("READ BEGIN");
      for (unsigned int i = 0; i < sizeof(DIGITAL_PINS)/sizeof(int); i++) {
        int p = DIGITAL_PINS[i];
        notifyLine(String("D") + p + "=" + digitalRead(p));
      }
      for (int a = 0; a <= 5; a++) {
        int v = analogRead(a);
        notifyLine(String("A") + a + "=" + v);
      }
      notifyLine("READ END");
      break;
    }
    default:
      notifyLine(String("ERR CMD ") + cmd);
  }
}
