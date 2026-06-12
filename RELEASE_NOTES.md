<!--
  Ten plik trafia jako OPIS Release (body_path w .github/workflows/release.yml).
  Przed kazdym tagiem zaktualizuj sekcje ponizej "co nowego w tej wersji".
  GitHub doklei pod spodem auto-liste commitow (generate_release_notes).
-->

# 🛡️ Ortalion M+ — `v4`

Addon do organizacji **Mythic+** (WoW 7.3.5, Tauri). Pełna instrukcja: **[README](README.md)**.

## ✨ Co nowego (v4)
- 📣 **Guild-announce bridge** — admin wybiera osobę z innej gildii (prawy klik na liście „Online with addon" → **Announce to their guild…**, albo `/kloce announce <nick> <treść>`) i jej klient wrzuca treść na **czat jej gildii** (z prefiksem `[via Nick]`). Auto-relay; odbiorca weryfikuje, że nadawca to admin.
- 🔗 **Linki w ogłoszeniach** — możesz **shift-klik** wkleić item/czar/quest itp.; u odbiorcy wychodzi klikalny link.
- 🛠️ **Fix: nadawanie admin/blocked cross-guild** — flagi lecą teraz **szeptem do celu** (wcześniej tylko po kanale gildii, więc nie działały między gildiami).

## ✨ Z linii v3 (przypomnienie)
- 🌍 Cross-guild presence/klucze, 🔑 Keys (grupowanie po gildii, ilvl, notatka), ⌨️ podpowiedzi „played with", 🖱️ menu na graczu = **Alt + lewy klik**.

## 🧬 `DATA_VERSION = 4`
Sync tylko między zgodnymi wersjami. **Cała ekipa robi `/reload` razem** — v4 nie synchronizuje się z v3/wcześniejszymi.

## 📥 Instalacja
Rozpakuj `GigaKloce.zip` do `Interface/AddOns` (w środku jest folder `GigaKloce`) i **przeloguj się** (po pierwszej instalacji sam `/reload` nie wystarczy).
