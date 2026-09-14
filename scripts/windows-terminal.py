import os
from pathlib import Path
import subprocess
import sys
import tempfile


def main():
    import pynvim

    root = Path(__file__).resolve().parents[1]
    child = pynvim.attach(
        "child", argv=["nvim", "--embed", "-u", "NONE", "-i", "NONE", "-n", "--noplugin"]
    )
    try:
        child.ui_attach(100, 30, rgb=True)
        child.exec_lua("""
            local root, shell = ...
            local executable = vim.fn.executable
            vim.fn.executable = function(command)
              if shell == 'powershell' and command == 'pwsh' then return 0 end
              return executable(command)
            end
            dofile(root .. '/lua/config/settings.lua')
            vim.fn.executable = executable
            assert(vim.o.shell == shell, 'requested PowerShell was not selected')
            vim.cmd('terminal')
            assert(vim.bo.buftype == 'terminal', 'terminal buffer missing')
        """, str(root), os.environ["NVIM_WINDOWS_SHELL"])
        passed = child.exec_lua(r"""
            local buffer = vim.api.nvim_get_current_buf()
            local job = vim.bo.channel
            vim.api.nvim_chan_send(job, "Write-Output ('native-' + 'terminal-ok')\r\n")
            return vim.wait(15000, function()
              return table.concat(vim.api.nvim_buf_get_lines(buffer, 0, -1, false), '\n')
                :find('native-terminal-ok', 1, true) ~= nil
            end, 20)
        """)
        if not passed:
            raise AssertionError("PowerShell terminal did not display command output: " + repr(child.current.buffer[:]))
        print("PASS: attached-UI PowerShell terminal input and output")
    finally:
        try:
            child.command("qa!")
        except (EOFError, OSError):
            pass
        child.close()


if __name__ == "__main__":
    if sys.argv[1:] == ["--child"]:
        main()
    else:
        with tempfile.TemporaryDirectory(prefix="nvim-terminal-") as directory:
            env = dict(os.environ)
            for name in ("XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_STATE_HOME", "XDG_CACHE_HOME"):
                env[name] = str(Path(directory) / name)
            env["NVIM_APPNAME"] = "terminal-test"
            result = subprocess.run([sys.executable, __file__, "--child"], env=env, timeout=45)
            raise SystemExit(result.returncode)
