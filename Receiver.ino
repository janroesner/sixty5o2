#include <Base64.h>

char chunk[100] = {};
int8_t chunkSize = 9;
long counter;
bool firstRun;

// data output pins connected to the 6522
const byte DATA[] = {31, 33, 35, 37, 39, 41, 43, 45};

// interruptPIN connected directly to the IRQB pin (PIN4) of the 6502
#define INTERRUPT 53

// necessary timeouts
int responseTimeoutMicros = 5; // microseconds
int readBufferDelay = 20; // milliseconds

void setup() {
    
    // setting Arduinos pins to input before start, otherwise we interfere with the LCD
    for (int n = 0; n < 8; n += 1) {
        pinMode(DATA[n], INPUT);
    }

    // setting interrupt PIN to output is no problem, PIN must be normal HIGH
    pinMode(INTERRUPT, OUTPUT);
    digitalWrite(INTERRUPT, HIGH);
    
    // setting up helper variables to determine EOF later on
    counter = 0;
    firstRun = true;
        
    Serial.begin(9600);
}
 
void loop() {
    if (Serial.available() >= 9) {

        // as soon as data arrives, all pins are set to output exactly once
        if (firstRun == true) {
            for (int n = 0; n < 8; n += 1) {
                digitalWrite(DATA[n], LOW);
                pinMode(DATA[n], OUTPUT);
            }
            firstRun = false;
        }

        // that delay is needed, otherwise the buffer can not be read reliably
        delay(readBufferDelay);
        
        // reading in a chunk of 13 bytes ... a few more than necessary #TODO
        for (int i = 0; i <= 14; i+= 1)  {
            chunk[i] = Serial.read();
        }

        // base64 decode the chunk
        int chunkLength = sizeof(chunk);
        int decodedLength = Base64.decodedLength(chunk, chunkLength);
        char decodedChunk[decodedLength];
        Base64.decode(decodedChunk, chunk, chunkLength);
        
        // when the chunks checksum is correct, write the data, otherwise ask the sender to repeat the chunk (responding f=failure)
        if (decodedChunk[8] == checkSum(decodedChunk)) {
            writeData(decodedChunk);
        } else {
            delayMicroseconds(responseTimeoutMicros); 
            Serial.println('f');
        }
    } else {
        // detect EOF here and set pins to INPUT again to prevent interference with LCD display
        counter += 1;
        if (counter >= 150000) {
            counter = 150000;
            for (int n = 0; n < 8; n += 1) {
                pinMode(DATA[n], INPUT);
            }
            firstRun = true;
        }
    }
}

// writing the data on the output pins and trigger the 6502's interrupt service routine to write byte by byte
void writeData(char ary[]) {
    // loop through the 8 bytes of the given chunk
    for (int i = 0; i < 8; i += 1) {
        char inp = ary[i];

        // for each byte set up the byte's corresponding bits at the digital ports
        for (int n = 0;  n < 8; n += 1) {
            digitalWrite(31+2*n, bitRead(inp, n) ? HIGH : LOW);
        }
        
        // pull the interrupt low for 30 microseconds to trigger the interrupt service routine
        digitalWrite(INTERRUPT, LOW);
        delayMicroseconds(30);
        
        // pull interrupt high again
        digitalWrite(INTERRUPT, HIGH);
        
        // leave data on the lines for a while, since it seems to be available rising edge
        delayMicroseconds(20);
    }

    // report back success (k=ok)
    delayMicroseconds(responseTimeoutMicros);
    Serial.println('k');
}

// very simple 1-byte checksum algorithm - to be improved
char checkSum(char buf[]) {
    int cs = 0;
    for (int i = 0; i < chunkSize - 1; i++) {
        cs = (cs << 1) + ((int)buf[i] & 1);
    }

    return (char)cs;
}
