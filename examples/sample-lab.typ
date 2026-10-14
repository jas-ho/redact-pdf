// Fictional sample lab report (Kumulativbefund) for redact-pdf. Every name,
// number and value below is invented. It reproduces the layout that broke
// earlier versions: date/time column headers with 2-digit years, reference
// ranges, decimals, and a patient header repeated on every page.
// Build: typst compile examples/sample-lab.typ
#set document(title: "Kumulativbefund Beispiel", author: "Dr. Karl Probstmüller")
#set page(
  paper: "a4", margin: (x: 1.6cm, y: 2.2cm),
  header: [*Beispiel-Muster, Anna*, geb.: 14.03.1985 W, \#2045 #h(1fr) Zentrallabor Musterstadt],
)
#set text(lang: "de", size: 9pt)

#let lab(dates, rows) = table(
  columns: (auto, auto) + (1fr,) * dates.len(),
  align: (left, left) + (center,) * dates.len(),
  stroke: 0.4pt + luma(170),
  [*Parameter*], [*Referenz*], ..dates.map(d => [*#d*]),
  ..rows.flatten(),
)

= Kumulativbefund

== Hämatologie

#lab(
  ("18.02.14\n08:37", "01.04.14\n08:27", "13.05.14\n08:37", "24.05.17\n10:24"),
  (
    ([Leukozyten], [4.00 - 10.00 G/l], [\* 2.56], [\* 3.12], [\* 3.27], [4.41]),
    ([Thrombozyten], [150 - 350 G/l], [209], [191], [211], [198]),
    ([Hämoglobin], [12.5 - 16.0 g/dl], [\* 11.9], [\* 12.3], [\* 12.2], [12.8]),
    ([Retikulozyten abs.], [0.025 - 0.095 T/L], [0.0612], [0.0533], [0.0581], [0.0490]),
    ([Neutrophile abs.], [1.40 - 6.60 G/l], [\* 1.21], [1.65], [1.80], [2.02]),
  ),
)

== Kommentare

18.02.14 08:37 Hämoglobin mitgeteilt Dr. Karl Probstmüller (8:24). Station telefonisch verständigt, Rückruf unter Tel. 0664 1234567.

#pagebreak()

== Klinische Chemie

#lab(
  ("09.10.24\n08:40", "01.04.25\n07:12", "21.06.25\n10:04", "28.07.25\n08:50"),
  (
    ([Kreatinin], [0.50 - 0.90 mg/dl], [0.71], [0.78], [\* 0.93], [0.81]),
    ([Kalium], [3.5 - 5.1 mmol/l], [4.2], [4.6], [3.9], [4.4]),
    ([CRP], [0.0 - 0.5 mg/dl], [0.1], [\* 1.8], [0.3], [0.2]),
  ),
)

== Befundbericht

Die Kontrolle zeigt eine leichte Leukopenie mit stabilen Werten über den gesamten Beobachtungszeitraum. Die Thrombozyten liegen durchgehend im Referenzbereich, das Hämoglobin ist zu Beginn gering vermindert und normalisiert sich im Verlauf. Die Retikulozyten bewegen sich im unteren Normbereich, eine relevante Hämolyse ist nicht anzunehmen. Die neutrophilen Granulozyten sind initial knapp unter der Norm und steigen danach kontinuierlich an. In der klinischen Chemie zeigt sich ein einmalig erhöhtes CRP ohne klinisches Korrelat, das bei der Folgekontrolle wieder im Normbereich liegt. Die Nierenfunktion ist stabil, das Kalium unauffällig. Eine weitere Kontrolle in drei Monaten wird empfohlen, bei Fieber oder Infektzeichen früher. Bei Rückfragen steht das Labor gerne zur Verfügung. Der Befund wurde von Dr. Karl Probstmüller vidiert und am 28.07.25 an die Station übermittelt.
