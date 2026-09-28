// Fictional sample input for redact-pdf. Every name, number and address
// below is invented; domains use the reserved .example TLD (RFC 2606).
// Build: typst compile examples/sample-contract.typ
#set document(title: "Mietvertrag Beispiel", author: "Anna Beispiel")
#set page(paper: "a4", margin: 2cm)
#set text(lang: "de", size: 10.5pt)

= Mietvertrag / Tenancy agreement

Zwischen *Frau Dr. Anna Beispiel-Muster*, geb. 14.03.1985, wohnhaft Musterweg 12, 1234 Musterstadt, Tel.: +43 1 999 99 99, E-Mail: anna.beispiel\@beispiel.example (im Folgenden "Vermieterin") und *Herrn Mag. Karl Probstmüller*, Geburtsdatum: 26.07.1962 (im Folgenden "Mieter") wird folgender Vertrag geschlossen.

== 1. Mietgegenstand

Die Wohnung Top 4 im Haus Musterweg 12 wird ab 01.05.2026 vermietet. Die monatliche Miete beträgt 1.234,56 EUR. Kundennummer: TST-99887766 (Hausverwaltung).

== 2. Zahlung

Die Miete ist auf das Konto der Vermieterin zu überweisen: IBAN AT00 1111 2222 3333 4444, BIC TESTAT22XXX. Die Hausverwaltung TestVerwaltung GmbH (UID: ATU99999999, www.testverwaltung.example) erhält eine Kopie.

== 3. Personen im Haushalt

#table(
  columns: 3,
  [*Name*], [*Geburtsdatum*], [*Einzug*],
  [Karl Probstmüller], [26.07.1962], [01.05.2026],
  [Lena Probstmüller], [02.11.1990], [01.05.2026],
)

== 4. Unterschriften

Frau Beispiel-Muster und Herr Probstmüller bestätigen die Vereinbarung. Der Mieter hat eine Kopie erhalten. PROBSTMÜLLER, Wien, 28.09.2026.

== English summary

Landlord Dr. Anna Beispiel-Muster (email anna.beispiel\@beispiel.example) lets the flat to Mr. Karl Probstmüller from 01/05/2026 for EUR 1,234.56 per month.
