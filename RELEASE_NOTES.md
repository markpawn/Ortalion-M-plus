<!--
  Ten plik trafia jako OPIS Release (body_path w .github/workflows/release.yml).
  Przed kazdym tagiem zaktualizuj sekcje ponizej "co nowego w tej wersji".
  GitHub doklei pod spodem auto-liste commitow (generate_release_notes).
-->

# 🛡️ Ortalion M+ — `v4.6`

Addon do organizacji **Mythic+** (WoW 7.3.5, Tauri). Pełna instrukcja: **[README](README.md)**.

## ✨ v4.6 — chat emotki (animowane gify)
- 🎞️ **Animowane emotki na czacie**: wpisz `#nazwa` (np. `#ronaldo`) → u każdego z addonem token zamienia się w miniaturkę, a gif gra nad czatem. Działa też gdy nadawca nie ma addona (liczy się odbiorca).
- 🖱️ **Hover/klik** miniaturki → odtwarza ponownie.
- ⌨️ **Podpowiedzi `#`** w polu czatu (Tab/klik, z miniaturką).
- 🛠️ **Auto-pipeline**: wrzucasz gif do `assets/raw_gifs/`, odpalasz `tools/gif2blp` → konwersja do BLP + auto-`GigaKloce_Emotes.lua`. Zero ręcznej roboty.

## 🧬 `DATA_VERSION = 4` (bez zmian)
Kompatybilne z v4.x.

## 📥 Instalacja
Rozpakuj `GigaKloce.zip` do `Interface/AddOns` (w środku folder `GigaKloce`) i **przeloguj się**.
Uwaga: paczka jest większa niż zwykle — zawiera klatki animowanych emotek.
