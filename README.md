# redact-pdf

Turn a PDF into Markdown with personal data replaced by stable placeholders like `[person-1]` or `[iban-1]`, so the text can go to an LLM (or a colleague) without the original names, dates of birth, account numbers and contact details.

Built for contracts, insurance papers, tax and bank letters in German and English, where you want an AI to read the substance but not the identities.

## What it does

1. Docling converts the PDF into a structured document (text items and table cells).
2. Every text item and table cell goes through two detectors on the original text: regex patterns for structured IDs (IBAN, BIC, VAT, tax and social-security numbers, labeled customer/contract/account numbers, emails, phones, DOB after a "born"/"geb." anchor, maiden names after "née"/"geb.") and GLiNER (`urchade/gliner_multi_pii-v1`) for names, addresses, cities and other free-form PII.
3. Overlapping spans are split rather than dropped, then replaced end to start.
4. The rendered Markdown gets a post-pass: regex patterns again (catches IDs in links Docling synthesizes), DOB values in table cells whose label sits in another cell or in the column header, names under recognized DE/EN/FR/ES column headers, and a **recurrence sweep** that replaces every later literal occurrence of an already-found entity, including bare or upper-cased compound surnames of a titled person.
5. PDF metadata (Author, Title, Subject, Keywords) is redacted too and emitted as YAML front matter, with a warning when it held PII.
6. Output: `<stem>.md` (0644) next to the PDF, plus a hidden sidecar `.<stem>.entity_map.json` (0600) mapping each original surface to its placeholder, for re-identifying an LLM's answer later.

If NER fails on any chunk, the file is not written (fail closed).

## How it differs from Presidio or a plain GLiNER wrapper

Presidio and GLiNER-based PII tools detect and replace entities in text you hand them. redact-pdf is the PDF-to-LLM path around such a detector:

- **Markdown out**: headings and tables survive, so the redacted document is still useful to read or prompt with.
- **Recurrence sweep**: NER is inconsistent across mentions; a name caught once is replaced everywhere it recurs, including surname-only and all-caps variants.
- **Entity-map sidecar**: placeholders are reversible by you, not by whoever reads the Markdown.
- Plus: German-document rules (role nouns like "Eigentümer" or "Versicherungsnehmerin" that NER mislabels as people, Austrian/German ID formats, table-cell DOBs), filename-PII warning, cloud-sync-folder warning for the sidecar, scanned-PDF detection.

## Install and run

Needs [uv](https://docs.astral.sh/uv/). The script is a single file with inline dependencies (PEP 723); uv builds the environment on first run.

```bash
./redact-pdf --selftest                  # smoke test, see below
./redact-pdf contract.pdf                # writes contract.md + .contract.entity_map.json next to it
./redact-pdf *.pdf -j 4 -o redacted/     # batch, 4 workers, explicit output dir
./redact-pdf offer.pdf --strict          # also redact company names, countries, URLs, BIC, VAT IDs
./redact-pdf scan.pdf --ocr              # scanned PDFs without a text layer (slow)
./redact-pdf "Max Mustermann.pdf" --rename hash   # keep a name in the filename out of the output name
```

First-run download on macOS arm64, measured: about 1.2 GB Python environment (torch, transformers, docling) plus about 1.3 GB of models (GLiNER multi-PII about 1.1 GB, Docling layout models a few hundred MB). Later runs are offline-capable (`HF_HUB_OFFLINE=1`).

Default mode keeps organization names, countries, URLs, BIC and VAT IDs visible, because comparing offers from named companies is a common use. Personal PII categories are targeted in both modes, but detection is not complete: see Known limitations for what can survive.

## Smoke test

```bash
./redact-pdf --selftest            # default mode
./redact-pdf --selftest --strict   # strict mode
```

Feeds fictional DE, EN, FR and ES samples plus German edge-case, unlabeled-ID and table samples as strings through the redaction stages (per-item redaction, regex post-pass, table DOB/name anchoring, name aliasing, recurrence sweep) and checks must-redact and must-keep lists (dates that are not DOBs, amounts, "Kontoauszug", role nouns, tariff names). Model-independent checks also cover multilingual name headers, partial placeholders, short names, field-label preservation, title/case/whitespace name variants and ambiguous surnames in either mention order. It does not exercise Docling conversion, per-cell table processing, metadata or file writes; `examples/sample-contract.pdf` covers those by eye. Exit code 5 on failure. Documented leaks print as `KNOWN LEAK` warnings without failing the run.

Both modes pass with the pinned GLiNER revision (`GLINER_REVISION` in the script) and the dependency versions locked in `redact-pdf.lock`, which `uv run --script` picks up automatically. One run takes about 40 s on an Apple M3 laptop after the first download.

## Example

[`examples/sample-contract.pdf`](examples/sample-contract.pdf) is a fictional German tenancy agreement built from [`sample-contract.typ`](examples/sample-contract.typ) (`typst compile examples/sample-contract.typ`). Its redacted output and sidecar are committed next to it: [`sample-contract.md`](examples/sample-contract.md) and `examples/.sample-contract.entity_map.json`.

## Languages

- DE, EN: selftest cases, and checked by the author against a private corpus of real documents (not included).
- FR, ES: selftest cases only.
- IT, PT: regex anchors (DOB labels, customer-number labels) exist but no selftest case.
- Anything else: GLiNER still finds names, emails and IBANs, the language-specific anchors do not fire, and the tool warns when it detects a language outside this set.

## Known limitations

Visible in the example output:

- Detected person IDs ignore recognized leading titles/salutations, case and whitespace. Each original surface remains in the sidecar and can share an ID with other variants. Surname-only mentions join a full name only when exactly one known person has that surname: the example's Karl and Lena Probstmüller stay distinct, and `PROBSTMÜLLER` remains a separate, ambiguous identity. Surname matching uses the final name token, ignores recognized trailing qualifications and does not infer gender from salutations. Initials, spelling differences, reordered names, middle-name variants and unknown titles are not resolved; identical full names cannot be distinguished. Undetected recurrences use conservative literal aliases, so other casing can still be missed.
- Recognized field labels such as IBAN, BIC, Tel., E-Mail and Kundennummer stay visible when GLiNER includes them in a value span or tags them alone. Names and places that resemble field keywords (such as Swift or Tel Aviv) are redacted in full; trimming those spans requires an explicit field separator. Unrecognized or misclassified labels can still be over-redacted. BIC values are targeted by regex only in strict mode, but can still be redacted by GLiNER in default mode if it classifies them as personal PII.
- Postcodes and flat numbers can survive: `1234` and `Top 4` stay visible next to a redacted street and city.
- A labeled ID needs its label directly before it ("Kundennummer: X" works, "Kundennummer der Hausverwaltung: X" does not).
- Names under recognized DE/EN/FR/ES table headers (e.g. "Vorname", "Versicherte Personen", "Surname", "Prénom", "Apellido") are redacted without relying on GLiNER. Tables with missing or unrecognized headers, or without a Markdown header separator, still rely on GLiNER and recurrence matching and can leak names. Generic "Name" columns can also contain non-person text that gets redacted. Review tables by eye.

General:

- NER is probabilistic. Treat the output as a strong first pass and skim it before sharing anything sensitive.
- The source PDF is untouched; `exiftool -all= file.pdf` strips its metadata.
- The sidecar holds the original PII. Keep it out of synced folders and out of the LLM's context.

## Note for AI agents

If you are an agent using the output: run the tool, read only `<stem>.md`, and do not open the source PDF or the `.entity_map.json` sidecar. `redact-pdf --help` repeats this.

## License

MIT, see [LICENSE](LICENSE).
