module minima.tile;

enum TileName
{
    empty,
    dirt,
    bricks,
}

struct TileData
{
    bool isSolid;
}

private TileData[TileName] _tileDataMapping;

static this()
{
    _tileDataMapping = [
        TileName.empty: TileData(false),
        TileName.dirt: TileData(true),
	TileName.bricks: TileData(true),
    ];
}

TileData getData(TileName tileName)
{
    return _tileDataMapping[tileName];
}

