# redact-pdf

Turn a PDF into Markdown with personal data replaced by stable placeholders like `[person-1]` or `[iban-1]`, so the text can go to an LLM (or a colleague) without the original names, dates of birth, account numbers and contact details.

![Before and after: a fictional German tenancy contract PDF with names, birth dates, address, phone and email, next to the Markdown redact-pdf produces, where each of these is replaced by a placeholder such as [person-1], [date_of_birth-1] or [email-1]](docs/img/before-after.png)

Built for contracts, insurance papers, tax and bank letters in German and English, where you want an AI to read the substance but not the identities.

## What it does

1. Docling converts the PDF into a structured document (text items and table cells). Mojibake from the PDF's text layer ("HÃ¤matologie") is repaired first.
2. Every text item and table cell goes through two detectors on the original text: regex patterns for structured IDs (IBAN, BIC, VAT, tax and social-security numbers, labeled customer/contract/account numbers, emails, phones, DOB after a "born"/"geb." anchor, maiden names after "née"/"geb.") and GLiNER (`urchade/gliner_multi_pii-v1`) for names, addresses, cities and other free-form PII. Long text goes to GLiNER in overlapping windows, because the model silently ignores everything past its input limit. A phone-shaped match is judged with its surrounding text: inside a run of dates and times (`24.05.17 08:40`) it is data, not a phone number, and so is a regex match inside a run of 0.x decimals, unless a phone label like "Tel." precedes it.
3. Overlapping spans are split rather than dropped, then replaced end to start.
4. The rendered Markdown gets a post-pass: regex patterns again (catches IDs in links Docling synthesizes), DOB values in table cells whose label sits in another cell or in the column header, names under recognized DE/EN/FR/ES column headers, and a **recurrence sweep** that replaces every later literal occurrence of an already-found entity, including bare or upper-cased compound surnames of a titled person.
5. PDF metadata (Author, Title, Subject, Keywords) is redacted too and emitted as YAML front matter, with a warning when it held PII.
6. Output: `<stem>.md` (0644) next to the PDF, plus a hidden sidecar `.<stem>.entity_map.json` (0600) mapping each original surface to its placeholder, for re-identifying an LLM's answer later. Optionally `<stem>.tables.xlsx` (`--tables`) and `<stem>.redacted.pdf` (`--pdf`), both built from that final Markdown, so they never show more than the `.md` does.

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
./redact-pdf *.pdf -j 4 -o redacted/     # batch, 4 workers (CPU each), explicit output dir
./redact-pdf offer.pdf --strict          # also redact company names, countries, URLs, BIC, VAT IDs
./redact-pdf scan.pdf --ocr              # scanned PDFs without a text layer (slow)
./redact-pdf lab.pdf --keep Leukozyten    # name detector may not redact this exact term (regex hits still are)
./redact-pdf lab.pdf --tables             # + lab.tables.xlsx, one sheet per table (see "Lab reports")
./redact-pdf lab.pdf --pdf                # + lab.redacted.pdf, re-rendered from the .md (needs pandoc + typst)
./redact-pdf big.pdf --device cpu         # GLiNER on the CPU instead of the GPU (default: auto)
./redact-pdf "Max Mustermann.pdf" --rename hash   # keep a name in the filename out of the output name
```

First-run download on macOS arm64, measured: about 1.2 GB Python environment (torch, transformers, docling) plus about 1.3 GB of models (GLiNER multi-PII about 1.1 GB, Docling layout models a few hundred MB). Later runs are offline-capable (`HF_HUB_OFFLINE=1`).

Speed: GLiNER runs on the GPU when there is one (`--device auto` picks CUDA, then Apple MPS, then the CPU) and predicts all text windows of a document up front, in batches, each distinct window once (lab reports repeat the same cells on every page). In testing, GPU and batched runs gave byte-identical output to CPU one-at-a-time runs; floating-point differences could in principle flip a detection that sits exactly at the score threshold, so the selftest compares batched against one-at-a-time inference on the device in use. `--batch-size` (default 16) lowers GPU memory use. Parallel `-j` workers always run on the CPU.

Default mode keeps organization names, countries, URLs, BIC and VAT IDs visible, because comparing offers from named companies is a common use. Personal PII categories are targeted in both modes, but detection is not complete: see Known limitations for what can survive.

### Progress output

A long PDF takes minutes, so each file reports its stages on stderr: `[1/3] converting PDF (85 pages)`, `[2/3] redacting` with a done/total counter over text items and table cells (percent, current page, elapsed, rough ETA), `[3/3] post-pass + writing output` and `done in …`. On a terminal the counter is one line updated in place; when stderr is a pipe or file, or parallel `-j` workers run, it is a plain line at most every 5 s, prefixed with `file i/N` so parallel workers stay distinguishable. With `--json` the same events are JSON objects (`"tag": "progress"`, numeric fields such as `done`, `total`, `page`, `eta_s`) on stderr; stdout still carries only result lines. `--no-progress` turns it off.

Progress lines contain only counts, stage names, page numbers and times: no document text, no detected entities, no filenames. A file is identified by its position among the command-line arguments (`file 2/5`), because the input filename may itself contain a patient's name and the output stem is only known at the end (and is the input name under the default `--rename keep`). An agent can therefore watch progress safely. The guarantee covers the `progress` messages only: other stderr lines (warnings, errors, the final `output` line, third-party library warnings) can still name files, and on a terminal a library warning can land on the same screen line as the in-place counter.

## Smoke test

```bash
./redact-pdf --selftest            # default mode
./redact-pdf --selftest --strict   # strict mode
```

Feeds fictional DE, EN, FR and ES samples plus German edge-case (including lab-report dates, decimals and phone layouts next to them), unlabeled-ID, long-paragraph and table samples as strings through the redaction stages (per-item redaction, regex post-pass, table DOB/name anchoring, name aliasing, recurrence sweep) and checks must-redact and must-keep lists (dates that are not DOBs, amounts, "Kontoauszug", role nouns, tariff names). Model-independent checks also cover multilingual name headers, partial placeholders, short names, field-label preservation, title/case/whitespace name variants and ambiguous surnames in either mention order. It does not exercise Docling conversion, per-cell table processing, metadata or file writes; `examples/sample-contract-input.pdf` covers those by eye. Exit code 5 on failure. Documented leaks print as `KNOWN LEAK` warnings without failing the run.

Both modes pass with the pinned GLiNER revision (`GLINER_REVISION` in the script) and the dependency versions locked in `redact-pdf.lock`, which `uv run --script` picks up automatically. One run takes about 40 s on an Apple M3 laptop after the first download.

## Lab reports: spreadsheet and PDF output

Cumulative lab reports are mostly tables of dates, reference ranges and values, with a few names and phone numbers in between. redact-pdf keeps the data readable (dates, times and decimals are not mistaken for phone numbers) and can hand it on in two more shapes:

- `--tables` writes `<stem>.tables.xlsx` with every table of the redacted Markdown on its own sheet, ready to plot. Plain decimal-point numbers (`4.41`, `0.0612`) become numeric cells; anything else stays text: flagged values (`* 2.56`), ranges, decimal commas, leading zeros (`00123`, often IDs) and numbers over 15 digits. Text cells are always stored as text, so a cell like `=1+1` is never evaluated.
- `--pdf` writes `<stem>.redacted.pdf`, re-rendered from the redacted Markdown with [pandoc](https://pandoc.org) and [typst](https://typst.app) (`brew install pandoc typst`). It is a readable, printable report, not a copy of the original layout. The source PDF is never edited, because redacting text inside a PDF leaves too many places for it to survive (images, annotations, form fields, hidden text). The render reads plain Markdown only: raw Typst, title blocks and attribute syntax are switched off, so document text cannot execute code or set PDF metadata.

![Page 1 of the fictional examples/sample-lab-input.pdf beside the same page of sample-lab-output.redacted.pdf: the doctor's name and phone number in the comment are placeholders, every date header, reference range and value is unchanged, and the patient line from the page header is gone because Docling drops page headers](docs/img/lab-before-after.png)

`--pdf` checks for pandoc and typst before starting and exits with code 2 if one is missing, writing nothing. If either output fails later (say, typst cannot compile the document), the `.md` and sidecar are still written, the file counts as failed (exit code 3), and no stale output of the same name is left behind.

## Example

Each example is a fictional input PDF built from a typst source, plus the outputs redact-pdf writes for it. Inputs end in `-input`, outputs in `-output`; regenerate them with `./redact-pdf examples/<name>-input.pdf --rename <name>-output --force` (for the lab example add `--tables --pdf`).

[`examples/sample-contract-input.pdf`](examples/sample-contract-input.pdf) is a fictional German tenancy agreement built from [`sample-contract.typ`](examples/sample-contract.typ). Output: [`sample-contract-output.md`](examples/sample-contract-output.md) and its sidecar `examples/.sample-contract-output.entity_map.json`.

[`examples/sample-lab-input.pdf`](examples/sample-lab-input.pdf) is a fictional cumulative lab report ([`sample-lab.typ`](examples/sample-lab.typ)): date/time column headers with two-digit years, reference ranges, decimals, a doctor's name and a phone number in the comments. In [`sample-lab-output.md`](examples/sample-lab-output.md) (sidecar `examples/.sample-lab-output.entity_map.json`) the name and number are placeholders while every date, range and value stays readable. The patient line exists only in the page header, which Docling drops. [`sample-lab-output.tables.xlsx`](examples/sample-lab-output.tables.xlsx) and [`sample-lab-output.redacted.pdf`](examples/sample-lab-output.redacted.pdf) are its `--tables` and `--pdf` outputs.

## Languages

- DE, EN: selftest cases, and checked by the author against a private corpus of real documents (not included).
- FR, ES: selftest cases only.
- IT, PT: regex anchors (DOB labels, customer-number labels) exist but no selftest case.
- Anything else: GLiNER still finds names, emails and IBANs, the language-specific anchors do not fire, and the tool warns when it detects a language outside this set.

## Known limitations

Visible in the example output:

- Detected person IDs ignore recognized leading titles/salutations, case and whitespace. Each original surface remains in the sidecar and can share an ID with other variants. Surname-only mentions join a full name only when exactly one known person has that surname: the example's Karl and Lena Probstmüller stay distinct, and `PROBSTMÜLLER` remains a separate, ambiguous identity. Surname matching uses the final name token, ignores recognized trailing qualifications and does not infer gender from salutations. Initials, spelling differences, reordered names, middle-name variants and unknown titles are not resolved; identical full names cannot be distinguished. Undetected recurrences use conservative literal aliases, so other casing can still be missed.
- Recognized field labels such as IBAN, BIC, Tel., E-Mail and Kundennummer may stay visible only when a non-name GLiNER span has an accepted remainder starting with a token containing a digit or an email address. Name, organization, place and address spans are never prefix-trimmed. Bare labels and label fragments left by overlapping detections can be over-redacted. BIC values are targeted by regex only in strict mode, but can still be redacted by GLiNER in default mode if it classifies them as personal PII.
- Postcodes and flat numbers can survive: `1234` and `Top 4` stay visible next to a redacted street and city.
- A labeled ID needs its label directly before it ("Kundennummer: X" works, "Kundennummer der Hausverwaltung: X" does not).
- Names under recognized DE/EN/FR/ES table headers (e.g. "Vorname", "Versicherte Personen", "Surname", "Prénom", "Apellido") are redacted without relying on GLiNER. Tables with missing or unrecognized headers, or without a Markdown header separator, still rely on GLiNER and recurrence matching and can leak names. Generic "Name" columns can also contain non-person text that gets redacted. Review tables by eye.

General:

- NER is probabilistic. Treat the output as a strong first pass and skim it before sharing anything sensitive.
- GLiNER can label a lone table cell such as a lab parameter ("Leukozyten") as a person or city, and the recurrence sweep then replaces it everywhere. `--keep TERM` exempts an exact term from GLiNER (regex hits, name-column cells and recurrences of entities found elsewhere are still redacted).
- Date and time columns of lab reports (`24.05.17 08:40`, `0.0612 0.0533`) are not treated as phone numbers: a phone-shaped match is kept visible when the whole surrounding run is valid full dates and HH:MM times, or 0.x decimals it starts inside. A phone number written exactly like such a run with no phone label (Tel, Fax, Mobil, ...) shortly before it stays visible. A match that is a single full date (`Tel. 12.03.2024`) is never treated as a phone, label or not; the phone regex also skips matches containing `.19xx` or `.20xx`.
- Page headers and footers are dropped by Docling, so text that only appears there (often the patient line of a lab report) is missing from the output rather than redacted.
- `--tables` sees only what Docling recognized as a table; its quality decides the sheets. A header cell spanning two lines arrives as one cell (`24.05.17 10:24`), and a table that continues on the next page usually becomes two sheets.
- `--pdf` contains the text and tables of the `.md`, nothing else: no images, charts or logos, and not the original fonts, page breaks or layout.
- Docling's conversion dominates the runtime: an 85-page lab report (about 16,000 text items and table cells) takes about 5 minutes on an Apple M3 Max, almost all of it conversion; redaction takes about 20 seconds on the GPU (16 minutes on the CPU without batching, before this was added). On the CPU (`--device cpu`, or a machine without a supported GPU) batching and the window cache still apply.
- The source PDF is untouched; `exiftool -all= file.pdf` strips its metadata.
- The sidecar holds the original PII. Keep it out of synced folders and out of the LLM's context.

## Note for AI agents

If you are an agent using the output: run the tool, read only `<stem>.md`, and do not open the source PDF or the `.entity_map.json` sidecar. `redact-pdf --help` repeats this.

## License

MIT, see [LICENSE](LICENSE).
