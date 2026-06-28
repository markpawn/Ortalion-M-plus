<!--
  Ten plik trafia jako OPIS Release (body_path w .github/workflows/release.yml).
  Przed kazdym tagiem zaktualizuj sekcje ponizej "co nowego w tej wersji".
  GitHub doklei pod spodem auto-liste commitow (generate_release_notes).
-->

# 🛡️ Ortalion M+ — `v4.7`

Addon do organizacji **Mythic+** (WoW 7.3.5, Tauri). Pełna instrukcja: **[README](README.md)**.

## ✨ v4.7 — wyniki M+ (DPS/HPS) + chat emotki
**Wyniki M+** (integracja z **Details! / Skada / Recount**):
- **Sugestie Kloc/Chad po dungu** — po ukończeniu M+ popup: **top DPS → Chad** (>110% drugiego), **ostatni DPS → Kloc** (gdy nad nim ≥2×). Tylko DPS-i; pomija osoby z addonem, Ciebie i już dodanych. `/kloce dps`, podgląd `/kloce dps now`.
- **Statystyki M+ per gracz** — best klucz dla każdego z 14 podziemi + ostatni przebieg z **% obrażeń**. W **Active** tag `H:+N` i okno **„M+ stats"**.
- **Historia runów** `/kloce runs` — 10 ostatnich przebiegów per podziemie z całą piątką (DPS+HPS). Lokalne.

**Chat emotki**:
- Wpisz `#nazwa` (np. `#ronaldo`) → u każdego z addonem token → animowany gif nad czatem (hover/klik = replay). Podpowiedzi `#` w edytce (Tab/klik). Auto-pipeline `tools/gif2blp` (gif → BLP + manifest).

## 🧬 `DATA_VERSION = 4` (bez zmian)
Nowe rzeczy (statystyki M+ event `D`, emotki) są **dodatkowe** — v4.x wzajemnie zgodne. Zalecany wspólny `/reload`. Dla DPS/HPS potrzebny damage meter.

## 📥 Instalacja
Rozpakuj `GigaKloce.zip` do `Interface/AddOns` (w środku folder `GigaKloce`) i **przeloguj się**.
Uwaga: paczka jest większa niż zwykle — zawiera klatki animowanych emotek.
