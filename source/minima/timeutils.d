module minima.timeutils;

import derelict.sdl2.sdl;

public void delay(long msecs)
{
    SDL_Delay(cast(uint) msecs);
}
