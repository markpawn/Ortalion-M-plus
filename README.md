# 🛡️ Ortalion M+ (GigaKloce) — `cross-guild-bridge`

Addon do organizacji **Mythic+** dla ekipy — WoW **7.3.5 (Legion)**, serwer **Tauri**.

> 🌿 **To branch eksperymentalny (v3 / cross-guild).** Bazę (funkcje podstawowe) opisuje README na `main`. Poniżej **tylko to, co dochodzi/zmienia się względem `main`**.

---

## 🌍 Cross-guild — o co chodzi
Na `main` sync działa **w obrębie jednej gildii** (kanał gildii). Tu addon łączy też **różne gildie** — ale Tauri **nie przepuszcza addon-message po custom kanale**, więc transport jest podzielony na 3 pasy:

| Co | Czym | Zasięg |
|---|---|---|
| **Listy** Kloce/Chady/gildie | GUILD (addon) | w obrębie gildii |
| **Presence + klucze** | własny kanał czatu `OrtalionMplusSync` (zwykły czat, ukryty) | **cross-guild** |
| **Most pełnego stanu** | WHISPER (addon) | **cross-guild**, ręczny |

### 👀 Widoczność cross-guild
- Presence i klucze lecą po wspólnym, **ukrytym** kanale (parsowane z czatu, nie widać ich w oknie). Dzięki temu w **„Online with addon"** i **„Keys"** widać też ludzi z **innych gildii**.
- Presence niesie teraz **nazwę gildii** — wyświetlaną przy nicku.

### 🌉 Most cross-guild (tylko **Alvcard** — super admin)
Pełne listy między gildiami przenosi się **ręcznie, szeptem**:
- **Pull** — poproś osobę o jej stan (przyjdzie szeptem),
- **Push** — wyślij jej swój stan,
- **Force-share** — każ jej zrobić share w jej gildii.

Komendy: `/kloce pull|push|forceshare <nick>` **lub** przyciski w menu „Online with addon" (widoczne tylko dla Alvcarda).
Typowy flow: Alvcard `pull`/`push` z osobą X → merge → każdy rozlewa u siebie po gildii.

---

## 🔑 Zakładka Keys — ulepszenia
- **Grupowanie po gildii** (nagłówki **Z→A**, **„No Guild" na końcu**) + sekcja **Party** na górze.
- **ilvl** (equipped) przy każdym kluczu.
- **Gildiowa notatka (public note)** — odczytywana z rostera i wysyłana razem z kluczem (officer note nie ruszamy).
- **Prawy klik → menu**: *Invite*, *Whisper*. *(Target/Inspect się nie da — to funkcje chronione, blokowane z poziomu addona.)*

---

## 🧬 Wersjonowanie danych (`DATA_VERSION = 3`)
- Sync **list** przyjmowany tylko od zgodnej wersji (chroni przed rozjechaniem formatu). Wersja widoczna przy nickach w „Online with addon" — **czerwona = nieaktualny klient**.
- Dane przez **WHISPER (most)** omijają bramkę wersji (most inicjuje admin).
- Auto-pull na logowaniu tylko od źródła z **tej samej gildii**.

> ⚠️ **Wszyscy muszą zaktualizować i zrobić `/reload`** — v3 nie synchronizuje się z wcześniejszymi wersjami.

---

## 🆕 Nowe komendy (względem `main`)
| Komenda | Opis |
|---|---|
| `/kloce pull <nick>` | most: poproś o stan (Alvcard) |
| `/kloce push <nick>` | most: wyślij swój stan (Alvcard) |
| `/kloce forceshare <nick>` | most: każ zrobić share w jego gildii (Alvcard) |
| `/kloce sync` | ręczny pull od źródła z własnej gildii |
| `/kloce syncfrom <nick\|auto>` | preferowane źródło auto-pulla |

Reszta komend i funkcji — jak w README na `main`.
