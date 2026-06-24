<!--
  Ten plik trafia jako OPIS Release (body_path w .github/workflows/release.yml).
  Przed kazdym tagiem zaktualizuj sekcje ponizej "co nowego w tej wersji".
  GitHub doklei pod spodem auto-liste commitow (generate_release_notes).
-->

# 🛡️ Ortalion M+ — `v4.6`

Addon do organizacji **Mythic+** (WoW 7.3.5, Tauri). Pełna instrukcja: **[README](README.md)**.

## ✨ v4.6 — wyniki M+ (DPS / HPS)
Integracja z damage metrem (**Details! / Skada / Recount**):
- **Sugestie Kloc/Chad po dungu** — po ukończeniu M+ addon proponuje (popup) **top DPS → Chad** (>110% drugiego) i **ostatniego DPS → Kloc** (gdy nad nim ≥2×). Tylko DPS-i; pomija osoby z addonem, Ciebie i już dodanych. Przełącznik `/kloce dps`, podgląd `/kloce dps now`.
- **Statystyki M+ per gracz** — każdy rozsyła swój **najlepszy klucz dla każdego z 14 podziemi** + ostatni przebieg z **% obrażeń**. W **Active**: tag `H:+N` przy nicku i okno **„M+ stats"** (lewy klik na osobie, gdy panel Preset schowany).
- **Historia runów** `/kloce runs` — **10 ostatnich** przebiegów każdego podziemia z czasem, kluczem i całą piątką (**DPS + HPS**, też healer/tank). Czysto **lokalne**.

## 🧬 `DATA_VERSION = 4` (bez zmian)
Nowe statystyki M+ idą **dodatkowym** eventem — starsze klienty v4.x je ignorują, więc v4.x są wzajemnie zgodne. Zalecany wspólny `/reload`. Dla liczb DPS/HPS potrzebny zainstalowany damage meter (Details! / Skada / Recount).

## 📥 Instalacja
Rozpakuj `GigaKloce.zip` do `Interface/AddOns` (w środku jest folder `GigaKloce`) i **przeloguj się** (po pierwszej instalacji sam `/reload` nie wystarczy).
