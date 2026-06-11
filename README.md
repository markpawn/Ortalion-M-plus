# 🛡️ Ortalion M+ (GigaKloce)

Addon do organizacji **Mythic+** dla ekipy — World of Warcraft **7.3.5 (Legion)**, serwer **Tauri** (realmy połączone: Tauri + Evermoon).

TL;DR: zapisujesz graczy, których chcesz unikać (**Kloce**) i tych sprawdzonych (**Chady**), widzisz klucze i online całej ekipy — **nawet z różnych gildii** — budujesz składy, a wszystko **synchronizuje się po cichu** między osobami z addonem.

---

## ✨ Co potrafi

### 📑 Zakładki
- **🔑 Keys** — klucze M+ wszystkich z addonem (auto-rozsyłane co 30 s). **Skład (Party) na górze**, reszta **pogrupowana po gildii** (nagłówki Z→A, „No Guild" na końcu). Przy kluczu: ikona klasy/specu, **ilvl**, gildiowa **notatka publiczna**. **Prawy klik → Invite / Whisper.**
- **👥 Party** — builder składu: lista online (z klasą/specem), własne **presety**, **Invite all** jednym kliknięciem.
- **🧱 Kloce** — gracze do unikania. Tag (`noob`/`leaver`/`debil`/`ninja`), notatka „za co", klasa/spec, ikona. Klik → okno **Details**.
- **😎 Chady** — sprawdzeni gracze (z klasą/specem i notatką).

### ⌨️ Podpowiedzi przy dodawaniu
W polu **Add** (Kloce/Chady) pojawiają się podpowiedzi z **ostatnio granych razem** osób (party/raid bieżącej sesji), pokolorowane wg klasy. Klik = od razu tworzy wpis z **ustawioną klasą i specem**.

### 🚨 Alerty
- Gdy **kloc** trafi do Twojej grupy → dźwięk + popup z opcją kicka i **pulsująca ikonka** przy minimapie.
- Wiadomości na czacie: `[KLOC]` (czerwony) / `[CHAD]` (niebieski) przy autorze.

### 🖱️ Menu na graczu — **Alt + lewy klik**
Na dowolnym graczu (świat, ramka party/target) **Alt+lewy klik** otwiera własne menu: *Add to Kloce*, *Block guild* (blokuje całą gildię), *Add to Chads*.

> Dlaczego Alt+lewy, a nie prawy? Wstrzykiwanie pozycji do menu Blizzarda „brudzi" (taint) i losowo psuło chronione *Set Focus/Target*. Własne menu na Alt+lewy klik tego nie rusza — zwykły prawy klik to dalej **czyste menu Blizzarda**.

### 🚫 Blokowanie gildii
Lista zakazanych gildii. Gdy ktoś z takiej gildii **zaaplikuje do Twojego premade**, addon po cichu robi `/who`, sprawdza gildię i **automatycznie dodaje go na Kloce**. Bez wyskakujących okienek.

### ♻️ Reparty
Lider jednym kliknięciem rozwala i odbudowuje skład — osobom z addonem ponowne zaproszenie **auto-akceptuje się**.

---

## 🔄 Synchronizacja (cross-guild)
Tauri **nie przepuszcza addon-message po custom kanale**, więc transport jest podzielony na 3 pasy:

| Co | Czym | Zasięg |
|---|---|---|
| **Listy** Kloce/Chady/detale/gildie | kanał gildii (addon) | w obrębie gildii |
| **Presence + klucze** | wspólny, ukryty kanał czatu `OrtalionMplusSync` | **cross-guild** |
| **Most pełnego stanu** | szept (addon), tylko super-admin | **cross-guild**, ręczny |

Dzięki temu w **„Keys"** i na liście online widać też ludzi z **innych gildii** (z nazwą gildii przy nicku). Strategia synchronizacji list: **„ostatnia zmiana wygrywa"** ze znacznikami czasu i „nagrobkami" — **usunięcia nie wracają**.

- **Accept sync from others** (zębatka) — wyłączasz przyjmowanie zmian od innych.
- **Flagi admin/blocked** — nadawane przez super-admina; *blocked* = ktoś nie wysyła swoich zmian.
- **🌉 Most cross-guild** (super-admin): `pull` (poproś o stan), `push` (wyślij swój), `forceshare` (każ rozlać u siebie) — przez szept.

## 🧬 Wersjonowanie danych (`DATA_VERSION = 3`)
Sync **list** przyjmowany tylko od **zgodnej wersji** (chroni przed rozjechaniem formatu). Wersja widoczna przy nickach na liście online — **czerwona = nieaktualny klient**. Po update **wszyscy robią `/reload` razem**.

## 💾 Backup (snapshoty)
Codzienny automatyczny backup (max 10, rolling) — Kloce, Chady, detale, gildie, presety. Przywracanie z zębatki → **Import snapshot**. Siatka bezpieczeństwa na wypadek trolla.

---

## ⚙️ Komendy
| Komenda | Opis |
|---|---|
| `/kloce show` | otwórz okno |
| `/kloce add/remove <nick>` | dodaj/usuń kloca (lub na targecie) |
| `/chad add/remove <nick>` | dodaj/usuń chada |
| `/kloce guild add/remove/list <nazwa>` | blokowane gildie |
| `/kloce reparty` | odbuduj skład (tylko lider) |
| `/kloce share` | wypchnij wszystko do ekipy |
| `/kloce sync` | ręczny pull od źródła z własnej gildii |
| `/kloce syncfrom <nick\|auto>` | preferowane źródło auto-pulla |
| `/kloce pull/push/forceshare <nick>` | most cross-guild (super-admin) |
| `/kloce reset` | reset pozycji/rozmiaru okna |

## 📥 Instalacja
1. Wrzuć folder **`GigaKloce`** do `Interface/AddOns`.
2. **Po pierwszej instalacji przeloguj się** (sam `/reload` nie wczyta nowego addona).
3. Cała ekipa na **tej samej wersji** — po update zróbcie `/reload` razem.
