#include <WiFi.h>
#include <WebServer.h>
#include <Adafruit_Fingerprint.h>
#include <HardwareSerial.h>
#include <ArduinoJson.h>
#include "esp_system.h"
#include <LiquidCrystal_I2C.h>

// ---------- WiFi Credentials ----------
const char* ssid = "waheeda";
const char* password = "12345678";

// ---------- Fingerprint Sensor Setup ----------
HardwareSerial mySerial(2);  // RX = GPIO16, TX = GPIO17
Adafruit_Fingerprint finger = Adafruit_Fingerprint(&mySerial);

// ---------- Web Server ----------
WebServer server(80);

// ---------- Relay ----------
#define RELAY_PIN 25  // GPIO pin connected to Relay IN

// ---------- LCD ----------
LiquidCrystal_I2C lcd(0x27, 16, 2);  // I2C address 0x27, 16 cols, 2 rows

// ---------- Error Codes ----------
#define MATCH_TIMEOUT 208
#define MATCH_FAILED 201
#define IMAGE_FAIL 202

// ---------- Unlock Tracker ----------
bool unlockedToday[128] = { false };

void setup() {
  Serial.begin(115200);
  mySerial.begin(57600, SERIAL_8N1, 16, 17);

  lcd.init();
  lcd.backlight();
  lcd.setCursor(0, 0);
  lcd.print("Please scan");
  lcd.setCursor(0, 1);
  lcd.print("a fingerprint");

  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWiFi connected.");
  Serial.print("ESP32 IP: ");
  Serial.println(WiFi.localIP());

  finger.begin(57600);
  if (!finger.verifyPassword()) {
    Serial.println("Fingerprint sensor NOT found.");
    while (1);
  }

  pinMode(RELAY_PIN, OUTPUT);
  digitalWrite(RELAY_PIN, HIGH);  // Start locked

  server.on("/", []() {
    server.send(200, "text/plain", "ESP32 Fingerprint Server is running.");
  });
  server.on("/enroll", handleEnroll);
  server.on("/match", handleMatch);
  server.on("/delete_all", handleDeleteAll);
  server.on("/delete", handleDelete);
  server.on("/list", handleListEnrolled);

  server.begin();
  Serial.println("HTTP server started.");
}

void loop() {
  server.handleClient();
}

// ---------- /match ----------
void handleMatch() {
  Serial.println("Match request received.");
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Please scan");
  lcd.setCursor(0, 1);
  lcd.print("a fingerprint");

  uint8_t result = matchFingerprint();
  DynamicJsonDocument doc(256);

  if (result < 200) {
    Serial.printf("Match found. ID: %d\n", result);

    if (!unlockedToday[result]) {
      unlockedToday[result] = true;

      doc["status"] = "success";
      doc["fingerprintId"] = result;
      doc["message"] = "Unlocked.";

      String json;
      serializeJson(doc, json);
      server.send(200, "application/json", json);

      lcd.clear();
      lcd.setCursor(0, 0);
      lcd.print("Access granted");
      lcd.setCursor(0, 1);
      lcd.print("ID: ");
      lcd.print(result);

      digitalWrite(RELAY_PIN, LOW); // Unlock
      delay(8000);
      digitalWrite(RELAY_PIN, HIGH); // Lock again

      lcd.clear();
      lcd.setCursor(0, 0);
      lcd.print("Door locked");

    } else {
      doc["status"] = "denied";
      doc["fingerprintId"] = result;
      doc["message"] = "Already unlocked today.";

      String json;
      serializeJson(doc, json);
      server.send(200, "application/json", json);

      lcd.clear();
      lcd.setCursor(0, 0);
      lcd.print("Already unlocked");
    }

  } else {
    doc["status"] = "error";
    doc["message"] = getErrorMessage(result);

    String json;
    serializeJson(doc, json);
    server.send(404, "application/json", json);

    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("Access denied");
    lcd.setCursor(0, 1);
    lcd.print(getErrorMessage(result).substring(0, 16));
  }
}

// ---------- /enroll ----------
void handleEnroll() {
  Serial.println("[INFO] /enroll endpoint called");

  if (!server.hasArg("id")) {
    Serial.println("[ERROR] Missing fingerprint ID in request");
    server.send(400, "application/json", "{\"status\":\"error\",\"message\":\"Missing fingerprint ID\"}");
    return;
  }

  uint8_t id = server.arg("id").toInt();
  Serial.printf("[INFO] Enroll ID: %d\n", id);

  if (id < 1 || id > 127) {
    Serial.println("[ERROR] ID out of range (1-127)");
    server.send(400, "application/json", "{\"status\":\"error\",\"message\":\"ID must be 1-127\"}");
    return;
  }

  if (finger.loadModel(id) == FINGERPRINT_OK) {
    Serial.println("[WARN] ID already exists");
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("ID already exist");
    server.send(409, "application/json", "{\"status\":\"error\",\"message\":\"ID already exists\"}");
    return;
  }

  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Enrolling ID:");
  lcd.setCursor(0, 1);
  lcd.print(id);

  Serial.printf("[INFO] Starting enrollment for ID %d\n", id);
  uint8_t result = enrollFingerprint(id);

  DynamicJsonDocument doc(256);

  if (result == FINGERPRINT_OK) {
    Serial.printf("[SUCCESS] Enroll completed for ID %d\n", id);
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("Enroll success!");
    lcd.setCursor(0, 1);
    lcd.print("ID: ");
    lcd.print(id);

    doc["status"] = "success";
    doc["fingerprintId"] = id;
  } else {
    Serial.printf("[FAIL] Enroll failed: %s\n", getErrorMessage(result).c_str());
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("Enroll failed!");
    lcd.setCursor(0, 1);
    lcd.print(getErrorMessage(result).substring(0, 16));

    doc["status"] = "error";
    doc["message"] = "Enrollment failed: " + getErrorMessage(result);
    finger.deleteModel(id);  // Clean up failed slot
  }

  String json;
  serializeJson(doc, json);
  server.send((result == FINGERPRINT_OK ? 200 : 500), "application/json", json);
}


// ---------- Enroll Finger ----------
uint8_t enrollFingerprint(uint8_t id) {
  int p = -1;
  unsigned long start;

  // First scan
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Place finger...");
  Serial.println("[STEP] Place finger for 1st scan");

  start = millis();
  while ((p = finger.getImage()) != FINGERPRINT_OK) {
    if (millis() - start > 10000) {
      Serial.println("[ERROR] Timeout waiting for finger (1st scan)");
      return MATCH_TIMEOUT;
    }
    delay(100);
  }
  Serial.println("[INFO] Finger detected (1st scan)");

  if ((p = finger.image2Tz(1)) != FINGERPRINT_OK) {
    Serial.printf("[ERROR] image2Tz(1) failed: %d\n", p);
    return p;
  }

  // Wait to remove
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Remove finger...");
  Serial.println("[STEP] Remove finger");
  delay(2000);

  // Second scan
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Place again...");
  Serial.println("[STEP] Place finger for 2nd scan");

  start = millis();
  while ((p = finger.getImage()) != FINGERPRINT_OK) {
    if (millis() - start > 10000) {
      Serial.println("[ERROR] Timeout waiting for finger (2nd scan)");
      return MATCH_TIMEOUT;
    }
    delay(100);
  }
  Serial.println("[INFO] Finger detected (2nd scan)");

  if ((p = finger.image2Tz(2)) != FINGERPRINT_OK) {
    Serial.printf("[ERROR] image2Tz(2) failed: %d\n", p);
    return p;
  }

  if ((p = finger.createModel()) != FINGERPRINT_OK) {
    Serial.printf("[ERROR] createModel failed: %d\n", p);
    return p;
  }

  if ((p = finger.storeModel(id)) != FINGERPRINT_OK) {
    Serial.printf("[ERROR] storeModel failed: %d\n", p);
    return p;
  }

  return FINGERPRINT_OK;
}


// ---------- /delete?id ----------
void handleDelete() {
  if (!server.hasArg("id")) {
    server.send(400, "application/json", "{\"status\":\"error\",\"message\":\"Missing ID\"}");
    return;
  }

  uint8_t id = server.arg("id").toInt();
  if (finger.deleteModel(id) == FINGERPRINT_OK) {
    server.send(200, "application/json", "{\"status\":\"success\",\"message\":\"Fingerprint deleted\"}");
  } else {
    server.send(500, "application/json", "{\"status\":\"error\",\"message\":\"Failed to delete fingerprint\"}");
  }
}

// ---------- /delete_all ----------
void handleDeleteAll() {
  if (finger.emptyDatabase() == FINGERPRINT_OK) {
    server.send(200, "application/json", "{\"status\":\"success\",\"message\":\"All fingerprints deleted\"}");
  } else {
    server.send(500, "application/json", "{\"status\":\"error\",\"message\":\"Failed to delete all fingerprints\"}");
  }
}

// ---------- /list ----------
void handleListEnrolled() {
  DynamicJsonDocument doc(1024);
  JsonArray enrolled = doc.createNestedArray("enrolled");

  for (int id = 1; id < 128; id++) {
    if (finger.loadModel(id) == FINGERPRINT_OK) {
      enrolled.add(id);
    }
  }

  doc["count"] = enrolled.size();
  String json;
  serializeJson(doc, json);
  server.send(200, "application/json", json);
}

// ---------- Match Logic ----------
uint8_t matchFingerprint() {
  int p = -1;
  unsigned long start = millis();

  while ((p = finger.getImage()) != FINGERPRINT_OK) {
    if (millis() - start > 10000) return MATCH_TIMEOUT;
    delay(100);
  }

  if ((p = finger.image2Tz(1)) != FINGERPRINT_OK) return IMAGE_FAIL;
  if ((p = finger.fingerSearch()) != FINGERPRINT_OK) return MATCH_FAILED;

  return finger.fingerID;
}

// ---------- Error Strings ----------
String getErrorMessage(uint8_t code) {
  switch (code) {
    case FINGERPRINT_PACKETRECIEVEERR: return "Communication error";
    case FINGERPRINT_NOFINGER: return "No finger detected";
    case FINGERPRINT_IMAGEFAIL: return "Imaging error";
    case FINGERPRINT_IMAGEMESS: return "Image too messy";
    case FINGERPRINT_FEATUREFAIL: return "Couldn't find features";
    case FINGERPRINT_INVALIDIMAGE: return "Invalid image";
    case FINGERPRINT_ENROLLMISMATCH: return "Mismatch";
    case FINGERPRINT_BADLOCATION: return "Bad location";
    case FINGERPRINT_FLASHERR: return "Flash error";
    case MATCH_TIMEOUT: return "Timeout";
    case MATCH_FAILED: return "No match";
    case IMAGE_FAIL: return "Capture failed";
    default: return "Unknown error";
  }
}
