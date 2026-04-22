import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from models.rhythmic_creator_grid.grid_model import RhythmicCreatorGridModel

CKPT = str(Path(__file__).parent.parent / "models" / "grid_barpair_best_epoch.pt")


def test_model_loads():
    model = RhythmicCreatorGridModel(CKPT, device='cpu')
    assert '<SOS>' in model.stoi
    assert '<SEP>' in model.stoi
    assert '<EOS>' in model.stoi
    assert 'P0' in model.stoi
    assert 'P15' in model.stoi
    assert 'N36' in model.stoi
    assert 'N38' in model.stoi
    assert 'N42' in model.stoi


def test_generate_returns_valid_pn_pairs():
    model = RhythmicCreatorGridModel(CKPT, device='cpu')
    context = ['P0', 'N36', 'P4', 'N38', 'P8', 'N36', 'P12', 'N38']
    result = model.generate_variation(context, temperature=1.0, max_new_tokens=64)

    assert len(result) > 0
    assert len(result) % 2 == 0, f"Expected even number of tokens, got {len(result)}: {result}"

    for i in range(0, len(result), 2):
        assert result[i].startswith('P'), f"Position {i} should be P token, got {result[i]}"
        assert result[i + 1].startswith('N'), f"Position {i+1} should be N token, got {result[i+1]}"
        step = int(result[i][1:])
        assert 0 <= step <= 15, f"Step {step} out of 0-15 range at position {i}"


def test_generate_no_special_tokens_in_output():
    model = RhythmicCreatorGridModel(CKPT, device='cpu')
    context = ['P0', 'N36', 'P8', 'N38']
    result = model.generate_variation(context, temperature=1.0, max_new_tokens=64)
    for tok in result:
        assert tok not in ('<SOS>', '<SEP>', '<EOS>', '<PAD>'), \
            f"Special token {tok} leaked into output"
