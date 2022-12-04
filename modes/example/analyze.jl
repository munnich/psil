#=
# The analysis part of this just needs to check if any of the values within the
# stream are above the noise gate.
=#

# load SampledSignals module, which we will always need, along with the Alert
# module, which we'll use to send out alerts to the user
using SampledSignals, Alert

# the segment length for recordings needs to be returned via a function
# called default_segment_length
# the analysis will be infinitely looped over recordings of this length
function default_segment_length()
    return 2s
end

# return the maximum number of iterations to run (1 here) and the notification message
function analysis_values()
    return 1, "Speech detected!"
end

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
        # if we've hit our condition we have to return 1
        return 1
        # if we didn't and we had >1 max iterations we return -1
        # alternatively for neutral return 0
    end
    return 0
end
