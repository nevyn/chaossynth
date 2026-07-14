#!/usr/bin/env python3
"""Virtual Chaossynth panel: a fake MIDI source for testing without hardware.

Creates a virtual MIDI source named "Chaossynth" (per docs/midi-contract.md the
synth can't tell it from the real panel) and sends events from commands.

Usage:
  virtual-panel.py                        interactive REPL
  virtual-panel.py press 0 0.5            one command, then exit
  virtual-panel.py scenario smoke.json    timed event list
  echo "press 0 1" | virtual-panel.py -   commands from stdin

Commands:
  press <id> [seconds]   NoteOn; auto NoteOff after seconds (held if omitted)
  release <id>           NoteOff
  pot <id> <0-127>       CC 20+id
  cc <num> <val>         raw CC (specials, or 123 = all notes off)
  chaos [seconds]        random mashing (default 10)
  sleep <seconds>
  quit

Scenario file: JSON array of {"at": <seconds>, "cmd": "<command>"}.

The synth rescans for MIDI sources every ~2 s, so this waits CONNECT_GRACE
seconds after opening the port before sending anything.
"""
import json
import random
import sys
import time

import mido

CHANNEL = 0        # MIDI channel 1
BUTTONS = 18       # ids in the seed mapping.json
POTS = 4
CONNECT_GRACE = 4  # seconds for the synth's rescan to find us

held = set()


def note_on(port, note):
    port.send(mido.Message("note_on", note=note, velocity=127, channel=CHANNEL))
    held.add(note)
    print(f"-> note_on {note}")


def note_off(port, note):
    port.send(mido.Message("note_off", note=note, velocity=0, channel=CHANNEL))
    held.discard(note)
    print(f"-> note_off {note}")


def send_cc(port, cc, val):
    port.send(mido.Message("control_change", control=cc, value=val, channel=CHANNEL))
    print(f"-> cc {cc} = {val}")


def chaos(port, seconds):
    end = time.monotonic() + seconds
    while time.monotonic() < end:
        if random.random() < 0.7:
            note = random.randrange(BUTTONS)
            if note in held:
                note_off(port, note)
            else:
                note_on(port, note)
        else:
            send_cc(port, 20 + random.randrange(POTS), random.randrange(128))
        time.sleep(random.uniform(0.03, 0.2))
    for note in sorted(held):  # end clean; stuck notes are a separate test
        note_off(port, note)


def run_command(port, line):
    """Returns False when the REPL should quit."""
    parts = line.split()
    if not parts or parts[0].startswith("#"):
        return True
    cmd, args = parts[0], parts[1:]
    try:
        if cmd == "press":
            note_on(port, int(args[0]))
            if len(args) > 1:
                time.sleep(float(args[1]))
                note_off(port, int(args[0]))
        elif cmd == "release":
            note_off(port, int(args[0]))
        elif cmd == "pot":
            send_cc(port, 20 + int(args[0]), int(args[1]))
        elif cmd == "cc":
            send_cc(port, int(args[0]), int(args[1]))
        elif cmd == "chaos":
            chaos(port, float(args[0]) if args else 10.0)
        elif cmd == "sleep":
            time.sleep(float(args[0]))
        elif cmd in ("quit", "exit"):
            return False
        else:
            print(f"?? unknown command: {line}")
    except (ValueError, IndexError):
        print(f"?? bad arguments: {line}")
    return True


def run_scenario(port, path):
    with open(path) as f:
        events = json.load(f)
    # "press <id> <dur>" inside a timeline becomes on/off pairs so it can't
    # block and skew later "at" times.
    timeline = []
    for ev in events:
        parts = ev["cmd"].split()
        if parts[0] == "press" and len(parts) == 3:
            timeline.append((float(ev["at"]), f"press {parts[1]}"))
            timeline.append((float(ev["at"]) + float(parts[2]), f"release {parts[1]}"))
        else:
            timeline.append((float(ev["at"]), ev["cmd"]))
    timeline.sort(key=lambda e: e[0])
    t0 = time.monotonic()
    for at, cmd in timeline:
        time.sleep(max(0.0, t0 + at - time.monotonic()))
        print(f"[{at:6.2f}] {cmd}")
        run_command(port, cmd)


def main():
    port = mido.open_output("Chaossynth", virtual=True)
    print(f"virtual panel up as 'Chaossynth'; waiting {CONNECT_GRACE} s for the synth to connect")
    time.sleep(CONNECT_GRACE)

    args = sys.argv[1:]
    if args and args[0] == "scenario":
        run_scenario(port, args[1])
    elif args and args[0] != "-":
        run_command(port, " ".join(args))
        time.sleep(0.5)  # let the last message land before the port vanishes
    else:
        if sys.stdin.isatty():
            print("commands: press release pot cc chaos sleep quit")
        for line in sys.stdin:
            if not run_command(port, line.strip()):
                break
    port.close()


if __name__ == "__main__":
    main()
