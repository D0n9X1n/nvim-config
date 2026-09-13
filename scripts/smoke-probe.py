#!/usr/bin/env python3
import json
import os
import pathlib
import re
import subprocess
import sys
import tempfile


ERROR = re.compile(r"(?:^|\n)(?:Error\b|.*\bE\d{2,}:)")
GUARD = pathlib.Path(__file__).with_name("smoke-guard.lua")


def probe(arguments, *, isolated=False, quiet=False):
    with tempfile.TemporaryDirectory(prefix="probe-", dir=os.environ.get("TMPDIR")) as tmp:
        marker = pathlib.Path(tmp) / "passed"
        env = dict(os.environ, NVIM_SMOKE_SUCCESS=str(marker))
        command = ["nvim", "--headless", "-i", "NONE", "-n"]
        if isolated:
            command += ["-u", "NONE", "--noplugin"]
        command += ["--cmd", "lua dofile(" + json.dumps(str(GUARD)) + ")"]
        if not isolated:
            command += ["--cmd", "lua dofile(vim.env.NVIM_SMOKE_NO_INSTALL)"]
        for argument in arguments:
            if argument.startswith("+"):
                command += ["-c", "lua _G.smoke_command(" + json.dumps(argument[1:]) + ")"]
            else:
                command.append(argument)
        command += ["-c", "lua _G.smoke_finish()", "-c", "qa!"]
        try:
            result = subprocess.run(command, env=env, capture_output=True, text=True, timeout=45)
        except subprocess.TimeoutExpired as error:
            print("Smoke probe timed out", file=sys.stderr)
            if error.stdout:
                print(error.stdout.decode() if isinstance(error.stdout, bytes) else error.stdout)
            return False
        output = result.stdout + result.stderr
        passed = result.returncode == 0 and marker.is_file() and not ERROR.search(output)
        if not passed and not quiet:
            print(output or "Smoke probe exited without a success marker", file=sys.stderr)
        return passed


def self_test():
    cases = {
        "healthy predicate": (["+lua assert(1 == 1)"], True),
        "Lua assertion": (["+lua assert(false, 'injected failure')"], False),
        "missing predicate module": (["+lua require('smoke_missing_module')"], False),
        "Vim command error": (["+SmokeCommandDoesNotExist"], False),
        "autocommand error": (["+autocmd User SmokeFault lua error('autocmd failure')", "+doautocmd User SmokeFault"], False),
        "error notification": (["+lua vim.notify('setup failure', vim.log.levels.ERROR)"], False),
        "scheduled error notification": (["+lua vim.schedule(function() vim.notify('async setup failure', vim.log.levels.ERROR) end)"], False),
        "missing success marker": (["+qa!"], False),
    }
    with tempfile.TemporaryDirectory(prefix="smoke-fault-", dir=os.environ.get("TMPDIR")) as tmp:
        startup = pathlib.Path(tmp) / "init.lua"
        startup.write_text("error('injected startup failure')\n")
        cases["startup error"] = (["-u", str(startup)], False)
        lazy = os.environ.get("NVIM_SMOKE_LAZY_SOURCE")
        if lazy:
            code = "vim.opt.rtp:prepend(" + json.dumps(str(pathlib.Path(lazy) / "lazy.nvim")) + "); require('lazy.core.config').options.root = vim.env.NVIM_SMOKE_LAZY_SOURCE; require('lazy.core.util').try(function() error('injected config failure') end, 'Failed to run config')"
            cases["lazy configuration error"] = (["+lua " + code], False)
        failures = []
        for name, (arguments, expected) in cases.items():
            actual = probe(arguments, isolated=True, quiet=not expected)
            if actual != expected:
                failures.append(name)
            print(("PASS" if actual == expected else "FAIL") + ": harness " + name)
        return not failures


if __name__ == "__main__":
    success = self_test() if sys.argv[1:] == ["--self-test"] else probe(sys.argv[1:])
    raise SystemExit(0 if success else 1)
