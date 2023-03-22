using Configurations, PortAudio, SampledSignals
using ArgParse
using Gtk
using PyCall


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
        "--segment-length"
        help = "Change segment length. Mainly for debugging."
        required = false
        arg_type = Number
        default = 0
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


function loadmode(modepath)
    fnames = readdir(modepath)
    if any(endswith.(".py", fnames))
        py"""
        import sys
        sys.path.insert(0, ".$modepath")
        """
        pyfunc = pyimport("module.py")
        global analyze = pyfunc["analyze"]
        global calibrate = pyfunc["calibrate"]
        global default_segment_length = pyfunc["default_segment_length "]
        global analysis_values = pyfunc["analysis_values"]
    else
        include(modepath * "/analyze.jl")
        include(modepath * "/calibrate.jl")
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


# global variable to indicate whether to keep analyzing
# Ref{Bool} tells Julia we want a constant type
# this way performance isn't impacted (although it still isn't ideal)
global keeprunning = Ref{Bool}(true)

"""
Infinite loop running the analysis function.
"""
function loop_analyze(func::Function, N, fs, max_iterations::Int, notification_message::String, args...)
    # mono mic stream
    stream = PortAudioStream(1, 0, samplerate=fs)
    buf = read(stream, N)
    # gotta do this once outside of the infinite loop apparently
    counter = Base.invokelatest(func, buf, fs, args...)
    i = 1

    # access keeprunning global variable 
    global keeprunning
    # there's no real alternative to forcing an infinite loop here
    while keeprunning[]
        read!(stream, buf)
        counter += Base.invokelatest(func, buf, fs, args...)
        println(counter)
        println(i)
        i += 1
        if i == max_iterations
            if counter > 0
                alert(notification_message)
            end
            i = counter = 0
        end
    end
end


"""
PSIL CLI function; wrapper around everything else with printed instructions for user.
"""
function psil_cli(segment_length::Number)
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

    if segment_length == 0
        segment_length = Base.invokelatest(default_segment_length)
    end

    max_iterations, notification_message = Base.invokelatest(analysis_values)

    println("Proceeding to analysis. You will be notified whenever a speech impedement issue occurs. To exit, press CTRL+C.")
    loop_analyze(analyze, segment_length, config.fs, max_iterations, notification_message, config.args...)
end


"""
Simple GTK GUI. No multi-threading (yet?), but should be functional.
"""
function psil_gui(segment_length::Number)
    # make sure we only ever reference the global keeprunning
    global keeprunning

    # read config
    config = check_config()

    # start window
    win = GtkWindow("Process Speech Impediments Live", 400, 400)
    set_gtk_property!(win, :title, "Process Speech Impediments Live")
    
    # horizontal box array
    hbox = GtkButtonBox(:v)
    push!(win, hbox)

    # top text
    welcome = GtkLabel("\nWelcome to PSIL!")
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

    # set default segment length
    if segment_length == 0
        # need to grab the val as we have to × 1 s later to support the entry box
        segment_length = Base.invokelatest(default_segment_length).val
    end

    # segment length needs a an entry box but this needs a label box too
    sl_bbox = GtkBox(:h)

    push!(sl_bbox, GtkLabel("Segment length: "))

    # entry box for user to edit the segment length
    sl_box = GtkEntry()
    set_gtk_property!(sl_box, :text, string(round(segment_length, digits=3)))
    
    push!(sl_bbox, sl_box)

    set_gtk_property!(sl_bbox, :spacing, 2)

    push!(sl_bbox, GtkLabel("seconds"))
    
    push!(hbox, sl_bbox)
   
    # change mode on dropdown menu change
    signal_connect(cb, "changed") do widget, others...
        idx = get_gtk_property(cb, "active", Int)
        chosen_mode = Gtk.bytestring(GAccessor.active_text(cb))
        include("modes/$chosen_mode/calibrate.jl") 
        include("modes/$chosen_mode/analyze.jl")
        # change the segment length entry box's entry
        set_gtk_property!(sl_box, :text, string(round(Base.invokelatest(default_segment_length).val, digits=3)))
    end

    spinner = GtkSpinner()

    # calibration function for signal_connect
    function _run_calibrate(w::GtkButtonLeaf)
        run_calibrate(chosen_mode, info_dialog)
        config = check_config()
    end

    # analysis function for signal_connect
    function _loop_analyze(w::GtkButtonLeaf)
        max_iterations, notification_message = Base.invokelatest(analysis_values)
        # this has to use the segment length from its entry box
        loop_analyze(analyze, Base.parse(Float64, get_gtk_property(sl_box, :text, String)) * 1s, config.fs, max_iterations, notification_message, config.args...)
    end

    analbox = GtkBox(:h)

    calibutt = GtkButton("Calibrate")
    analbutt = GtkButton("Start Analyzing")

    push!(analbox, analbutt)
    push!(analbox, spinner)

    push!(hbox, calibutt)
    push!(hbox, analbox)
 
    signal_connect(_run_calibrate, calibutt, "clicked")

    function _start_running(w::GtkButtonLeaf)
        set_gtk_property!(analbutt, :label, "Stop Analyzing")
        signal_connect(_stop_running, analbutt, "clicked")
        start(spinner)
        keeprunning[] = true
        Threads.@spawn begin
            _loop_analyze(analbutt)
            Gtk.GLib.g_idle_add(nothing) do user_data
                stop(spinner)
                Cint(false)
            end
        end
    end

    signal_connect(_start_running, analbutt, "clicked")

    function _stop_running(w::GtkButtonLeaf)
        keeprunning[] = false
        set_gtk_property!(analbutt, :label, "Start Analyzing")
        signal_connect(_start_running, analbutt, "clicked")
    end

    # empty bottom via text label
    push!(hbox, GtkLabel(""))

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
        psil_gui(pargs["segment-length"])
        return
    end

    psil_cli(pargs["segment-length"])
end

initialize()
