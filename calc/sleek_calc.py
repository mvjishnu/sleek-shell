#!/usr/bin/env python3
"""Sleek Shell calculator & unit converter engine (stdlib only).

User input is never passed to eval/exec/compile or a shell: it is tokenized
and parsed by a hand-written recursive-descent parser into values that are
evaluated directly.
"""

import json
import math
import os
import re
import subprocess
import sys
import tempfile
import time
from decimal import (Context, Decimal, DivisionByZero, InvalidOperation,
                     Overflow, ROUND_CEILING, ROUND_FLOOR, ROUND_HALF_UP,
                     localcontext)
from fractions import Fraction

APP_NAME = "Sleek Shell"
MAX_INPUT = 512
MAX_DEPTH = 60
MAX_FACT = 1000
MAX_EXP10 = 100000
FRACTION_BITS = 40000
HISTORY_MAX = 50
DEFAULT_PRECISION = 12
DEFAULT_MODE = "deg"

CTX = Context(prec=50, Emax=4 * MAX_EXP10, Emin=-4 * MAX_EXP10,
              rounding=ROUND_HALF_UP,
              traps=[InvalidOperation, DivisionByZero, Overflow])

PI = Decimal("3.14159265358979323846264338327950288419716939937510582097494")
E = Decimal("2.71828182845904523536028747135266249775724709369995957496697")
PHI = Decimal("1.61803398874989484820458683436563811772030917980576286213544")


class CalcError(Exception):
    pass


# ---------------------------------------------------------------- numbers

def to_dec(v):
    if isinstance(v, Fraction):
        try:
            return CTX.divide(Decimal(v.numerator), Decimal(v.denominator))
        except (Overflow, InvalidOperation):
            raise CalcError("Result too large")
    if isinstance(v, int):
        return Decimal(v)
    return v


def is_int(v):
    if isinstance(v, Fraction):
        return v.denominator == 1
    return v.is_finite() and v == v.to_integral_value()


def to_frac_int(v):
    if isinstance(v, Fraction):
        return v.numerator
    return int(v)


def to_float(v):
    try:
        f = float(v)
    except OverflowError:
        raise CalcError("Number too large for this function")
    if math.isinf(f):
        raise CalcError("Number too large for this function")
    return f


def from_float(f):
    if math.isnan(f):
        raise CalcError("Math domain error")
    if math.isinf(f):
        raise CalcError("Result too large")
    return Decimal(repr(f))


def norm(v):
    if isinstance(v, Fraction):
        if (v.numerator.bit_length() > FRACTION_BITS
                or v.denominator.bit_length() > FRACTION_BITS):
            return norm(to_dec(v))
        return v
    if not v.is_finite():
        raise CalcError("Result is not a finite number")
    if v != 0:
        a = v.adjusted()
        if a > MAX_EXP10:
            raise CalcError("Result too large")
        if a < -MAX_EXP10:
            return Decimal(0)
    return v


def dec_op(fn, *args):
    try:
        return norm(fn(*args))
    except DivisionByZero:
        raise CalcError("Division by zero")
    except Overflow:
        raise CalcError("Result too large")
    except InvalidOperation:
        raise CalcError("Invalid operation")


def n_add(a, b):
    if isinstance(a, Fraction) and isinstance(b, Fraction):
        return norm(a + b)
    return dec_op(CTX.add, to_dec(a), to_dec(b))


def n_sub(a, b):
    if isinstance(a, Fraction) and isinstance(b, Fraction):
        return norm(a - b)
    return dec_op(CTX.subtract, to_dec(a), to_dec(b))


def n_mul(a, b):
    if isinstance(a, Fraction) and isinstance(b, Fraction):
        return norm(a * b)
    return dec_op(CTX.multiply, to_dec(a), to_dec(b))


def n_div(a, b):
    if b == 0:
        raise CalcError("Division by zero")
    if isinstance(a, Fraction) and isinstance(b, Fraction):
        return norm(a / b)
    return dec_op(CTX.divide, to_dec(a), to_dec(b))


def n_neg(a):
    return -a


def n_cmp(a, b):
    if not (isinstance(a, Fraction) and isinstance(b, Fraction)):
        a, b = to_dec(a), to_dec(b)
    return (a > b) - (a < b)


def n_floor(a):
    if isinstance(a, Fraction):
        return Fraction(math.floor(a))
    return dec_op(lambda x: x.to_integral_value(rounding=ROUND_FLOOR), a)


def n_ceil(a):
    if isinstance(a, Fraction):
        return Fraction(math.ceil(a))
    return dec_op(lambda x: x.to_integral_value(rounding=ROUND_CEILING), a)


def n_mod(a, b):
    if b == 0:
        raise CalcError("Modulo by zero")
    q = n_floor(n_div(a, b))
    return n_sub(a, n_mul(b, q))


def int_root(n, k):
    """Exact integer k-th root of n >= 0, or None."""
    if n < 2:
        return n
    if k == 2:
        r = math.isqrt(n)
        return r if r * r == n else None
    if n.bit_length() > 4000:
        return None
    r = int(round(math.exp(math.log(n) / k))) if n.bit_length() < 1000 else \
        1 << (n.bit_length() // k)
    for _ in range(200):
        nr = ((k - 1) * r + n // r ** (k - 1)) // k
        if nr >= r:
            break
        r = nr
    for c in (r - 1, r, r + 1):
        if c >= 0 and c ** k == n:
            return c
    return None


def exact_root(a, k):
    if not isinstance(a, Fraction) or a < 0 or k < 1 or k > 1000:
        return None
    rn = int_root(a.numerator, k)
    if rn is None:
        return None
    rd = int_root(a.denominator, k)
    if rd is None:
        return None
    return Fraction(rn, rd)


def dec_log10_abs(d):
    with localcontext(Context(prec=30)):
        return abs(d).log10()


def n_pow(a, b):
    if isinstance(a, Fraction) and isinstance(b, Fraction):
        if b.denominator == 1:
            e = b.numerator
            if a == 0:
                if e < 0:
                    raise CalcError("Division by zero")
                return Fraction(1) if e == 0 else Fraction(0)
            if a in (1, -1):
                return a ** e
            bits = max(a.numerator.bit_length(), a.denominator.bit_length())
            if abs(e) * bits <= FRACTION_BITS:
                return norm(a ** e)
        else:
            p, q = b.numerator, b.denominator
            if a < 0 and q % 2 == 0:
                raise CalcError("Complex result (even root of a negative number)")
            r = exact_root(abs(a), q)
            if r is not None:
                if a < 0:
                    r = -r
                return n_pow(r, Fraction(p))
    A, B = to_dec(a), to_dec(b)
    if A == 0:
        if B < 0:
            raise CalcError("Division by zero")
        return Fraction(1) if B == 0 else Fraction(0)
    if A < 0 and not is_int(B):
        raise CalcError("Complex result (fractional power of a negative number)")
    try:
        mag = dec_log10_abs(A) * B
    except (Overflow, InvalidOperation):
        raise CalcError("Result too large")
    if mag > MAX_EXP10:
        raise CalcError("Result too large")
    if mag < -MAX_EXP10:
        return Decimal(0)
    return dec_op(CTX.power, A, B)


def n_sqrt(a):
    if a < 0:
        raise CalcError("Square root of a negative number")
    r = exact_root(a, 2)
    if r is not None:
        return r
    return dec_op(CTX.sqrt, to_dec(a))


def n_root(a, k):
    if isinstance(k, Fraction) and k.denominator == 1 and k.numerator > 0:
        kk = k.numerator
        if a < 0:
            if kk % 2 == 0:
                raise CalcError("Even root of a negative number")
            return -n_root(-a, k)
        r = exact_root(a, kk)
        if r is not None:
            return r
    if k == 0:
        raise CalcError("Zeroth root is undefined")
    if a < 0:
        raise CalcError("Root of a negative number")
    return n_pow(a, n_div(Fraction(1), k))


# --------------------------------------------------------------- dimensions

DIMS = ("m", "kg", "s", "K", "bit", "rad")
ND = len(DIMS)
NODIM = (0,) * ND


def dim(m=0, kg=0, s=0, K=0, bit=0, rad=0):
    return (m, kg, s, K, bit, rad)


def dim_add(a, b):
    return tuple(x + y for x, y in zip(a, b))


def dim_sub(a, b):
    return tuple(x - y for x, y in zip(a, b))


def dim_scale(a, k):
    out = []
    for x in a:
        v = x * k
        if v.denominator != 1:
            raise CalcError("Fractional power of a unit is not supported")
        out.append(int(v))
    return tuple(out)


CATEGORY = {
    NODIM: "number",
    dim(m=1): "length",
    dim(m=2): "area",
    dim(m=3): "volume",
    dim(kg=1): "mass",
    dim(s=1): "time",
    dim(K=1): "temperature",
    dim(m=1, s=-1): "speed",
    dim(m=1, s=-2): "acceleration",
    dim(m=-1, kg=1, s=-2): "pressure",
    dim(m=2, kg=1, s=-2): "energy",
    dim(m=2, kg=1, s=-3): "power",
    dim(m=1, kg=1, s=-2): "force",
    dim(s=-1): "frequency",
    dim(rad=1): "angle",
    dim(bit=1): "data",
    dim(bit=1, s=-1): "data rate",
    dim(m=-2): "fuel economy",
    dim(kg=1, m=-3): "density",
}

SI_NAMES = {
    dim(m=2): "m^2", dim(m=3): "m^3", dim(m=1, s=-1): "m/s",
    dim(m=1, s=-2): "m/s^2", dim(m=-1, kg=1, s=-2): "Pa",
    dim(m=2, kg=1, s=-2): "J", dim(m=2, kg=1, s=-3): "W",
    dim(m=1, kg=1, s=-2): "N", dim(s=-1): "Hz", dim(bit=1): "bit",
    dim(bit=1, s=-1): "bit/s", dim(m=-2): "m^-2", dim(kg=1, m=-3): "kg/m^3",
}


def si_text(d):
    if d in SI_NAMES:
        return SI_NAMES[d]
    num = []
    den = []
    for name, e in zip(DIMS, d):
        if e > 0:
            num.append(name if e == 1 else "%s^%d" % (name, e))
        elif e < 0:
            den.append(name if e == -1 else "%s^%d" % (name, -e))
    s = "*".join(num) or "1"
    if den:
        s += "/" + (den[0] if len(den) == 1 else "(" + "*".join(den) + ")")
    return s


def category(d):
    if d in CATEGORY:
        return CATEGORY[d]
    return "a quantity in " + si_text(d)


# -------------------------------------------------------------------- units

class Unit:
    __slots__ = ("sym", "factor", "dim", "offset", "cat")

    def __init__(self, sym, factor, d, offset=None):
        self.sym = sym
        self.factor = factor
        self.dim = d
        self.offset = offset


UNITS = {}
F = Fraction


def U(names, factor, d, offset=None, sym=None):
    if isinstance(names, str):
        names = names.split()
    if isinstance(factor, (str, int)):
        factor = Fraction(factor)
    u = Unit(sym or names[0], factor, d, offset)
    for n in names:
        UNITS[n] = u
    return u


PI_FACTOR = PI
L, MS, T, K, B, A = dim(m=1), dim(kg=1), dim(s=1), dim(K=1), dim(bit=1), dim(rad=1)

# length
U("m meter meters metre metres", 1, L)
U("km kilometer kilometers kilometre kilometres", 1000, L)
U("dm decimeter decimeters", "0.1", L)
U("cm centimeter centimeters centimetre centimetres", "0.01", L)
U("mm millimeter millimeters millimetre millimetres", "0.001", L)
U("µm um μm micrometer micrometers micron microns", "1e-6", L, sym="µm")
U("nm nanometer nanometers", "1e-9", L)
U("pm picometer picometers", "1e-12", L)
U("in inch inches", "0.0254", L)
U("ft foot feet", "0.3048", L)
U("yd yard yards", "0.9144", L)
U("mi mile miles", "1609.344", L)
U("nmi NM nauticalmile nauticalmiles", 1852, L)
U("ly lightyear lightyears", 9460730472580800, L)
U("au AU", 149597870700, L, sym="au")
U("pc parsec parsecs", "30856775814913673", L)
# area
for _n in ("mm", "cm", "m", "km", "in", "ft", "yd", "mi"):
    _u = UNITS[_n]
    U([_n + "2", _n + "²", "sq" + _n], _u.factor ** 2, dim(m=2), sym=_n + "^2")
UNITS["sqft"].sym = "sqft"
U("ha hectare hectares", 10000, dim(m=2))
U("acre acres ac", "4046.8564224", dim(m=2))
# volume
for _n in ("mm", "cm", "m", "km", "in", "ft", "yd"):
    _u = UNITS[_n]
    U([_n + "3", _n + "³", "cu" + _n], _u.factor ** 3, dim(m=3), sym=_n + "^3")
U("cc", "1e-6", dim(m=3))
U("L l liter liters litre litres", "0.001", dim(m=3))
U("mL ml milliliter milliliters millilitre millilitres", "1e-6", dim(m=3))
U("cL cl centiliter centiliters centilitre centilitres", "1e-5", dim(m=3))
U("dL dl deciliter deciliters decilitre decilitres", "1e-4", dim(m=3))
U("µL uL μL microliter microliters", "1e-9", dim(m=3), sym="µL")
U("hL hl hectoliter hectoliters", "0.1", dim(m=3))
_GAL = Fraction("0.003785411784")
U("gal gallon gallons", _GAL, dim(m=3))
U("qt quart quarts", _GAL / 4, dim(m=3))
U("pt pint pints", _GAL / 8, dim(m=3))
U("cup cups", _GAL / 16, dim(m=3))
U("floz fl_oz fluidounce fluidounces", _GAL / 128, dim(m=3), sym="fl oz")
U("tbsp tablespoon tablespoons Tbsp", _GAL / 256, dim(m=3))
U("tsp teaspoon teaspoons", _GAL / 768, dim(m=3))
_IGAL = Fraction("0.00454609")
IMPERIAL = {}
for _base, _f in (("gal", _IGAL), ("qt", _IGAL / 4), ("pt", _IGAL / 8),
                  ("cup", _IGAL / 16), ("floz", _IGAL / 160)):
    _sym = "imp " + ("fl oz" if _base == "floz" else _base)
    _u = U([_base + "_imp", "imp" + _base, "uk" + _base, _base + "_uk"],
           _f, dim(m=3), sym=_sym)
    IMPERIAL[_base] = _u
# mass
U("kg kilogram kilograms kilo kilos", 1, MS)
U("g gram grams gramme grammes", "0.001", MS)
U("mg milligram milligrams", "1e-6", MS)
U("µg ug μg mcg microgram micrograms", "1e-9", MS, sym="µg")
U("t tonne tonnes metricton", 1000, MS)
U("ton tons shortton", "907.18474", MS)
U("longton", "1016.0469088", MS)
U("oz ounce ounces", "0.028349523125", MS)
U("lb lbs pound pounds", "0.45359237", MS)
U("st stone stones", "6.35029318", MS)
U("ct carat carats", "0.0002", MS)
U("gr grain grains", "0.00006479891", MS)
# time
U("s sec secs second seconds", 1, T)
U("ms millisecond milliseconds", "0.001", T)
U("µs us μs microsecond microseconds", "1e-6", T, sym="µs")
U("ns nanosecond nanoseconds", "1e-9", T)
U("min mins minute minutes", 60, T)
U("h hr hrs hour hours", 3600, T)
U("d day days", 86400, T, sym="day")
U("wk week weeks", 604800, T, sym="week")
U("month months mo", "2629746", T, sym="month")
U("yr year years y", "31556952", T, sym="year")
U("decade decades", "315569520", T)
U("century centuries", "3155695200", T)
# temperature (offset in the unit's own scale; K = (x + offset) * factor)
TEMP_C = U("°C C degC celsius Celsius", 1, K, offset=Fraction("273.15"), sym="°C")
TEMP_F = U("°F F degF fahrenheit Fahrenheit", Fraction(5, 9), K,
           offset=Fraction("459.67"), sym="°F")
TEMP_K = U("K kelvin kelvins Kelvin", 1, K, offset=Fraction(0))
TEMP_R = U("°R R degR rankine Rankine", Fraction(5, 9), K, offset=Fraction(0), sym="°R")
# speed
U("kmh kph kmph", Fraction(1000, 3600), dim(m=1, s=-1), sym="km/h")
U("mph", Fraction("0.44704"), dim(m=1, s=-1))
U("mps", 1, dim(m=1, s=-1), sym="m/s")
U("kn knot knots kt kts", Fraction(1852, 3600), dim(m=1, s=-1), sym="kn")
U("mach Ma", "340.29", dim(m=1, s=-1), sym="mach")
U("fps", Fraction("0.3048"), dim(m=1, s=-1), sym="ft/s")
U("gee gn", Fraction("9.80665"), dim(m=1, s=-2), sym="gee")
# pressure
P = dim(m=-1, kg=1, s=-2)
U("Pa pascal pascals", 1, P)
U("hPa", 100, P)
U("kPa", 1000, P)
U("MPa", 10 ** 6, P)
U("GPa", 10 ** 9, P)
U("bar bars", 100000, P)
U("mbar millibar millibars", 100, P)
U("atm atmosphere atmospheres", 101325, P)
_LBF = Fraction("4.4482216152605")
U("psi", _LBF / Fraction("0.00064516"), P)
U("mmHg", Fraction("133.322387415"), P)
U("inHg", Fraction("3386.389"), P)
U("torr Torr", Fraction(101325, 760), P, sym="torr")
# energy
EN = dim(m=2, kg=1, s=-2)
U("J joule joules", 1, EN)
U("mJ", "0.001", EN)
U("kJ kilojoule kilojoules", 1000, EN)
U("MJ megajoule megajoules", 10 ** 6, EN)
U("GJ", 10 ** 9, EN)
U("cal calorie calories", "4.184", EN)
U("kcal Cal kilocalorie kilocalories", 4184, EN, sym="kcal")
U("Wh", 3600, EN)
U("kWh", 3600000, EN)
U("MWh", 3600000000, EN)
U("GWh", 3600000000000, EN)
U("eV electronvolt electronvolts", "1.602176634e-19", EN)
U("keV", "1.602176634e-16", EN)
U("MeV", "1.602176634e-13", EN)
U("GeV", "1.602176634e-10", EN)
U("BTU btu Btu", "1055.05585262", EN, sym="BTU")
U("erg ergs", "1e-7", EN)
# power
PW = dim(m=2, kg=1, s=-3)
U("W watt watts", 1, PW)
U("mW milliwatt milliwatts", "0.001", PW)
U("kW kilowatt kilowatts", 1000, PW)
U("MW megawatt megawatts", 10 ** 6, PW)
U("GW gigawatt gigawatts", 10 ** 9, PW)
U("hp horsepower", "745.69987158227022", PW)
U("PS", "735.49875", PW)
# force
FO = dim(m=1, kg=1, s=-2)
U("N newton newtons", 1, FO)
U("mN", "0.001", FO)
U("kN kilonewton kilonewtons", 1000, FO)
U("MN", 10 ** 6, FO)
U("lbf", _LBF, FO)
U("kgf kp", "9.80665", FO, sym="kgf")
U("dyn dyne dynes", "1e-5", FO, sym="dyn")
# frequency
FR = dim(s=-1)
U("Hz hertz", 1, FR)
U("kHz", 1000, FR)
U("MHz", 10 ** 6, FR)
U("GHz", 10 ** 9, FR)
U("THz", 10 ** 12, FR)
U("rpm RPM", Fraction(1, 60), FR, sym="rpm")
# angle (factors depend on pi -> Decimal)
U("rad radian radians", 1, A)
U("mrad", "0.001", A)
U("deg degree degrees °", PI / 180, A)
U("grad gon gradian gradians", PI / 200, A)
U("turn turns rev revs revolution revolutions", PI * 2, A)
U("arcmin arcminute arcminutes", PI / 10800, A)
U("arcsec arcsecond arcseconds", PI / 648000, A)
# data
U("bit bits b", 1, B, sym="bit")
U("nibble nibbles", 4, B)
U("B byte bytes", 8, B)
for _p, _f in (("k", 10 ** 3), ("M", 10 ** 6), ("G", 10 ** 9), ("T", 10 ** 12),
               ("P", 10 ** 15), ("E", 10 ** 18)):
    U([_p + "bit", _p + "b"] + (["Kbit"] if _p == "k" else []), _f, B, sym=_p + "bit")
    U([_p + "B"] + (["KB"] if _p == "k" else []), 8 * _f, B)
    U([_p + "bps"], _f, dim(bit=1, s=-1), sym=_p + "bit/s")
for _p, _n, _e in (("Ki", "kibi", 1), ("Mi", "mebi", 2), ("Gi", "gibi", 3),
                   ("Ti", "tebi", 4), ("Pi", "pebi", 5), ("Ei", "exbi", 6)):
    U([_p + "B", _n + "byte", _n + "bytes"], 8 * 1024 ** _e, B)
    U([_p + "bit", _p + "b"], 1024 ** _e, B, sym=_p + "bit")
U("kilobyte kilobytes", 8000, B, sym="kB")
U("megabyte megabytes", 8 * 10 ** 6, B, sym="MB")
U("gigabyte gigabytes", 8 * 10 ** 9, B, sym="GB")
U("terabyte terabytes", 8 * 10 ** 12, B, sym="TB")
U("petabyte petabytes", 8 * 10 ** 15, B, sym="PB")
U("bps", 1, dim(bit=1, s=-1), sym="bit/s")
# fuel
U("L100km l100km", Fraction("0.001") / 100000, dim(m=2), sym="L/100km")
U("mpg mpg_us", Fraction("1609.344") / _GAL, dim(m=-2), sym="mpg")
U("mpg_imp mpgimp mpguk mpg_uk", Fraction("1609.344") / _IGAL, dim(m=-2),
  sym="mpg (imp)")
U("kmpl kml", Fraction(1000) / Fraction("0.001"), dim(m=-2), sym="km/L")

_LOWER = {}
for _n, _u in UNITS.items():
    _LOWER.setdefault(_n.lower(), set()).add(_u)

COMMON = {
    "length": ["m", "km", "cm", "mi", "ft", "in", "yd"],
    "area": ["m2", "km2", "ha", "acre", "sqft"],
    "volume": ["L", "mL", "gal", "floz", "cup", "gal_imp"],
    "mass": ["kg", "g", "lb", "oz", "st"],
    "time": ["s", "min", "h", "day", "week", "year"],
    "temperature": ["°C", "°F", "K"],
    "speed": ["km/h", "mph", "m/s", "kn"],
    "pressure": ["kPa", "bar", "psi", "atm"],
    "energy": ["J", "kJ", "kcal", "kWh"],
    "power": ["W", "kW", "hp"],
    "force": ["N", "lbf", "kgf"],
    "frequency": ["Hz", "kHz", "rpm"],
    "angle": ["deg", "rad", "turn"],
    "data": ["B", "kB", "MB", "GB", "MiB", "GiB"],
    "data rate": ["Mbps", "MB/s"],
    "fuel economy": ["L/100km", "mpg"],
}
COMMON["fuel economy"] = ["L/100km", "mpg", "mpg_imp"]


# ----------------------------------------------------------------- quantity

class Hint:
    """Display unit for a quantity: text, factor (SI per unit), dim."""
    __slots__ = ("text", "factor", "dim", "simple")

    def __init__(self, text, factor, d, simple=True):
        self.text = text
        self.factor = factor
        self.dim = d
        self.simple = simple


class Q:
    __slots__ = ("v", "dim", "hint", "temp", "pct", "measure", "unit_only")

    def __init__(self, v, d=NODIM, hint=None, temp=None, pct=False,
                 measure=False, unit_only=False):
        self.v = v
        self.dim = d
        self.hint = hint
        self.temp = temp
        self.pct = pct
        self.measure = measure
        self.unit_only = unit_only

    @property
    def scalar(self):
        return self.dim == NODIM


def q_from_unit(u):
    return Q(u.factor, u.dim, Hint(u.sym, u.factor, u.dim),
             temp=(u, Fraction(1)) if u.offset is not None else None,
             unit_only=True)


def need_scalar(q, what):
    if not q.scalar:
        raise CalcError("%s expects a plain number, got %s" % (what, category(q.dim)))
    return q.v


def q_add(a, b, sign=1):
    if b.pct and b.scalar and not a.pct:
        f = n_add(Fraction(1), b.v) if sign > 0 else n_sub(Fraction(1), b.v)
        return q_scale(a, f)
    if a.dim != b.dim:
        raise CalcError("Cannot %s %s and %s" % ("add" if sign > 0 else "subtract",
                                                 category(a.dim), category(b.dim)))
    v = n_add(a.v, b.v) if sign > 0 else n_sub(a.v, b.v)
    temp = None
    if a.temp and b.temp and a.temp[0] is b.temp[0]:
        raw = n_add(a.temp[1], b.temp[1]) if sign > 0 else n_sub(a.temp[1], b.temp[1])
        temp = (a.temp[0], raw)
    return Q(v, a.dim, a.hint or b.hint, temp=temp, measure=a.measure and b.measure)


def q_scale(a, f):
    temp = (a.temp[0], n_mul(a.temp[1], f)) if a.temp else None
    return Q(n_mul(a.v, f), a.dim, a.hint, temp=temp)


def hint_combine(ha, hb, op):
    if ha is None or hb is None:
        return None
    if op == "*":
        f = n_mul(ha.factor, hb.factor)
        t = "%s*%s" % (ha.text, hb.text)
        return Hint(t, f, dim_add(ha.dim, hb.dim), simple=False)
    f = n_div(ha.factor, hb.factor)
    bt = hb.text if hb.simple and "/" not in hb.text else "(%s)" % hb.text
    return Hint("%s/%s" % (ha.text, bt), f, dim_sub(ha.dim, hb.dim), simple=False)


def q_mul(a, b):
    if b.scalar and not a.scalar:
        return q_scale(a, b.v)
    if a.scalar and not b.scalar:
        r = q_scale(b, a.v)
        return r
    d = dim_add(a.dim, b.dim)
    v = n_mul(a.v, b.v)
    if d == NODIM:
        return Q(v)
    return Q(v, d, hint_combine(a.hint, b.hint, "*"))


def q_div(a, b):
    if b.scalar:
        if b.v == 0:
            raise CalcError("Division by zero")
        if a.scalar:
            return Q(n_div(a.v, b.v))
        return q_scale(a, n_div(Fraction(1), b.v))
    d = dim_sub(a.dim, b.dim)
    v = n_div(a.v, b.v)
    if d == NODIM:
        return Q(v)
    h = hint_combine(a.hint, b.hint, "/") if not a.scalar else None
    if a.scalar and b.hint is not None:
        h = Hint("1/%s" % (b.hint.text if b.hint.simple else "(%s)" % b.hint.text),
                 n_div(Fraction(1), b.hint.factor), d, simple=False)
    return Q(v, d, h)


def q_neg(a):
    temp = (a.temp[0], -a.temp[1]) if a.temp else None
    return Q(-a.v, a.dim, a.hint, temp=temp, pct=a.pct, measure=a.measure)


def q_pow(a, b):
    e = need_scalar(b, "Exponent")
    if a.scalar:
        return Q(n_pow(a.v, e))
    if not isinstance(e, Fraction):
        raise CalcError("Unit exponent must be exact")
    d = dim_scale(a.dim, e)
    v = n_pow(a.v, e)
    h = None
    if a.hint is not None and e.denominator == 1:
        base = a.hint.text if a.hint.simple else "(%s)" % a.hint.text
        h = Hint("%s^%d" % (base, e.numerator), n_pow(a.hint.factor, e), d, simple=True)
    if d == NODIM:
        return Q(v)
    return Q(v, d, h)


# ---------------------------------------------------------------- settings

def config_path():
    p = os.environ.get("SLEEK_CALC_CONFIG")
    if p:
        return p if p.endswith(".json") else os.path.join(p, "settings.json")
    base = os.environ.get("XDG_CONFIG_HOME") or os.path.join(os.path.expanduser("~"), ".config")
    return os.path.join(base, "sleek-shell", "settings.json")


def state_dir():
    p = os.environ.get("SLEEK_CALC_STATE")
    if p:
        return p
    base = os.environ.get("XDG_STATE_HOME") or os.path.join(os.path.expanduser("~"), ".local", "state")
    return os.path.join(base, "sleek-shell")


def atomic_write_json(path, data):
    d = os.path.dirname(path) or "."
    os.makedirs(d, exist_ok=True)
    mode = None
    try:
        mode = os.stat(path).st_mode & 0o777
    except OSError:
        pass
    fd, tmp = tempfile.mkstemp(dir=d, prefix="." + os.path.basename(path) + ".", suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
            f.write("\n")
            f.flush()
            os.fsync(f.fileno())
        if mode is not None:
            os.chmod(tmp, mode)
        os.replace(tmp, path)
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def read_json(path, default):
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return default


def load_settings():
    data = read_json(config_path(), {})
    if not isinstance(data, dict):
        data = {}
    calc = data.get("calc") if isinstance(data.get("calc"), dict) else {}
    mode = calc.get("angleMode", data.get("calc.angleMode", DEFAULT_MODE))
    prec = calc.get("precision", data.get("calc.precision", DEFAULT_PRECISION))
    if mode not in ("deg", "rad"):
        mode = DEFAULT_MODE
    if isinstance(prec, bool) or not isinstance(prec, (int, float)):
        prec = DEFAULT_PRECISION
    prec = max(1, min(40, int(prec)))
    return {"angleMode": mode, "precision": prec}


def save_angle_mode(mode):
    path = config_path()
    data = {}
    if os.path.exists(path):
        try:
            with open(path, "r", encoding="utf-8") as f:
                data = json.load(f)
        except (OSError, ValueError):
            raise CalcError("settings.json is not valid JSON; not modifying it")
        if not isinstance(data, dict):
            raise CalcError("settings.json is not a JSON object; not modifying it")
    calc = data.get("calc")
    if not isinstance(calc, dict):
        calc = {}
    calc["angleMode"] = mode
    data["calc"] = calc
    try:
        atomic_write_json(path, data)
    except OSError as e:
        raise CalcError("Could not save settings: %s" % e.strerror)


def state_file():
    return os.path.join(state_dir(), "calc-state.json")


def history_file():
    return os.path.join(state_dir(), "calc-history.json")


def load_ans():
    st = read_json(state_file(), {})
    if isinstance(st, dict) and isinstance(st.get("ans"), str):
        return st["ans"]
    return None


def save_ans(expr):
    try:
        atomic_write_json(state_file(), {"ans": expr, "time": int(time.time())})
    except OSError:
        pass


def load_history():
    h = read_json(history_file(), [])
    if not isinstance(h, list):
        return []
    out = []
    for item in h:
        if isinstance(item, dict) and isinstance(item.get("result"), str):
            out.append({"expr": str(item.get("expr", "")), "result": item["result"],
                        "time": item.get("time", 0)})
    return out[:HISTORY_MAX]


def add_history(expr, result):
    if not result:
        return
    h = [x for x in load_history() if not (x["result"] == result and x["expr"] == expr)]
    h.insert(0, {"expr": expr, "result": result, "time": int(time.time())})
    try:
        atomic_write_json(history_file(), h[:HISTORY_MAX])
    except OSError:
        pass


def delete_history(index):
    h = load_history()
    if 0 <= index < len(h):
        del h[index]
        try:
            atomic_write_json(history_file(), h)
        except OSError:
            pass


# ---------------------------------------------------------------- tokenizer

NUM_RE = re.compile(r"(?:\d[\d_]*(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?")
HEX_RE = re.compile(r"0[xX][0-9a-fA-F]+|0[bB][01]+|0[oO][0-7]+")
SUPERSCRIPT = {"²": "^2", "³": "^3"}
OPS2 = {"**": "^", "->": "->"}
OPS1 = {"+": "+", "-": "-", "−": "-", "*": "*", "×": "*", "·": "*", "/": "/",
        "÷": "/", "^": "^", "(": "(", ")": ")", ",": ",", ";": ",", "!": "!",
        "%": "%", "→": "->", "[": "(", "]": ")"}
KEYWORDS = {"mod", "of", "to", "in", "as", "into"}
SEPARATORS = {"to", "in", "as", "into", "->"}
FUEL_RE = re.compile(r"\b[lL]\s*/\s*100\s*km\b")


class Tok:
    __slots__ = ("kind", "text", "val", "pos")

    def __init__(self, kind, text, val, pos):
        self.kind = kind
        self.text = text
        self.val = val
        self.pos = pos

    def __repr__(self):
        return "Tok(%s,%r)" % (self.kind, self.text)


def is_ident_start(c):
    return c.isalpha() or c in "_°µμ"


def is_ident_char(c):
    return c.isalnum() or c in "_²³" and c != "" or c in "µμ"


def parse_number(text):
    clean = text.replace("_", "")
    m = re.match(r"^([^eE]*)(?:[eE]([+-]?\d+))?$", clean)
    exp = int(m.group(2)) if m.group(2) else 0
    if abs(exp) > 400:
        if abs(exp) > MAX_EXP10:
            raise CalcError("Number out of range: %s" % text)
        return norm(Decimal(clean))
    return Fraction(clean)


def tokenize(s):
    s = FUEL_RE.sub("L100km", s)
    toks = []
    i = 0
    n = len(s)
    while i < n:
        c = s[i]
        if c.isspace():
            i += 1
            continue
        m = HEX_RE.match(s, i)
        if m:
            t = m.group(0)
            toks.append(Tok("NUM", t, Fraction(int(t, 0)), i))
            i = m.end()
            continue
        if c.isdigit() or (c == "." and i + 1 < n and s[i + 1].isdigit()):
            m = NUM_RE.match(s, i)
            t = m.group(0)
            toks.append(Tok("NUM", t, parse_number(t), i))
            i = m.end()
            continue
        if c == "°" and i + 1 < n and s[i + 1] in "CFR" and not (i + 2 < n and s[i + 2].isalnum()):
            toks.append(Tok("ID", "°" + s[i + 1], None, i))
            i += 2
            continue
        if is_ident_start(c):
            j = i + 1
            while j < n and (s[j].isalnum() or s[j] in "_µμ"):
                j += 1
            word = s[i:j]
            if j < n and s[j] in "²³" and word in UNITS and word + s[j] in UNITS:
                word += s[j]
                j += 1
            toks.append(Tok("ID", word, None, i))
            i = j
            continue
        if c in SUPERSCRIPT:
            toks.append(Tok("OP", "^", None, i))
            toks.append(Tok("NUM", SUPERSCRIPT[c][1], Fraction(int(SUPERSCRIPT[c][1])), i))
            i += 1
            continue
        two = s[i:i + 2]
        if two in OPS2:
            toks.append(Tok("OP", OPS2[two], None, i))
            i += 2
            continue
        if c in OPS1:
            toks.append(Tok("OP", OPS1[c], None, i))
            i += 1
            continue
        if c == "=" and s[i + 1:].strip() == "":
            break
        raise CalcError("Unexpected character '%s'" % c)
    return toks


# ---------------------------------------------------------------- functions

def _trig_arg(q, ctx):
    """Return (radians float, exact degrees Fraction or None)."""
    if q.dim == A:
        return to_float(q.v), None
    v = need_scalar(q, "Trigonometric function")
    if ctx.mode == "deg":
        if isinstance(v, Fraction):
            r = v % 360
            return to_float(r) * math.pi / 180, r
        return to_float(v) * math.pi / 180, None
    return to_float(v), None


def _snap(x):
    if abs(x) < 1e-14:
        return 0.0
    return x


SIN_EXACT = {0: 0, 30: F(1, 2), 90: 1, 150: F(1, 2), 180: 0, 210: F(-1, 2),
             270: -1, 330: F(-1, 2)}
COS_EXACT = {0: 1, 60: F(1, 2), 90: 0, 120: F(-1, 2), 180: -1, 240: F(-1, 2),
             270: 0, 300: F(1, 2)}
TAN_EXACT = {0: 0, 45: 1, 135: -1, 180: 0, 225: 1, 315: -1}


def f_sin(ctx, q):
    x, d = _trig_arg(q, ctx)
    if d is not None and d in SIN_EXACT:
        return Q(Fraction(SIN_EXACT[d]))
    return Q(from_float(_snap(math.sin(x))))


def f_cos(ctx, q):
    x, d = _trig_arg(q, ctx)
    if d is not None and d in COS_EXACT:
        return Q(Fraction(COS_EXACT[d]))
    return Q(from_float(_snap(math.cos(x))))


def f_tan(ctx, q):
    x, d = _trig_arg(q, ctx)
    if d is not None:
        if d in TAN_EXACT:
            return Q(Fraction(TAN_EXACT[d]))
        if d % 180 == 90:
            raise CalcError("tan is undefined at 90°")
    c = math.cos(x)
    if abs(c) < 1e-15:
        raise CalcError("tan is undefined here")
    return Q(from_float(_snap(math.tan(x))))


def _inv_out(ctx, rad):
    if ctx.mode == "deg":
        return Q(from_float(math.degrees(rad)))
    return Q(from_float(rad))


def f_asin(ctx, q):
    x = to_float(need_scalar(q, "asin"))
    if not -1 <= x <= 1:
        raise CalcError("asin argument must be between -1 and 1")
    return _inv_out(ctx, math.asin(x))


def f_acos(ctx, q):
    x = to_float(need_scalar(q, "acos"))
    if not -1 <= x <= 1:
        raise CalcError("acos argument must be between -1 and 1")
    return _inv_out(ctx, math.acos(x))


def f_atan(ctx, q):
    return _inv_out(ctx, math.atan(to_float(need_scalar(q, "atan"))))


def f_atan2(ctx, y, x):
    if y.dim != x.dim:
        raise CalcError("atan2 arguments must have the same units")
    return _inv_out(ctx, math.atan2(to_float(y.v), to_float(x.v)))


def _float_fn(name, fn, domain=None):
    def f(ctx, q):
        x = to_float(need_scalar(q, name))
        if domain and not domain(x):
            raise CalcError("%s: argument out of domain" % name)
        try:
            return Q(from_float(fn(x)))
        except OverflowError:
            raise CalcError("Result too large")
        except ValueError:
            raise CalcError("Math domain error in %s" % name)
    return f


def f_sqrt(ctx, q):
    if q.scalar:
        return Q(n_sqrt(q.v))
    return q_pow(q, Q(Fraction(1, 2)))


def f_cbrt(ctx, q):
    if q.scalar:
        return Q(n_root(q.v, Fraction(3)))
    return q_pow(q, Q(Fraction(1, 3)))


def f_root(ctx, q, k):
    kv = need_scalar(k, "root degree")
    if q.scalar:
        return Q(n_root(q.v, kv))
    return q_pow(q, Q(n_div(Fraction(1), kv)))


def f_exp(ctx, q):
    x = need_scalar(q, "exp")
    if n_cmp(x, Fraction(230000)) > 0:
        raise CalcError("Result too large")
    if n_cmp(x, Fraction(-230000)) < 0:
        return Q(Fraction(0))
    return Q(dec_op(CTX.exp, to_dec(x)))


def _pos(x, name):
    if x <= 0:
        raise CalcError("%s of a non-positive number is undefined" % name)


def f_ln(ctx, q):
    x = need_scalar(q, "ln")
    _pos(x, "ln")
    return Q(dec_op(CTX.ln, to_dec(x)))


def f_log(ctx, q, base=None):
    x = need_scalar(q, "log")
    _pos(x, "log")
    if base is None:
        return Q(dec_op(CTX.log10, to_dec(x)))
    b = need_scalar(base, "log base")
    _pos(b, "log base")
    if b == 1:
        raise CalcError("log base cannot be 1")
    if isinstance(x, Fraction) and isinstance(b, Fraction) and b.denominator == 1 \
            and x.denominator == 1 and b > 1:
        n, k = x.numerator, 0
        bb = b.numerator
        while n % bb == 0 and n > 1:
            n //= bb
            k += 1
        if n == 1:
            return Q(Fraction(k))
    return Q(dec_op(CTX.divide, CTX.ln(to_dec(x)), CTX.ln(to_dec(b))))


def f_log2(ctx, q):
    return f_log(ctx, q, Q(Fraction(2)))


def f_abs(ctx, q):
    r = Q(abs(q.v), q.dim, q.hint)
    if q.temp:
        r.temp = (q.temp[0], abs(q.temp[1]))
    return r


def _keep(q, v):
    temp = None
    if q.temp and q.v != 0:
        temp = (q.temp[0], n_mul(q.temp[1], n_div(v, q.v)))
    return Q(v, q.dim, q.hint, temp=temp)


def _in_hint(q, fn):
    """Apply a rounding function in the quantity's display unit."""
    if q.temp:
        raw = fn(q.temp[1])
        u = q.temp[0]
        return Q(n_mul(raw, u.factor), q.dim, q.hint, temp=(u, raw))
    if q.hint is not None and not q.scalar:
        x = n_div(q.v, q.hint.factor)
        return Q(n_mul(fn(x), q.hint.factor), q.dim, q.hint)
    return Q(fn(q.v), q.dim, q.hint)


def f_floor(ctx, q):
    return _in_hint(q, n_floor)


def f_ceil(ctx, q):
    return _in_hint(q, n_ceil)


def round_half_up(x, nd=0):
    if not isinstance(x, Fraction):
        x = Fraction(x)
    s = Fraction(10) ** nd
    y = abs(x) * s
    r = math.floor(y + Fraction(1, 2))
    r = Fraction(r) / s
    return -r if x < 0 else r


def f_round(ctx, q, nd=None):
    n = 0
    if nd is not None:
        nv = need_scalar(nd, "round digits")
        if not is_int(nv) or abs(nv) > 50:
            raise CalcError("round digits must be an integer between -50 and 50")
        n = to_frac_int(nv)
    return _in_hint(q, lambda v: norm(round_half_up(v, n)))


def f_trunc(ctx, q):
    return _in_hint(q, lambda v: Fraction(math.trunc(Fraction(v))))


def f_sign(ctx, q):
    return Q(Fraction((q.v > 0) - (q.v < 0)))


def _same_dims(args, name):
    for a in args[1:]:
        if a.dim != args[0].dim:
            raise CalcError("%s arguments must have compatible units" % name)


def f_min(ctx, *args):
    _same_dims(args, "min")
    best = args[0]
    for a in args[1:]:
        if n_cmp(a.v, best.v) < 0:
            best = a
    return best


def f_max(ctx, *args):
    _same_dims(args, "max")
    best = args[0]
    for a in args[1:]:
        if n_cmp(a.v, best.v) > 0:
            best = a
    return best


def f_sum(ctx, *args):
    r = args[0]
    for a in args[1:]:
        r = q_add(r, a)
    return r


def f_avg(ctx, *args):
    return q_div(f_sum(ctx, *args), Q(Fraction(len(args))))


def f_hypot(ctx, *args):
    _same_dims(args, "hypot")
    s = Fraction(0)
    for a in args:
        s = n_add(s, n_mul(a.v, a.v))
    return Q(n_sqrt(s), args[0].dim, args[0].hint)


def _int_arg(q, name, limit=None):
    v = need_scalar(q, name)
    if not is_int(v):
        raise CalcError("%s needs integer arguments" % name)
    i = to_frac_int(v)
    if limit is not None and abs(i) > limit:
        raise CalcError("%s argument too large (max %d)" % (name, limit))
    return i


def f_gcd(ctx, *args):
    r = 0
    for a in args:
        r = math.gcd(r, _int_arg(a, "gcd", 10 ** 100))
    return Q(Fraction(r))


def f_lcm(ctx, *args):
    r = 1
    for a in args:
        r = math.lcm(r, _int_arg(a, "lcm", 10 ** 100))
        if r.bit_length() > 4000:
            raise CalcError("Result too large")
    return Q(Fraction(r))


def f_ncr(ctx, n, k):
    n, k = _int_arg(n, "ncr", 10000), _int_arg(k, "ncr", 10000)
    if n < 0 or k < 0:
        raise CalcError("ncr needs non-negative integers")
    return Q(norm(Fraction(math.comb(n, k))))


def f_npr(ctx, n, k):
    n, k = _int_arg(n, "npr", 10000), _int_arg(k, "npr", 10000)
    if n < 0 or k < 0:
        raise CalcError("npr needs non-negative integers")
    return Q(norm(Fraction(math.perm(n, k))))


def factorial(q):
    v = need_scalar(q, "Factorial")
    if is_int(v):
        i = to_frac_int(v)
        if i < 0:
            raise CalcError("Factorial of a negative integer is undefined")
        if i > MAX_FACT:
            raise CalcError("Factorial argument too large (max %d)" % MAX_FACT)
        return Q(norm(Fraction(math.factorial(i))))
    x = to_float(v)
    if x > 170:
        raise CalcError("Factorial argument too large")
    try:
        return Q(from_float(math.gamma(x + 1)))
    except (ValueError, OverflowError):
        raise CalcError("Factorial undefined for this value")


def f_fact(ctx, q):
    return factorial(q)


def f_gamma(ctx, q):
    x = to_float(need_scalar(q, "gamma"))
    if x > 171:
        raise CalcError("Result too large")
    try:
        return Q(from_float(math.gamma(x)))
    except (ValueError, OverflowError):
        raise CalcError("gamma undefined for this value")


def f_deg(ctx, q):
    if q.dim == A:
        return Q(n_div(q.v, n_div(PI, Fraction(180))))
    return Q(n_div(n_mul(need_scalar(q, "deg"), Fraction(180)), PI))


def f_rad(ctx, q):
    if q.dim == A:
        return Q(q.v)
    return Q(n_div(n_mul(need_scalar(q, "rad"), PI), Fraction(180)))


FUNCS = {
    "sqrt": (f_sqrt, 1, 1), "cbrt": (f_cbrt, 1, 1), "root": (f_root, 2, 2),
    "abs": (f_abs, 1, 1), "exp": (f_exp, 1, 1), "ln": (f_ln, 1, 1),
    "log": (f_log, 1, 2), "log10": (f_log, 1, 1), "lg": (f_log, 1, 1),
    "log2": (f_log2, 1, 1), "lb": None,
    "sin": (f_sin, 1, 1), "cos": (f_cos, 1, 1), "tan": (f_tan, 1, 1),
    "asin": (f_asin, 1, 1), "acos": (f_acos, 1, 1), "atan": (f_atan, 1, 1),
    "arcsin": (f_asin, 1, 1), "arccos": (f_acos, 1, 1), "arctan": (f_atan, 1, 1),
    "atan2": (f_atan2, 2, 2),
    "sinh": (_float_fn("sinh", math.sinh), 1, 1),
    "cosh": (_float_fn("cosh", math.cosh), 1, 1),
    "tanh": (_float_fn("tanh", math.tanh), 1, 1),
    "asinh": (_float_fn("asinh", math.asinh), 1, 1),
    "acosh": (_float_fn("acosh", math.acosh, lambda x: x >= 1), 1, 1),
    "atanh": (_float_fn("atanh", math.atanh, lambda x: -1 < x < 1), 1, 1),
    "floor": (f_floor, 1, 1), "ceil": (f_ceil, 1, 1), "round": (f_round, 1, 2),
    "trunc": (f_trunc, 1, 1), "sign": (f_sign, 1, 1), "sgn": (f_sign, 1, 1),
    "min": (f_min, 1, 100), "max": (f_max, 1, 100), "sum": (f_sum, 1, 100),
    "avg": (f_avg, 1, 100), "mean": (f_avg, 1, 100),
    "hypot": (f_hypot, 1, 100), "gcd": (f_gcd, 1, 100), "lcm": (f_lcm, 1, 100),
    "ncr": (f_ncr, 2, 2), "npr": (f_npr, 2, 2), "nCr": (f_ncr, 2, 2), "nPr": (f_npr, 2, 2),
    "fact": (f_fact, 1, 1), "factorial": (f_fact, 1, 1), "gamma": (f_gamma, 1, 1),
    "deg": (f_deg, 1, 1), "rad": (f_rad, 1, 1),
}
del FUNCS["lb"]

CONSTS = {
    "pi": PI, "π": PI, "tau": PI * 2, "τ": PI * 2, "e": E, "phi": PHI, "φ": PHI,
}

PREFIX_IMP = {"uk", "imp", "imperial", "british"}


# ------------------------------------------------------------------- parser

class EvalCtx:
    def __init__(self, mode, precision, ans=None, allow_ans=True):
        self.mode = mode
        self.precision = precision
        self.ans = ans
        self.allow_ans = allow_ans


class Parser:
    def __init__(self, toks, ctx):
        self.toks = toks
        self.i = 0
        self.ctx = ctx
        self.depth = 0

    def peek(self, k=0):
        j = self.i + k
        return self.toks[j] if j < len(self.toks) else None

    def next(self):
        t = self.peek()
        self.i += 1
        return t

    def at_op(self, op):
        t = self.peek()
        return t is not None and t.kind == "OP" and t.text == op

    def at_kw(self, kw):
        t = self.peek()
        return t is not None and t.kind == "ID" and t.text == kw

    def expect_op(self, op):
        t = self.next()
        if t is None:
            raise CalcError("Incomplete expression: expected '%s'" % op)
        if t.kind != "OP" or t.text != op:
            raise CalcError("Expected '%s' but found '%s'" % (op, t.text))

    def enter(self):
        self.depth += 1
        if self.depth > MAX_DEPTH:
            raise CalcError("Expression is too deeply nested")

    def parse_all(self):
        if not self.toks:
            raise CalcError("Empty expression")
        q = self.expr()
        t = self.peek()
        if t is not None:
            if t.kind == "OP" and t.text == ")":
                raise CalcError("Unmatched ')'")
            raise CalcError("Unexpected '%s'" % t.text)
        return q

    def expr(self):
        self.enter()
        left = self.mult()
        while True:
            t = self.peek()
            if t is not None and t.kind == "OP" and t.text in "+-":
                self.next()
                right = self.mult()
                left = q_add(left, right, 1 if t.text == "+" else -1)
            else:
                break
        self.depth -= 1
        return left

    def starts_operand(self, t):
        if t is None:
            return False
        if t.kind == "NUM":
            return True
        if t.kind == "OP":
            return t.text == "("
        return t.text == "in" or t.text not in KEYWORDS

    def mult(self):
        left = self.unary()
        while True:
            t = self.peek()
            if t is None:
                break
            if t.kind == "OP" and t.text in ("*", "/", "%"):
                self.next()
                right = None
                if t.text == "/" and not left.scalar:
                    nt = self.peek()
                    if nt is not None and nt.kind == "NUM":
                        save = self.i
                        right = self.measure_term()
                        if right is None:
                            self.i = save
                if right is None:
                    right = self.unary()
                if t.text == "*":
                    left = q_mul(left, right)
                elif t.text == "/":
                    left = q_div(left, right)
                else:
                    left = self.modulo(left, right)
            elif t.kind == "ID" and t.text == "mod":
                self.next()
                left = self.modulo(left, self.unary())
            elif t.kind == "ID" and t.text == "of":
                self.next()
                left = q_mul(left, self.unary())
            elif self.starts_operand(t):
                if t.kind == "NUM" and left.measure:
                    save = self.i
                    right = self.measure_term()
                    if right is not None and right.dim == left.dim:
                        left = q_add(left, right)
                        continue
                    self.i = save
                    nt = self.peek(1)
                    if nt is None or (nt.kind == "ID" and nt.text in KEYWORDS and nt.text != "in"):
                        raise CalcError("Missing unit after '%s'" % t.text)
                right = self.unary()
                was_scalar = left.scalar and right.unit_only
                left = q_mul(left, right)
                if was_scalar:
                    left.measure = True
            else:
                break
        return left

    def measure_term(self):
        depth = self.depth
        try:
            num = self.unary()
            if not num.scalar:
                return None
            nt = self.peek()
            if nt is None or nt.kind != "ID" or nt.text in CONSTS or (nt.text in KEYWORDS and nt.text != "in"):
                return None
            if nt.text in FUNCS:
                nn = self.peek(1)
                if nt.text not in UNITS or (nn is not None and nn.kind == "OP" and nn.text == "("):
                    return None
            u = self.unary()
        except CalcError:
            self.depth = depth
            return None
        if not u.unit_only:
            return None
        r = q_mul(num, u)
        r.measure = True
        return r

    def modulo(self, a, b):
        if a.dim != b.dim:
            raise CalcError("mod needs compatible units")
        return Q(n_mod(a.v, b.v), a.dim, a.hint)

    def unary(self):
        self.enter()
        t = self.peek()
        if t is not None and t.kind == "OP" and t.text in "+-":
            self.next()
            q = self.unary()
            r = q_neg(q) if t.text == "-" else q
        else:
            r = self.power()
        self.depth -= 1
        return r

    def power(self):
        base = self.postfix()
        if self.at_op("^"):
            self.next()
            self.enter()
            exp = self.unary_power()
            self.depth -= 1
            return q_pow(base, exp)
        return base

    def unary_power(self):
        t = self.peek()
        if t is not None and t.kind == "OP" and t.text in "+-":
            self.next()
            self.enter()
            q = self.unary_power()
            self.depth -= 1
            return q_neg(q) if t.text == "-" else q
        return self.power()

    def postfix(self):
        q = self.primary()
        while True:
            t = self.peek()
            if t is None or t.kind != "OP":
                break
            if t.text == "!":
                self.next()
                q = factorial(q)
            elif t.text == "%":
                nt = self.peek(1)
                if self.starts_operand(nt):
                    break
                self.next()
                q = Q(n_div(need_scalar(q, "Percent"), Fraction(100)), pct=True)
            else:
                break
        return q

    def args(self):
        self.expect_op("(")
        out = []
        if self.at_op(")"):
            self.next()
            return out
        while True:
            out.append(self.expr())
            if self.at_op(","):
                self.next()
                continue
            self.expect_op(")")
            return out

    def primary(self):
        self.enter()
        t = self.next()
        if t is None:
            raise CalcError("Incomplete expression")
        if t.kind == "NUM":
            r = Q(t.val)
        elif t.kind == "OP":
            if t.text == "(":
                r = self.expr()
                if self.peek() is None:
                    raise CalcError("Missing ')'")
                self.expect_op(")")
            else:
                raise CalcError("Unexpected '%s'" % t.text)
        else:
            r = self.ident(t)
        self.depth -= 1
        return r

    def ident(self, t):
        name = t.text
        if name in KEYWORDS and name != "in":
            raise CalcError("Unexpected '%s'" % name)
        if name in FUNCS and (self.at_op("(") or name not in UNITS):
            fn, lo, hi = FUNCS[name]
            if self.at_op("("):
                args = self.args()
            else:
                if not self.starts_operand(self.peek()) and not self.at_op("-"):
                    raise CalcError("%s needs an argument" % name)
                args = [self.unary()]
            if not lo <= len(args) <= hi:
                if lo == hi:
                    raise CalcError("%s takes %d argument%s" % (name, lo, "" if lo == 1 else "s"))
                raise CalcError("%s takes %d to %d arguments" % (name, lo, hi))
            return fn(self.ctx, *args)
        if name in CONSTS:
            return Q(CONSTS[name])
        if name == "ans":
            return self.ans_value()
        nt = self.peek()
        if name.lower() in PREFIX_IMP and nt is not None and nt.kind == "ID":
            base = self.unit_lookup(nt.text)
            for k, u in IMPERIAL.items():
                if UNITS[k] is base:
                    self.next()
                    return q_from_unit(u)
            if nt.text == "fl" and self.peek(1) is not None and self.peek(1).text == "oz":
                self.next()
                self.next()
                return q_from_unit(IMPERIAL["floz"])
            raise CalcError("No imperial variant of '%s'" % nt.text)
        if name.lower() == "us" and nt is not None and nt.kind == "ID" \
                and nt.text in UNITS and UNITS[nt.text].dim == dim(m=3):
            self.next()
            return q_from_unit(UNITS[nt.text])
        if name == "fl" and nt is not None and nt.kind == "ID" and nt.text == "oz":
            self.next()
            return q_from_unit(UNITS["floz"])
        if name == "sq" and nt is not None and nt.kind == "ID" and "sq" + nt.text in UNITS:
            self.next()
            return q_from_unit(UNITS["sq" + nt.text])
        return q_from_unit(self.unit_lookup(name))

    def unit_lookup(self, name):
        u = UNITS.get(name)
        if u is not None:
            return u
        cands = _LOWER.get(name.lower())
        if cands:
            if len(cands) == 1:
                return next(iter(cands))
            syms = sorted(set(c.sym for c in cands))
            raise CalcError("Ambiguous unit '%s' (did you mean %s?)" % (name, " or ".join(syms)))
        if name.endswith("s") and name[:-1] in UNITS and len(name) > 3:
            return UNITS[name[:-1]]
        if name in ("farad", "coulomb"):
            raise CalcError("Electrical units (%s) are not supported" % name)
        raise CalcError("Unknown name or unit '%s'" % name)

    def ans_value(self):
        if not self.ctx.allow_ans:
            raise CalcError("'ans' is not available here")
        if self.ctx.ans is None:
            return Q(Fraction(0))
        sub = EvalCtx(self.ctx.mode, self.ctx.precision, None, allow_ans=False)
        try:
            toks = tokenize(self.ctx.ans)
            return Parser(toks, sub).parse_all()
        except CalcError:
            return Q(Fraction(0))


# --------------------------------------------------------------- formatting

def fmt_num(v, precision):
    if isinstance(v, Fraction) and v.denominator == 1 and v.numerator.bit_length() <= 100:
        n = v.numerator
        if abs(n) < 10 ** 30:
            return str(n)
    d = to_dec(v)
    with localcontext(Context(prec=precision, rounding=ROUND_HALF_UP,
                              Emax=CTX.Emax, Emin=CTX.Emin)):
        r = +d
    if r.is_zero():
        return "0"
    e = r.adjusted()
    if -7 <= e < 15:
        s = format(r, "f")
        if "." in s:
            s = s.rstrip("0").rstrip(".")
        return s
    m = r.scaleb(-e)
    ms = format(m, "f")
    if "." in ms:
        ms = ms.rstrip("0").rstrip(".")
    return "%se%d" % (ms, e)


def value_in_hint(q, hint):
    return n_div(q.v, hint.factor)


def convert_value(src, tgt):
    """Return numeric value of src expressed in target quantity tgt."""
    if tgt.v == 0:
        raise CalcError("Cannot convert to a zero unit")
    if src.dim == tgt.dim:
        if src.dim == K and tgt.temp is not None and tgt.temp[1] == 1:
            tu = tgt.temp[0]
            if src.temp is not None:
                su, raw = src.temp
                kel = n_mul(n_add(raw, su.offset), su.factor)
            else:
                kel = src.v
            return n_sub(n_div(kel, tu.factor), tu.offset)
        return n_div(src.v, tgt.v)
    if src.dim != NODIM and src.dim == tuple(-x for x in tgt.dim) and abs(src.dim[0]) == 2 \
            and all(x == 0 for x in src.dim[1:]):
        if src.v == 0:
            raise CalcError("Cannot convert zero fuel economy")
        return n_div(Fraction(1), n_mul(src.v, tgt.v))
    raise CalcError("Cannot convert %s to %s" % (category(src.dim), category(tgt.dim)))


def quantity_text(q, precision):
    """Format a quantity in its own display unit."""
    if q.scalar:
        return fmt_num(q.v, precision)
    if q.temp is not None:
        return "%s %s" % (fmt_num(q.temp[1], precision), q.temp[0].sym)
    if q.hint is not None and q.hint.dim == q.dim:
        return "%s %s" % (fmt_num(value_in_hint(q, q.hint), precision), q.hint.text)
    return "%s %s" % (fmt_num(q.v, precision), si_text(q.dim))


def alternatives(q, precision, limit=4):
    cat = CATEGORY.get(q.dim)
    if cat not in COMMON:
        return []
    own = quantity_text(q, precision).split(" ", 1)[-1]
    cands = []
    for name in COMMON[cat]:
        try:
            tgt = Parser(tokenize(name), EvalCtx("rad", precision, allow_ans=False)).parse_all()
            val = convert_value(q, tgt)
        except CalcError:
            continue
        sym = tgt.hint.text if tgt.hint is not None else name
        if tgt.temp is not None:
            sym = tgt.temp[0].sym
        if sym == own:
            continue
        av = abs(to_dec(val)) if val != 0 else Decimal(0)
        nice = 0 if (av == 0 or Decimal("0.01") <= av < Decimal("1e7")) else 1
        cands.append((nice, len(cands), "%s %s" % (fmt_num(val, precision), sym)))
    cands.sort()
    return [c[2] for c in cands[:limit]]


# ------------------------------------------------------------------ driver

MODE_CMD_RE = re.compile(r"^\s*:(deg|rad)\b\s*(.*)$", re.S)


def split_conversion(toks):
    """Yield (left, right, sep) candidates, rightmost separator first."""
    idx = [i for i, t in enumerate(toks)
           if (t.kind == "ID" and t.text in SEPARATORS) or (t.kind == "OP" and t.text == "->")]
    for i in reversed(idx):
        yield toks[:i], toks[i + 1:], toks[i].text


def evaluate(text, settings=None, ans=None):
    """Evaluate input. Returns dict (never raises)."""
    settings = settings or load_settings()
    mode = settings["angleMode"]
    precision = settings["precision"]
    res = {"ok": False, "result": "", "value": "", "display": "", "error": "",
           "mode": mode, "kind": "", "alternatives": [], "setMode": ""}
    try:
        if not isinstance(text, str):
            raise CalcError("Invalid input")
        if len(text) > MAX_INPUT:
            raise CalcError("Input too long (max %d characters)" % MAX_INPUT)
        text = text.strip()
        m = MODE_CMD_RE.match(text)
        if m:
            mode = m.group(1)
            res["mode"] = mode
            res["setMode"] = mode
            text = m.group(2).strip()
            if not text:
                res.update(ok=True, kind="command",
                           display="Switch angle mode to %s" % ("degrees" if mode == "deg" else "radians"))
                return res
        if not text:
            raise CalcError("Empty expression")
        ctx = EvalCtx(mode, precision, ans)
        toks = tokenize(text)
        if len(toks) > 400:
            raise CalcError("Expression too long")
        out = None
        first_err = None
        for left, right, sep in split_conversion(toks):
            if not right:
                if sep in ("to", "as", "->", "into") and left:
                    raise CalcError("Missing target unit after '%s'" % sep)
                continue
            if not left:
                continue
            try:
                tgt = Parser(right, ctx).parse_all()
                if tgt.scalar:
                    raise CalcError("Target '%s' is not a unit" % " ".join(t.text for t in right))
                src = Parser(left, ctx).parse_all()
                val = convert_value(src, tgt)
            except CalcError as e:
                if sep == "in":
                    first_err = first_err or e
                    continue
                raise
            sym = tgt.temp[0].sym if tgt.temp is not None else (
                tgt.hint.text if tgt.hint is not None else si_text(tgt.dim))
            vs = fmt_num(val, precision)
            out = {"kind": "conversion", "value": vs, "result": "%s %s" % (vs, sym),
                   "display": "%s = %s %s" % (quantity_text(src, precision), vs, sym),
                   "full": "%s %s" % (fmt_num(val, 40), sym)}
            break
        if out is None:
            try:
                q = Parser(toks, ctx).parse_all()
            except CalcError as e:
                if first_err is not None and "Unknown" in str(e):
                    raise first_err
                raise
            if q.scalar:
                vs = fmt_num(q.v, precision)
                out = {"kind": "number", "value": vs, "result": vs, "display": vs,
                       "full": fmt_num(q.v, 40)}
            else:
                txt = quantity_text(q, precision)
                alts = alternatives(q, precision)
                out = {"kind": "quantity", "value": txt.split(" ", 1)[0], "result": txt,
                       "display": txt + ("  =  " + "  =  ".join(alts[:2]) if alts else ""),
                       "alternatives": alts,
                       "full": quantity_text(q, 40)}
        res.update(out)
        res["ok"] = True
    except CalcError as e:
        res["error"] = str(e)
    except RecursionError:
        res["error"] = "Expression is too deeply nested"
    except (MemoryError, OverflowError):
        res["error"] = "Result too large"
    except Exception as e:  # never leak a traceback to the user
        res["error"] = "Cannot evaluate: %s" % type(e).__name__
    res.setdefault("full", res.get("result", ""))
    return res


def commit(text):
    """Evaluate with side effects: persist mode switch, ans and history."""
    r = evaluate(text, ans=load_ans())
    if r["ok"] and r.get("setMode"):
        try:
            save_angle_mode(r["setMode"])
        except CalcError as e:
            r["ok"] = False
            r["error"] = str(e)
            return r
    if r["ok"] and r["kind"] != "command":
        save_ans(r.get("full") or r["result"])
    return r


def public(r):
    out = dict(r)
    out.pop("full", None)
    return out


# --------------------------------------------------------------------- I/O

def copy_to_clipboard(value):
    ok = False
    try:
        p = subprocess.run(["wl-copy", "--", value], stdin=subprocess.DEVNULL,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                           timeout=5)
        ok = p.returncode == 0
    except (OSError, subprocess.TimeoutExpired):
        ok = False
    try:
        subprocess.Popen(["notify-send", "-a", APP_NAME, "--",
                          "Copied" if ok else "Copy failed", value],
                         stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                         stderr=subprocess.DEVNULL, start_new_session=True)
    except OSError:
        pass
    return ok


def serve():
    out = sys.stdout
    for line in sys.stdin:
        line = line.rstrip("\n")
        try:
            if line.startswith("\x1e"):
                cmd, _, arg = line[1:].partition(" ")
                if cmd == "commit":
                    r = public(commit(arg))
                    if r["ok"] and r["kind"] != "command":
                        add_history(arg.strip(), r["result"])
                elif cmd == "record":
                    expr, _, result = arg.partition("\x1f")
                    add_history(expr.strip(), result)
                    save_ans(result)
                    r = {"ok": True}
                elif cmd == "history":
                    h = load_history()
                    r = {"ok": True, "results": [x["result"] for x in h],
                         "exprs": [x["expr"] for x in h], "mode": load_settings()["angleMode"]}
                elif cmd == "delete":
                    try:
                        delete_history(int(arg))
                    except ValueError:
                        pass
                    r = {"ok": True}
                else:
                    r = {"ok": True, "mode": load_settings()["angleMode"]}
            else:
                r = public(evaluate(line, ans=load_ans()))
        except Exception as e:
            r = {"ok": False, "error": "Internal error: %s" % type(e).__name__}
        out.write(json.dumps(r, ensure_ascii=False) + "\n")
        out.flush()


def script_mode(argv):
    """Rofi script-mode protocol (fallback when the plugin is unavailable)."""
    def opt(k, v):
        sys.stdout.write("\0%s\x1f%s\n" % (k, v))

    def row(text, info):
        sys.stdout.write("%s\0info\x1f%s\n" % (text.replace("\n", " "), info))

    def esc(s):
        return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")

    retv = os.environ.get("ROFI_RETV", "0")
    info = os.environ.get("ROFI_INFO", "")
    arg = argv[0] if argv else None
    if retv == "1" and info.startswith("copy:"):
        value = info[5:]
        add_history(os.environ.get("ROFI_DATA", ""), value)
        save_ans(value)
        copy_to_clipboard(value)
        return 0
    settings = load_settings()
    opt("prompt", "Calc")
    message = "Mode: <b>%s</b>   ·   type an expression and press Enter" % settings["angleMode"].upper()
    if arg is not None and retv in ("2", "1"):
        r = commit(arg)
        if r["ok"] and r["kind"] == "command":
            message = "Angle mode set to <b>%s</b>" % r["mode"].upper()
        elif r["ok"]:
            opt("data", arg.replace("\n", " "))
            message = "<b>%s</b>   ·   Enter copies   ·   Mode %s" % (esc(r["display"]), r["mode"].upper())
            row("= " + r["result"], "copy:" + r["result"])
            for a in r.get("alternatives", []):
                row("= " + a, "copy:" + a)
        else:
            message = "<span foreground='#f38ba8'>%s</span>" % esc(r["error"])
    opt("message", message)
    opt("markup-rows", "false")
    for h in load_history()[:20]:
        row("%s    ·  %s" % (h["result"], h["expr"]), "copy:" + h["result"])
    sys.stdout.flush()
    return 0


def main(argv):
    if not argv:
        sys.stderr.write("usage: sleek_calc.py [--json] EXPR | --serve | --script [TEXT]\n")
        return 2
    if argv[0] == "--serve":
        serve()
        return 0
    if argv[0] == "--script":
        return script_mode(argv[1:])
    if argv[0] == "--clear-history":
        try:
            atomic_write_json(history_file(), [])
        except OSError as e:
            sys.stderr.write("error: %s\n" % e.strerror)
            return 1
        return 0
    if argv[0] == "--history-count":
        sys.stdout.write("%d\n" % len(load_history()))
        return 0
    if argv[0] in ("-h", "--help"):
        sys.stdout.write(__doc__.strip() + "\n\nusage: sleek_calc.py [--json [--commit]] EXPR | --serve | --script [TEXT] | --clear-history | --history-count\n")
        return 0
    if argv[0] == "--json":
        rest = argv[1:]
        do_commit = False
        if rest and rest[0] == "--commit":
            do_commit = True
            rest = rest[1:]
        text = " ".join(rest)
        r = commit(text) if do_commit else evaluate(text, ans=load_ans())
        sys.stdout.write(json.dumps(public(r), ensure_ascii=False) + "\n")
        return 0 if r["ok"] else 1
    if argv[0] == "--":
        argv = argv[1:]
    text = " ".join(argv)
    r = commit(text)
    if not r["ok"]:
        sys.stderr.write("error: %s\n" % r["error"])
        return 1
    if r["kind"] == "command":
        sys.stdout.write("Angle mode: %s\n" % r["mode"])
    elif r["kind"] == "quantity":
        sys.stdout.write(r["result"] + "\n")
        for a in r.get("alternatives", []):
            sys.stdout.write("= %s\n" % a)
    else:
        sys.stdout.write(r["result"] + "\n")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except KeyboardInterrupt:
        sys.exit(130)
    except BrokenPipeError:
        sys.exit(0)
