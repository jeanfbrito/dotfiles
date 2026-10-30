"""Check file linking with a temporary HOME and no package installation."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class InstallTests(unittest.TestCase):
    def test_links_preserve_files_and_repeat_without_new_backup(self):
        with tempfile.TemporaryDirectory() as temporary:
            home = Path(temporary)
            original = home / ".zshrc"
            original.write_text("original shell settings\n")
            config = home / ".claude/settings.json"
            config.parent.mkdir()
            config.write_text('{"theme":"dark"}\n')
            env = dict(os.environ, HOME=str(home))
            for attempt in range(2):
                result = subprocess.run(["bash", str(ROOT / "install.sh"), "--link-only"],
                                        env=env, capture_output=True, text=True, timeout=30)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertTrue(original.is_symlink())
                self.assertEqual(original.resolve(), ROOT / "zsh/.zshrc")
                self.assertEqual(config.read_text(), '{"theme":"dark"}\n')
                backups = list((home / ".local/state/dotfiles").glob("backup.*"))
                self.assertEqual(len(backups), 1)
                self.assertEqual((backups[0] / ".zshrc").read_text(), "original shell settings\n")
                self.assertEqual(backups[0].stat().st_mode & 0o777, 0o700)
                self.assertFalse((ROOT / "zsh/.zshrc").is_symlink())
                self.assertTrue((home / ".claude/statusline-command.sh").is_symlink())
                self.assertTrue((home / ".claude/hooks/pin-pr.sh").is_symlink())

    def test_shell_has_no_inline_authentication_or_absolute_mac_home(self):
        text = (ROOT / "zsh/.zshrc").read_text()
        self.assertNotIn("ANTHROPIC_AUTH_TOKEN=", text)
        self.assertNotIn("/Users/", text)
        self.assertIn('[[ -r "$HOME/.zshrc.local" ]]', text)

    def test_installer_does_not_adopt_or_reset(self):
        text = (ROOT / "install.sh").read_text()
        self.assertNotIn("--adopt", text)
        self.assertNotIn("checkout .", text)
        self.assertIn("! -name '._*'", text)


if __name__ == "__main__":
    unittest.main()
