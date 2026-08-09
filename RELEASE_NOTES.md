<!--
  Ten plik trafia jako OPIS Release (body_path w .github/workflows/release.yml).
  Przed kazdym tagiem zaktualizuj sekcje ponizej "co nowego w tej wersji".
  GitHub doklei pod spodem auto-liste commitow (generate_release_notes).
-->

# 🛡️ Ortalion M+ — `v5.0`

Addon do organizacji **Mythic+** (WoW 7.3.5, Tauri). Pełna instrukcja: **[README](README.md)**.

## ✨ v5.0 — koniec „nie możesz pisać" + lżejsza synchronizacja

**Transport przebudowany.** Presence, klucze, skład i statystyki M+ (dotąd rozsyłane po ukrytym kanale czatu) przeszły na **wewnętrzny transport gildii** — niewidzialny, **nie liczony do anty-spamu czatu**. Efekt: **znika serwerowe „nie możesz pisać"**, które wyskakiwało od ruchu addona.
- Presence i klucze widać teraz **w obrębie gildii** (wspólna gildia ekipy).

**Lżejsza synchronizacja (anti-entropy).**
- Każdy niesie **hash swojej listy** w presence. **Login nie rozsyła już całej listy** — pełny sync leci **tylko gdy coś faktycznie się rozjechało**.
- Uzgadnianie przez wybieranego **„sync leadera"** (jeden, dynamicznie przenoszony) zamiast „każdy z każdym" → brak lawiny przy wielu osobach. Koalescencja odpowiedzi + okresowy backstop.
- Heartbeat co **60 s** (skrojone pod większe ekipy, ~50–60 osób).

**Diagnostyka.**
- `/kloce leader` — kto jest liderem synchronizacji + czyje listy się zgadzają.
- `/kloce debug` — logi synchronizacji na żywo.

## 🧬 `DATA_VERSION = 5` (cutover)
To zmiana transportu — **wszyscy robią `/reload` razem**. Do czasu update'u stare i nowe klienty nie widzą wzajemnie presence (listy się **nie psują**, format bez zmian).

## 📥 Instalacja
Rozpakuj `GigaKloce.zip` do `Interface/AddOns` (w środku folder `GigaKloce`) i **przeloguj się**.
Uwaga: paczka jest większa niż zwykle — zawiera klatki animowanych emotek.
