<!--
  Ten plik trafia jako OPIS Release (body_path w .github/workflows/release.yml).
  Przed kazdym tagiem zaktualizuj sekcje ponizej "co nowego w tej wersji".
  GitHub doklei pod spodem auto-liste commitow (generate_release_notes).
-->

# 🛡️ Ortalion M+ — `v4.2`

Addon do organizacji **Mythic+** (WoW 7.3.5, Tauri). Pełna instrukcja: **[README](README.md)**.

## ✨ Co nowego (v4.2)
- 📣 **Global advert (admin)** — automatyczne ogłoszenie o gildii na kanale **global** co 15 min (pierwsze po 15 min, nie na wejściu). Tekst i włącznik **wspólne dla adminów** (synchronizowane, ostatnia zmiana wygrywa). Gdy jeden admin rozgłosi, pozostali pomijają swój cykl (bez dubla). Sterowanie w **zębatce**: *Enabled · Set advert text… · Broadcast now*.
- 🪪 **„Invite to guild"** w menu nicku na **czacie** (prawy klik) — gdy masz uprawnienia do zapraszania.
- 🖼️ **Logo w oknie** — okrągły portret w lewym górnym rogu.
- 🔒 **Opcje admina tylko dla osób z addonem** — Admin/Blocked/Announce/most pokazują się w menu wyłącznie dla graczy, których addon faktycznie odbierze (bez addona zostaje samo Invite/Whisper).

## ✨ Z linii v4.1 (przypomnienie)
- 🧹 Scalony widok **Active** (Keys+Party), toggle **Preset** i **Party** (drużyny — admin), 📍 strefa/instancja na hover (z presence, też bez klucza), 🖱️ Invite/Whisper na każdej liście.

## 🧬 `DATA_VERSION = 4` (bez zmian)
**Kompatybilne z v4.0/v4.1** — nowe pola i typy wiadomości są dodatkowe, starsze klienty je ignorują. Zalecany wspólny `/reload`, żeby wszyscy mieli nowy UI i funkcje.

## 📥 Instalacja
Rozpakuj `GigaKloce.zip` do `Interface/AddOns` (w środku jest folder `GigaKloce`) i **przeloguj się** (po pierwszej instalacji sam `/reload` nie wystarczy).
