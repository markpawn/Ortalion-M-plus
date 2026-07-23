<!--
  Ten plik trafia jako OPIS Release (body_path w .github/workflows/release.yml).
  Przed kazdym tagiem zaktualizuj sekcje ponizej "co nowego w tej wersji".
  GitHub doklei pod spodem auto-liste commitow (generate_release_notes).
-->

# 🛡️ Ortalion M+ — `v4.8`

Addon do organizacji **Mythic+** (WoW 7.3.5, Tauri). Pełna instrukcja: **[README](README.md)**.

## ✨ v4.8 — statyczne obrazki na czacie + drobiazgi
- **Obrazki `#nazwa`** — obok animowanych gifów doszły **statyczne obrazki wpisywane wprost w linijkę czatu** (inline). Wpisujesz np. `#uwolnic-barabasza` → u każdego z addonem token zamienia się w obrazek. Nadawca **nie musi mieć addona**. Gify dalej wyświetlają się animowane **nad** czatem, obrazki — **w** czacie.
- Obrazki są w podpowiedziach `#` w edytce (z miniaturką) i w `/kloce emote <nazwa>`.
- Nowe obrazki: wrzuć gotowy `.blp` do `assets/images/`, a `tools/gif2blp` sam zaktualizuje manifest (skan nagłówków BLP).
- **Guild advert — „Enabled" jest teraz lokalny**: włączenie/wyłączenie ogłoszenia dotyczy tylko Ciebie (treść nadal synchronizuje się „ostatnia zmiana wygrywa").

## 🧬 `DATA_VERSION = 4` (bez zmian)
Obrazki czatu to render lokalny — nic nowego w synchronizacji. v4.x nadal wzajemnie zgodne. Zalecany wspólny `/reload`.

## 📥 Instalacja
Rozpakuj `GigaKloce.zip` do `Interface/AddOns` (w środku folder `GigaKloce`) i **przeloguj się**.
Uwaga: paczka jest większa niż zwykle — zawiera klatki animowanych emotek.
