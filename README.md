# PSIL

PSIL (Process Speech Impediments Live) is a modular program for speech impediment detection designed to be run as a background process.

## Requirements

#### PSIL

```
Configurations, PortAudio, SampledSignals, ArgParse
```

#### Mode: lisp

```
FFTW, Statistics, LinearAlgebra, Alert
```

## Usage

```
julia psil.jl
```

The program will print instructions to the command line.

To rerun the configuration process:

```
julia psil.jl --reconfig
```

## Modes

Currently, the only supported mode is (lateral) lisp detection, which can be loaded with the "lisp" prompt.

The available modes can always be listed using the program:

```
julia psil.jl --list-modes
```

### Adding modes

Modes can easily be added by creating a directory in the `modes` folder with the mode's name.
Within this folder, a calibration file, `calibrate.jl` and an analysis file, `analyze.jl` should be present.

The calibration algorithm, which should be wrapped inside a function called `calibrate`, needs to take no import and return the arguments to be fed to the analysis algorithm.

The analysis algorithm, which should be wrapped inside a function called `analyze`, needs to take an array containing the audio recording, an integer for the sampling frequency, and then the aforementioned arguments returned by the calibration function.

