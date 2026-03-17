// Simple MIDI monitor - shows what's being pressed
MidiIn min;
MidiMsg msg;

if (!min.open(0)) {
    <<< "No MIDI device found" >>>;
    me.exit();
}

<<< "MIDI Monitor - press keys/knobs to see values" >>>;
<<< "-------------------------------------------" >>>;

while (true) {
    min => now;
    while (min.recv(msg)) {
        if ((msg.data1 & 0xF0) == 0x90 && msg.data3 > 0) {
            <<< "NOTE ON  | note:", msg.data2, "| velocity:", msg.data3 >>>;
        } else if ((msg.data1 & 0xF0) == 0x80 || ((msg.data1 & 0xF0) == 0x90 && msg.data3 == 0)) {
            <<< "NOTE OFF | note:", msg.data2 >>>;
        } else if ((msg.data1 & 0xF0) == 0xB0) {
            <<< "CC       | cc:", msg.data2, "| value:", msg.data3 >>>;
        }
    }
}