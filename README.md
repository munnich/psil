# PSIL

PSIL (Process Speech Impediments Live) is a modular program for speech impediment detection designed to be run as a background process.

## Requirements

```
Configurations, PortAudio, SampledSignals, ArgParse, Gtk, PyCall, Alert, FFTW, Statistics, LinearAlgebra
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

This GUI is best ran with at least two threads:

```
julia -t2 psil.jl --gui
```

It is, however, recommended to stick to the CLI.

To rerun the configuration process:

```
julia psil.jl --reconfig
```

## Modes

Available modes are:

* lateral lisp detection: `Lisp`
* basic speech detection via noise gate: `NoiseGate`
* clipping detection: `Clipping`

The available modes can always be listed using the program:

```
julia psil.jl --list-modes
```

### Adding modes

Modes can easily be added by creating a directory in the `modes` folder with the mode's name, containing a module with a matching name, either written in Julia or Python.

The module must consist of at least four functions:
* `calibrate`: A calibration function taking an instruction function, which is fed a string, as input, and returning the desired sampling frequency along with any calibrated parameters to be passed on. All audio recording necessary for calibration must be handled within the function.
* `default_segment_length`: A function taking no input parameters and returning the desired segment length to use for the mode, either as a number, which is interpreted in seconds, or a `Unitful.Quantity` as in `SampledSignals.jl`, e.g. 1s for 1 second.
* `analysis_values`: A function taking no input parameters and returning the desired number of segments to be analyzed before result analysis is performed, along with a string containing the notification message if the result is positive.
* `analyze`: The main analysis function, which takes an audio array, the sampling frequency, and any calibration parameters returned by `calibrate`. The function must return `1` for positive results, `0` for neutral results, and `-1` for negative results.

When PSIL starts analyzing, it runs `analyze` until the desired segment number as given in `analysis_values` is reached, then sums the results. If the result is greater zero, the notification message given in `analysis_values` is sent out via the operating system's alert system.

Example modes can be found in `modes/NoiseGate` for Julia and `modes/Clipping` for Python.

