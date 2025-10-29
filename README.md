# CHULOOPA (a CHUCK Loopa)

## GIST

- A experimental looper in Chuck to push the bounds of the language and identify areas for improvment.
  - AUDIO
    - Aside from simply looping a sound recording, this project seeks to use AI techniques to have these sound recordings evolve over time.
  - VISUALS
    - Using CHUGL, add an intuitive visualization of the recorded audio for the users.

## PROGRESS

[ ] Intial Implementation and Exploration (Can we build a quick looper and what can we do with chuck)
[ ] Architecture and Data Pipeline

### INITIAL IMPLEMENTATION EXPLORATIONS

- AUDIO
  - Currently have a couple looper iterations
    1. simple looper
       - looper.ck (audio engine) + looper_gui.ck (interface)
       - uses osc controls
    2. looper w vocoder
       - looper_vocoder.ck (audio engine) + looper_gui_vocoder.ck (interface)
       - uses osc controls
    3. looper midi quneo
       - NEEDED SPECIFIC WORKAROUNDS FOR THE QUNEO MIDI CONTROLLER
       - looper_midi_quneo.ck
       - looper_midi_quneo_vocoder.ck
    4. looper midi quneo visual
       - NEEDED SPECIFIC WORKAROUNDS FOR THE QUNEO MIDI CONTROLLER
       - looper_midi_quneo_grid_visual.ck
       - looper_midi_quneo_visual.ck
    5. realtime symbolic transcription
       - pitch_detector_recorder.ck (records from mic to MIDI text file)
       - pitch_detector_file.ck (converts WAV files to MIDI text file)
       - midi_playback.ck (plays back MIDI text files)
       - uses autocorrelation for pitch detection
