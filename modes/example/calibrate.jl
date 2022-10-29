#=
# To detect speech, we need a calibration in which room noise is recorded.
# We'll then set a gate slightly above the maximum of the room noise.
# As such, we only need to save the maximum of the room noise.
=#

# load the PortAudio and SampledSignals modules
using PortAudio, SampledSignals

# calibration has to be done via a function called calibrate
function calibrate()
    # open a mono microphone stream
    stream = PortAudioStream(1, 0)

    # save sampling frequency
    fs = stream.sample_rates

    # print instructions for the user
    println("Please stay silent for the next 5 seconds!")

    # read the microphone stream for 5 seconds and save as array
    recording = read(stream, 5s)

    # notify the user they can stop staying silent
    println("Done!")

    # close the microphone stream
    close(stream)

    # return fs and the argument to be fed to the analysis function
    # this is just the maximum of the recording in this case
    # this has to be returned as an array/vector
    return fs, [maximum(recording)]
end
