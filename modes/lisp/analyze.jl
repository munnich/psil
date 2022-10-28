using FFTW, WAV, Statistics, LinearAlgebra, Alert, SampledSignals

include("shared.jl")

# the segment length for PSIL live recordings
segment_length = 10s


"""
Segment examination function from original lisp project.
"""
function examinesegment(input::FFTResult, segment::Vector{Int}, rest::Vector{Int})
    # adjustment for differing sample lengths
    factor = length(input.waveform) / input.fs
    low = trunc(Int, rest[1] * factor)
    high = trunc(Int, rest[2] * factor)
    # normalized bandpass
    slicedfft = normalize(input.fftmagnitude[low:high])
    # scale the segment
    scaledsegment = [trunc(Int, (s - rest[1]) * factor) for s in segment]
    # we have to make sure the rest segment isn't greater than the whole length
    slicemean = mean(slicedfft[scaledsegment[1]:min(scaledsegment[2], end)])
    if segment[2] == length(slicedfft)
        slicemeanrest = mean(slicedfft[1:scaledsegment[1]])
    elseif segment[1] == 1
        slicemeanrest = mean(slicedfft[scaledsegment[2]:end])
    else
        slicemeanrest = mean(vcat(slicedfft[1:scaledsegment[1]],
                                  slicedfft[scaledsegment[2]:end]))
    end
    # mean(end) - mean(rest) > 0 ⇒ lisp
    slicemeandiff = slicemean - slicemeanrest
    return slicemeandiff > 0
end


"""
Lisp analyze function. Similar to the original, but optimized for single recordings.
"""
function analyze(audio, fs::Int, lisp::Vector{Int}, normal::Vector{Int},
        rest::Vector{Int})
    audiomean = mean(abs.(audio))

    # use standard deviation to filter out completely silent recordings
    if std(audio) < 0.01
        return
    end
    
    # seglength = 0.5 s seemed to be the best performing in tests
    segmentlength = trunc(Int, fs * 0.5)

    segments = []
    Threads.@threads for i in 1:segmentlength:(length(audio) - segmentlength)
        slice = abs.(audio[i:(i + segmentlength)])
        # use mean to filter out silent segments
        if mean(slice) > audiomean
            push!(segments, getfft(audio, audiomean, fs))
        end
    end

    hits = misses = 0
    Threads.@threads for segment in segments
        if examinesegment(segment, lisp, rest)
            hits += 1
        elseif examinesegment(segment, normal, rest)
            misses += 1
        end
    end

    # hits > misses ⇒ lisp
    if hits > misses
        alert("Lisp detected!")
    end
end

