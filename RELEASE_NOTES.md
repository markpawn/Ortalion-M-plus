<!--
  Ten plik trafia jako OPIS Release (body_path w .github/workflows/release.yml).
  Przed kazdym tagiem zaktualizuj sekcje ponizej "co nowego w tej wersji".
  GitHub doklei pod spodem auto-liste commitow (generate_release_notes).
-->

# 🛡️ Ortalion M+ — `v3.x`

Addon do organizacji **Mythic+** (WoW 7.3.5, Tauri). Pełna instrukcja: **[README](README.md)**.

## ✨ Co nowego (linia v3)
- 🌍 **Cross-guild** — presence i klucze widać między gildiami (po ukrytym kanale czatu), listy dalej po kanale gildii, most pełnego stanu szeptem (super-admin).
- 🔑 **Keys** — grupowanie po gildii (Z→A, „No Guild" na końcu), skład na górze, **ilvl**, gildiowa **notatka publiczna**, prawy klik → **Invite / Whisper**.
- ⌨️ **Podpowiedzi w polu Add** — ostatnio grani razem (party/raid), pokolorowani wg klasy; klik = od razu wpis z ustawioną klasą i specem.
- 🖱️ **Menu na graczu = Alt + lewy klik** (własne menu, bez „taintu" psującego Set Focus). Zwykły prawy klik = czyste menu Blizzarda.
- 🧬 **`DATA_VERSION = 3`** — sync tylko między zgodnymi wersjami (chroni przed rozjechaniem danych).

## 🛠️ Poprawki
- Paczka zawiera komplet plików: `assets/` (ikony) + `wipe.ogg`.
- Koniec z „zip w zipie" przy pobieraniu artefaktu.

## ⚠️ Ważne
Po update **cała ekipa robi `/reload` razem** — v3 nie synchronizuje się z wcześniejszymi wersjami.

## 📥 Instalacja
Rozpakuj `GigaKloce.zip` do `Interface/AddOns` (w środku jest folder `GigaKloce`) i **przeloguj się** (po pierwszej instalacji sam `/reload` nie wystarczy).
