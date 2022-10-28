using FFTW, WAV


"""
FFT result struct.
"""
struct FFTResult
    waveform::Array{Float64}
    fs::Int
    fftmagnitude::Array{Float64}
end


"""
Function to calculate FFT as necessary and return FFTResult.
"""
function getfft(audio, audiomean, fs::Int)
    audio = audio .- audiomean

    normalize!(audio)

    fftdata = fft(audio)

    return FFTResult(audio, fs, abs.(fftdata))
end

