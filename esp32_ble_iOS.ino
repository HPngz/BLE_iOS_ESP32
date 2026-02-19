#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"
#define WRITE_UUID          "beb5483e-36e1-4688-b7f5-ea07361b26a9"  // 写特征UUID

BLEServer* pServer = NULL;
BLECharacteristic* pCharacteristic = NULL;
BLECharacteristic* pWriteCharacteristic = NULL;  // 新增
bool deviceConnected = false;

// 收到手机数据时的回调
class MyWriteCallbacks: public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* pCharacteristic) {
    String value = String(pCharacteristic->getValue().c_str());
    if (value.length() > 0) {
        Serial.print("📥 Received: ");
        Serial.println(value);
    }
  }
};

class MyServerCallbacks: public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    deviceConnected = true;
    Serial.println("✅ The APP is connected");
  };
  void onDisconnect(BLEServer* pServer) {
    deviceConnected = false;
    Serial.println("❌ The APP has been disconnected");
    pServer->startAdvertising();
  }
};

int sendData = 1;
unsigned long lastSendTime = 0;
const unsigned long sendInterval = 1000;

void setup() {
  Serial.begin(115200);
  delay(1000);

  BLEDevice::init("ESP32-BLE-Data1");
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  BLEService *pService = pServer->createService(SERVICE_UUID);

  // 原来的Notify特征（ESP32→手机）
  pCharacteristic = pService->createCharacteristic(
    CHARACTERISTIC_UUID,
    BLECharacteristic::PROPERTY_READ |
    BLECharacteristic::PROPERTY_NOTIFY
  );
  pCharacteristic->addDescriptor(new BLE2902());

  // Write特征（手机→ESP32）
  pWriteCharacteristic = pService->createCharacteristic(
    WRITE_UUID,
    BLECharacteristic::PROPERTY_WRITE |
    BLECharacteristic::PROPERTY_WRITE_NR
  );
  pWriteCharacteristic->setCallbacks(new MyWriteCallbacks());

  pService->start();
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  BLEDevice::startAdvertising();

  Serial.println("🔍 ESP32 BLE started. Waiting for connection...");
}

void loop() {
  if (deviceConnected) {
    if (millis() - lastSendTime >= sendInterval) {
      lastSendTime = millis();
      uint8_t data = sendData;
      pCharacteristic->setValue(&data, 1);
      pCharacteristic->notify();
      Serial.print("📤 Send: ");
      Serial.println(sendData);
      sendData++;
      if (sendData > 3) sendData = 1;
    }
  }
  delay(10);
}