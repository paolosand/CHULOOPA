//----------------------------------------------------------------------------
// name: osc_test_python.ck
// desc: Test OSC - simulates Python side (like drum_variation_ai.py)
//       Sends to port 5001, receives on port 5000
//----------------------------------------------------------------------------

<<< "╔═══════════════════════════════════════╗" >>>;
<<< "║  OSC TEST - Python Side              ║" >>>;
<<< "╚═══════════════════════════════════════╝" >>>;

// RECEIVE on port 5000 (ChucK sends here)
OscIn oin;
OscMsg msg;
5000 => oin.port;
oin.listenAll();
<<< "Listening on port 5000 (waiting for messages from ChucK)..." >>>;

// SEND to port 5001 (ChucK receives here)
OscOut oout;
oout.dest("localhost", 5001);
<<< "Sending to port 5001 (ChucK listens here)" >>>;

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
            if(msg.typetag == "f") {
                <<< "    Float value:", msg.getFloat(0) >>>;
            }
            else if(msg.typetag == "s") {
                <<< "    String value:", msg.getString(0) >>>;
            }

            // Respond to specific messages
            if(msg.address == "/chuloopa/regenerate") {
                <<< "" >>>;
                <<< "*** Regenerate requested! Sending back variations_ready..." >>>;
                <<< "" >>>;

                // Simulate generating variations
                1::second => now;

                // Send progress update
                oout.start("/chuloopa/generation_progress");
                "Generating variation..." => oout.add;
                oout.send();
                <<< "SENT: /chuloopa/generation_progress" >>>;

                // Simulate more generation time
                1::second => now;

                // Send variations ready
                oout.start("/chuloopa/variations_ready");
                1 => oout.add;  // 1 variation ready
                oout.send();
                <<< "SENT: /chuloopa/variations_ready (1)" >>>;

                // Send completion
                oout.start("/chuloopa/generation_progress");
                "Complete!" => oout.add;
                oout.send();
                <<< "SENT: /chuloopa/generation_progress (Complete!)" >>>;
            }
            <<< "" >>>;
        }
    }
}

spork ~ receiver();

// Give receiver time to start
100::ms => now;

<<< "" >>>;
<<< "Sending initial test message..." >>>;
<<< "" >>>;

// Send initial test message
oout.start("/chuloopa/generation_progress");
"Python OSC test - connection established!" => oout.add;
oout.send();
<<< "SENT: /chuloopa/generation_progress (test message)" >>>;

<<< "" >>>;
<<< "Waiting for messages from ChucK..." >>>;
<<< "Press Ctrl+C to stop" >>>;
<<< "" >>>;

// Keep running
while(true) {
    1::second => now;
}
