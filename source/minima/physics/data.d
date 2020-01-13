module minima.physics.data;

public
{
    alias BoxId = size_t;
    interface ForceApplier
    {
        float[2] apply(BoxId boxId, float timeChange);
    }

    public TileName* getTile(int x, int y)
    {
        with (_tileMap)
        {
            if (x >= 0 && x < width && y >= 0 && y < height)
                return &data[x][y];
            return null;
        }
    }
}

package(minima.physics)
{
    // maximum width acceptable for tilemaps in number of tiles.
    const maxTileMapWidth = 1000;
    // maximum height acceptable for tilemaps in number of tiles.
    const maxTileMapHeight = 1000;
    struct TileMap
    {
        // 2d array of tile names.
        TileName[maxTileMapWidth][maxTileMapHeight] data;
        // dimensions of tilemap in number of tiles.
        uint width, height;
    }

    TileMap _tileMap;
    struct Box
    {
        this(float[2] center, float[2] halfSize, BoxId id, float friction)
        {
            import std.container;

            this._center = center;
            this._halfSize = halfSize;
            this._velocity = 0;
            this._appliedForces = SList!ForceApplier();
            this._id = id;
        }

        public float[2] center()
        {
            return _center;
        }

        public float[2] halfSize()
        {
            return _halfSize;
        }

        public float[2] velocity()
        {
            return _velocity;
        }

        public float friction()
        {
            return _friction;
        }

        public BoxId id()
        {
            return _id;
        }

        public void setFriction(float newFriction)
        {
            _friction = newFriction;
        }

        private float[2] _center = void;
        private float[2] _halfSize = void;
        private float[2] _velocity = void;
        private float _friction = 1.0;
        private BoxId _id = -1;

        import std.container : SList;

        SList!ForceApplier _appliedForces;
        void addForceApplier(ForceApplier forceApplier)
        {
            _appliedForces.insertFront(forceApplier);
        }

        void applyForces(float timeChange)
        {
            while (!_appliedForces.empty)
            {
                _velocity = _appliedForces.front.apply(id, timeChange);
                _appliedForces.removeFront;
            }
        }

        void move(float timeChange)
        {
            static foreach (axis; 0 .. 2)
                moveInAxis(axis, timeChange);
        }

        void moveInAxis(int axis, float timeChange)
        in
        {
            assert(!collides(this));
        }
        out
        {
            assert(!collides(this));
        }
        do
        {
            float amount = _velocity[axis] * timeChange;
            if (amount == 0)
                return;

            import std.math;
            import minima.util;
            import std.algorithm;

            auto direction = cast(int) sgn(amount);
            float[] centerRange = [_center[axis], _center[axis] + amount];
            sort(centerRange);

            // try simple move
            _center[axis] += amount;
            if (!collides(this))
                return;
            _center[axis] -= amount;

            // if not possible...
            _velocity[axis] = 0;
            // snap corner
            auto corner = _center[axis] + direction * _halfSize[axis];
            corner += direction * pfmod(-direction * corner, 1.0);
            _center[axis] = corner - direction * _halfSize[axis];
            // while on range continue stepping
            while (_center[axis] >= centerRange[0]
                    && _center[axis] <= centerRange[1] && !collides(this))
                _center[axis] += direction;

            if (collides(this))
                _center[axis] -= direction;
        }
    }

    const maxNumberOfBoxes = 1000;
    Box[maxNumberOfBoxes] _boxPool;
    Box[] _currentBoxes;

    import minima.tile;

    void initTileMap(uint width, uint height, TileName fill)
    {
        _tileMap.width = width;
        _tileMap.height = height;
        for (uint x = 0; x < width; x++)
            for (uint y = 0; y < height; y++)
                _tileMap.data[x][y] = fill;
    }

    bool isSolid(int x, int y)
    {
        import tile = minima.tile;

        auto tileName = getTile(x, y);
        if (tileName is null)
            return true;
        return tile.getData(*tileName).isSolid;
    }

    import std.typecons;

    bool isSolid(Tuple!(int, int) p)
    {
        return isSolid(p[0], p[1]);
    }

    bool collides(ref Box box)
    {
        import std.math;
        import std.range;
        import std.algorithm.setops;
        import std.algorithm;
        import minima.util;

        int[2] lowerIndex = mixin(q{cast(int) floor(box.center[$] - box.halfSize[$])}.makeArray(2));
        int[2] higherIndex = mixin(q{cast(int) ceil(box.center[$] + box.halfSize[$])}.makeArray(2));
        auto boxRange = cartesianProduct(iota(lowerIndex[0], higherIndex[0]),
                iota(lowerIndex[1], higherIndex[1]));
        return boxRange.any!isSolid;
    }

}
