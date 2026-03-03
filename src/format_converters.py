#!/usr/bin/env python3
"""
format_converters.py - Convert between CHULOOPA and rhythmic_creator formats

CHULOOPA format:
    DrumHit(drum_class, timestamp, velocity, delta_time)
    - drum_class: 0=kick, 1=snare, 2=hat
    - timestamp: seconds from loop start
    - velocity: 0.0-1.0
    - delta_time: seconds until next hit

Rhythmic Creator format:
    Space-separated triplets: "DRUM_CLASS START_TIME END_TIME"
    - DRUM_CLASS: MIDI note number (36=kick, 38=snare, 42=hat)
    - START_TIME: seconds (2 decimal places)
    - END_TIME: seconds (2 decimal places)
"""

import random


# MIDI note mapping
CHULOOPA_TO_MIDI = {
    0: 36,  # kick -> bass drum
    1: 38,  # snare -> acoustic snare
    2: 42,  # hat -> closed hi-hat
}

MIDI_TO_CHULOOPA = {
    # === KICKS (0) === #
    35: 0,  # acoustic bass drum
    36: 0,  # bass drum 1 (primary kick)

    # Toms (low pitched) -> Kick
    41: 0,  # low floor tom
    43: 0,  # high floor tom
    45: 0,  # low tom
    47: 0,  # low-mid tom
    48: 0,  # hi-mid tom
    50: 0,  # high tom

    # === SNARES (1) === #
    38: 1,  # acoustic snare (primary snare)
    40: 1,  # electric snare
    37: 1,  # side stick / rimshot
    39: 1,  # hand clap
    31: 1,  # sticks

    # Percussion (snare-like) -> Snare
    54: 1,  # tambourine
    56: 1,  # cowbell
    60: 1,  # hi bongo
    61: 1,  # low bongo
    62: 1,  # mute hi conga
    63: 1,  # open hi conga
    64: 1,  # low conga
    66: 1,  # high timbale
    67: 1,  # low timbale

    # === HATS/CYMBALS (2) === #
    42: 2,  # closed hi-hat (primary hat)
    44: 2,  # pedal hi-hat
    46: 2,  # open hi-hat

    # Cymbals -> Hat
    49: 2,  # crash cymbal 1
    51: 2,  # ride cymbal 1
    52: 2,  # chinese cymbal
    53: 2,  # ride bell
    55: 2,  # splash cymbal
    57: 2,  # crash cymbal 2
    59: 2,  # ride cymbal 2

    # Metallic percussion -> Hat
    68: 2,  # low agogo
    69: 2,  # high agogo
    70: 2,  # cabasa
    73: 2,  # short guiro
    74: 2,  # long guiro
    80: 2,  # mute triangle
    81: 2,  # open triangle
}


def chuloopa_to_rhythmic_creator(pattern) -> str:
    """
    Convert CHULOOPA DrumPattern to rhythmic_creator text format.

    Args:
        pattern: CHULOOPA DrumPattern object

    Returns:
        Space-separated string: "36 0.0 0.12 38 0.5 0.6 ..."
    """
    if not pattern.hits:
        return ""

    tokens = []

    for hit in pattern.hits:
        # Map drum class to MIDI note
        midi_note = CHULOOPA_TO_MIDI.get(hit.drum_class, 36)

        # Start time is the timestamp
        start_time = hit.timestamp

        # End time: use short duration (rhythmic_creator doesn't use it meaningfully)
        end_time = start_time + 0.1

        # Format timestamps to match training data format
        # Use up to 2 decimal places, strip trailing zeros, but keep at least one decimal
        start_str = f"{start_time:.2f}".rstrip('0')
        if start_str.endswith('.'):
            start_str += '0'

        end_str = f"{end_time:.2f}".rstrip('0')
        if end_str.endswith('.'):
            end_str += '0'

        # Add triplet
        tokens.extend([str(midi_note), start_str, end_str])

    return " ".join(tokens)


def rhythmic_creator_to_chuloopa(text: str, loop_duration: float):
    """
    Convert rhythmic_creator output to CHULOOPA DrumPattern.

    Args:
        text: Space-separated MIDI events "36 0.0 0.1 38 0.5 0.6 ..."
        loop_duration: Total loop duration in seconds

    Returns:
        DrumPattern object with hits and delta_times calculated
    """
    # Import here to avoid circular dependency
    from drum_variation_ai import DrumPattern, DrumHit

    if not text or not text.strip():
        return DrumPattern(hits=[], loop_duration=loop_duration)

    tokens = text.split()
    hits = []

    # Parse triplets
    for i in range(0, len(tokens), 3):
        if i + 2 >= len(tokens):
            break

        try:
            midi_note = int(tokens[i])
            start_time = float(tokens[i + 1])
            end_time = float(tokens[i + 2])

            # Map MIDI note to CHULOOPA drum class
            # Skip unknown MIDI notes (melody notes, non-drum percussion)
            if midi_note not in MIDI_TO_CHULOOPA:
                continue

            drum_class = MIDI_TO_CHULOOPA[midi_note]

            # Assign velocity based on position
            velocity = assign_velocity(start_time, loop_duration)

            # Create hit
            hit = DrumHit(
                drum_class=drum_class,
                timestamp=start_time,
                velocity=velocity,
                delta_time=0.0  # Will be recalculated
            )
            hits.append(hit)

        except (ValueError, IndexError):
            continue

    # Create pattern and recalculate delta_times
    pattern = DrumPattern(hits=hits, loop_duration=loop_duration)
    pattern._recalculate_delta_times()

    return pattern


def assign_velocity(timestamp: float, loop_duration: float) -> float:
    """
    Assign velocity based on position in the loop (accent pattern).

    Args:
        timestamp: Hit timestamp in seconds
        loop_duration: Total loop duration

    Returns:
        Velocity value between 0.4 and 1.0
    """
    # Estimate beat duration (assume 4/4 time)
    beat_duration = loop_duration / 4
    half_beat = beat_duration / 2

    # Position within current beat
    beat_position = timestamp % beat_duration

    # Check if on downbeat or backbeat
    is_downbeat = beat_position < (beat_duration * 0.1)
    is_backbeat = abs(beat_position - half_beat) < (beat_duration * 0.1)

    # Base velocity with random variation
    base_velocity = random.uniform(0.6, 0.8)

    # Accent downbeats and backbeats
    if is_downbeat:
        base_velocity += random.uniform(0.1, 0.2)
    elif is_backbeat:
        base_velocity += random.uniform(0.05, 0.15)

    # Clamp to valid range
    return max(0.4, min(1.0, base_velocity))
