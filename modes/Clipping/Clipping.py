from typing import Literal

def calibrate(instruct) -> tuple[Literal[44100], list[int]]:
    instruct("No calibration necessary.")
    return 44100, [16]


def default_segment_length() -> float:
    return 0.2


def analysis_values() -> tuple[Literal[1], Literal["Clipping detected!"]]:
    return 1, "Clipping detected!"


def analyze(audio, fs: int = 44100, bit_depth: int = 16) -> Literal[1, 0]:
    maximum = 2 ** bit_depth - 1
    if any([sample == maximum for sample in audio]):
        return 1
    return 0
