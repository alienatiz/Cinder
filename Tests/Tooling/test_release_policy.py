from pathlib import Path
import importlib.util
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('release_policy', ROOT / 'Tools/Check-Release.py')
policy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(policy)
SHA = 'a' * 40


class ReleasePolicyTests(unittest.TestCase):
    def plan(self, version='1.0.0-dev', ref='refs/heads/dev', event='push', base='', on_main=False, **options):
        return policy.build_plan(version, ref, event, base, SHA, on_main, **options)

    def test_development_builds_are_not_releases(self):
        result = self.plan()
        self.assertEqual(result['channel'], 'dev')
        self.assertEqual(result['artifact'], 'Cinder-dev-1.0.0-dev-aaaaaaa-arm64')
        self.assertEqual(self.plan(event='workflow_dispatch')['channel'], 'staging')
        for version in ['1.0.0-dev', '1.0.0-dev.1', '1.0.0-alpha.1', '1.0.0-beta.1', '1.0.0-rc.1']:
            with self.subTest(version=version):
                self.assertEqual(self.plan(version=version)['channel'], 'dev')
        with self.assertRaises(ValueError):
            self.plan(version='1.0.0')

    def test_main_requires_stable_version_but_is_not_automatically_published(self):
        self.assertEqual(self.plan(version='1.0.0', ref='refs/heads/main')['channel'], 'candidate')
        with self.assertRaises(ValueError):
            self.plan(ref='refs/heads/main')

    def test_test_release_is_opt_in_and_identifies_version_branch_and_commit(self):
        self.assertNotIn('test_tag', self.plan(event='workflow_dispatch'))
        options = dict(event='workflow_dispatch', test_release=True)
        result = self.plan(**options)
        self.assertEqual(result['channel'], 'staging')
        self.assertEqual(result['version'], '1.0.0-dev')
        self.assertEqual(result['test_tag'], 'test-1.0.0-dev-aaaaaaa')
        self.assertEqual(result['test_tag'], self.plan(**options)['test_tag'])
        other_commit = policy.build_plan('1.0.0-dev', 'refs/heads/dev', 'workflow_dispatch', '', 'b' * 40,
                                         test_release=True)
        self.assertNotEqual(result['test_tag'], other_commit['test_tag'])

    def test_test_tag_uses_base_version_without_duplicating_prerelease_suffix(self):
        for version in ['1.0.0-dev', '1.0.0-dev.1', '1.0.0-alpha.1', '1.0.0-beta.1', '1.0.0-rc.1']:
            with self.subTest(version=version):
                result = self.plan(version=version, event='workflow_dispatch', test_release=True)
                self.assertEqual(result['test_tag'], 'test-1.0.0-dev-aaaaaaa')
                self.assertEqual(result['version'], version)
        self.assertEqual(self.plan(version='1.2.3-dev', event='workflow_dispatch',
                                   test_release=True)['test_tag'], 'test-1.2.3-dev-aaaaaaa')

    def test_test_release_rejects_automatic_runs_and_other_refs(self):
        for options in [
            dict(event='push'),
            dict(event='local'),
            dict(event='pull_request', ref='refs/pull/12/merge', base='dev'),
            dict(event='workflow_dispatch', ref='refs/heads/main', version='1.0.0'),
            dict(event='workflow_dispatch', ref='refs/tags/v1.0.0', version='1.0.0', on_main=True),
            dict(event='workflow_dispatch', ref='refs/heads/test-build'),
        ]:
            with self.subTest(options=options):
                with self.assertRaises(ValueError):
                    self.plan(**options, test_release=True)

    def test_test_tag_does_not_change_between_workflow_runs(self):
        for run_id, attempt in [('123', '1'), ('123', '2'), ('124', '1')]:
            with self.subTest(run_id=run_id, attempt=attempt):
                with patch.dict(policy.os.environ, GITHUB_RUN_ID=run_id, GITHUB_RUN_ATTEMPT=attempt):
                    result = self.plan(event='workflow_dispatch', test_release=True)
                    self.assertEqual(result['test_tag'], 'test-1.0.0-dev-aaaaaaa')

    def test_intel_is_optional_and_keeps_arm64_artifacts_and_test_tags(self):
        self.assertNotIn('intel_artifact', self.plan(event='workflow_dispatch'))
        for test_release in [False, True]:
            with self.subTest(test_release=test_release):
                options = dict(event='workflow_dispatch', test_release=test_release)
                standard = self.plan(**options)
                intel = self.plan(**options, intel_experimental=True)
                self.assertEqual(intel.pop('intel_artifact'),
                                 'Cinder-staging-1.0.0-dev-aaaaaaa-x86_64-experimental')
                self.assertEqual(intel, standard)

    def test_intel_rejects_automatic_runs_and_non_dev_refs(self):
        for options in [
            dict(event='push'),
            dict(event='local'),
            dict(event='pull_request', ref='refs/pull/12/merge', base='dev'),
            dict(event='workflow_dispatch', ref='refs/heads/main', version='1.0.0'),
            dict(event='workflow_dispatch', ref='refs/tags/v1.0.0', version='1.0.0', on_main=True),
        ]:
            with self.subTest(options=options):
                with self.assertRaises(ValueError):
                    self.plan(**options, intel_experimental=True)

    def test_release_requires_matching_stable_tag_and_main_ancestry(self):
        result = self.plan(version='1.0.0', ref='refs/tags/v1.0.0', on_main=True)
        self.assertEqual(result['channel'], 'release')
        self.assertEqual(result['artifact'], 'Cinder-v1.0.0-arm64')
        for version, ref, on_main in [
            ('1.0.0', 'refs/tags/v1.0.1', True),
            ('1.0.0', 'refs/tags/v1.0.0', False),
            ('1.0.0-dev', 'refs/tags/v1.0.0-dev', True),
            ('1.0.0-beta.1', 'refs/tags/v1.0.0-beta.1', True),
            ('1.0.0', 'refs/tags/latest', True),
        ]:
            with self.subTest(version=version, ref=ref, on_main=on_main):
                with self.assertRaises(ValueError):
                    self.plan(version, ref, on_main=on_main)

    def test_pull_requests_check_target_channel_and_produce_review_artifacts(self):
        self.assertEqual(self.plan(ref='refs/pull/12/merge', event='pull_request', base='dev')['channel'], 'review')
        self.assertEqual(self.plan(version='1.0.0', ref='refs/pull/12/merge', event='pull_request', base='main')['channel'], 'review')
        with self.assertRaises(ValueError):
            self.plan(ref='refs/pull/12/merge', event='pull_request', base='main')
        with self.assertRaises(ValueError):
            self.plan(event='pull_request', base='dev')

    def test_unsupported_refs_and_malformed_versions_fail_closed(self):
        for ref in ['refs/heads/latest', 'refs/heads/release/1.0', 'refs/heads/dev\nchannel=release']:
            with self.assertRaises(ValueError):
                self.plan(ref=ref)
        for version in ['1.0', '01.0.0', '1.0.0-beta', '1.0.0-dev.', '1.0.0-dev.01', '1.0.0-dev.1.2', '1.0.0\n', '1.0.0+build.2']:
            with self.assertRaises(ValueError):
                self.plan(version=version)
        with self.assertRaises(ValueError):
            self.plan(event='pull_request_target')

    def test_local_working_records_cannot_enter_tracked_tree(self):
        policy.check_tracked_files(['README.md', 'Sources/CinderApp/AppModel.swift'])
        for path in ['AGENTS.md', 'Sources/AGENTS.md', 'CHATGPT-HANDOFF.md',
                     'NATIVE-VALIDATION.json', 'DEVELOPMENT-TREE-VALIDATION.json',
                     'Docs/History/MIGRATION.md', 'Docs/Audio/DEVICE-VALIDATION.md',
                     'Docs/Audio/PRESET-MUSIC-VALIDATION.json']:
            with self.assertRaises(ValueError):
                policy.check_tracked_files(['README.md', path])


if __name__ == '__main__':
    unittest.main()
