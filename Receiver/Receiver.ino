#include <Base64.h>

char chunk[100] = {};
int8_t chunkSize = 9;
long counter;
bool firstRun;

// Protocol constants
char PROTOCOL_OK = 'k';
char PROTOCOL_FAILURE = 'f';

// **************************************************************************
// ***** Important ** Change according to the Arduino PINs that you use *****
// **************************************************************************

// Data output pins connected to the 6522; values for the Arduino Mega
// const byte DATA[] = {31, 33, 35, 37, 39, 41, 43, 45};

// Data output pins connected to the 6522; values for Arduino Nano
const byte DATA[] = {5, 6, 7, 8, 9, 10, 11, 12};

// Interrupt PIN on the Arduino Mega connected directly to the IRQB pin (PIN4) of the 6502(!)
//#define INTERRUPT 53

// Interrupt PIN on the Arduino Nano connected directly to the IRQB pin (PIN4) of the 6502(!)
#define INTERRUPT 3

// **************************************************************************
// ***** Important ** End                                               *****
// **************************************************************************

// Necessary delays
int RESPONSE_DELAY = 5; // microseconds
int READ_BUFFER_DELAY = 20; // milliseconds

int INTERRUPT_LOW_DELAY = 30; // microseconds
int INTERRUPT_HIGH_DELAY = 20; // microseconds

long EOF_TIMEOUT = 150000;


void setup() {
    
    // Setting Arduinos pins to input before start, otherwise we interfere with the LCD
    for (int n = 0; n < 8; n += 1) {
        pinMode(DATA[n], INPUT);
    }

    // Setting interrupt PIN to output is no problem, PIN must be normal HIGH
    pinMode(INTERRUPT, OUTPUT);
    digitalWrite(INTERRUPT, HIGH);
    
    // Setting up helper variables to determine EOF later on
    counter = 0;
    firstRun = true;
        
    Serial.begin(9600);
}
 
void loop() {
    if (Serial.available() >= 9) {

        // As soon as data arrives, all pins are set to output exactly once
        if (firstRun == true) {
            for (int n = 0; n < 8; n += 1) {
                digitalWrite(DATA[n], LOW);
                pinMode(DATA[n], OUTPUT);
            }
            firstRun = false;
        }

        // This delay is needed, otherwise the buffer can not be read reliably
        delay(READ_BUFFER_DELAY);
        
        // Reading in a chunk of 14 bytes ... a few more than necessary #TODO
        for (int i = 0; i <= 14; i+= 1)  {
            chunk[i] = Serial.read();
        }

        // Base64-decode the chunk
        int chunkLength = sizeof(chunk);
        int decodedLength = Base64.decodedLength(chunk, chunkLength);
        char decodedChunk[decodedLength];
        Base64.decode(decodedChunk, chunk, chunkLength);
        
        // If the chunks checksum is correct, write the data, otherwise ask the sender to repeat the chunk
        if (decodedChunk[8] == checkSum(decodedChunk)) {
            if (writeData(decodedChunk)) {
                Serial.println(PROTOCOL_OK);
            } else {
                Serial.println(PROTOCOL_FAILURE);
            }
        } else {
            delayMicroseconds(RESPONSE_DELAY); 
            Serial.println(PROTOCOL_FAILURE);
        }
    } else {
        // Detect EOF here and set pins to INPUT again to prevent interference with LCD display
        counter += 1;
        if (counter >= EOF_TIMEOUT) {
            counter = EOF_TIMEOUT;
            for (int n = 0; n < 8; n += 1) {
                pinMode(DATA[n], INPUT);
            }
			pinMode(INTERRUPT, INPUT);
            firstRun = true;
        }
    }
}

// Writing the data on the output pins and trigger the 6502's interrupt service routine to write byte by byte
bool writeData(char ary[]) {
    // Loop through the 8 bytes of the given chunk
    for (int i = 0; i < 8; i += 1) {
        char data = ary[i];

        // For each byte set up the byte's corresponding bits at the digital ports
        for (int n = 0;  n < 8; n += 1) {
            digitalWrite(DATA[n], bitRead(data, n) ? HIGH : LOW);
        }
        
        // Pull the interrupt pin low to trigger the interrupt service routine
        digitalWrite(INTERRUPT, LOW);
        delayMicroseconds(INTERRUPT_LOW_DELAY);
        
        // Pull interrupt high again
        digitalWrite(INTERRUPT, HIGH);
        
        // Leave data on the lines for a while, since it seems to be read on rising edge
        delayMicroseconds(INTERRUPT_HIGH_DELAY);
    }
    delayMicroseconds(RESPONSE_DELAY);

    // Report back success
    return (true);
}

// Very simple 1-byte checksum algorithm - to be improved
char checkSum(char buf[]) {
    int cs = 0;
    for (int i = 0; i < chunkSize - 1; i++) {
        cs = (cs << 1) + ((int)buf[i] & 1);
    }

    return (char)cs;
}
