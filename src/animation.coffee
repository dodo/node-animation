{ EventEmitter } = require 'events'
{requestAnimationFrame,cancelAnimationFrame} = require 'request-animation-frame'
ms = require 'ms'

now = -> new Date().getTime()

requestAnimationFrame = do ->
    orig = requestAnimationFrame
    return (callback, timeout) ->
        if orig.isNative
            orig(callback)
        else
            orig(callback, timeout)


class @Animation extends EventEmitter

    constructor: (opts = {}) ->
        # options
        @executiontime = ms(opts.execution ? 5)
        @timeouttime =  opts.timeout
        @timeouttime = ms(@timeouttime) if @timeouttime?
        @autotoggle = opts.toggle ? no
        @frametime = opts.frame
        @frametime = ms(@frametime) if @frametime?
        # values
        @queue = []
        # states
        @running = no
        @paused = no
        super

    work_queue: (started, dt) ->
        t = now()
        while @queue.length and t - started < @executiontime
            (@queue.shift())?() # execute
            t = now()

    push: (callback) ->
        @queue.push(callback)
        @resume() if @running and @autotoggle and @paused

    nextTick: (callback) =>
        [timeout, request] = [null, null]
        t = now()
        tick = (success) ->
            # calc delta time
            started = now()
            dt = started - t
            # break other timeout
            if success
                clearTimeout(timeout)
            else # skip the requested AnimationFrame when it gets called
                cancelAnimationFrame(request)
            # work
            @emit('tick', dt)
            callback?(dt)
            @work_queue(started, dt)
            # if animation is running and not paused, keep it running
            #  or pause it if autotoggle is enabled
            if @running and not @paused
                if @queue.length
                    @nextTick()
                else # decide if animation can pause
                    if @autotoggle
                        @pause()
                    else # keep running
                        @nextTick()
        frame = =>
            # calc delta time
            started = now()
            dt = started - t
            # when a frametime is specified and requestAnimationFrame
            #  is faster, throttle it until we nealry hit the frametime
            if @frametime? and dt < @frametime * 0.8 # hope that's alright
                request = requestAnimationFrame(frame, @frametime)
            else
                tick.call(this, true)
        # send the request
        request = requestAnimationFrame(frame, @frametime)
        if @timeoutime?
            timeout = setTimeout(tick.bind(this, no), @timeouttime)

    # switches

    start: () ->
        return if @running
        @running = yes
        @emit 'start'
        @nextTick() unless @paused or @autotoggle

    stop: () ->
        return unless @running
        @running = no
        @emit 'stop'

    pause: () ->
        return if @paused
        @paused = yes
        @emit 'pause'

    resume: () ->
        return unless @paused
        @paused = no
        @emit 'resume'
        @nextTick() if @running and (not @autotoggle or @queue.length is 1)

