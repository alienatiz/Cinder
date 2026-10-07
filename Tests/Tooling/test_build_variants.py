from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]


class BuildVariantTests(unittest.TestCase):
    def configure(self, *arguments, channel='dev'):
        return subprocess.run(
            ['bash', '-c', '''
set -euo pipefail
source ./Build-Identity.sh
source ./Check-Toolchain.sh
RELEASE_CHANNEL="$1"
shift
cinder_configure_app_build "$@"
printf '%s\\n' "$TARGET_ARCH" "$CINDER_APP_OUTPUT" "$CINDER_APP_SCRATCH" "$CINDER_INSTALL_GUIDE"
''', 'build-variant-test', channel, *arguments],
            cwd=ROOT, capture_output=True, text=True,
        )

    def test_default_keeps_official_arm64_output(self):
        result = self.configure()
        self.assertEqual(result.returncode, 0, result.stderr)
        architecture, output, scratch, guide = result.stdout.splitlines()
        self.assertEqual(architecture, 'arm64')
        self.assertEqual(Path(output), ROOT / 'dist')
        self.assertEqual(Path(scratch), ROOT / '.build/golden-gate-app')
        self.assertEqual(guide, 'Docs/INSTALLING.md')
        self.assertEqual(self.configure('native').stdout, result.stdout)

    def test_intel_cannot_replace_official_outputs_or_test_cache(self):
        native = self.configure().stdout.splitlines()
        result = self.configure('intel-experimental')
        self.assertEqual(result.returncode, 0, result.stderr)
        architecture, output, scratch, guide = result.stdout.splitlines()
        self.assertEqual(architecture, 'x86_64')
        self.assertNotEqual(output, native[1])
        self.assertNotEqual(scratch, native[2])
        self.assertEqual(Path(output), ROOT / 'dist/intel-experimental')
        self.assertEqual(guide, 'Docs/INSTALLING-INTEL.md')
        self.assertTrue((ROOT / guide).is_file())

    def test_intel_is_limited_to_development_channel(self):
        for channel in ['stable', 'alpha', 'beta', 'rc']:
            with self.subTest(channel=channel):
                result = self.configure('intel-experimental', channel=channel)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('require the dev channel', result.stderr)
                self.assertEqual(result.stdout, '')
        self.assertEqual(self.configure(channel='stable').returncode, 0)

    def test_invalid_options_fail_before_building(self):
        for script in ['Build-App.command', 'Build-DMG.command']:
            for arguments in [('x86',), ('x86_64',), ('intel-experimental', 'extra')]:
                with self.subTest(script=script, arguments=arguments):
                    result = subprocess.run(['bash', script, *arguments], cwd=ROOT,
                                            capture_output=True, text=True)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn('variant', result.stderr)
                    self.assertEqual(result.stdout, '')


if __name__ == '__main__':
    unittest.main()
