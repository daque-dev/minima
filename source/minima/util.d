module minima.util;

T pmod(T)(T a, T m)
{
    return (a % m + m) % m;
}

T pfmod(T)(T a, T m)
{
    import std.math;

    a = fmod(a, m);
    if (a < 0)
        return a + m;
    return a;
}

deprecated string makeArray(int n, string dg)()
{
    import std.array;
    import std.conv;

    string literal = "[";
    static foreach (i; 0 .. n)
        literal ~= dg.replace("$", to!string(i)) ~ ", ";
    literal ~= "]";
    return literal;
}

string makeArray(string dg, int n)
{
    import std.array;
    import std.conv;

    string literal = "[";
    foreach (i; 0 .. n)
        literal ~= dg.replace("$", to!string(i)) ~ ", ";
    literal ~= "]";
    return literal;
}
