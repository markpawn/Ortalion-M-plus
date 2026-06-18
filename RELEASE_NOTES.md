<!--
  Ten plik trafia jako OPIS Release (body_path w .github/workflows/release.yml).
  Przed kazdym tagiem zaktualizuj sekcje ponizej "co nowego w tej wersji".
  GitHub doklei pod spodem auto-liste commitow (generate_release_notes).
-->

# 🛡️ Ortalion M+ — `v4.4`

Addon do organizacji **Mythic+** (WoW 7.3.5, Tauri). Pełna instrukcja: **[README](README.md)**.

## ✨ v4.4
- **ilvl + notatka gildiowa pokazują się teraz dla KAŻDEGO** w Active (też bez klucza) — to atrybuty gracza, więc przeniesione z klucza do danych obecności.
- Porządki pod maską: dane lecą rozdzielone (klucz / dane gracza / skład), mniejsze i pewniejsze wiadomości.

## 🧬 `DATA_VERSION = 4` (bez zmian)
Zmienił się format wiadomości, ale bez podbicia wersji. **Zróbcie wspólny `/reload`** — na mieszanych wersjach starszy klient pokaże niepełne dane (np. brak ilvl/notki/drużyn) do czasu aktualizacji.

## 📥 Instalacja
Rozpakuj `GigaKloce.zip` do `Interface/AddOns` (w środku jest folder `GigaKloce`) i **przeloguj się** (po pierwszej instalacji sam `/reload` nie wystarczy).
