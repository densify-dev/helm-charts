#!/usr/bin/env python3
import importlib.util
import unittest
from pathlib import Path
from unittest.mock import patch


MODULE_PATH = Path(__file__).with_name("notify_changelog.py")
SPEC = importlib.util.spec_from_file_location("notify_changelog", MODULE_PATH)
notify = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(notify)


class NotifyChangelogTests(unittest.TestCase):
    def test_dependency_metadata_is_read_from_yaml(self):
        chart = """
dependencies:
  - name: engine
    version: "1.2.3"
  - name: other
    version: 4.5.6
"""
        with patch.object(notify, "file_at", return_value=chart):
            self.assertEqual(
                notify.dependency_names("after", "Chart.yaml"),
                ["engine", "other"],
            )
            self.assertEqual(
                notify.dependency_version("after", "Chart.yaml", "engine"),
                "1.2.3",
            )

    def test_subchart_notes_require_a_stack_version_upgrade(self):
        chart_path = "charts/stack/Chart.yaml"
        engine_path = "charts/engine/CHANGELOG.md"
        old_chart = "dependencies:\n  - name: engine\n    version: 1.0.0\n"
        new_chart = "dependencies:\n  - name: engine\n    version: 1.1.0\n"
        engine_changelog = "## [1.1.0]\n\n### Fixed\n- A fix.\n"

        def fake_file_at(ref, path):
            if path == chart_path:
                return old_chart if ref == "before" else new_chart
            if path == engine_path:
                return engine_changelog
            return ""

        config = {
            "include_subcharts": True,
            "subchart_changelog_template": "charts/{dependency}/CHANGELOG.md",
            "includes": [],
        }
        with patch.object(notify, "file_at", side_effect=fake_file_at):
            result = notify.combined_changelog_text(
                "before", "after", "charts/stack/CHANGELOG.md", "", config,
                "https://github.com", "owner/repo",
            )
        self.assertIn("A fix.", result)

    def test_missing_subchart_changelog_is_skipped(self):
        config = {
            "include_subcharts": True,
            "subchart_changelog_template": "charts/{dependency}/CHANGELOG.md",
            "includes": [],
        }
        chart = "dependencies:\n  - name: engine\n    version: 1.1.0\n"

        def fake_file_at(ref, path):
            return chart if path.endswith("Chart.yaml") else ""

        with patch.object(notify, "file_at", side_effect=fake_file_at):
            result = notify.combined_changelog_text(
                "before", "after", "charts/stack/CHANGELOG.md", "", config,
                "https://github.com", "owner/repo",
            )
        self.assertEqual(result, "")

    def test_unsafe_link_scheme_is_removed(self):
        result = notify.build_html(
            "chart", "[unsafe](javascript:alert(1))", "https://example.com"
        )
        self.assertNotIn("javascript:", result)
        self.assertIn('href="#"', result)

    def test_email_bodies_do_not_include_postal_address(self):
        address = "200 – 120 East Beaver Creek Rd Richmond Hill, ON L4B 4V1 Canada."
        text = notify.build_text("chart", "Notes", "https://example.com")
        html = notify.build_html("chart", "Notes", "https://example.com")
        self.assertNotIn(address, text)
        self.assertNotIn(address, html)

    def test_prerelease_sections_are_selected(self):
        changelog = """
## [1.2.0-rc.1]
- Candidate

## [1.1.0]
- Older
"""
        result = notify.release_notes_between(changelog, "1.1.0", "1.2.0-rc.1")
        self.assertIn("Candidate", result)

    def test_malformed_dependency_metadata_fails_clearly(self):
        with self.assertRaisesRegex(ValueError, "dependencies must be a list"):
            notify.chart_dependencies("dependencies: [engine]\n")


if __name__ == "__main__":
    unittest.main()
