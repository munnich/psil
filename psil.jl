using Configurations, PortAudio, SampledSignals
using ArgParse
using Gtk


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
        "--gui"
        help = "Launch graphical user interface instead of command line interface."
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
    fs::Int
    args::Array{}
end


"""
Config file loading function (in case it ends up needing to be more complicated).
"""
function check_config()
    try
        return from_toml(Config, "config.toml")
    catch
        return
    end
end


"""
Calibration wrapper with instruct function input to support both CLI and GUI properly.
"""
function run_calibrate(chosen_mode::String, instruct::Function=println)
    println("Starting calibration process...")

    fs, args = Base.invokelatest(calibrate, instruct)
    config = from_kwargs(Config, mode=chosen_mode, fs=fs, args=args)
    to_toml("config.toml", config)
    return
end


"""
Infinite loop running the analysis function.
"""
function loop_analyze(func::Function, N, fs, args...)
    # mono mic stream
    stream = PortAudioStream(1, 0, samplerate=fs)
    buf = read(stream, N)
    Base.invokelatest(func, buf, fs, args...)

    # there's no real alternative to forcing an infinite loop here
    while true
        read!(stream, buf)
        Base.invokelatest(func, buf, fs, args...)
    end
end


"""
PSIL CLI function; wrapper around everything else with printed instructions for user.
"""
function psil_cli()
    println("Welcome to Process Speech Impediments Live!\nReading config...")
    config = check_config()

    if isnothing(config)
        println("No configuration file found. Please enter the mode you'd like to use.")
        chosen_mode = readline()
        # a simple way of handling modular modes is to just use folders for them
        try
            include("modes/$chosen_mode/calibrate.jl") 
            include("modes/$chosen_mode/analyze.jl")
        catch e
            if isa(e, SystemError)
                @error "Mode not found. Please restart and enter the directory name containing the mode's files."
            elseif isa(e, LoadError)
                @error "Dependency missing: $e"
            else
                @error "An error has occurred: $e"
            end
            return
        end
        run_calibrate(chosen_mode)
        config = check_config()
    else
        println("Loading configuration.")
        include("modes/$(config.mode)/analyze.jl")
    end

    println("Proceeding to analysis. You will be notified whenever a speech impedement issue occurs. To exit, press CTRL+C.")
    loop_analyze(analyze, segment_length, config.fs, config.args...)
end


"""
Simple GTK GUI. No multi-threading (yet?), but should be functional.
"""
function psil_gui()
    # read config
    config = check_config()

    # start window
    win = GtkWindow("Process Speech Impediments Live", 300, 300)
    set_gtk_property!(win, :title, "Process Speech Impediments Live")
    
    # horizontal box array
    hbox = GtkButtonBox(:v)
    push!(win, hbox)

    # top text
    welcome = GtkLabel("Welcome to PSIL!")
    push!(hbox, welcome)

    # dropdown menu
    cb = GtkComboBoxText()

    # add the list of modes to the dropdown menu
    modes = readdir("modes")

    for choice in modes
        push!(cb, choice)
    end

    # set default mode
    if isnothing(config)
        chosen_mode = "lisp"
    else
        chosen_mode = config.mode
    end

    include("modes/$chosen_mode/calibrate.jl") 
    include("modes/$chosen_mode/analyze.jl")

    set_gtk_property!(cb, :active, findfirst(isequal(chosen_mode), modes) - 1)

    push!(hbox, cb)
   
    # change mode on dropdown menu change
    signal_connect(cb, "changed") do widget, others...
        idx = get_gtk_property(cb, "active", Int)
        chosen_mode = Gtk.bytestring(GAccessor.active_text(cb))
        include("modes/$chosen_mode/calibrate.jl") 
        include("modes/$chosen_mode/analyze.jl")
    end

    # calibration function for signal_connect
    function _run_calibrate(w::GtkButtonLeaf)
        run_calibrate(chosen_mode, info_dialog)
        config = check_config()
    end

    # analysis function for signal_connect
    function _loop_analyze(w::GtkButtonLeaf)
        loop_analyze(analyze, segment_length, config.fs, config.args...)
    end

    calibutt = GtkButton("Calibrate")
    analbutt = GtkButton("Start Analyzing")

    push!(hbox, calibutt)
    push!(hbox, analbutt)
 
    signal_connect(_run_calibrate, calibutt, "clicked")
    signal_connect(_loop_analyze, analbutt, "clicked")

    # empty bottom via text label
    endlabel = GtkLabel("")
    push!(hbox, endlabel)

    showall(win)

    # make sure we can actually run this outside the REPL
    if !isinteractive()
        c = Condition()
        signal_connect(win, :destroy) do widget
            notify(c)
        end
        @async Gtk.gtk_main()
        wait(c)
    end
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

    if pargs["gui"]
        println("Starting GUI...")
        psil_gui()
        return
    end

    psil_cli()
end

initialize()
