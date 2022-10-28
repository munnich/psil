using Configurations, PortAudio, SampledSignals
using ArgParse


function parse()
    modes = readdir("modes")

    if length(modes) == 0
        @error "No modes found in \"modes\" directory."
    end

    s = ArgParseSettings(description="Process Speech Impedements Live - speech impedement notification tool")

    @add_arg_table s begin
        "--reconfig"
        help = "Rerun the configuration by deleting current configuration file; reselect the mode and recalibrate."
        action = :store_true
        "--list-modes"
        help = "List available modes."
        action = :store_true
    end

    parse_args(s)
end


"""
Config struct
"""
@option "config" struct Config
    # in case we want to support the user having access to multiple modes
    # we should use one struct per mode
    mode::String
    args::Array{}
end


"""
Config file loading function (in case it ends up needing to be more complicated).
"""
function check_config()
    try
        return from_toml("config.toml")
    catch
        return
    end
end


"""
Infinite loop running the analysis function.
"""
function loop_analyze(func::Function, N, args...)
    # mono mic stream
    stream = PortAudioStream(1, 0)
    buf = read(stream, N)

    # there's no real alternative to forcing an infinite loop here
    while true
        read!(stream, buf)
        func(buf, args...)
    end
end


"""
PSIL CLI function; wrapper around everything else with printed instructions for user.
"""
function psil_cli()
    println("Welcome to Process Speech Impedements Live, reading config...")
    config = check_config()

    if !config
        println("No configuration file found. Please enter the mode you'd like to use.")
        chosen_mode = readline()
        # a simple way of handling modular modes is to just use folders for them
        try
            include("modes/$chosen_mode/calibrate.jl") 
            include("modes/$chosen_mode/analyze.jl")
        catch
            @error "Mode not found. Please restart and enter the directory name containing the mode's files."
            return
        end
        # calibrate will return an array containing args in each position
        args = calibrate()

        # save to config
        config = from_kwargs(Config, chosen_mode, args)
        to_toml("config.toml", config)
    else
        include("modes/$(config.mode)/analyze.jl")
    end

    println("Proceeding to analysis. You will be notified whenever a speech impedement issue occurs. To exit, press CTRL+C.")
    loop_analyze(analyze, segment_length, config.args...)
end


"""
PSIL initialization; parses args passed on launch.
"""
function initialize()
    pargs = parse()
    if pargs["reconfig"]
        rm("config.toml")
    end

    if pargs["list-modes"]
        println(join(readdir("modes"), ", "))
        return
    end

    psil_cli()
end

initialize()
