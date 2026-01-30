//----------------------------------------------------------------------------
// name: osc_test_chuck.ck
// desc: Test OSC - simulates ChucK side (like chuloopa_drums_v2.ck)
//       Sends to port 5000, receives on port 5001
//----------------------------------------------------------------------------

<<< "╔═══════════════════════════════════════╗" >>>;
<<< "║  OSC TEST - ChucK Side               ║" >>>;
<<< "╚═══════════════════════════════════════╝" >>>;

// RECEIVE on port 5001 (Python sends here)
OscIn oin;
OscMsg msg;
5001 => oin.port;
oin.listenAll();
<<< "Listening on port 5001 (waiting for messages from Python)..." >>>;

// SEND to port 5000 (Python receives here)
OscOut oout;
oout.dest("localhost", 5000);
<<< "Sending to port 5000 (Python listens here)" >>>;

// Spork receiver
fun void receiver() {
    while(true) {
        oin => now;

        while(oin.recv(msg)) {
            <<< "" >>>;
            <<< ">>> RECEIVED:", msg.address >>>;
            <<< "    Typetag:", msg.typetag >>>;
            <<< "    Args:", msg.numArgs() >>>;

            // Print arguments
            if(msg.typetag == "i") {
                <<< "    Int value:", msg.getInt(0) >>>;
            }
            else if(msg.typetag == "s") {
                <<< "    String value:", msg.getString(0) >>>;
            }
            <<< "" >>>;
        }
    }
}

spork ~ receiver();

// Give receiver time to start
100::ms => now;

<<< "" >>>;
<<< "Sending test messages every 2 seconds..." >>>;
<<< "Press Ctrl+C to stop" >>>;
<<< "" >>>;

// Send messages periodically
while(true) {
    // Send test spice value (simulates CC 18 knob)
    oout.start("/chuloopa/spice");
    Math.random2f(0.0, 1.0) => float spice => oout.add;
    oout.send();
    <<< "SENT: /chuloopa/spice", spice >>>;

    2::second => now;

    // Send regenerate request
    oout.start("/chuloopa/regenerate");
    oout.send();
    <<< "SENT: /chuloopa/regenerate" >>>;

    2::second => now;
}
