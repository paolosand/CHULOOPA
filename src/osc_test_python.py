#!/usr/bin/env python3
"""
Simple Python OSC test - sends messages to ChucK on port 5001
Run alongside chuloopa_drums_v2.ck or osc_test_chuck.ck
"""

import time
from pythonosc import udp_client

print("="*60)
print("  Python OSC Test - Sending to ChucK")
print("="*60)

# Create OSC client sending to port 5001
client = udp_client.SimpleUDPClient("localhost", 5001)
print("OSC client created - sending to localhost:5001")
print()

# Send test messages
print("Sending test messages every 2 seconds...")
print("Press Ctrl+C to stop")
print()

count = 0
while True:
    count += 1

    # Send test message with string
    print(f"[{count}] Sending: /chuloopa/generation_progress")
    client.send_message("/chuloopa/generation_progress", f"Test message #{count}")

    time.sleep(1)

    # Send test message with int
    print(f"[{count}] Sending: /chuloopa/variations_ready")
    client.send_message("/chuloopa/variations_ready", 1)

    time.sleep(1)

    # Send test message with float
    print(f"[{count}] Sending: /test/float")
    client.send_message("/test/float", 0.5)

    time.sleep(1)

    print()
