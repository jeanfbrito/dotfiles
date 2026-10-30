"""Exercise the status line and PR hook without network access."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import time
import unittest


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "claude/.claude/statusline-command.sh"
HOOK = ROOT / "claude/.claude/hooks/pin-pr.sh"


class StatuslineTests(unittest.TestCase):
    def render(self, home, payload, pr=True):
        env = dict(os.environ, HOME=str(home), CLAUDE_STATUSLINE_PR="1" if pr else "0")
        result = subprocess.run(["bash", str(SCRIPT)], input=json.dumps(payload),
                                capture_output=True, text=True, env=env, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stderr, "")
        return re.sub(r"\x1b\[[0-9;]*m", "", result.stdout)

    def test_basic_render(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            text = self.render(home, {"cwd": str(home), "model": {"display_name": "Test Model"},
                                     "context_window": {"used_percentage": 25}}, pr=False)
            self.assertIn("Test Model", text)
            self.assertIn("ctx 25%", text)
            self.assertIn("~", text)

    def test_fresh_pinned_cache_renders_without_network(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            cache = home / ".cache/claude-statusline"
            cache.mkdir(parents=True)
            pin = "example/repository#42"
            (cache / "session-test.pr").write_text(pin)
            digest = hashlib.sha1(pin.encode()).hexdigest()[:16]
            state = {"v": 1, "fetchedAt": int(time.time()), "none": False, "error": None,
                     "failures": 0, "pr": {"number": 42, "state": "OPEN", "headRefName": "topic",
                     "headRefOid": "a" * 40, "passed": 3, "failed": 1, "pending": 2,
                     "isDraft": False, "reviewDecision": "APPROVED", "mergeable": "CONFLICTING",
                     "unresolvedThreads": 2}}
            (cache / f"pr-{digest}.json").write_text(json.dumps(state))
            # Any unexpected refresh must fail locally instead of contacting GitHub.
            binary = home / "bin"
            binary.mkdir()
            gh = binary / "gh"
            gh.write_text('#!/bin/sh\nprintf unexpected > "$HOME/network-called"\nexit 1\n')
            gh.chmod(0o700)
            env_path = os.environ.get("PATH", "")
            from unittest.mock import patch
            with patch.dict(os.environ, PATH=str(binary) + os.pathsep + env_path):
                text = self.render(home, {"cwd": str(home), "session_id": "test",
                                         "model": {"display_name": "Test Model"}})
            self.assertIn("#42", text)
            self.assertIn("✓3", text)
            self.assertIn("✗1", text)
            self.assertIn("…2", text)
            self.assertFalse((home / "network-called").exists())

    def test_pin_hook_writes_synthetic_pr(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            payload = {"session_id": "test", "tool_name": "Bash",
                       "tool_input": {"command": "gh pr view 42 -R example/repository"},
                       "tool_response": {"stdout": "https://github.com/example/repository/pull/42"}}
            result = subprocess.run(["bash", str(HOOK)], input=json.dumps(payload),
                                    env=dict(os.environ, HOME=str(home)), capture_output=True,
                                    text=True, timeout=10)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual((home / ".cache/claude-statusline/session-test.pr").read_text(),
                             "example/repository#42")


if __name__ == "__main__":
    unittest.main()
