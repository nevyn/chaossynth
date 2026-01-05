// For Shiny Art, a pyramidal structure with random controls that each send out a MIDI signal
// Targets ESP32 P4 dev board
#include <Arduino.h>
#include <Adafruit_TinyUSB.h>
#include <MIDI.h>
#include <Button.h>
#include <vector>
using namespace std;

////////////// Types and setup //////////////

Adafruit_USBD_MIDI usb_midi;
MIDI_CREATE_INSTANCE(Adafruit_USBD_MIDI, usb_midi, MIDI);
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
  TinyUSBDevice.setManufacturerDescriptor("ChaosSynth");
  TinyUSBDevice.setProductDescriptor("ChaosSynth MIDI");
  usb_midi.begin();
  MIDI.begin(MIDI_CHANNEL_OMNI);
  MIDI.setHandleControlChange(controlCallback);
  
  Serial.begin(115200);
  while (!TinyUSBDevice.mounted()) delay(1);
  Serial.println("TinyUSBDevice mounted");

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
      MIDI.sendNoteOn(control.noteNumber, 127, channel);
    } else if (!newOn && wasOn) {
      MIDI.sendNoteOff(control.noteNumber, 0, channel);
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
