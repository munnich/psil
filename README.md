# PSIL

PSIL (Process Speech Impediments Live) is a modular program for speech impediment detection designed to be run as a background process.

## Requirements

#### PSIL

```
Configurations, PortAudio, SampledSignals, ArgParse, Gtk
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

Alternatively, the program can be run with a small GTK-based GUI:

```
julia psil.jl --gui
```

It is, however, recommended to stick to the CLI.

To rerun the configuration process:

```
julia psil.jl --reconfig
```

## Modes

Available modes are:

* (lateral) lisp detection based on [Munnich et al.](https://github.com/munnich/lateral-lisp): `lisp`
* basic speech detection via noise gate: `example`

The available modes can always be listed using the program:

```
julia psil.jl --list-modes
```

### Adding modes

Modes can easily be added by creating a directory in the `modes` folder with the mode's name.
Within this folder, a calibration file, `calibrate.jl` and an analysis file, `analyze.jl` should be present.

The calibration algorithm, which should be wrapped inside a function called `calibrate`, needs to take no import and return the sampling frequency and the arguments to be fed to the analysis algorithm, which should be in an array.

The analysis algorithm, which should be wrapped inside a function called `analyze`, needs to take an array containing the audio recording, an integer for the sampling frequency, and then the aforementioned arguments returned by the calibration function.

Within the analysis file, a function called `default_segment_length` needs to exist. As its name implies, this returns the length of audio recording segments that the algorithm function will be run over.

An example mode can be found in `modes/example`.
