#!/usr/bin/env python3
"""Integration checks with real mise and a disposable HOME/checkout; no live setup."""
import os
import json
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import unittest

SOURCE = Path(__file__).resolve().parents[2]
MISE = str(Path(os.environ['MISE_BIN']).resolve())


class Migration(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='dotfiles-mise-test-')
        self.addCleanup(self.temp.cleanup)
        base = Path(self.temp.name)
        self.repo = base / 'repo'
        self.home = base / 'home'
        self.home.mkdir()
        shutil.copytree(SOURCE, self.repo, symlinks=True,
                        ignore=shutil.ignore_patterns('.git', 'persistent', 'dotbot',
                                                     '.claude', '.codex', '__pycache__'))
        self.env = {k: v for k, v in os.environ.items()
                    if not k.startswith(('MISE_', 'DEVBOX_', 'XDG_', 'DOTFILES_'))}
        self.env.update(HOME=str(self.home), MISE_BIN=MISE, MISE_YES='1',
                        MISE_DATA_DIR=str(base / 'data'), MISE_CACHE_DIR=str(base / 'cache'),
                        MISE_STATE_DIR=str(base / 'state'),
                        XDG_CONFIG_HOME=str(self.home / '.config'),
                        PATH=str(Path(MISE).parent) + ':' + os.environ['PATH'])

    def run_cmd(self, *args, ok=True):
        process = subprocess.Popen(args, cwd=self.repo, env=self.env, text=True,
                                   stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                   start_new_session=True)
        try:
            output, _ = process.communicate(timeout=120)
        except subprocess.TimeoutExpired:
            # Hooks can spawn descendants that keep stdout open after their shell dies.
            os.killpg(process.pid, signal.SIGKILL)
            output, _ = process.communicate()
            self.fail('Command timed out: ' + repr(args) + '\n' + output)
        result = subprocess.CompletedProcess(args, process.returncode, output)
        if ok:
            self.assertEqual(result.returncode, 0, result.stdout)
        return result

    def apply(self):
        return self.run_cmd('bash', str(self.repo / 'install'), '--only', 'dotfiles')

    def test_links_backups_and_idempotence(self):
        (self.home / '.bashrc').write_text('existing rc\n')
        self.apply()
        self.assertEqual((self.home / '.bashrc').resolve(), self.repo / 'bashrc')
        backups = list(self.home.glob('.bashrc.before-mise.*'))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_text(), 'existing rc\n')
        self.assertEqual((self.home / '.config/nvim').resolve(), self.repo / 'nvim')
        self.assertEqual((self.home / '.codex/sessions').resolve(),
                         self.repo / 'persistent/codex/sessions')
        history = self.home / '.claude/history.jsonl'
        history.write_text('history stays\n')
        self.apply()
        self.assertEqual(history.read_text(), 'history stays\n')
        self.assertEqual(list(self.home.glob('.bashrc.before-mise.*')), backups)
        # Tools/tasks are available globally without a project cwd.
        result = self.run_cmd(MISE, '-C', str(self.home), 'tasks', 'ls')
        self.assertIn('setup:shell_fallback', result.stdout)
        self.env['PATH'] = '/usr/bin:/bin'
        result = self.run_cmd(MISE, '-C', str(self.home), 'run', 'status')
        self.assertIn('up to date', result.stdout)
        self.assertFalse(Path(self.env['MISE_DATA_DIR'], 'installs').exists())

    def test_setup_through_home_symlink(self):
        self.apply()
        self.env['DEVBOX_ROOT'] = str(self.home / '.devbox')
        direct = self.run_cmd('bash', str(self.home / '.devbox/setup/gdu'), '--help')
        self.assertIn('Usage:', direct.stdout)
        dispatched = self.run_cmd('bash', str(self.home / '.devbox/libexec/devbox'),
                                  'setup', 'gdu', '--help')
        self.assertIn('Usage:', dispatched.stdout)
        status = self.run_cmd('bash', str(self.home / '.devbox/libexec/devbox'),
                              'setup', 'gdu', '--status')
        self.assertNotIn('No such file', status.stdout)

    def test_preserves_existing_data_and_agent_config(self):
        for name in ['Downloads', '.codex/sessions', '.claude/projects']:
            folder = self.home / name
            folder.mkdir(parents=True)
            (folder / 'keep').write_text('data')
        settings = self.home / '.claude/settings.json'
        settings.write_text('{"keep": true}')
        self.apply()
        for name in ['Downloads', '.codex/sessions', '.claude/projects']:
            self.assertFalse((self.home / name).is_symlink())
            self.assertEqual((self.home / name / 'keep').read_text(), 'data')
        self.assertEqual(settings.read_text(), '{"keep": true}')

    def test_empty_lazygit_and_nonempty_lazygit(self):
        cfg = self.home / '.config/lazygit/config.yml'
        cfg.parent.mkdir(parents=True)
        cfg.touch()
        self.apply()
        self.assertTrue(cfg.is_symlink())
        cfg.unlink()
        cfg.write_text('user: config\n')
        self.apply()
        self.assertFalse(cfg.is_symlink())
        self.assertEqual(cfg.read_text(), 'user: config\n')

    def test_preview_does_not_write_home_or_persistent(self):
        (self.home / '.bashrc').write_text('existing rc\n')
        before = sorted(str(p.relative_to(self.home)) for p in self.home.rglob('*'))
        preview = self.run_cmd('bash', str(self.repo / 'install'), '--dry-run', '--only', 'dotfiles', ok=False)
        self.assertIn('refusing to overwrite existing files', preview.stdout)
        after = sorted(str(p.relative_to(self.home)) for p in self.home.rglob('*'))
        self.assertEqual(before, after)
        self.assertEqual((self.home / '.bashrc').read_text(), 'existing rc\n')
        self.assertFalse((self.repo / 'persistent').exists())
        (self.home / '.bashrc').unlink()
        self.run_cmd('bash', str(self.repo / 'install'), '--dry-run', '--only', 'dotfiles')
        self.assertFalse((self.repo / 'persistent').exists())
        self.assertFalse((self.home / '.config').exists())

    def test_private_config_and_guarded_links(self):
        private = self.repo / 'persistent/custom'
        private.mkdir(parents=True)
        (private / 'private.conf').write_text('private')
        (private / 'mise.toml').write_text('''[dotfiles]
"~/.private-test" = "private.conf"
[tasks."private:test"]
run = 'echo private-ok'
''')
        self.apply()
        self.assertEqual((self.home / '.private-test').resolve(), private / 'private.conf')
        out = self.run_cmd(MISE, '-C', str(self.home), 'run', 'private:test')
        self.assertIn('private-ok', out.stdout)
        (private / 'mise.toml').unlink()
        self.apply()
        self.assertFalse((self.home / '.config/mise/conf.d/60-dotfiles-private').is_symlink())

    def test_reserved_private_registration_conflict_stops_install(self):
        slot = self.home / '.config/mise/conf.d/60-dotfiles-private'
        slot.mkdir(parents=True)
        config = '[bootstrap.hooks]\npre-dotfiles = \'touch "$HOME/stale-hook-ran"\'\n'
        (slot / 'mise.toml').write_text(config)
        out = self.run_cmd('bash', str(self.repo / 'install'), '--only', 'dotfiles', ok=False)
        self.assertNotEqual(out.returncode, 0)
        self.assertIn('Refusing to replace', out.stdout)
        self.assertEqual((slot / 'mise.toml').read_text(), config)
        self.assertFalse((self.home / 'stale-hook-ran').exists())

    def test_unowned_private_registration_symlink_is_preserved(self):
        unrelated = self.home.parent / 'unrelated-config'
        unrelated.mkdir()
        (unrelated / 'mise.toml').write_text('[env]\nUNRELATED_CONFIG = "retained"\n')
        slot = self.home / '.config/mise/conf.d/60-dotfiles-private'
        slot.parent.mkdir(parents=True)
        slot.symlink_to(unrelated, target_is_directory=True)
        for selected in [False, True]:
            if selected:
                private = self.repo / 'persistent/custom'
                private.mkdir(parents=True)
                (private / 'mise.toml').write_text('[env]\nPRIVATE_CONFIG = "selected"\n')
            out = self.run_cmd('bash', str(self.repo / 'install'), '--only', 'dotfiles', ok=False)
            self.assertNotEqual(out.returncode, 0)
            self.assertIn('unowned registration', out.stdout)
            self.assertEqual(slot.resolve(), unrelated)
            self.assertTrue((unrelated / 'mise.toml').exists())

    def test_legacy_private_config_fails_loudly(self):
        private = self.repo / 'persistent/custom'
        private.mkdir(parents=True)
        (private / 'install.conf.yaml').write_text('- link: {}\n')
        out = self.run_cmd('bash', str(self.repo / 'install'), '--only', 'dotfiles', ok=False)
        self.assertNotEqual(out.returncode, 0)
        self.assertIn('Private Dotbot config found', out.stdout)
        self.assertFalse((self.home / '.bashrc').exists())

    def test_setup_dispatch_and_custom_precedence(self):
        self.apply()
        self.env['DEVBOX_ROOT'] = str(self.repo / 'devbox')
        self.env['DEVBOX_DEBUG'] = ''
        dispatcher = str(self.repo / 'devbox/libexec/devbox-setup')
        out = self.run_cmd('bash', dispatcher, 'gdu', '--status')
        self.assertIn('setup:gdu', out.stdout)
        custom = self.home / 'custom-setup'
        custom.mkdir()
        script = custom / 'gdu'
        script.write_text('#!/bin/sh\nprintf "custom:%s\\n" "$1"\n')
        script.chmod(0o755)
        self.env['DEVBOX_SETUP_PATH'] = str(custom) + ':' + str(self.repo / 'devbox/setup')
        out = self.run_cmd('bash', dispatcher, 'gdu', '--status')
        self.assertEqual(out.stdout.strip(), 'custom:--status')

    def test_external_inhouse_overlay_merge_and_isolation(self):
        private = self.home.parent / 'inhouse repo'
        private.mkdir()
        (private / 'private.conf').write_text('private')
        (private / 'mise.toml').write_text('''[vars]
dotfiles_private_root = "{{config_source | canonicalize | dirname}}"
[tools]
"aqua:astral-sh/uv" = "0.13.0"
[dotfiles]
"~/.condarc" = "private.conf"
[tasks."inhouse:test"]
dir = "{{vars.dotfiles_private_root}}"
run = 'cat private.conf'
''')
        (private / 'shell').mkdir()
        (private / 'shell/00_test.sh').write_text('export INHOUSE_EXAMPLE=loaded\n')
        (private / 'devbox/snippets').mkdir(parents=True)
        (private / 'devbox/snippets/inhouse-example').write_text('#!/bin/sh\necho private\n')
        (private / 'devbox/setup').mkdir()
        setup = private / 'devbox/setup/inhouse-example'
        setup.write_text('#!/bin/sh\nprintf "inhouse:%s\\n" "$1"\n')
        setup.chmod(0o755)
        self.env['DOTFILES_CUSTOM_ROOT'] = os.path.relpath(private, self.repo)
        self.apply()
        self.assertTrue((self.repo / 'persistent/custom').is_symlink())
        self.assertEqual((self.home / '.condarc').resolve(), private / 'private.conf')
        for directory in [self.home, self.repo, private]:
            out = self.run_cmd(MISE, '-C', str(directory), 'run', 'inhouse:test')
            self.assertIn('private', out.stdout)
        self.assertEqual((private / 'private.conf').read_text(), 'private')
        out = self.run_cmd('bash', '--noprofile', '--norc', '-c',
                           'source "$HOME/.shell/common/50_custom.sh"; printf %s "$INHOUSE_EXAMPLE"')
        self.assertEqual(out.stdout, 'loaded')
        devbox = str(self.home / '.devbox/libexec/devbox')
        out = self.run_cmd('bash', devbox, 'snippets', '--list')
        self.assertIn('inhouse-example', out.stdout)
        out = self.run_cmd('bash', devbox, 'setup', 'inhouse-example', 'argument')
        self.assertEqual(out.stdout, 'inhouse:argument\n')
        out = self.run_cmd(MISE, '-C', str(self.home), 'ls', 'aqua:astral-sh/uv')
        self.assertIn('0.13.0', out.stdout)
        del self.env['DOTFILES_CUSTOM_ROOT']
        self.apply()  # Later runs reuse the private alias without an environment override.
        # Higher-precedence machine overrides stay outside both repositories.
        (self.home / '.config/mise/config.toml').write_text(
            '[dotfiles]\n"~/.condarc" = { source = "' + str(self.repo / 'condarc') + '" }\n')
        self.apply()
        self.assertEqual((self.home / '.condarc').resolve(), self.repo / 'condarc')

    def test_migrates_private_directory_links_without_data_loss(self):
        private = self.repo / 'persistent/custom'
        private.mkdir(parents=True)
        yaml = private / 'install.conf.yaml'
        yaml.write_text('''- defaults:
    link:
      create: true
      relink: true
- create:
    - ../example/sessions
    - ~/private-created
- link:
    ~/.example/sessions:
      path: ../example/sessions
      if: '[ ! -e "$HOME/.example/sessions" ] || [ -L "$HOME/.example/sessions" ]'
''')
        self.run_cmd(sys.executable, str(self.repo / 'mise/scripts/migrate-private'), str(yaml))
        (self.home / '.bashrc').write_text('existing rc')
        self.apply()
        self.assertTrue((self.home / '.persistent').is_symlink())
        self.assertTrue(list(self.home.glob('.bashrc.before-mise.*')))
        self.assertTrue((self.home / 'private-created').is_dir())
        self.assertFalse((private / '~').exists())
        target = self.home / '.example/sessions'
        self.assertEqual(target.resolve(), self.repo / 'persistent/example/sessions')
        target.unlink()
        target.mkdir()
        (target / 'keep').write_text('private data')
        self.apply()
        self.assertEqual((target / 'keep').read_text(), 'private data')
        self.assertTrue(yaml.exists())

    def test_converter_rejects_unsupported_steps_before_writing(self):
        private = self.repo / 'persistent/custom'
        private.mkdir(parents=True)
        yaml = private / 'install.conf.yaml'
        original = '- create: [safe-directory]\n- shell: [echo unsupported]\n'
        yaml.write_text(original)
        out = self.run_cmd(sys.executable, str(self.repo / 'mise/scripts/migrate-private'),
                           str(yaml), ok=False)
        self.assertNotEqual(out.returncode, 0)
        self.assertIn('Unsupported action', out.stdout)
        self.assertEqual(yaml.read_text(), original)
        for name in ['mise.toml', 'mise-prepare.sh', 'mise-persistent.tsv', 'safe-directory']:
            self.assertFalse((private / name).exists())

    def test_converter_rejects_home_escape_and_absolute_create(self):
        outside = self.home.parent / 'outside-created'
        cases = [
            [{'create': ['~/../outside-created']}],
            [{'create': [str(outside)]}],
            [{'link': {'~/../escaped': 'source'}}],
            [{'link': {'~/../escaped': {'path': 'source',
               'if': '[ ! -e "$HOME/../escaped" ] || [ -L "$HOME/../escaped" ]'}}}],
        ]
        for index, data in enumerate(cases):
            with self.subTest(index=index):
                private = self.repo / ('conversion-' + str(index))
                private.mkdir()
                yaml = private / 'install.conf.yaml'
                yaml.write_text(json.dumps(data))
                out = self.run_cmd(sys.executable, str(self.repo / 'mise/scripts/migrate-private'),
                                   str(yaml), ok=False)
                self.assertNotEqual(out.returncode, 0)
                for name in ['mise.toml', 'mise-prepare.sh', 'mise-persistent.tsv']:
                    self.assertFalse((private / name).exists())
        self.assertFalse(outside.exists())
        self.assertFalse((self.home.parent / 'escaped').exists())

    def test_guarded_links_rejects_home_escape(self):
        manifest = self.repo / 'unsafe-links.tsv'
        for target in ['../escaped', '/absolute-target', 'nested/../../escaped']:
            with self.subTest(target=target):
                manifest.write_text('dir\t' + target + '\tgenerated-source\n')
                out = self.run_cmd('bash', str(self.repo / 'mise/scripts/guarded-links'),
                                   str(manifest), ok=False)
                self.assertNotEqual(out.returncode, 0)
                self.assertIn('must stay inside HOME', out.stdout)
                self.assertFalse((self.repo / 'generated-source').exists())
        self.assertFalse((self.home.parent / 'escaped').exists())

    def test_replaces_dangling_links_and_preserves_real_dotfiles(self):
        (self.home / '.dotfiles').mkdir()
        (self.home / '.dotfiles/keep').write_text('checkout')
        (self.home / '.claude').mkdir()
        (self.home / '.claude/history.jsonl').write_text('existing history')
        (self.home / 'Downloads').symlink_to('/nonexistent/dotfiles-test-source')
        self.apply()
        self.assertEqual((self.home / 'Downloads').resolve(), self.repo / 'persistent/Downloads')
        self.assertEqual((self.home / '.dotfiles/keep').read_text(), 'checkout')
        self.assertEqual((self.home / '.claude/history.jsonl').read_text(), 'existing history')

    def test_preserved_special_setup_tasks_are_callable(self):
        self.apply()
        for name in ['shell_fallback', 'tmux', 'nvm', 'pyenv', 'conda', 'codex', 'claude']:
            result = self.run_cmd(MISE, '-C', str(self.home), 'run', 'setup:' + name, '--', '--help')
            self.assertIn('Usage:', result.stdout)
        self.assertFalse((self.home / '.nvm').exists())
        self.assertFalse((self.home / '.pyenv').exists())

    def test_standalone_devbox_install_and_uninstall(self):
        self.env['PATH'] = '/usr/bin:/bin'
        self.run_cmd('bash', str(self.repo / 'devbox/install.sh'))
        self.run_cmd('bash', str(self.repo / 'devbox/install.sh'))
        rc = self.home / '.bashrc'
        self.assertEqual(rc.read_text().count('# >>> devbox initialize >>>'), 1)
        self.assertIn('\"' + MISE + '\" activate bash', rc.read_text())
        self.assertIn('\"' + MISE + '\" activate zsh', (self.home / '.zshrc').read_text())
        self.assertIn('\"' + MISE + '\" activate fish', (self.home / '.config/fish/conf.d/devbox.fish').read_text())
        for shell, source in [('bash', '.bashrc'), ('zsh', '.zshrc'),
                              ('fish', '.config/fish/conf.d/devbox.fish')]:
            out = self.run_cmd(shell, '-c', 'source \"$HOME/' + source + '\"')
            self.assertNotIn('command not found', out.stdout)
            self.assertNotIn('Unknown command', out.stdout)
        self.run_cmd('bash', str(self.repo / 'devbox/install.sh'), '--uninstall')
        self.assertNotIn('activate bash', rc.read_text())
        self.assertFalse((self.home / '.devbox').is_symlink())
        self.assertFalse((self.home / '.config/fish/conf.d/devbox.fish').exists())
        self.assertTrue((self.home / '.config/mise/conf.d/50-dotfiles').is_symlink())


if __name__ == '__main__':
    unittest.main(verbosity=2)
