// For Shiny Art, a pyramidal structure with random controls that each send out a MIDI signal
#include <MIDI.h>
#include <Button.h>
#include <vector>
using namespace std;

////////////// Types and setup //////////////

MIDI_CREATE_DEFAULT_INSTANCE();
void controlCallback(byte channel, byte number, byte value);

class Control
{
public:
  byte pin;
  bool isOn = false;
  Button button;
  byte noteNumber;
  // TODO: Also support a knob instance
  // TODO: Also support control change instead of notes
  Control(byte pin, byte noteNumber) : pin(pin), button(pin, PULLUP), noteNumber(noteNumber) {}
};

////////////// Global variables //////////////

vector<Control> controls =
{
  Control(21, 60),
  Control(25, 61)
};

byte channel = 1;

////////////// Startup //////////////

void setup()
{
  MIDI.begin(MIDI_CHANNEL_OMNI);  // Listen to all incoming messages
  MIDI.setHandleControlChange(controlCallback);
  //MIDI.turnThruOff();
  //Serial.begin(115200);
  for (Control control : controls) {
    pinMode(control.pin, INPUT_PULLUP);
  }

  MIDI.sendNoteOn(42, 127, 1);
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
  }
  delay(100);
}

void controlCallback(byte channel, byte number, byte value)
{
  Serial.print("Control change: ");
  Serial.print(channel);
  Serial.print(", ");
  Serial.print(number);
  Serial.print(", ");
  Serial.println(value);
}
