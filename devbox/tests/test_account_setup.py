"""Exercise account-switcher setup without network access or real credentials."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
TOOLS = ("codex_auth", "claude_swap")


class AccountSetupTest(unittest.TestCase):
    def setUp(self):
        scratch = ROOT / ".tmp" / "account-setup-tests"
        scratch.mkdir(parents=True, exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(dir=scratch, prefix="account setup ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.home = self.root / "home"
        self.bin = self.root / "bin"
        self.home.mkdir()
        self.bin.mkdir()
        for command in ("bash", "dirname", "basename", "cat", "grep"):
            (self.bin / command).symlink_to(shutil.which(command))
        self.env = dict(os.environ, HOME=str(self.home), PATH=str(self.bin),
                        DEVBOX_ROOT=str(ROOT / "devbox"), TEST_ROOT=str(self.root))
        for key in ("BASH_ENV", "NVM_DIR", "DEVBOX_SETUP_PATH", "DEVBOX_UTILS"):
            self.env.pop(key, None)

    def executable(self, path, content):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("#!/bin/bash\n" + content)
        path.chmod(0o755)

    def manager(self, name, directory=None):
        self.executable((directory or self.bin) / name, '''
printf '%s %s\\n' "${0##*/}" "$*" >> "$TEST_ROOT/calls"
if [[ "$*" == "tool list" ]]; then echo 'claude-swap v1.0'; fi
if [[ "$1" == "ls" ]]; then echo '@loongphy/codex-auth@1.0'; fi
exit "${INSTALL_EXIT:-0}"
''')

    def run_setup(self, tool, *args, ok=True):
        result = subprocess.run([str(ROOT / "devbox/setup" / tool), *args],
                                env=self.env, text=True, capture_output=True)
        self.assertEqual(result.returncode == 0, ok, result.stdout + result.stderr)
        return result

    def test_help_status_and_invalid_options_without_dependencies(self):
        for tool in TOOLS:
            self.run_setup(tool, "--help")
            result = self.run_setup(tool, "--status")
            self.assertIn("not found", result.stdout)
            self.run_setup(tool, "--unknown", ok=False)
            self.run_setup(tool, ok=False)
        self.assertFalse((self.root / "calls").exists())

    def test_install_update_and_failure_preserve_account_and_shell_files(self):
        files = [self.home / name for name in
                 (".codex/auth.json", ".claude/.credentials.json", ".bashrc", ".zshrc")]
        for path in files:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("keep me\n")
        self.manager("npm")
        self.manager("uv", self.home / ".local/bin")
        for _ in range(2):
            for tool in TOOLS:
                self.run_setup(tool)
        calls = (self.root / "calls").read_text().splitlines()
        self.assertEqual(calls.count("npm install -g @loongphy/codex-auth"), 2)
        self.assertEqual(calls.count("uv tool install --upgrade claude-swap"), 2)
        self.env["INSTALL_EXIT"] = "23"
        for tool in TOOLS:
            self.run_setup(tool, ok=False)
        for path in files:
            self.assertEqual(path.read_text(), "keep me\n")

    def test_nvm_default_node_in_noninteractive_shell(self):
        node_bin = self.home / ".nvm/versions/node/default/bin"
        self.manager("npm", node_bin)
        self.executable(self.home / ".nvm/nvm.sh",
                        'export PATH="$HOME/.nvm/versions/node/default/bin:$PATH"\n')
        self.run_setup("codex_auth")
        self.assertIn("npm install -g @loongphy/codex-auth\n",
                      (self.root / "calls").read_text())

    def test_discovery_and_dispatch_without_custom_setup(self):
        self.env["DEVBOX_CUSTOM_ROOT"] = str(self.root / "empty-custom")
        dispatcher = str(ROOT / "devbox/libexec/devbox-setup")
        result = subprocess.run([dispatcher, "--complete"], env=self.env,
                                text=True, capture_output=True, check=True)
        self.assertTrue(set(TOOLS) <= set(result.stdout.splitlines()))
        for tool in TOOLS:
            result = subprocess.run([dispatcher, tool, "--help"], env=self.env,
                                    text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
