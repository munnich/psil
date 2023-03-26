from typing import List, Literal

def calibrate(instruct) -> tuple[Literal[44100], list[int]]:
    """
    Passthrough, since clipping requires no calibration.

    :param instruct: Instruction printing function.
    :return:         44100, [16] (sampling frequency and bits per sample)
    """
    instruct("No calibration necessary.")
    return 44100, [16]


def default_segment_length() -> float:
    """
    Default segment length, e.g. 0.2 seconds.

    :return: 0.2
    """
    return 0.2


def analysis_values() -> tuple[Literal[1], Literal["Clipping detected!"]]:
    """
    Analysis values: number of segments to analyze and notification message.

    :return: 1, "Clipping detected!"
    """
    return 1, "Clipping detected!"


def analyze(audio: List[int],
            fs: int = 44100,
            bit_depth: int = 16) -> Literal[1, 0]:
    """
    Analysis function, assume clipping if any sample is equal to maximum.

    :param audio:     Audio array to analyze.
    :param fs:        Audio sampling frequency.
    :param bit_depth: Audio bits per sample.
    :return:          1 if clipping, 0 else.
    """
    # audio is signed
    maximum: int = 2 ** bit_depth / 2 - 1
    minimum: int = -1 * maximum - 1
    if any([sample == maximum or sample == minimum for sample in audio]):
        return 1
    return 0

