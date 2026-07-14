// For Shiny Art: a pyramidal structure with buttons + pots that emit MIDI.
// Target: Waveshare RP2350-Zero (or any RP2040/RP2350 board using the arduino-pico core).
//
// Required setup in the Arduino IDE:
//   Boards Manager: install "Raspberry Pi Pico/RP2040/RP2350" by Earle F. Philhower III
//   Tools > Board:      Raspberry Pi Pico 2 / Waveshare RP2350-Zero
//   Tools > USB Stack:  Adafruit TinyUSB
// Required libraries (Library Manager):
//   Adafruit TinyUSB Library
//   MIDI Library         (by Forty Seven Effects)
//   Adafruit MCP23017 Arduino Library

#include <Arduino.h>
#include <Wire.h>
#include <Adafruit_MCP23X17.h>
#include <Adafruit_TinyUSB.h>
#include <MIDI.h>

////////////// USB MIDI //////////////

Adafruit_USBD_MIDI usbMidiTransport;
MIDI_CREATE_INSTANCE(Adafruit_USBD_MIDI, usbMidiTransport, MIDI);

////////////// Source types //////////////
//
// A Button or Pot can read from either the Pico directly or from an external chip.
// Use the static factory methods (e.g. Button::onPico, Pot::onMux) so the config
// table reads as a self-documenting menu of where each control lives.

struct Button {
  uint8_t expanderIdx;   // 0xFF means direct Pico GPIO; otherwise index into expanderAddresses[]
  uint8_t pin;           // direct: Pico GPIO number; expander: 0..15 within MCP23017
  uint8_t note;          // MIDI note number

  static constexpr Button onPico(uint8_t gpio, uint8_t note) {
    return Button{ 0xFF, gpio, note };
  }
  static constexpr Button onExpander(uint8_t expIdx, uint8_t pin, uint8_t note) {
    return Button{ expIdx, pin, note };
  }

  bool isDirect() const { return expanderIdx == 0xFF; }
};

struct Pot {
  uint8_t muxIdx;        // 0xFF means direct Pico ADC; otherwise index into muxes[]
  uint8_t pin;           // direct: ADC-capable Pico GPIO (26-29); mux: channel 0..7
  uint8_t cc;            // MIDI CC number

  static constexpr Pot onPico(uint8_t adcGpio, uint8_t cc) {
    return Pot{ 0xFF, adcGpio, cc };
  }
  static constexpr Pot onMux(uint8_t muxIdx, uint8_t channel, uint8_t cc) {
    return Pot{ muxIdx, channel, cc };
  }

  bool isDirect() const { return muxIdx == 0xFF; }
};

struct Mux {
  // TMUX4051 (or any 8:1 analog mux with 3 select lines). Multiple muxes can share
  // select pins to save GPIOs; each still needs its own ADC pin on the Pico.
  uint8_t s0;
  uint8_t s1;
  uint8_t s2;
  uint8_t adcPin;        // ADC-capable Pico GPIO (26-29)
};

////////////// Configuration //////////////

constexpr uint8_t  MIDI_CHANNEL     = 1;
constexpr uint8_t  I2C_SDA_PIN      = 4;
constexpr uint8_t  I2C_SCL_PIN      = 5;
constexpr uint32_t I2C_CLOCK_HZ     = 400000;
constexpr uint16_t POLL_INTERVAL_MS = 5;
constexpr uint16_t MUX_SETTLE_US    = 5;
constexpr bool     SERIAL_DEBUG     = true;

// MCP23017 chips on the I2C bus. Addresses 0x20..0x27, set via A0/A1/A2 pins.
// Leave empty (just `{}`) if you're not using any expanders yet.
constexpr uint8_t expanderAddresses[] = { 0x20 };

// TMUX4051 (or compatible) analog muxes. Add one entry per mux board.
// Leave empty if you're not using any muxes yet.
constexpr Mux muxes[] = {
  // { S0, S1, S2, ADC }
  { 6, 7, 8, 26 },
};

// Buttons: any mix of direct GPIO and expander pins.
constexpr Button buttons[] = {
  Button::onPico(2, 60),           // direct: GP2 -> C4
  Button::onPico(3, 61),           // direct: GP3 -> C#4
  Button::onExpander(0, 0, 62),    // expander 0, GPA0 (DIP pin 21) -> D4
  Button::onExpander(0, 1, 63),    // expander 0, GPA1 (DIP pin 22) -> D#4
  Button::onExpander(0, 2, 64),    // expander 0, GPA2 (DIP pin 23) -> E4
  Button::onExpander(0, 3, 65),    // expander 0, GPA3 (DIP pin 24) -> F4
  Button::onExpander(0, 4, 66),    // expander 0, GPA4 (DIP pin 25) -> F#4
  Button::onExpander(0, 5, 67),    // expander 0, GPA5 (DIP pin 26) -> G4
  Button::onExpander(0, 6, 68),    // expander 0, GPA6 (DIP pin 27) -> G#4
  Button::onExpander(0, 7, 69),    // expander 0, GPA7 (DIP pin 28) -> A4
  Button::onExpander(0, 8, 70),    // expander 0, GPB0 (DIP pin 1) -> A#4
  Button::onExpander(0, 9, 71),    // expander 0, GPB1 (DIP pin 2) -> B4
  Button::onExpander(0, 10, 72),   // expander 0, GPB2 (DIP pin 3) -> C5
  Button::onExpander(0, 11, 73),   // expander 0, GPB3 (DIP pin 4) -> C#5 
  Button::onExpander(0, 12, 74),   // expander 0, GPB4 (DIP pin 5) -> D5
  Button::onExpander(0, 13, 75),   // expander 0, GPB5 (DIP pin 6) -> D#5
  Button::onExpander(0, 14, 76),   // expander 0, GPB6 (DIP pin 7) -> E5
  Button::onExpander(0, 15, 77),   // expander 0, GPB7 (DIP pin 8) -> F5
};

// Pots: any mix of direct ADC and mux channels.
constexpr Pot pots[] = {
  Pot::onPico(27, 20),             // direct: GP27 -> CC 20
  Pot::onPico(28, 21),             // direct: GP28 -> CC 21
  Pot::onMux(0, 0, 22),            // mux 0, channel 0 -> CC 22
  Pot::onMux(0, 1, 23),            // mux 0, channel 1 -> CC 23
};

////////////// State //////////////

constexpr size_t NUM_EXPANDERS = sizeof(expanderAddresses) / sizeof(expanderAddresses[0]);
constexpr size_t NUM_MUXES     = sizeof(muxes) / sizeof(muxes[0]);
constexpr size_t NUM_BUTTONS   = sizeof(buttons) / sizeof(buttons[0]);
constexpr size_t NUM_POTS      = sizeof(pots) / sizeof(pots[0]);

Adafruit_MCP23X17 expanders[NUM_EXPANDERS > 0 ? NUM_EXPANDERS : 1];
bool     buttonState[NUM_BUTTONS > 0 ? NUM_BUTTONS : 1] = { false };
uint16_t potSmoothed[NUM_POTS > 0 ? NUM_POTS : 1]       = { 0 };
uint8_t  potLastSent[NUM_POTS > 0 ? NUM_POTS : 1]       = { 0xFF };

////////////// Helpers //////////////

static void selectMuxChannel(const Mux& m, uint8_t channel) {
  digitalWrite(m.s0,  channel       & 0x01);
  digitalWrite(m.s1, (channel >> 1) & 0x01);
  digitalWrite(m.s2, (channel >> 2) & 0x01);
  delayMicroseconds(MUX_SETTLE_US);
}

////////////// Startup //////////////

void setup() {
  if (SERIAL_DEBUG) {
    Serial.begin(115200);
  }

  usbMidiTransport.setStringDescriptor("Chaossynth");
  MIDI.begin(MIDI_CHANNEL_OMNI);

  Wire.setSDA(I2C_SDA_PIN);
  Wire.setSCL(I2C_SCL_PIN);
  Wire.begin();
  Wire.setClock(I2C_CLOCK_HZ);

  for (size_t i = 0; i < NUM_EXPANDERS; i++) {
    if (!expanders[i].begin_I2C(expanderAddresses[i], &Wire)) {
      if (SERIAL_DEBUG) {
        Serial.print("MCP23017 not found at 0x");
        Serial.println(expanderAddresses[i], HEX);
      }
      continue;
    }
    for (uint8_t p = 0; p < 16; p++) {
      expanders[i].pinMode(p, INPUT_PULLUP);
    }
  }

  for (size_t i = 0; i < NUM_MUXES; i++) {
    pinMode(muxes[i].s0, OUTPUT);
    pinMode(muxes[i].s1, OUTPUT);
    pinMode(muxes[i].s2, OUTPUT);
  }

  for (size_t i = 0; i < NUM_BUTTONS; i++) {
    if (buttons[i].isDirect()) {
      pinMode(buttons[i].pin, INPUT_PULLUP);
    }
  }

  analogReadResolution(12);
}

////////////// Main loop //////////////

void loop() {
  static uint32_t lastPoll = 0;
  uint32_t now = millis();
  if (now - lastPoll < POLL_INTERVAL_MS) return;
  lastPoll = now;

  // Batch-read every expander once per poll (single I2C transaction per chip).
  uint16_t expanderBits[NUM_EXPANDERS > 0 ? NUM_EXPANDERS : 1];
  for (size_t i = 0; i < NUM_EXPANDERS; i++) {
    expanderBits[i] = expanders[i].readGPIOAB();
  }

  for (size_t i = 0; i < NUM_BUTTONS; i++) {
    const Button& b = buttons[i];
    bool pressed;
    if (b.isDirect()) {
      pressed = digitalRead(b.pin) == LOW;             // INPUT_PULLUP -> active-low
    } else {
      pressed = !((expanderBits[b.expanderIdx] >> b.pin) & 1);
    }
    if (pressed && !buttonState[i]) {
      MIDI.sendNoteOn(b.note, 127, MIDI_CHANNEL);
      if (SERIAL_DEBUG) { Serial.print("button "); Serial.print(i); Serial.println(" down"); }
    } else if (!pressed && buttonState[i]) {
      MIDI.sendNoteOff(b.note, 0, MIDI_CHANNEL);
      if (SERIAL_DEBUG) { Serial.print("button "); Serial.print(i); Serial.println(" up"); }
    }
    buttonState[i] = pressed;
  }

  for (size_t i = 0; i < NUM_POTS; i++) {
    const Pot& p = pots[i];
    uint16_t raw;
    if (p.isDirect()) {
      raw = analogRead(p.pin);
    } else {
      const Mux& m = muxes[p.muxIdx];
      selectMuxChannel(m, p.pin);
      raw = analogRead(m.adcPin);
    }
    potSmoothed[i] = (potSmoothed[i] * 7 + raw) / 8;   // EMA, alpha = 1/8
    uint8_t value7 = potSmoothed[i] >> 5;              // 12-bit -> 7-bit
    if (value7 != potLastSent[i]) {
      MIDI.sendControlChange(p.cc, value7, MIDI_CHANNEL);
      potLastSent[i] = value7;
    }
  }

}
