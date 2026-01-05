// For Shiny Art, a pyramidal structure with random controls that each send out a MIDI signal
// Targets ESP32 P4 dev board
#include <Arduino.h>
#include <USB.h>
#include <USBMIDI.h>
#include <Button.h>
#include <vector>
using namespace std;

////////////// Types and setup //////////////

USBMIDI MIDI;
void controlCallback(uint8_t channel, uint8_t number, uint8_t value);

class Control
{
public:
  uint8_t pin;
  bool isOn = false;
  Button button;
  uint8_t noteNumber;
  // TODO: Also support a knob instance
  // TODO: Also support control change instead of notes
  Control(uint8_t pin, uint8_t noteNumber) : pin(pin), button(pin, PULLUP), noteNumber(noteNumber) {}
};

////////////// Global variables //////////////

vector<Control> controls =
{
  Control(22, 60),
  Control(23, 61)
};

uint8_t channel = 1;

////////////// Startup //////////////

void setup()
{
  Serial.begin(115200);
  delay(1000);
  Serial.println("Setting up USB MIDI...");

  MIDI.begin();
  USB.begin();
  //MIDI.setHandleControlChange(controlCallback);

  Serial.println("USB MIDI initialized");

  for (Control control : controls) {
    pinMode(control.pin, INPUT_PULLUP);
  }
}

////////////// Main loop and logic //////////////

void loop()
{
  for (Control& control : controls) {
    bool newOn = control.button.isPressed();
    bool wasOn = control.isOn;
    control.isOn = newOn;
    if (newOn && !wasOn) {
      MIDI.noteOn(control.noteNumber, 127, channel);
    } else if (!newOn && wasOn) {
      MIDI.noteOff(control.noteNumber, 0, channel);
    }
    Serial.print(control.isOn ? "1" : "0");
  }
  Serial.println();
  delay(100);
}

void controlCallback(uint8_t channel, uint8_t number, uint8_t value)
{
  Serial.print("Control change: ");
  Serial.print(channel);
  Serial.print(", ");
  Serial.print(number);
  Serial.print(", ");
  Serial.println(value);
}
