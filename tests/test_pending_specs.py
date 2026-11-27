"""Tests for scripts/roadmap/pending_specs.py (QA-08)."""

from pathlib import Path
import json
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts/roadmap"))
import pending_specs  # noqa: E402


def item(title, status="Todo", body="**Aceite:** Faz X; mostra Y.\n\nNota final."):
    return {"title": title, "status": status, "content": {"body": body}}


class AcceptanceTests(unittest.TestCase):
    def test_extracts_acceptance_paragraph(self):
        body = "**Camada:** UI\n**Aceite:** Primeiro critério; segundo critério.\nContinua aqui.\n\nOutra seção."
        self.assertEqual(pending_specs.acceptance(body),
                         ["Primeiro critério", "segundo critério. Continua aqui."])

    def test_missing_acceptance_falls_back_to_title(self):
        self.assertEqual(pending_specs.acceptance("sem critérios"), [])

    def test_card_id_and_file_name(self):
        self.assertEqual(pending_specs.card_id("NAV-04 · Disparar radar"), "NAV-04")
        self.assertIsNone(pending_specs.card_id("Sem identificador"))
        self.assertEqual(pending_specs.spec_path(Path("t"), "NAV-04"), Path("t/nav_04_spec.lua"))

    def test_lua_string_escaping(self):
        self.assertEqual(pending_specs.lua_string('a "b" \\ c\nd'), '"a \\"b\\" \\\\ c\\nd"')


class GeneratorTests(unittest.TestCase):
    def run_generator(self, items, existing=None):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        out = Path(tmp.name) / "acceptance"
        out.mkdir()
        for name, text in (existing or {}).items():
            (out / name).write_text(text, encoding="utf-8")
        board = Path(tmp.name) / "board.json"
        board.write_text(json.dumps({"items": items}), encoding="utf-8")
        result = subprocess.run([sys.executable, str(ROOT / "scripts/roadmap/pending_specs.py"), str(board), str(out)],
                                check=True, capture_output=True, text=True, encoding="utf-8")
        return out, result.stdout

    def test_writes_one_spec_per_todo_card_only(self):
        out, _ = self.run_generator([
            item("NAV-04 · Radar automático"),
            item("NAV-01 · Feito", status="Done"),
            item("QA-06 · Em andamento", status="In progress"),
            item("Sem id"),
        ])
        self.assertEqual(sorted(p.name for p in out.iterdir()), ["nav_04_spec.lua"])
        text = (out / "nav_04_spec.lua").read_text(encoding="utf-8")
        self.assertIn('pending("NAV-04", "Radar automático", {', text)
        self.assertIn('"Faz X"', text)
        self.assertIn('"mostra Y."', text)

    def test_never_overwrites_an_existing_spec(self):
        out, stdout = self.run_generator([item("NAV-04 · Radar")], {"nav_04_spec.lua": "-- real spec\n"})
        self.assertEqual((out / "nav_04_spec.lua").read_text(encoding="utf-8"), "-- real spec\n")
        self.assertIn("kept 1", stdout)


if __name__ == "__main__":
    unittest.main()
