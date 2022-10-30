#=
# The analysis part of this just needs to check if any of the values within the
# stream are above the noise gate.
=#

# load SampledSignals module, which we will always need, along with the Alert
# module, which we'll use to send out alerts to the user
using SampledSignals, Alert

# set the segment length for recordings
# the analysis will be infinitely looped over recordings of this length
segment_length = 2s

# define the required analyze function
# this needs to take the audio recording, sampling frequency, and the 
# calibration function's returned values
# in our case, this is noise_maximum, which we will use for the gate
function analyze(audio, fs, noise_maximum)
    # save our gate value to a variable, let's use noise_maximum * 2
    gate = noise_maximum * 2

    # go through all recorded values and check if > gate
    above_gate = audio .> gate

    # check if any of the recorded values are above the gate
    if any(above_gate)
        # if so let's print out a message
        println("Speech detected!")
        # we can also send out a system notification
        alert("Speech detected!")
    end
end