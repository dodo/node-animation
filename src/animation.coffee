{ EventEmitter } = require 'events'
{requestAnimationFrame,cancelAnimationFrame} = require 'request-animation-frame'
ms = require 'ms'

now = Date.now ? -> new Date().getTime()


# FIXME larger executiontime for timeouts?


class @Animation extends EventEmitter

    constructor: (opts = {}) ->
        # options
        @timoutexecutiontime = ms(opts.timeoutexecution ? '32ms') # 2 missed frames
        @executiontime = ms(opts.execution ? '8ms') # half of 16ms (60 FPS)
        @timeouttime = opts.timeout
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

    need_next_tick: () ->
        @running and not @paused and (@queue.length or not @autotoggle)

    work_queue: (started, dt, executiontime) ->
        t = now()
        while @queue.length and t - started < executiontime
            (@queue.shift())?(dt) # execute
            t = now()

    push: (callback) ->
        @queue.push(callback)
        @resume() if @running and @autotoggle

    nextTick: (callback) =>
        [timeout, request] = [null, null]
        t = now()
        tick = (success) ->
            if requestAnimationFrame.isNative
                # request next tick immediately
                if do @need_next_tick
                    # if animation is running and not paused, keep it running
                    # or pause it if autotoggle is enabled and no jobs left in queue
                    nextid = @nextTick()
            # calc delta time
            started = now()
            dt = started - t
            executiontime = if success
                    @executiontime
                else
                    @timoutexecutiontime
            # break other timeout
            if success
                clearTimeout(timeout)
            else # skip the requested AnimationFrame when it gets called
                cancelAnimationFrame(request)
            # work
            @emit('tick', dt)
            callback?(dt)
            @work_queue(started, dt, executiontime)
            unless nextid?
                if do @need_next_tick
                    nextid = @nextTick()
                # else no need to check stuff when no next tick was requested
                # or we already checked the current state
                return
            # cancel requested next tick if animation stopped, paused
            # or ran out of jobs (when autotoggle is enabled)
            unless do @need_next_tick
                clearTimeout(nextid.timeout) if @timeouttime?
                cancelAnimationFrame(nextid)
                @pause()
            return
        # send the request
        request = requestAnimationFrame(tick.bind(this, yes), @frametime)
        if @timeouttime?
            timeout = setTimeout(tick.bind(this, no), @timeouttime)
            request.timeout = timeout
        return request

    # switches

    start: () ->
        return if @running
        @running = yes
        @emit 'start'
        if not @paused and @autotoggle and not @queue.length
            @pause()
        else
            @nextTick()

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

