using FFTW, Statistics, LinearAlgebra, PortAudio, SampledSignals

# https://github.com/tungli/Findpeaks.jl
"""
`findpeaks(y::Array{T},
x::Array{S}=collect(1:length(y))
;min_height::T=minimum(y), min_prom::T=minimum(y),
min_dist::S=0, threshold::T=0 ) where {T<:Real,S}`\n
Returns indices of local maxima (sorted from highest peaks to lowest)
in 1D array of real numbers. Similar to MATLAB's findpeaks().\n
*Arguments*:\n
`y` -- data\n
*Optional*:\n
`x` -- x-data\n
*Keyword*:\n
`min_height` -- minimal peak height\n
`min_prom` -- minimal peak prominence\n
`min_dist` -- minimal peak distance (keeping highest peaks)\n
`threshold` -- minimal difference (absolute value) between
 peak and neighboring points\n
"""
function findpeaks(
                   y :: AbstractVector{T},
                   x :: AbstractVector{S} = collect(1:length(y))
                   ;
                   min_height :: T = minimum(y),
                   min_prom :: T = zero(y[1]),
                   min_dist :: S = zero(x[1]),
                   max_dist :: S = zero(x[1]),
                   threshold :: T = zero(y[1]),
                  ) where {T <: Real, S}

    dy = diff(y)

    peaks = in_threshold(dy, threshold)

    yP = y[peaks]
    peaks = with_prominence(y, peaks, min_prom)
    
    #minimal height refinement
    peaks = peaks[y[peaks] .> min_height]
    yP = y[peaks]

    peaks = with_distance(peaks, x, y, min_dist)

    peaks = within_distance(peaks, x, y, max_dist)

    peaks
end

"""
Select peaks that are inside threshold.
"""
function in_threshold(
                      dy :: AbstractVector{T},
                      threshold :: T,
                     ) where {T <: Real}

    peaks = 1:length(dy) |> collect

    k = 0
    for i = 2:length(dy)
        if dy[i] <= -threshold && dy[i-1] >= threshold
            k += 1
            peaks[k] = i
        end
    end
    peaks[1:k]
end

"""
Select peaks that have a given prominence
"""
function with_prominence(
                         y :: AbstractVector{T},
                         peaks :: AbstractVector{Int},
                         min_prom::T,
                        ) where {T <: Real}

    #minimal prominence refinement
    peaks[prominence(y, peaks) .> min_prom]
end


"""
Calculate peaks' prominences
"""
function prominence(y::AbstractVector{T}, peaks::AbstractVector{Int}) where {T <: Real}
    yP = y[peaks]
    proms = zero(yP)

    for (i, p) in enumerate(peaks)
        lP, rP = 1, length(y)
        for j = (i-1):-1:1
            if yP[j] > yP[i]
                lP = peaks[j]
                break
            end
        end
        ml = minimum(y[lP:p])
        for j = (i+1):length(yP)
            if yP[j] > yP[i]
                rP = peaks[j]
                break
            end
        end
        mr = minimum(y[p:rP])
        ref = max(mr,ml)
        proms[i] = yP[i] - ref
    end

    proms
end

"""
Select only peaks that are further apart than `min_dist`
"""
function with_distance(
                       peaks :: AbstractVector{Int},
                       x :: AbstractVector{S},
                       y :: AbstractVector{T},
                       min_dist::S,
                      ) where {T <: Real, S}

    peaks2del = zeros(Bool, length(peaks))
    inds = sortperm(y[peaks], rev=true)
    permute!(peaks, inds)
    for i = 1:length(peaks)
        for j = 1:(i-1)
            if abs(x[peaks[i]] - x[peaks[j]]) <= min_dist
                if !peaks2del[j]
                    peaks2del[i] = true
                end
            end
        end
    end

    peaks[.!peaks2del]
end

"""
Select only peaks that are closer together than `max_dist`
"""
function within_distance(
                       peaks :: AbstractVector{Int},
                       x :: AbstractVector{S},
                       y :: AbstractVector{T},
                       max_dist::S,
                      ) where {T <: Real, S}

    peaks2del = zeros(Bool, length(peaks))
    inds = sortperm(y[peaks], rev=true)
    permute!(peaks, inds)
    for i = 1:length(peaks)
        for j = 1:(i-1)
            if abs(x[peaks[i]] - x[peaks[j]]) >= max_dist
                if !peaks2del[j]
                    peaks2del[i] = true
                end
            end
        end
    end

    peaks[.!peaks2del]
end


"""
Calibration function to run on single buffers.
"""
function calibrate_buf(buf, range, x, start)
    ofinterest = abs.(fft(buf))[range]
    peaks = findpeaks(ofinterest, x, max_dist=1000, min_height=maximum(ofinterest) / 4)
    return [minimum(peaks), maximum(peaks)] .+ start
end


"""
Calibration wrapper to record audio and run through calibrate_buf.
"""
function calibrate()
    fs = 24000
    stream = PortAudioStream(1, 0; samplerate=fs)
    println("For the next 5 seconds, make a lisp-free S sound.")
    # wait for user to read the instructions
    sleep(2)
    # now we actually read the audio
    bufs = [read(stream, 3s)]
    # repeat for lisped sound
    println("Done! Now, do the same for a lisped S sound.")
    sleep(2)
    push!(bufs, read(stream, 3s))
    close(stream)

    println("Done!")
    range = 1000:trunc(Int, fs / 2)
    x = (range |> collect)
    results = Array{Vector{Int}}(undef, 3)
    Threads.@threads for i in 1:2
        results[i] = calibrate_buf(bufs[i], range, x, 1000)
    end
    results[3] = [1000, trunc(Int, fs / 2)]
    # 1 is normal, 2 is lisp, 3 is rest
    return fs, results
end

