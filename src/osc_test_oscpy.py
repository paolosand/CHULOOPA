#!/usr/bin/env python3
"""
Test using oscpy library instead of python-osc
"""

try:
    from oscpy.client import OSCClient
    print("Using oscpy library")

    client = OSCClient("localhost", 5001)
    print("OSC client created - sending to localhost:5001")
    print()

    import time
    count = 0
    while True:
        count += 1

        print(f"[{count}] Sending: /chuloopa/generation_progress")
        client.send_message(b"/chuloopa/generation_progress", [f"Test #{count}".encode()])

        time.sleep(1)

        print(f"[{count}] Sending: /chuloopa/variations_ready")
        client.send_message(b"/chuloopa/variations_ready", [1])

        time.sleep(2)
        print()

except ImportError:
    print("oscpy not installed. Install with: pip install oscpy")
