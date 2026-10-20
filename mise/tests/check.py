#!/usr/bin/env python3
"""Exercise native mise composition in disposable checkouts, HOME and state."""
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import tempfile
import unittest

SOURCE = Path(__file__).resolve().parents[2]
MISE = str(Path(os.environ['MISE_BIN']).resolve())


class NativeMise(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='dotfiles-native-test-')
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.repo = self.base / 'repo'
        self.home = self.base / 'home'
        self.home.mkdir()
        shutil.copytree(SOURCE, self.repo, symlinks=True,
                        ignore=shutil.ignore_patterns('.git', 'persistent', '.orca',
                                                     '__pycache__', '.claude', '.codex'))
        self.env = {k: v for k, v in os.environ.items()
                    if not k.startswith(('MISE_', 'DEVBOX_', 'XDG_', 'DOTFILES_'))}
        self.env.update(HOME=str(self.home), MISE_BIN=MISE, MISE_YES='1',
                        MISE_DATA_DIR=str(self.base / 'data'),
                        MISE_CACHE_DIR=str(self.base / 'cache'),
                        MISE_STATE_DIR=str(self.base / 'state'),
                        XDG_CONFIG_HOME=str(self.home / '.config'),
                        PATH=str(Path(MISE).parent) + ':' + os.environ['PATH'])

    def cmd(self, *args, cwd=None, ok=True):
        process = subprocess.Popen(args, cwd=cwd or self.repo, env=self.env,
                                   text=True, stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT, start_new_session=True)
        try:
            output, _ = process.communicate(timeout=45)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            output, _ = process.communicate()
            self.fail('Timed out: ' + repr(args) + '\n' + output)
        result = subprocess.CompletedProcess(args, process.returncode, output)
        if ok:
            self.assertEqual(result.returncode, 0, result.stdout)
        return result

    def apply(self, *args):
        return self.cmd('bash', str(self.repo / 'install'), '--only', 'dotfiles', *args)

    def mise(self, *args, cwd=None, ok=True):
        return self.cmd(MISE, *args, cwd=cwd or self.home, ok=ok)

    def private(self, path=None):
        path = path or self.repo / 'persistent/custom'
        path.mkdir(parents=True)
        (path / 'mise.toml').write_text('''[vars]
private_root = "{{config_source | canonicalize | dirname}}"
[tools]
"aqua:astral-sh/uv" = "0.13.1"
[env]
PRIVATE_MARKER = "inhouse"
_.path = ["{{vars.private_root}}/bin"]
[dotfiles]
"~/.config/private.conf" = "private.conf"
"~/.config/dotfiles/bash.sh" = "bash.sh"
"~/.config/dotfiles/zsh.zsh" = "zsh.zsh"
"~/.config/dotfiles/fish.fish" = "fish.fish"
[tasks."inhouse:check"]
dir = "{{vars.private_root}}"
run = "cat private.conf"
[tasks."inhouse:file"]
dir = "{{vars.private_root}}"
file = "{{vars.private_root}}/operations/check"
''')
        (path / 'private.conf').write_text('private-content\n')
        (path / 'bash.sh').write_text('export PRIVATE_SHELL_MARKER=loaded\n')
        (path / 'zsh.zsh').write_text('export PRIVATE_SHELL_MARKER=loaded\n')
        (path / 'fish.fish').write_text('set -gx PRIVATE_SHELL_MARKER loaded\n')
        (path / 'operations').mkdir()
        task = path / 'operations/check'
        task.write_text('#!/bin/sh\ncat private.conf; printf \"arg=%s\\n\" \"$1\"\n')
        task.chmod(0o755)
        (path / 'bin').mkdir()
        tool = path / 'bin/private-command'
        tool.write_text('#!/bin/sh\nprintf "private-bin\\n"\n')
        tool.chmod(0o755)
        return path

    def test_native_links_backups_and_idempotence(self):
        (self.home / '.bashrc').write_text('existing rc\n')
        self.apply()
        self.assertEqual((self.home / '.bashrc').resolve(), self.repo / 'bashrc')
        backups = list(self.home.glob('.bashrc.before-mise.*'))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_text(), 'existing rc\n')
        history = self.home / '.claude/history.jsonl'
        history.write_text('preserved\n')
        self.mise('run', 'dotfiles')
        self.assertEqual(history.read_text(), 'preserved\n')
        self.assertEqual(list(self.home.glob('.bashrc.before-mise.*')), backups)
        self.assertFalse((self.home / '.devbox').exists())
        self.assertEqual((self.home / '.config/nvim').resolve(), self.repo / 'nvim')

    def test_existing_real_data_and_agent_config_preserved(self):
        for name in ['Downloads', '.codex/sessions', '.claude/projects']:
            folder = self.home / name
            folder.mkdir(parents=True)
            (folder / 'keep').write_text('data')
        settings = self.home / '.claude/settings.json'
        settings.write_text('{"local":true}')
        self.apply()
        self.assertEqual(settings.read_text(), '{"local":true}')
        for name in ['Downloads', '.codex/sessions', '.claude/projects']:
            self.assertFalse((self.home / name).is_symlink())
            self.assertEqual((self.home / name / 'keep').read_text(), 'data')

    def test_global_native_tasks_and_status_without_installing_tools(self):
        self.apply()
        self.env['PATH'] = '/usr/bin:/bin'
        # Tasks receive mise's own MISE_BIN automatically, even outside PATH.
        self.env.pop('MISE_BIN')
        names = self.mise('tasks', 'ls', '--name-only').stdout.splitlines()
        self.assertIn('shell:fallback', names)
        self.assertIn('ssh:authorize', names)
        self.assertNotIn('shell-fallback', names)
        self.assertFalse(any(n.startswith('setup') for n in names))
        self.assertIn('up to date', self.mise('run', 'status').stdout)
        self.assertFalse((self.base / 'data/installs').exists())

    def test_public_private_composition_and_project_precedence(self):
        private = self.private()
        self.apply()
        for cwd in [self.home, self.repo, private]:
            self.assertIn('private-content', self.mise('run', 'inhouse:check', cwd=cwd).stdout)
            result = self.mise('run', 'inhouse:file', 'with spaces', cwd=cwd)
            self.assertIn('private-content', result.stdout)
            self.assertIn('arg=with spaces', result.stdout)
        env = json.loads(self.mise('env', '--json').stdout)
        self.assertEqual(env['PRIVATE_MARKER'], 'inhouse')
        self.assertEqual(env['HF_HOME'], str(self.repo / 'persistent/cache/huggingface'))
        self.assertIn(str(self.repo / 'bin'), env['PATH'])
        self.assertIn(str(private / 'bin'), env['PATH'])
        self.assertEqual((self.home / '.config/private.conf').resolve(), private / 'private.conf')
        # User config overrides global fragments; project still has native precedence.
        config = self.home / '.config/mise/config.toml'
        config.write_text('[env]\nPRIVATE_MARKER="user"\n')
        self.assertEqual(json.loads(self.mise('env', '--json').stdout)['PRIVATE_MARKER'], 'user')
        project = self.base / 'project'
        project.mkdir()
        (project / 'mise.toml').write_text('[env]\nPRIVATE_MARKER="project"\n')
        self.mise('trust', str(project / 'mise.toml'))
        self.assertEqual(json.loads(self.mise('env', '--json', cwd=project).stdout)['PRIVATE_MARKER'], 'project')
        ls = json.loads(self.mise('ls', '--json', '--offline', '--quiet').stdout)
        self.assertEqual(ls['aqua:astral-sh/uv'][0]['requested_version'], '0.13.1')

    def test_external_private_repo_with_spaces_and_reuse(self):
        private = self.private(self.base / 'inhouse space')
        self.env['DOTFILES_CUSTOM_ROOT'] = str(private)
        self.apply()
        self.env.pop('DOTFILES_CUSTOM_ROOT')
        self.apply()
        self.assertIn('private-content', self.mise('run', 'inhouse:check').stdout)
        self.assertFalse((self.repo / 'persistent/custom').exists())
        self.assertEqual((self.home / '.config/mise/conf.d/60-dotfiles-private').resolve(), private)

    def test_relative_private_path_canonicalized(self):
        private = self.private(self.base / 'inhouse')
        self.env['DOTFILES_CUSTOM_ROOT'] = '../inhouse'
        self.apply()
        self.assertEqual((self.home / '.config/mise/conf.d/60-dotfiles-private').resolve(), private)
        self.assertIn('private-content', self.mise('run', 'inhouse:check').stdout)

    def test_private_requires_native_manifest(self):
        private = self.repo / 'persistent/custom'
        private.mkdir(parents=True)
        (private / 'install.conf.yaml').write_text('- shell: [echo legacy]\n')
        result = self.apply_result()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('requires mise.toml', result.stdout)
        self.assertFalse((self.home / '.bashrc').exists())

    def apply_result(self):
        return self.cmd('bash', str(self.repo / 'install'), '--only', 'dotfiles', ok=False)

    def test_conflicting_registration_preserves_unrelated_data(self):
        slot = self.home / '.config/mise/conf.d/60-dotfiles-private'
        slot.mkdir(parents=True)
        (slot / 'keep').write_text('untouched')
        self.assertNotEqual(self.apply_result().returncode, 0)
        self.assertEqual((slot / 'keep').read_text(), 'untouched')
        self.assertFalse((self.home / '.bashrc').exists())

    def test_conflicting_unowned_symlink_preserved(self):
        unrelated = self.base / 'unrelated'
        unrelated.mkdir()
        (unrelated / 'mise.toml').write_text('[env]\nUNRELATED="yes"\n')
        self.private()
        slot = self.home / '.config/mise/conf.d/60-dotfiles-private'
        slot.parent.mkdir(parents=True)
        slot.symlink_to(unrelated)
        result = self.apply_result()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(slot.resolve(), unrelated)

    def test_dry_run_isolates_all_writes(self):
        (self.home / '.bashrc').write_text('keep\n')
        before = sorted(str(p.relative_to(self.home)) for p in self.home.rglob('*'))
        self.cmd('bash', str(self.repo / 'install'), '--dry-run', '--only', 'dotfiles', ok=False)
        self.assertEqual(before, sorted(str(p.relative_to(self.home)) for p in self.home.rglob('*')))
        self.assertEqual((self.home / '.bashrc').read_text(), 'keep\n')
        self.assertFalse((self.repo / 'persistent').exists())

    def test_native_shell_env_and_explicit_private_extension(self):
        self.private()
        self.apply()
        for shell, args in [('bash', ['--noprofile', '--norc']), ('zsh', ['-f'])]:
            if not shutil.which(shell):
                continue
            rc = '.bashrc' if shell == 'bash' else '.zshrc'
            result = self.cmd(shell, *args, '-c',
                f'source "$HOME/{rc}"; test "$PRIVATE_SHELL_MARKER" = loaded || exit 1; '
                'private-command; catpick --help >/dev/null', cwd=self.home)
            self.assertIn('private-bin', result.stdout)
        if shutil.which('fish'):
            result = self.cmd('fish', '--no-config', '-c',
                'source "$HOME/.config/fish/config.fish"; test "$PRIVATE_SHELL_MARKER" = loaded; or exit 1; private-command; catpick --help >/dev/null', cwd=self.home)
            self.assertIn('private-bin', result.stdout)

    def test_shell_preference_in_native_user_config(self):
        self.apply()
        self.mise('run', 'shell:fallback', '/bin/sh')
        env = json.loads(self.mise('env', '--json').stdout)
        self.assertEqual(env['DOTFILES_LOGIN_SHELL'], '/bin/sh')
        self.assertNotIn('DOTFILES_LOGIN_SHELL', (self.repo / 'bashrc').read_text())
        self.mise('run', 'shell:fallback', 'off')
        self.assertEqual(json.loads(self.mise('env', '--json').stdout)['DOTFILES_LOGIN_SHELL'], '')

    def test_ssh_authorization_is_validated_and_idempotent(self):
        self.apply()
        key = self.base / 'key'
        self.cmd('ssh-keygen', '-q', '-t', 'ed25519', '-f', str(key), '-N', '')
        public = key.with_suffix('.pub').read_text().strip()
        self.mise('run', 'ssh:authorize', public)
        self.mise('run', 'ssh:authorize', public)
        authorized = self.home / '.ssh/authorized_keys'
        self.assertEqual(authorized.read_text(), public + '\n')
        self.assertEqual(authorized.stat().st_mode & 0o777, 0o600)
        self.assertNotEqual(self.mise('run', 'ssh:authorize', 'not-a-key', ok=False).returncode, 0)
        self.assertEqual(authorized.read_text(), public + '\n')

    def test_skills_nonempty_library_not_overwritten(self):
        self.apply()
        library = self.repo / 'persistent/skills'
        library.mkdir(parents=True)
        (library / 'keep').write_text('data')
        result = self.mise('run', 'skills:init', ok=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('nonempty', result.stdout)
        self.assertEqual((library / 'keep').read_text(), 'data')

    def test_project_file_task_discovery_retains_native_defaults(self):
        self.apply()
        project = self.base / 'file-task-project'
        task_dir = project / 'mise-tasks'
        task_dir.mkdir(parents=True)
        (project / 'mise.toml').write_text('[env]\nPROJECT_TASK="yes"\n')
        task = task_dir / 'hello'
        task.write_text('#!/bin/sh\nprintf "native-discovery=%s\\n" "$PROJECT_TASK"\n')
        task.chmod(0o755)
        self.mise('trust', str(project / 'mise.toml'))
        result = self.mise('run', 'hello', cwd=project)
        self.assertIn('native-discovery=yes', result.stdout)

    def test_profiles_resolve_through_global_fragments(self):
        self.apply()
        output = self.mise('-E', 'apps', 'ls', '--json', '--offline', '--quiet').stdout
        tools = json.loads(output)
        # Offline ls omits unresolved `latest` tools; pinned declarations still
        # prove the profile is loaded from HOME without project discovery.
        for tool in ['github:lemoony/snipkit',
                     'github:yaojie-shen/Skills-Manager-TUI', 'http:code']:
            self.assertIn(tool, tools)
        self.assertFalse((self.base / 'data/installs').exists())
        self.mise('-E', 'system', 'bootstrap', '--only', 'packages', '--dry-run')

    def test_guarded_links_reject_home_traversal(self):
        manifest = self.base / 'bad.tsv'
        manifest.write_text('dir\t../escape\tpersistent/escape\n')
        result = self.cmd('bash', str(self.repo / 'mise/scripts/guarded-links'),
                          str(manifest), str(self.repo), ok=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.base / 'escape').exists())


if __name__ == '__main__':
    unittest.main(verbosity=2)
