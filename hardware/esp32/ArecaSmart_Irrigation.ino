/*
  ArecaSmart ESP32 Irrigation Firmware
  Board: ESP32 DevKit V1 (ESP-WROOM-32)

  Backend-driven automatic/manual irrigation, with fail-OFF behavior.
  Hardware has NOT been physically tested. Replace placeholders and calibrate
  the sensor before connecting a pump. Verify relay polarity/current rating.
*/

#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <cstring>

// ---------- USER CONFIGURATION ----------
const char* WIFI_SSID     = "YOUR_WIFI_NAME";
const char* WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";

// Set this to the computer's current LAN IPv4 address, e.g.:
// const char* API_BASE_URL = "http://192.168.29.24:8000";
const char* API_BASE_URL = "http://YOUR_COMPUTER_LAN_IP:8000";

// Must match ARECASMART_IOT_API_TOKEN configured on the backend.
const char* DEVICE_TOKEN = "REPLACE_WITH_DEVICE_TOKEN";
const char* DEVICE_ID = "ARECA_SENSOR_001";
const char* FARM_ID = "FARM_001";

const int SOIL_MOISTURE_PIN = 34;  // ESP32 ADC input-only pin
const int RELAY_PIN = 26;
const bool RELAY_ACTIVE_LOW = true; // Verify your actual relay module.

// Calibrate for your specific sensor and soil. These are only placeholders.
int ADC_DRY_VALUE = 3000;
int ADC_WET_VALUE = 1400;

// Timing
const unsigned long SENSOR_INTERVAL_MS = 5000;
const unsigned long UPLOAD_INTERVAL_MS = 30000;
const unsigned long COMMAND_POLL_INTERVAL_MS = 5000;
const unsigned long MAX_COMMAND_AGE_MS = 15000;
const unsigned long MAX_PUMP_RUN_MS = 30000; // Independent local safety cap.

const char* READINGS_PATH = "/api/v1/sensors/readings";
// ----------------------------------------

enum ControlMode { MODE_AUTO, MODE_MANUAL };
ControlMode controlMode = MODE_AUTO;

bool pumpIsOn = false;
bool backendPumpTarget = false;
bool backendEmergencyStop = false;
bool haveFreshBackendCommand = false;
bool localRuntimeLockout = false;
unsigned long lastSuccessfulCommandMs = 0;
unsigned long lastSensorMs = 0;
unsigned long lastUploadMs = 0;
unsigned long lastCommandPollMs = 0;
unsigned long pumpStartedMs = 0;
int latestRawMoisture = 0;
int latestMoisturePercent = -1;

void setPump(bool turnOn) {
  if (turnOn == pumpIsOn) return;

  pumpIsOn = turnOn;
  if (pumpIsOn) pumpStartedMs = millis();

  const int onLevel = RELAY_ACTIVE_LOW ? LOW : HIGH;
  const int offLevel = RELAY_ACTIVE_LOW ? HIGH : LOW;
  digitalWrite(RELAY_PIN, pumpIsOn ? onLevel : offLevel);
  Serial.printf("Pump: %s\n", pumpIsOn ? "ON" : "OFF");
}

int readMoisturePercent(int rawValue) {
  if (ADC_DRY_VALUE == ADC_WET_VALUE) return -1;
  long percent = map(rawValue, ADC_DRY_VALUE, ADC_WET_VALUE, 0, 100);
  percent = constrain(percent, 0, 100);
  return static_cast<int>(percent);
}

void readSensor() {
  long total = 0;
  const int sampleCount = 10;
  for (int i = 0; i < sampleCount; i++) {
    total += analogRead(SOIL_MOISTURE_PIN);
    delay(10);
  }

  latestRawMoisture = static_cast<int>(total / sampleCount);
  latestMoisturePercent = readMoisturePercent(latestRawMoisture);
  Serial.printf("Soil ADC: %d | Estimated moisture: %d%%\n",
                latestRawMoisture, latestMoisturePercent);
}

bool addCommonHeaders(HTTPClient& http) {
  http.addHeader("Content-Type", "application/json");
  if (strlen(DEVICE_TOKEN) > 0 &&
      strcmp(DEVICE_TOKEN, "REPLACE_WITH_DEVICE_TOKEN") != 0) {
    http.addHeader("X-Device-Token", DEVICE_TOKEN);
  }
  return true;
}

void applyControlLogic() {
  // Independent local cap remains active even if the backend is delayed.
  if (pumpIsOn && millis() - pumpStartedMs >= MAX_PUMP_RUN_MS) {
    Serial.println("Local maximum runtime reached; forcing pump OFF.");
    localRuntimeLockout = true;
    setPump(false);
    return;
  }

  const bool commandIsStale = !haveFreshBackendCommand ||
      (millis() - lastSuccessfulCommandMs > MAX_COMMAND_AGE_MS);

  // Never use a local fallback to start watering when backend or network is down.
  if (WiFi.status() != WL_CONNECTED || commandIsStale || backendEmergencyStop) {
    if (commandIsStale) backendPumpTarget = false;
    setPump(false);
    return;
  }

  // After the local runtime limit, wait until backend reports OFF before re-arming.
  if (localRuntimeLockout) {
    if (!backendPumpTarget) localRuntimeLockout = false;
    setPump(false);
    return;
  }

  // The backend is authoritative for both auto and manual modes.
  setPump(backendPumpTarget);
}

void uploadReadings() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("Skipping upload: Wi-Fi disconnected.");
    return;
  }

  HTTPClient http;
  http.setTimeout(5000);
  const String url = String(API_BASE_URL) + READINGS_PATH;
  if (!http.begin(url)) {
    Serial.println("Could not start readings HTTP request.");
    return;
  }

  addCommonHeaders(http);
  JsonDocument doc;
  doc["device_id"] = DEVICE_ID;
  doc["farm_id"] = FARM_ID;
  doc["soil_moisture_raw"] = latestRawMoisture;
  doc["soil_moisture_percent"] = latestMoisturePercent;
  doc["pump_on"] = pumpIsOn;
  doc["control_mode"] = (controlMode == MODE_AUTO) ? "auto" : "manual";
  doc["sensor_valid"] = latestMoisturePercent >= 0;
  doc["timestamp_ms"] = millis();

  String payload;
  serializeJson(doc, payload);
  const int statusCode = http.POST(payload);
  Serial.printf("Readings upload HTTP status: %d\n", statusCode);
  if (statusCode > 0) Serial.println(http.getString());
  else Serial.printf("Upload error: %s\n", http.errorToString(statusCode).c_str());
  http.end();
}

void pollBackendCommand() {
  if (WiFi.status() != WL_CONNECTED) return;

  HTTPClient http;
  http.setTimeout(5000);
  const String url = String(API_BASE_URL) + "/api/v1/devices/" +
                     DEVICE_ID + "/command";
  if (!http.begin(url)) return;

  if (strlen(DEVICE_TOKEN) > 0 &&
      strcmp(DEVICE_TOKEN, "REPLACE_WITH_DEVICE_TOKEN") != 0) {
    http.addHeader("X-Device-Token", DEVICE_TOKEN);
  }

  const int statusCode = http.GET();
  if (statusCode == 200) {
    const String response = http.getString();
    JsonDocument doc;
    const DeserializationError error = deserializeJson(doc, response);

    if (!error) {
      const char* mode = doc["mode"] | "auto";
      controlMode = (strcmp(mode, "manual") == 0) ? MODE_MANUAL : MODE_AUTO;
      backendPumpTarget = doc["pump_on"] | false;
      backendEmergencyStop = doc["emergency_stop"] | false;
      lastSuccessfulCommandMs = millis();
      haveFreshBackendCommand = true;

      Serial.printf("Backend mode: %s | pump target: %s | emergency stop: %s\n",
                    mode, backendPumpTarget ? "ON" : "OFF",
                    backendEmergencyStop ? "ACTIVE" : "clear");
    } else {
      Serial.println("Could not parse command JSON; previous command will expire.");
    }
  } else if (statusCode > 0) {
    Serial.printf("Command poll HTTP status: %d; previous command will expire.\n",
                  statusCode);
  } else {
    Serial.printf("Command poll error: %s\n",
                  http.errorToString(statusCode).c_str());
  }

  http.end();
}

void connectWiFi() {
  if (WiFi.status() == WL_CONNECTED) return;

  // Fail OFF immediately. Reconnection alone does not authorize irrigation.
  haveFreshBackendCommand = false;
  backendPumpTarget = false;
  setPump(false);

  Serial.printf("Connecting to Wi-Fi: %s\n", WIFI_SSID);
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  const unsigned long start = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - start < 15000) {
    delay(500);
    Serial.print(".");
  }
  Serial.println();

  if (WiFi.status() == WL_CONNECTED) {
    Serial.print("Wi-Fi connected. ESP32 IP: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("Wi-Fi unavailable; pump stays OFF until a fresh backend command arrives.");
  }
}

void setup() {
  Serial.begin(115200);

  // Initialize relay OFF as early as possible.
  pinMode(RELAY_PIN, OUTPUT);
  const int offLevel = RELAY_ACTIVE_LOW ? HIGH : LOW;
  digitalWrite(RELAY_PIN, offLevel);
  pumpIsOn = false;

  analogReadResolution(12);
  pinMode(SOIL_MOISTURE_PIN, INPUT);

  Serial.println("\nArecaSmart ESP32 irrigation firmware starting.");
  Serial.println("Firmware prepared but not physically tested.");
  connectWiFi();
  readSensor();

  // Let the first loop attempt a command poll and telemetry upload immediately.
  lastCommandPollMs = millis() - COMMAND_POLL_INTERVAL_MS;
  lastUploadMs = millis() - UPLOAD_INTERVAL_MS;
  applyControlLogic();
}

void loop() {
  const unsigned long now = millis();

  if (now - lastSensorMs >= SENSOR_INTERVAL_MS) {
    lastSensorMs = now;
    readSensor();
  }

  if (now - lastCommandPollMs >= COMMAND_POLL_INTERVAL_MS) {
    lastCommandPollMs = now;
    if (WiFi.status() != WL_CONNECTED) connectWiFi();
    pollBackendCommand();
  }

  if (now - lastUploadMs >= UPLOAD_INTERVAL_MS) {
    lastUploadMs = now;
    uploadReadings();
  }

  // Evaluate safety every loop iteration, not just on scheduled network events.
  applyControlLogic();
  delay(10);
}
