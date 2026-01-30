#!/usr/bin/env python3
"""
Alternative Python OSC test with explicit configuration
"""

from pythonosc import udp_client
import time

print("="*60)
print("  Python OSC Test - Alternative Method")
print("="*60)
print()

# Try with explicit IP instead of "localhost"
host = "127.0.0.1"  # Use IP instead of hostname
port = 5001

print(f"Creating OSC client to {host}:{port}")
client = udp_client.SimpleUDPClient(host, port)
print("OSC client created")
print()

# Try sending with different message types
print("Sending test messages...")
print()

count = 0
while True:
    count += 1

    # Method 1: String message
    try:
        print(f"[{count}] Attempting: /chuloopa/generation_progress (string)")
        client.send_message("/chuloopa/generation_progress", "Test string")
        print("  Sent successfully (no exception)")
    except Exception as e:
        print(f"  ERROR: {e}")

    time.sleep(0.5)

    # Method 2: Integer message
    try:
        print(f"[{count}] Attempting: /chuloopa/variations_ready (int)")
        client.send_message("/chuloopa/variations_ready", 1)
        print("  Sent successfully (no exception)")
    except Exception as e:
        print(f"  ERROR: {e}")

    time.sleep(0.5)

    # Method 3: No arguments
    try:
        print(f"[{count}] Attempting: /chuloopa/regenerate (no args)")
        client.send_message("/chuloopa/regenerate", [])
        print("  Sent successfully (no exception)")
    except Exception as e:
        print(f"  ERROR: {e}")

    time.sleep(2)
    print()
