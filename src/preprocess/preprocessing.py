class MIDIProcessor:

    def __init__(self, path):
        self.path = path
        self.midi_list, self.unique_notes = self.split_text()

    def split_text(self):
        assert self.path is not None, "please enter the folder name."
        midi = open(self.path, 'r').read().splitlines()

        # split with white space, get rid of the '', set unique elements, and sort
        midi_list = [midi[m].split(' ')[:-1] for m in range(len(midi))]
        unique_notes = sorted(list(set().union(*midi_list)))
        midi_flatten = [info for sub in midi_list for info in sub]
        return midi_flatten, unique_notes

    def encode_with_mapping(self, string):
        midi_to_int = {nt: i for i, nt in enumerate(self.unique_notes)}
        return [midi_to_int[m_str] for m_str in string]

    def decode_with_mapping(self, integer):
        int_to_midi = {i: nt for i, nt in enumerate(self.unique_notes)}
        return ' '.join([int_to_midi[i] for i in integer])

