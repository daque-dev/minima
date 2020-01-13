module minima.graphics;

import minima.util;

import std.exception;
import std.string;
import std.conv;
import derelict.sdl2.sdl;

public struct Color
{
  byte red, green, blue, alpha;
  this(byte red, byte green, byte blue, byte alpha = cast(byte) 255)
  {
    this.red = red;
    this.green = green;
    this.blue = blue;
    this.alpha = alpha;
  }
}

private struct Camera
{
    float[2] center;
    float[2] halfSize;
    float[2] upperLeftCorner()
    {
        return mixin(q{center[$] + [-1.0, 1.0][$] * halfSize[$]}.makeArray(2));
    }
}

private struct Texture
{
    this(string fileName, int border)
    {
        import std.conv;
        import std.string;
        import derelict.sdl2.image;

        auto surface = IMG_Load(fileName.toStringz);
        enforce(surface, "couldn't load image file: ", fileName);
        enforce(border >= 0);

        this.texture = SDL_CreateTextureFromSurface(_renderer, surface);
        enforce(this.texture, "couldn't create texture from surface");
        this.border = border;
    }

    SDL_Texture* texture;
    int border;
}

private Camera _camera;
private float[2]delegate() _followedByCamera;
private SDL_Window* _window;
private SDL_Renderer* _renderer;
private Color _backgroundColor;
private float[2] _windowSize;
import tile = minima.tile;

private Texture[tile.TileName] _textureForTile;
private Texture _playerTexture;

public void setCameraObjective(float[2]delegate() obj)
{
    _followedByCamera = obj;
}

public void renderWorld()
{
    import world = minima.physics.query;
    import tile = minima.tile;

    import std.math : floor, ceil;
    import std.range : iota;
    import std.algorithm.setops : cartesianProduct;
    import std.algorithm : each, map;
    import std.typecons : Tuple;

    void renderTile(Tuple!(int, int) tilePos)
    {
        auto x = tilePos[0];
        auto y = tilePos[1];
        static import minima.physics.data;

        auto tileName = minima.physics.data.getTile(x, y);
        if (tileName is null)
        {
            renderRectangle([x, y], [1, 1], Color(cast(byte) 0, cast(byte) 0, cast(byte) 0));
            return;
        }
	auto texture = *tileName in _textureForTile;
	if (texture)
	    renderTexture([x, y], [1, 1], *texture);
    }

    auto lowCorner = mixin(q{cast(int) floor(_camera.center[$] - _camera.halfSize[$])}.makeArray(2));
    auto highCorner = mixin(q{cast(int) ceil(_camera.center[$] + _camera.halfSize[$])}.makeArray(2));
    cartesianProduct(iota(lowCorner[0], highCorner[0]), iota(lowCorner[1], highCorner[1]))
        .each!renderTile;

    world.foreachBox((world.BoxGeometry boxGeometry) {
        float[2] lowCorner = mixin(q{boxGeometry.center[$] - boxGeometry.halfSize[$]}.makeArray(2));
        float[2] size = mixin(q{boxGeometry.halfSize[$] * 2.0}.makeArray(2));
        renderTexture(lowCorner, size, _playerTexture);
    });
}

public void renderRectangle(float[2] lowCorner, float[2] size, Color color)
{
    import std.math;

    auto windowLow = lowCorner.toWindow;
    float[2] highCorner = mixin(q{lowCorner[$] + size[$]}.makeArray(2));
    auto windowHigh = highCorner.toWindow;
    int[2] windowSize = mixin(q{abs(windowHigh[$] - windowLow[$])}.makeArray(2));
    SDL_Rect rect;
    with (rect)
    {
        x = windowLow[0];
        y = windowHigh[1];
        w = windowSize[0];
        h = windowSize[1];
    }
    SDL_SetRenderDrawColor(_renderer, color.red, color.green, color.blue, 255);
    SDL_RenderFillRect(_renderer, &rect);
}

public void renderTexture(float[2] lowCorner, float[2] size, SDL_Texture* texture)
{
    import std.math;

    auto windowLow = lowCorner.toWindow;
    float[2] highCorner = mixin(q{lowCorner[$] + size[$]}.makeArray(2));
    auto windowHigh = highCorner.toWindow;
    int[2] windowSize = mixin(q{abs(windowHigh[$] - windowLow[$])}.makeArray(2));
    SDL_Rect rect;
    with (rect)
    {
        x = windowLow[0];
        y = windowHigh[1];
        w = windowSize[0];
        h = windowSize[1];
    }

    SDL_RenderCopy(_renderer, texture, null, &rect);
}

public void renderTexture(float[2] lowCorner, float[2] size, Texture texture)
{
    import std.math;
    import minima.util;

    int[2] textureSize;
    SDL_QueryTexture(texture.texture, null, null, &textureSize[0], &textureSize[1]);
    textureSize = mixin(q{textureSize[$] - 2 * texture.border}.makeArray(2));
    float[2] sizePerPixel = mixin(q{size[$] / cast(float)textureSize[$]}.makeArray(2));
    float[2] newLowCorner = mixin(q{lowCorner[$] - texture.border * sizePerPixel[$]}.makeArray(2));
    float[2] newSize = mixin(q{size[$] + 2 * texture.border * sizePerPixel[$]}.makeArray(2));
    renderTexture(newLowCorner, newSize, texture.texture);
}

public void updateCamera()
{
    auto objective = _followedByCamera();
    immutable factor = 0.1;
    _camera.center = mixin(
            q{_camera.center[$] + factor * (objective[$] - _camera.center[$])}.makeArray(2));
}

public void setCameraSize(float[2] cameraSize)
{
    _camera.halfSize[] = cameraSize[] / 2.0;
}

public void setCameraCenter(float[2] cameraCenter)
{
    _camera.center[] = cameraCenter[];
}

private int[2] toWindow(float[2] w)
{
    float[2] ul = _camera.upperLeftCorner;
    w[] -= ul[];
    w[] /= 2 * _camera.halfSize[];
    w[] *= _windowSize[];
    w[1] *= -1;
    return [cast(int) w[0], cast(int) w[1]];
}

public float[2] toWorldCoordinates(int[2] windowCoordinates)
{
    windowCoordinates[1] = -windowCoordinates[1];
    auto cameraUpperLeft = _camera.upperLeftCorner;
    return mixin(
            q{cast(float) windowCoordinates[$] * 2.0 * _camera.halfSize[$] / _windowSize[$] + cameraUpperLeft[$]}.makeArray(
            2));
}

public void init(string windowTitle, uint windowWidth, uint windowHeight)
{
    void initializeSdl2()
    {
        DerelictSDL2.load();
        bool sdlInitSuccess = SDL_Init(SDL_INIT_EVERYTHING) == 0;
        enforce(sdlInitSuccess, text("couldn't initialize sdl2, SDL2 says: ",
                fromStringz(SDL_GetError())));
        import derelict.sdl2.image;

        DerelictSDL2Image.load();
        bool imgInitSuccess = IMG_Init(IMG_INIT_PNG) >= 0;
        enforce(imgInitSuccess, text("couldn't initialize sdl2image, SLD2Image says: "));
    }

    void initializeWindowSize()
    {
        _windowSize[] = [windowWidth, windowHeight];
    }

    void initializeWindow()
    {
        alias sdlWindowPosCentered = SDL_WINDOWPOS_CENTERED;
        alias sdlWindowShown = SDL_WINDOW_SHOWN;
        auto positionX = sdlWindowPosCentered;
        auto positionY = sdlWindowPosCentered;
        auto flags = sdlWindowShown;
        _window = SDL_CreateWindow(windowTitle.toStringz, sdlWindowPosCentered,
                sdlWindowPosCentered, windowWidth, windowHeight, flags);
        enforce(_window != null, text("couldn't initialize window, SDL2 says: ",
                fromStringz(SDL_GetError())));
    }

    void initializeRenderer()
    {
        alias sdlRendererAccelerated = SDL_RENDERER_ACCELERATED;
        auto index = -1;
        auto flags = sdlRendererAccelerated;
        _renderer = SDL_CreateRenderer(_window, index, flags);
        enforce(_renderer != null, text("couldn't initialize renderer, SDL2 says: ",
                fromStringz(SDL_GetError())));
    }

    void initBackgroundColor()
    {
        _backgroundColor = Color(0, 0, 0);
    }

    void initTextures()
    {
        import tile = minima.tile;

        _textureForTile[tile.TileName.dirt] = Texture("rdirt.png", 4);
	_textureForTile[tile.TileName.bricks] = Texture("bricks.png", 4);
        _playerTexture = Texture("dude.png", 4);
    }

    initializeSdl2;
    initializeWindowSize;
    initializeWindow;
    initializeRenderer;
    initTextures;
}

void setBackgroundColor(Color backgroundColor)
{
    _backgroundColor = backgroundColor;
}

void clearScreen()
{
    with (_backgroundColor)
        SDL_SetRenderDrawColor(_renderer, red, green, blue, 255);
    SDL_RenderClear(_renderer);
}

void presentScreen()
{
    SDL_RenderPresent(_renderer);
}
