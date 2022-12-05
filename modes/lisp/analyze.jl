using FFTW, Statistics, LinearAlgebra, Alert, SampledSignals

include("shared.jl")


"""
Return default segment length for lisp analysis.
0.5 seconds seems to work pretty fine.
"""
function default_segment_length()
    return 0.5s
end


"""
Return number of segments to analyze and the notification message.
"""
function analysis_values()
    return 10, "Lisping detected!"
end

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
    slicemeandiff = slicemean - slicemeanrest
    return slicemeandiff > 0
end


"""
Lisp analyze function. Similar to the original, but optimized for single recordings.
"""
function analyze(audio, fs::Int, normal::Vector{Int}, lisp::Vector{Int},
        rest::Vector{Int})
    audiomean = mean(abs.(audio))

    # use standard deviation to filter out completely silent recordings
    if std(audio) < 0.05
        return
    end

    # use mean to filter out silent segments
    segment = getfft(audio, audiomean, fs)

    # multithreaded way of checking both
    # only do for > 2 since the GUI might require another thread
    if Threads.nthreads() > 2
        results = zeros(2)
        Threads.@threads for i in 1:2
            if i == 1
                if examinesegment(segment, lisp, rest)
                    results[i] = 1
                end
            else
                if examinesegment(segment, normal, rest)
                    results[i] = 1
                end
            end
        end
    
        # lisp ⇒ 1
        if i[1] == 1
            return 1
        # normal ⇒ -1
        elseif i[2] == 1
            return -1
        end
    # this is more optimal if we don't have enough threads available
    else
        if examinesegment(segment, lisp, rest)
            return 1
        elseif examinesegment(segment, normal, rest)
            return -1
        end
    end

    # else ⇒ 0
    return 0
end

