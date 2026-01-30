import mido

# 1. List available input ports so you can see your keyboard's name
print("Available inputs:", mido.get_input_names())

# 2. Replace 'Your Keyboard Name' with the actual name from the list above
# Or use the line below to just open the first one it finds automatically
try:
    with mido.open_input() as inport:
        print(f"\n--- Monitoring {inport.name} ---")
        print("Press keys or turn knobs (Ctrl+C to stop)...\n")
        
        for msg in inport:
            # 'note_on' is a key press, 'note_off' is a release
            if msg.type == 'note_on':
                print(f"KEY PRESSED  | Note: {msg.note} | Velocity: {msg.velocity}")
            
            # 'control_change' is usually a knob or fader
            elif msg.type == 'control_change':
                print(f"KNOB TURNED  | Control ID: {msg.control} | Value: {msg.value}")
            
            # Catch-all for other MIDI data (pitch bend, etc.)
            else:
                print(f"OTHER DATA   | {msg}")

except KeyboardInterrupt:
    print("\nStopping monitor. Happy composing!")
except IOError:
    print("Error: Could not find MIDI device. Check your connection.")