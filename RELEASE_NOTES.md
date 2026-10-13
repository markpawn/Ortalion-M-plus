<!--
  Ten plik trafia jako OPIS Release (body_path w .github/workflows/release.yml).
  Przed kazdym tagiem zaktualizuj sekcje ponizej "co nowego w tej wersji".
  GitHub doklei pod spodem auto-liste commitow (generate_release_notes).
-->

# 🛡️ Ortalion M+ — `v5.5`

Addon do organizacji **Mythic+** (WoW 7.3.5, Tauri). Pełna instrukcja: **[README](README.md)**.

## ✨ v5.5 — klucze na żywo, lepsze sugestie, czystszy UI

🗝️ **Klucz rozgłasza się automatycznie przy zmianie.**
Po ukończeniu M+ (albo po odebraniu klucza z tygodniowej skrzynki) Twój **nowy klucz leci do ekipy od razu** — bez czekania na odświeżenie. Koniec z „ej, co Ci poleciało?" po każdym dungu. Rozgłoszenie idzie tylko gdy klucz **faktycznie się zmienił** (zero spamu przy zwykłym grzebaniu w torbach).

🧠 **Sugestie Kloc/Chad po DPS — rozdzielone i bezpieczniejsze.**
- Sugestia **Kloc** (po DPS) to teraz **osobny przełącznik, domyślnie WYŁĄCZONY** — bo blacklista po jednym przebiegu bywa niesprawiedliwa. Włączysz w zębatce → **„Suggest Kloc by DPS"** lub `/kloce dps kloc`. Sugestia **Chad** działa jak dotąd (osobny toggle).
- **Nie proponuje już graczy z Twojej gildii** — ani na kloca, ani na chada.

🖱️ **„In Group": lewy klik = detale.**
W zakładkach Kloce/Chady, w prawym panelu „In Group", **lewy klik na graczu otwiera okno detali** (klasa/spec/notatka) — tak jak w głównej liście. Prawy klik dalej = Invite / Whisper / Kick.

🎨 **Poprawki interfejsu.**
- **Active**: długie wpisy (ilvl + notatka) **ładnie się zawijają** — pełna szerokość, równy padding góra/dół i lewa, bez ucinania.
- **Uchwyt zmiany rozmiaru** okna **nie „skacze"** już przy pierwszym chwyceniu.

## 🧬 `DATA_VERSION = 5` (bez zmian)
Zgodne z v5.x — wystarczy `/reload`.

## 📥 Instalacja
Rozpakuj `GigaKloce.zip` do `Interface/AddOns` (w środku folder `GigaKloce`) i **przeloguj się**.
Uwaga: paczka jest większa niż zwykle — zawiera klatki animowanych emotek.
