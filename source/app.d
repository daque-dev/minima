int main()
{
    import std.stdio;
    import graph = minima.graphics;
    import physics = minima.physics.query;
    import time = minima.timeutils;
    import sdl = derelict.sdl2.sdl;
    bool alive = true;
    physics.BoxId playerBox;
    bool[sdl.SDL_Keycode] keyState;

    void initGraphics()
    {
        auto windowTitle = "minima";
        auto windowWidth = 400;
        auto windowHeight = 400;
        graph.init(windowTitle, windowWidth, windowHeight);
        graph.setBackgroundColor(graph.Color(cast(byte) 100, cast(byte) 200, cast(byte) 255));
        graph.setCameraSize([20, 20]);
        graph.setCameraCenter([0, 0]);
        graph.setCameraObjective(() => physics.queryBox(playerBox).center);
    }

    void initPhysics()
    {
        physics.init;
        playerBox = physics.newBox([50, 70], [1.5, 2]);
    }

    void handleKeyboardEvent(sdl.SDL_KeyboardEvent keyboardEvent)
    {
        auto keySym = keyboardEvent.keysym;
        auto keyCode = keySym.sym;
        keyState[keyCode] = keyboardEvent.state == sdl.SDL_PRESSED;
        switch (keyCode)
        {
        case sdl.SDLK_w:
            if (!keyboardEvent.repeat && keyboardEvent.state == sdl.SDL_PRESSED
                    && physics.onGround(playerBox))
                physics.applyForce(playerBox, new physics.SimpleForceApplier([
                            0.0f, 500.0f
                        ]));
            break;
        default:
            break;
        }

    }

    void handleMouseButtonEvent(sdl.SDL_MouseButtonEvent mouseButtonEvent)
    {
        auto worldClickCoordinates = graph.toWorldCoordinates([
                mouseButtonEvent.x, mouseButtonEvent.y
                ]);
        if (mouseButtonEvent.state == sdl.SDL_PRESSED)
        {
            import tile = minima.tile;
            import pd = minima.physics.data;

            tile.TileName* tileName = pd.getTile(cast(int) worldClickCoordinates[0],
                    cast(int) worldClickCoordinates[1]);
            if (tileName !is null)
            {
                *tileName = mouseButtonEvent.button == sdl.SDL_BUTTON_LEFT
                    ? tile.TileName.bricks : tile.TileName.empty;
            }
        }
    }

    void handleEvent(sdl.SDL_Event event)
    {
        switch (event.type)
        {
        case sdl.SDL_QUIT:
            alive = false;
            break;
        case sdl.SDL_KEYDOWN:
        case sdl.SDL_KEYUP:
            handleKeyboardEvent(event.key);
            break;
        case sdl.SDL_MOUSEBUTTONDOWN:
        case sdl.SDL_MOUSEBUTTONUP:
            handleMouseButtonEvent(event.button);
            break;
        default:
            break;
        }
    }

    bool keyDown(typeof(sdl.SDLK_a) key)
    {
        return key in keyState && keyState[key];
    }

    import minima.util;

    physics.SimpleForceApplier[typeof(sdl.SDLK_a)] forceByKey;
    forceByKey[sdl.SDLK_a] = new physics.SimpleForceApplier([-12, 0]);
    forceByKey[sdl.SDLK_d] = new physics.SimpleForceApplier([+12, 0]);
    void mainLoop()
    {
        void physicsUpdate()
        {
            auto forceApplier = cast(physics.SimpleForceApplier) null;
            physics.setFriction(playerBox, 1.0);
            foreach (key, force; forceByKey)
                if (keyDown(key))
                {
                    forceApplier = force;
                    physics.setFriction(playerBox, 0.0);
                }
            if (forceApplier !is null)
                physics.applyForce(playerBox, forceApplier);
            physics.update(1.0 / 60.0);
        }

        void graphicsUpdate()
        {
            graph.updateCamera;
            graph.clearScreen;
            graph.renderWorld;
            graph.presentScreen;
        }

        void eventProcessing()
        {
            sdl.SDL_Event event;
            while (sdl.SDL_PollEvent(&event))
                handleEvent(event);
        }

        import std.datetime.stopwatch;

        auto sw = StopWatch(AutoStart.no);
        sw.start();
        long mdt = 1000 / 60;
        while (alive)
        {
            sw.reset;
            physicsUpdate;
            graphicsUpdate;
            eventProcessing;
            long remaining = mdt - sw.peek.total!"msecs";
            import std.stdio;
            import minima.timeutils;

            delay(remaining);
        }
    }

    initGraphics;
    initPhysics;
    mainLoop;

    return 0;
}
