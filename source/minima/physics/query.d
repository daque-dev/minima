module minima.physics.query;

public import minima.physics.data;

class SimpleForceApplier : ForceApplier
{
    this(float[2] magnitude)
    {
        this.magnitude = magnitude;
    }

    float[2] magnitude;

    float[2] apply(BoxId boxId, float timeChange)
    {
        auto velocity = _currentBoxes[boxId].velocity;
        import minima.util;

        return mixin(q{velocity[$] + timeChange * magnitude[$]}.makeArray(2));
    }
}

class FrictionApplier : ForceApplier
{
    float coefficient;
    this(float coefficient)
    {
        this.coefficient = coefficient;
    }

    float[2] apply(BoxId boxId, float timeChange)
    {
        Box* box = &_currentBoxes[boxId];
        auto velocity = box.velocity;
        import std.math : sgn;

        auto sign = sgn(velocity[0]);
        auto force = -coefficient * box.friction * sign;
        velocity[0] += force * timeChange;
        if (sgn(velocity[0]) * sign < 0)
            velocity[0] = 0;
        return velocity;
    }

}

auto queryBox(BoxId boxId)
{
    struct BoxQueryInformation
    {
        float[2] center, halfSize, velocity;
    }

    auto box = _currentBoxes[boxId];
    return BoxQueryInformation(box.center, box.halfSize, box.velocity);
}

immutable float[2] gravity = [0, -10];

public void update(float timeChange)
{
    void move(ref Box box, float timeChange)
    in
    {
        assert(!collides(box));
    }
    out
    {
        assert(!collides(box));
    }
    do
    {
        static foreach (axis; 0 .. 2)
            box.moveInAxis(axis, timeChange);
    }

    import minima.util;

    foreach (i, ref box; _currentBoxes)
    {
        box.addForceApplier(new SimpleForceApplier(gravity));
        if (onGround(i))
            box.addForceApplier(new FrictionApplier(20));
        box.applyForces(timeChange);
        move(box, timeChange);
    }
}

public void applyForce(BoxId boxId, ForceApplier forceApplier)
{
    _currentBoxes[boxId].addForceApplier(forceApplier);
}

public BoxId newBox(float[2] lowCorner, float[2] size)
{
    auto box = Box([lowCorner[0] + size[0] * 0.5, lowCorner[1] + size[1] * 0.5],
            [size[0] * 0.5, size[1] * 0.5], _currentBoxes.length, 1.0);
    _currentBoxes = _boxPool[0 .. _currentBoxes.length + 1];
    _currentBoxes[$ - 1] = box;
    return _currentBoxes.length - 1;
}

public void setFriction(BoxId boxId, float friction)
{
    _currentBoxes[boxId].setFriction(friction);
}

public bool onGround(BoxId boxId)
{
    import std.math;
    import std.range;
    import std.algorithm;

    auto box = _currentBoxes[boxId];
    int y = cast(int) ceil(box.center[1] - box.halfSize[1]) - 1;
    auto xRange = iota(cast(int) floor(box.center[0] - box.halfSize[0]),
            cast(int) ceil(box.center[0] + box.halfSize[0]));
    return xRange.any!(x => isSolid(x, y));
}

struct BoxGeometry
{
    float[2] center, halfSize;
}

public void foreachBox(void delegate(BoxGeometry) dg)
{
    foreach (box; _currentBoxes)
    {
        auto boxGeometry = BoxGeometry(box.center, box.halfSize);
        dg(boxGeometry);
    }
}

public int[2] tileMapSize()
{
    return [_tileMap.width, _tileMap.height];
}

public void init()
{
    _currentBoxes = _boxPool[0 .. 0];
    initTileMap(100, 100, TileName.empty);
    import derelict.sdl2.sdl;
    import derelict.sdl2.image;

    auto image = IMG_Load("map.png");
    ubyte* ptr = cast(ubyte*) image.pixels;
    for (int i = 0; i < image.h; i++)
    {
        for (int j = 0; j < image.w; j++)
        {
            if (ptr[3 * j + i * image.pitch] == 0)
                *getTile(j, image.h - i - 1) = TileName.dirt;
            else
                *getTile(j, image.h - i - 1) = TileName.empty;
        }
    }

}
