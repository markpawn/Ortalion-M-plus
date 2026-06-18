<!--
  Ten plik trafia jako OPIS Release (body_path w .github/workflows/release.yml).
  Przed kazdym tagiem zaktualizuj sekcje ponizej "co nowego w tej wersji".
  GitHub doklei pod spodem auto-liste commitow (generate_release_notes).
-->

# 🛡️ Ortalion M+ — `v4.1`

Addon do organizacji **Mythic+** (WoW 7.3.5, Tauri). Pełna instrukcja: **[README](README.md)**.

## ✨ Co nowego (v4.1)
- 🧹 **Jeden widok „Active"** — zakładki **Keys** i **Party** scalone. 3 zakładki: **Active · Kloce · Chady**. Active pokazuje **wszystkich** (skład + online z addonem + klucze); Twoja grupa na górze jako **Party**/**Me**, reszta pogrupowana po gildii.
- 🎛️ **Toggle „Preset"** (po prawej) — chowa/pokazuje panel presetu. Lewy klik na osobie w Active = dodaj do presetu; lewy klik na członku presetu = usuń. Później **Invite all**.
- 👥 **Toggle „Party"** (tylko admin/Alvcard) — grupuje listę Active w **drużyny** („<lider>'s group"), widać kto z kim gra. Osoby bez addona = sam nick (Invite/Whisper).
- 📍 **Lokalizacja na hover** — strefa + typ instancji (M+/raid/BG/arena) jedzie teraz z **presence**, więc widać ją **też dla osób bez klucza**. Strefa zgodna z panelem gildii (np. „Frostwall").
- 🖱️ **Invite/Whisper na każdej liście** (prawy klik). Opcje adminowe (Admin/Blocked/Announce/Pull/Push/Force) tylko dla osób z addonem.
- ⚙️ **Resync** i **Reparty** przeniesione do menu zębatki (czystszy dolny pasek).

## 🧬 `DATA_VERSION = 4` (bez zmian)
**Kompatybilne z v4.0** — nowe pola (strefa, skład drużyny) są dodatkowe i stare klienty je ignorują. Mimo to zalecany wspólny `/reload`, żeby wszyscy mieli nowy UI.

## 📥 Instalacja
Rozpakuj `GigaKloce.zip` do `Interface/AddOns` (w środku jest folder `GigaKloce`) i **przeloguj się** (po pierwszej instalacji sam `/reload` nie wystarczy).
