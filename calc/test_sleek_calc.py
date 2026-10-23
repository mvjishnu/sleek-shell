import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, "sleek_calc.py")
_TMP = tempfile.mkdtemp(prefix="sleek-calc-test-")
os.environ["SLEEK_CALC_STATE"] = os.path.join(_TMP, "state")
os.environ["SLEEK_CALC_CONFIG"] = os.path.join(_TMP, "config")
sys.path.insert(0, HERE)

import sleek_calc as sc  # noqa: E402

DEG = {"angleMode": "deg", "precision": 12}
RAD = {"angleMode": "rad", "precision": 12}


def tearDownModule():
    shutil.rmtree(_TMP, ignore_errors=True)


def ev(text, settings=DEG, ans=None):
    return sc.evaluate(text, settings=dict(settings), ans=ans)


class Base(unittest.TestCase):
    def ok(self, text, settings=DEG, ans=None):
        r = ev(text, settings, ans)
        self.assertTrue(r["ok"], "%r failed: %s" % (text, r["error"]))
        return r

    def assertResult(self, text, expected, settings=DEG):
        self.assertEqual(self.ok(text, settings)["result"], expected)

    def assertValue(self, text, expected, places=6, unit=None):
        r = self.ok(text)
        self.assertAlmostEqual(float(r["value"]), expected, places=places, msg=text)
        if unit is not None:
            self.assertEqual(r["result"].split(" ", 1)[1], unit)

    def assertError(self, text, contains=None, settings=DEG):
        r = ev(text, settings)
        self.assertFalse(r["ok"], "%r unexpectedly gave %r" % (text, r["result"]))
        self.assertTrue(r["error"])
        self.assertNotIn("Traceback", r["error"])
        if contains:
            self.assertIn(contains, r["error"])
        return r


class Arithmetic(Base):
    def test_required(self):
        self.assertResult("sqrt(144) + 3^4", "93")
        self.assertResult("log(1000)", "3")
        self.assertResult("25% of 840", "210")
        self.assertResult("(12.5 * 8) / 3", "33.3333333333")
        self.assertResult("0.1+0.2", "0.3")
        self.assertResult("-2^2", "-4")
        self.assertResult("2^3^2", "512")
        self.assertResult("5!", "120")
        self.assertResult("10 mod 3", "1")
        self.assertResult("1.5e3", "1500")
        self.assertResult("1.5e-3", "0.0015")
        self.assertResult("1E6", "1000000")

    def test_precedence_and_unary(self):
        self.assertResult("2+3*4", "14")
        self.assertResult("(2+3)*4", "20")
        self.assertResult("2**3**2", "512")
        self.assertResult("-(2+3)", "-5")
        self.assertResult("2^-1", "0.5")
        self.assertResult("--3", "3")
        self.assertResult("10 - 2 - 3", "5")
        self.assertResult("100 / 10 / 5", "2")

    def test_implicit_multiplication(self):
        self.assertResult("2pi", "6.28318530718")
        self.assertResult("3(4+1)", "15")
        self.assertResult("(1+1)(2+2)", "8")

    def test_percent(self):
        self.assertResult("50%", "0.5")
        self.assertResult("840 + 10%", "924")
        self.assertResult("840 - 10%", "756")
        self.assertResult("200 * 15%", "30")
        self.assertResult("10 % 3", "1")

    def test_factorial(self):
        self.assertResult("20!", "2432902008176640000")
        self.assertResult("0!", "1")
        self.assertResult("3!!", "720")
        self.assertError("1001!", "too large")
        self.assertError("(-1)!")

    def test_exact_decimals(self):
        self.assertResult("1/3*3", "1")
        self.assertResult("0.1*3", "0.3")
        self.assertResult("1.1-1", "0.1")
        self.assertResult("2^64", "18446744073709551616")
        self.assertResult("1/3", "0.333333333333")

    def test_functions(self):
        cases = {
            "cbrt(27)": "3", "root(16,4)": "2", "abs(-3)": "3", "exp(0)": "1",
            "ln(e)": "1", "log2(8)": "3", "log(8,2)": "3", "floor(-2.5)": "-3",
            "ceil(2.1)": "3", "round(2.5)": "3", "round(3.14159,2)": "3.14",
            "min(3,1,2)": "1", "max(1,5)": "5", "hypot(3,4)": "5",
            "gcd(12,18)": "6", "lcm(4,6)": "12", "ncr(5,2)": "10", "npr(5,2)": "20",
            "deg(pi)": "180", "rad(180)": "3.14159265359", "sqrt(2)": "1.41421356237",
            "sinh(0)": "0", "cosh(0)": "1", "tanh(0)": "0", "asinh(0)": "0",
            "acosh(1)": "0", "atanh(0)": "0",
        }
        for expr, want in cases.items():
            with self.subTest(expr=expr):
                self.assertResult(expr, want)

    def test_constants(self):
        self.assertResult("pi", "3.14159265359")
        self.assertResult("π", "3.14159265359")
        self.assertResult("e", "2.71828182846")
        self.assertResult("tau", "6.28318530718")
        self.assertResult("phi", "1.61803398875")

    def test_precision_setting(self):
        self.assertResult("1/3", "0.333333", {"angleMode": "deg", "precision": 6})
        self.assertResult("2/3", "0.67", {"angleMode": "deg", "precision": 2})

    def test_scientific_format(self):
        self.assertResult("10^20", "100000000000000000000")
        self.assertResult("1.5*10^20", "150000000000000000000")
        self.assertResult("2^0.5*10^20", "1.41421356237e20")
        self.assertResult("1/10^9", "1e-9")


class Trig(Base):
    def test_degrees(self):
        self.assertResult("sin(30)", "0.5")
        self.assertResult("cos(60)", "0.5")
        self.assertResult("cos(90)", "0")
        self.assertResult("tan(45)", "1")
        self.assertResult("asin(0.5)", "30")
        self.assertResult("acos(0.5)", "60")
        self.assertResult("atan(1)", "45")
        self.assertResult("atan2(1,1)", "45")
        self.assertError("tan(90)")

    def test_radians(self):
        self.assertResult("sin(pi/2)", "1", RAD)
        self.assertResult("cos(pi)", "-1", RAD)
        self.assertResult("atan(1)", "0.785398163397", RAD)

    def test_inline_mode_override(self):
        r = self.ok(":rad sin(pi/2)")
        self.assertEqual(r["result"], "1")
        self.assertEqual(r["mode"], "rad")
        r = self.ok(":deg sin(30)", RAD)
        self.assertEqual(r["result"], "0.5")

    def test_mode_command_preview(self):
        r = self.ok(":rad")
        self.assertEqual(r["kind"], "command")
        self.assertEqual(r["setMode"], "rad")

    def test_domain_errors(self):
        self.assertError("asin(2)")
        self.assertError("sqrt(-1)")
        self.assertError("ln(0)")
        self.assertError("log(-5)")
        self.assertError("acosh(0.5)")


class Units(Base):
    def test_required(self):
        self.assertValue("10 miles to km", 16.09344, unit="km")
        self.assertResult("2.5 L to mL", "2500 mL")
        self.assertValue("72 F to C", 22.2222222222, places=6, unit="°C")
        self.assertResult("0 C to K", "273.15 K")
        self.assertValue("100 km/h to mph", 62.1371192237, unit="mph")
        self.assertResult("1 GiB to MB", "1073.741824 MB")
        self.assertValue("1 GB to GiB", 0.931323, places=6)
        self.assertResult("1 atm to kPa", "101.325 kPa")
        self.assertResult("1 kWh to J", "3600000 J")
        self.assertValue("1 hp to W", 745.7, places=0)
        self.assertValue("1 hp to W", 745.699871582, places=6)

    def test_separators(self):
        self.assertResult("10 km in m", "10000 m")
        self.assertResult("10 km as m", "10000 m")
        self.assertResult("10 km -> m", "10000 m")
        self.assertResult("10 km → m", "10000 m")
        self.assertResult("10 km into m", "10000 m")

    def test_inch_vs_in(self):
        self.assertResult("10 in to cm", "25.4 cm")
        self.assertResult("2 in in cm", "5.08 cm")
        self.assertResult("6 ft in cm", "182.88 cm")

    def test_compound_measure(self):
        self.assertResult("5 ft 11 in to cm", "180.34 cm")
        self.assertResult("1 h 30 min to min", "90 min")
        self.assertResult("1 m 20 cm", "1.2 m")

    def test_arithmetic_in_quantity(self):
        self.assertValue("(3+2) km to mi", 3.10685596119, unit="mi")
        self.assertResult("2 km + 300 m to m", "2300 m")
        self.assertResult("10 m/s^2 * 2 s to km/h", "72 km/h")

    def test_divide_by_measure(self):
        self.assertResult("5 km / 20 min to km/h", "15 km/h")
        self.assertResult("100 km / 2 h", "50 km/h")
        self.assertResult("1/2 km", "0.5 km")
        self.assertResult("10 m / 2", "5 m")

    def test_temperatures(self):
        self.assertResult("100 C to F", "212 °F")
        self.assertResult("-40 F to C", "-40 °C")
        self.assertResult("300 K to C", "26.85 °C")
        self.assertResult("32 °F to °C", "0 °C")
        self.assertResult("20 celsius to fahrenheit", "68 °F")
        self.assertResult("0 K to R", "0 °R")

    def test_volumes(self):
        self.assertResult("1 gal to L", "3.785411784 L")
        self.assertResult("1 uk gal to L", "4.54609 L")
        self.assertResult("1 imp pt to mL", "568.26125 mL")
        self.assertResult("1 cup to mL", "236.5882365 mL")
        self.assertResult("1 m3 to L", "1000 L")

    def test_data(self):
        self.assertResult("8 bit to B", "1 B")
        self.assertResult("1 KiB to B", "1024 B")
        self.assertResult("1 Gbit to MB", "125 MB")
        self.assertResult("100 Mbps to MB/s", "12.5 MB/s")
        self.assertResult("1 PB to TB", "1000 TB")
        self.assertError("1 mB", "Ambiguous")

    def test_categories(self):
        cases = {
            "1 lb to kg": "0.45359237 kg", "1 st to lb": "14 lb", "1 t to kg": "1000 kg",
            "1 km2 to ha": "100 ha", "1 acre to m2": "4046.8564224 m^2",
            "1 bar to kPa": "100 kPa", "1 kcal to kJ": "4.184 kJ", "1 kgf to N": "9.80665 N",
            "60 rpm to Hz": "1 Hz", "1 GHz to MHz": "1000 MHz", "1 turn to deg": "360 deg",
            "100 grad to deg": "90 deg", "1 arcmin to arcsec": "60 arcsec",
            "1 week to h": "168 h", "1 year to day": "365.2425 day",
            "1 month to day": "30.436875 day", "1 knot to km/h": "1.852 km/h",
            "1 MPa to bar": "10 bar", "1 Wh to J": "3600 J", "1 PS to W": "735.49875 W",
        }
        for expr, want in cases.items():
            with self.subTest(expr=expr):
                self.assertResult(expr, want)

    def test_fuel(self):
        self.assertValue("30 mpg to L/100km", 7.84048611111)
        self.assertValue("1 L/100km to mpg", 235.214583333)

    def test_bare_quantity_alternatives(self):
        r = self.ok("10 km")
        self.assertEqual(r["kind"], "quantity")
        self.assertEqual(r["result"], "10 km")
        self.assertIn("6.21371192237 mi", r["alternatives"])

    def test_dimension_errors(self):
        self.assertError("5 kg to m", "Cannot convert mass to length")
        self.assertError("5 kg + 3 m", "Cannot add")
        self.assertError("10 km to", "Missing target")
        self.assertError("1 farad", "not supported")


class Safety(Base):
    def test_garbage(self):
        for text in ("hello world", "2 +* 3", "((", "3)", "", "+", "sin", "1,5", "#$@", "§"):
            with self.subTest(text=text):
                self.assertError(text)

    def test_injection(self):
        for text in ("__import__('os')", "__import__(\"os\").system(\"ls\")",
                     "open('/etc/passwd')", "().__class__", "exec('1')", "eval(1)",
                     "lambda: 1", "os.system"):
            with self.subTest(text=text):
                self.assertError(text)

    def test_long_input_rejected(self):
        self.assertError("1+" * 300 + "1", "too long")

    def test_deep_nesting(self):
        self.assertError("(" * 200 + "1" + ")" * 200)

    def test_huge_power_fast(self):
        t0 = time.monotonic()
        self.assertError("9^9^9", "too large")
        self.assertError("10^10^10", "too large")
        self.assertError("2^(2^40)")
        self.assertLess(time.monotonic() - t0, 2.0)

    def test_big_but_allowed(self):
        self.assertResult("10^100000", "1e100000")
        r = self.ok("1000!")
        self.assertTrue(r["result"].startswith("4.02387260077e2567"))

    def test_no_eval_in_source(self):
        with open(os.path.join(HERE, "sleek_calc.py"), encoding="utf-8") as f:
            src = f.read()
        for pat in (r"(?<![.\w])(eval|exec|compile)\s*\(", r"shell\s*=\s*True",
                    r"os\.system", r"os\.popen", r"__import__"):
            m = re.search(pat, src)
            self.assertIsNone(m, "forbidden construct %r found" % (m.group(0) if m else ""))


class State(Base):
    def setUp(self):
        for d in (os.environ["SLEEK_CALC_STATE"], os.environ["SLEEK_CALC_CONFIG"]):
            shutil.rmtree(d, ignore_errors=True)

    def test_ans(self):
        sc.commit("6*7")
        self.assertEqual(sc.load_ans(), "42")
        r = ev("ans + 1", ans=sc.load_ans())
        self.assertEqual(r["result"], "43")
        sc.commit("10 km")
        self.assertEqual(ev("ans to m", ans=sc.load_ans())["result"], "10000 m")

    def test_history(self):
        for i in range(60):
            sc.add_history("%d+0" % i, str(i))
        h = sc.load_history()
        self.assertEqual(len(h), 50)
        self.assertEqual(h[0]["result"], "59")
        sc.delete_history(0)
        self.assertEqual(sc.load_history()[0]["result"], "58")

    def test_settings_missing_and_partial(self):
        s = sc.load_settings()
        self.assertEqual(s["angleMode"], "deg")
        self.assertEqual(s["precision"], 12)
        os.makedirs(os.environ["SLEEK_CALC_CONFIG"], exist_ok=True)
        path = os.path.join(os.environ["SLEEK_CALC_CONFIG"], "settings.json")
        with open(path, "w") as f:
            json.dump({"calc": {"precision": 500}}, f)
        self.assertEqual(sc.load_settings()["precision"], 40)
        with open(path, "w") as f:
            json.dump({"calc.angleMode": "rad"}, f)
        self.assertEqual(sc.load_settings()["angleMode"], "rad")

    def test_mode_persist_preserves_keys(self):
        os.makedirs(os.environ["SLEEK_CALC_CONFIG"], exist_ok=True)
        path = os.path.join(os.environ["SLEEK_CALC_CONFIG"], "settings.json")
        with open(path, "w") as f:
            json.dump({"theme": {"accent": "#fff"}, "calc": {"precision": 8}}, f)
        r = sc.commit(":rad")
        self.assertTrue(r["ok"])
        with open(path) as f:
            data = json.load(f)
        self.assertEqual(data["theme"], {"accent": "#fff"})
        self.assertEqual(data["calc"], {"precision": 8, "angleMode": "rad"})
        self.assertEqual(sc.load_settings()["angleMode"], "rad")
        self.assertEqual(sc.commit(":deg sin(30)")["result"], "0.5")
        self.assertEqual(sc.load_settings()["angleMode"], "deg")

    def test_invalid_settings_untouched(self):
        os.makedirs(os.environ["SLEEK_CALC_CONFIG"], exist_ok=True)
        path = os.path.join(os.environ["SLEEK_CALC_CONFIG"], "settings.json")
        with open(path, "w") as f:
            f.write("{broken")
        self.assertEqual(sc.load_settings()["angleMode"], "deg")
        self.assertFalse(sc.commit(":rad")["ok"])
        with open(path) as f:
            self.assertEqual(f.read(), "{broken")


class CLI(unittest.TestCase):
    def setUp(self):
        self.env = dict(os.environ)
        fake = os.path.join(_TMP, "bin")
        os.makedirs(fake, exist_ok=True)
        self.log = os.path.join(_TMP, "copy.log")
        for name in ("wl-copy", "notify-send"):
            p = os.path.join(fake, name)
            with open(p, "w") as f:
                f.write('#!/bin/sh\nprintf "%%s\\n" "%s $*" >> "%s"\n' % (name, self.log))
            os.chmod(p, 0o755)
        self.env["PATH"] = fake + os.pathsep + self.env.get("PATH", "")

    def run_cli(self, *args, stdin=None, extra=None):
        env = dict(self.env)
        env.update(extra or {})
        return subprocess.run([sys.executable, SCRIPT] + list(args), input=stdin,
                              capture_output=True, text=True, env=env, timeout=20)

    def test_plain(self):
        p = self.run_cli("sqrt(144) + 3^4")
        self.assertEqual((p.returncode, p.stdout), (0, "93\n"))
        p = self.run_cli("5 kg to m")
        self.assertEqual(p.returncode, 1)
        self.assertIn("Cannot convert mass to length", p.stderr)
        self.assertNotIn("Traceback", p.stderr)

    def test_json(self):
        p = self.run_cli("--json", "72 F to C")
        d = json.loads(p.stdout)
        for k in ("ok", "result", "display", "error", "mode"):
            self.assertIn(k, d)
        self.assertTrue(d["ok"])
        self.assertTrue(d["result"].startswith("22.2222"))
        p = self.run_cli("--json", "garbage(")
        self.assertEqual(p.returncode, 1)
        self.assertFalse(json.loads(p.stdout)["ok"])

    def test_9_9_9_cli_fast(self):
        t0 = time.monotonic()
        p = self.run_cli("9^9^9")
        self.assertEqual(p.returncode, 1)
        self.assertLess(time.monotonic() - t0, 5.0)

    def test_serve(self):
        lines = ["1+1", "10 miles to km", "bad(", "\x1ecommit 6*7",
                 "\x1ehistory", "ans", "", "\x1edelete 0", "\x1ehistory"]
        p = self.run_cli("--serve", stdin="\n".join(lines) + "\n")
        out = [json.loads(x) for x in p.stdout.splitlines()]
        self.assertEqual(len(out), len(lines))
        self.assertEqual(out[0]["result"], "2")
        self.assertEqual(out[1]["value"], "16.09344")
        self.assertFalse(out[2]["ok"])
        self.assertEqual(out[3]["result"], "42")
        self.assertEqual(out[4]["results"][0], "42")
        self.assertEqual(out[5]["result"], "42")
        self.assertFalse(out[6]["ok"])
        self.assertNotIn("42", out[8]["results"][:1])

    def test_script_mode(self):
        p = self.run_cli("--script")
        self.assertIn("\0prompt\x1fCalc\n", p.stdout)
        p = self.run_cli("--script", "10 miles to km", extra={"ROFI_RETV": "2"})
        self.assertIn("= 16.09344 km\0info\x1fcopy:16.09344 km\n", p.stdout)
        if os.path.exists(self.log):
            os.remove(self.log)
        p = self.run_cli("--script", "= 16.09344 km",
                         extra={"ROFI_RETV": "1", "ROFI_INFO": "copy:16.09344 km",
                                "ROFI_DATA": "10 miles to km"})
        self.assertEqual(p.returncode, 0)
        self.assertEqual(p.stdout, "")
        deadline = time.monotonic() + 3
        while time.monotonic() < deadline:
            with open(self.log) as f:
                log = f.read()
            if "notify-send" in log:
                break
            time.sleep(0.05)
        self.assertIn("wl-copy -- 16.09344 km", log)
        self.assertIn("notify-send -a Sleek Shell -- Copied 16.09344 km", log)


if __name__ == "__main__":
    unittest.main()
