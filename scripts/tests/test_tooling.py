import importlib.util
import json
from pathlib import Path
import re
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


def module(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / "scripts" / f"{name}.py")
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


class ToolingTests(unittest.TestCase):
    def test_catalog_compiles_both_languages(self):
        with tempfile.TemporaryDirectory() as destination:
            count = module("compile-localizations").compile_catalog(ROOT / "WhisperDictation/Localizable.xcstrings", destination)
            self.assertGreater(count, 100)
            for language in ["en", "nl"]:
                text = (Path(destination) / f"{language}.lproj/Localizable.strings").read_text()
                self.assertEqual(len(text.splitlines()), count)

    def test_translation_format_arguments_match(self):
        catalog = json.loads((ROOT / "WhisperDictation/Localizable.xcstrings").read_text())
        for key, entry in catalog["strings"].items():
            formats = [re.findall(r"%(?:lld|d|@|%)", entry["localizations"][lang]["stringUnit"]["value"]) for lang in ["en", "nl"]]
            self.assertEqual(*formats, msg=key)

    def test_corpus_is_unique_and_has_at_least_fifty_prompts(self):
        corpus = json.loads((ROOT / "evaluation/nl/prompts.json").read_text())
        self.assertGreaterEqual(len(corpus), 50)
        self.assertEqual(len({row["id"] for row in corpus}), len(corpus))
        self.assertTrue(all(row["read_aloud"] for row in corpus))

    def test_wer_exact_and_insertion(self):
        evaluator = module("evaluate-transcripts")
        rows = [{"id": "a", "reference": "Een café!", "hypothesis": "een café"},
                {"id": "b", "reference": "hallo", "hypothesis": "hallo wereld"}]
        result = evaluator.evaluate(rows)
        self.assertEqual(result["word_errors"], 1)
        self.assertAlmostEqual(result["wer"], 1 / 3)

    def test_wer_rejects_missing_data_and_duplicates(self):
        evaluator = module("evaluate-transcripts")
        with self.assertRaises(ValueError):
            evaluator.evaluate([])
        row = {"id": "a", "reference": "hallo", "hypothesis": "hallo"}
        with self.assertRaises(ValueError):
            evaluator.evaluate([row, row])

    def test_every_app_source_is_in_makefile(self):
        makefile = (ROOT / "Makefile").read_text()
        for path in (ROOT / "WhisperDictation").rglob("*.swift"):
            self.assertIn(str(path.relative_to(ROOT)), makefile)

    def test_download_hashes_match_app_catalog(self):
        swift = (ROOT / "WhisperDictation/Engine/ModelManager.swift").read_text()
        script = (ROOT / "scripts/download-model.sh").read_text()
        for filename, checksum in re.findall(r'fileName: "(ggml-[^"]+)".*?sha256: "([a-f0-9]{64})"', swift, re.S):
            if "silero" not in filename:
                self.assertIn(filename[5:-4] + ") SHA256=" + checksum, script)


if __name__ == "__main__":
    unittest.main()
