#include <ESP8266WiFi.h>
#include <WebSocketsClient.h>

const char* ssid = "YOUR_WIFI_SSID";
const char* password = "YOUR_WIFI_PASSWORD";


const char* websocket_server_host = "192.168.1.10"; 
const uint16_t websocket_server_port = 3000;

WebSocketsClient webSocket;

#define LED_PIN LED_BUILTIN 

void webSocketEvent(WStype_t type, uint8_t * payload, size_t length) {
    switch(type) {
        case WStype_DISCONNECTED:
            Serial.printf("[WSc] Disconnected!\n");
            break;
        case WStype_CONNECTED:
            Serial.printf("[WSc] Connected to url: %s\n", payload);
            webSocket.sendTXT("NodeMCU Connected");
            break;
        case WStype_TEXT:
            Serial.printf("[WSc] Got text: %s\n", payload);
            if (strcmp((char *)payload, "on") == 0) {
                Serial.println("LED ON karne ka command mila.");
                digitalWrite(LED_PIN, LOW);
            } else if (strcmp((char *)payload, "off") == 0) {
                Serial.println("LED OFF karne ka command mila.");
                digitalWrite(LED_PIN, HIGH);
            }
            break;
        case WStype_BIN:
            Serial.printf("[WSc] Got binary length: %u\n", length);
            break;
        case WStype_ERROR:
        case WStype_FRAGMENT_TEXT_START:
        case WStype_FRAGMENT_BIN_START:
        case WStype_FRAGMENT:
        case WStype_FRAGMENT_FIN:
            break;
    }
}

void setup() {
    Serial.begin(115200);
    Serial.println();
    
    pinMode(LED_PIN, OUTPUT);
    digitalWrite(LED_PIN, HIGH); 

    Serial.printf("Connecting to WiFi: %s\n", ssid);
    WiFi.begin(ssid, password);
    while (WiFi.status() != WL_CONNECTED) {
        delay(500);
        Serial.print(".");
    }
    Serial.println("\nWiFi connected!");
    Serial.print("IP address: ");
    Serial.println(WiFi.localIP());

    webSocket.begin(websocket_server_host, websocket_server_port, "/ws");

    webSocket.onEvent(webSocketEvent);
    webSocket.setReconnectInterval(5000);
}

void loop() {
    webSocket.loop();
}