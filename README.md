# 🛡️ Ortalion M+ (GigaKloce)

Addon do organizacji **Mythic+** dla ekipy — World of Warcraft **7.3.5 (Legion)**, serwer **Tauri**.

TL;DR: zapisujesz graczy, których chcesz unikać (**Kloce**) i tych sprawdzonych (**Chady**), widzisz klucze i online całej gildii, budujesz składy — a wszystko **synchronizuje się po cichu** między osobami z addonem.

---

## ✨ Co potrafi

### 📑 Zakładki
- **🔑 Keys** — klucze M+ wszystkich z addonem (auto-rozsyłane co 30 s). Skład na górze, reszta gildii niżej. Ikona klasy/specu przy każdym kluczu.
- **👥 Party** — builder składu: lista online (z klasą/specem), własne **presety**, **Invite all** jednym kliknięciem.
- **🧱 Kloce** — gracze do unikania. Tag (`noob`/`leaver`/`debil`/`ninja`), notatka „za co", klasa/spec, ikona. Klik → okno **Details**.
- **😎 Chady** — sprawdzeni gracze (z klasą/specem i notatką).

### 🚨 Alerty
- Gdy **kloc** trafi do Twojej grupy → dźwięk + popup z opcją kicka i **pulsująca ikonka** przy minimapie.
- Wiadomości na czacie: `[KLOC]` (czerwony) / `[CHAD]` (niebieski) przy autorze.

### 🖱️ Menu pod prawym przyciskiem (na graczu)
Sekcja **Kloce** z opcjami: *Add to Kloce*, *Block guild* (blokuje całą gildię), *Add to Chads*.

### 🚫 Blokowanie gildii
Lista zakazanych gildii. Gdy ktoś z takiej gildii **zaaplikuje do Twojego premade**, addon po cichu robi `/who`, sprawdza gildię i **automatycznie dodaje go na Kloce**. Bez wyskakujących okienek.

### ♻️ Reparty
Lider jednym kliknięciem rozwala i odbudowuje skład — osobom z addonem ponowne zaproszenie **auto-akceptuje się**.

---

## 🔄 Synchronizacja
Wszystko rozsyła się między osobami z addonem **po kanale gildii**: Kloce, Chady, detale (tag/notatka/klasa/spec), blokowane gildie. Strategia **„ostatnia zmiana wygrywa"** ze znacznikami czasu i „nagrobkami" (usunięcia nie wracają).

- **Accept sync from others** (zębatka) — wyłączasz przyjmowanie zmian od innych.
- **Flagi admin/blocked** — nadawane przez super-admina; *blocked* = ktoś nie wysyła swoich zmian.

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
| `/kloce reset` | reset pozycji/rozmiaru okna |

## 📥 Instalacja
1. Wrzuć folder **`GigaKloce`** do `Interface/AddOns`.
2. **Po pierwszej instalacji przeloguj się** (sam `/reload` nie wczyta nowego addona).
3. Działa najlepiej, gdy ekipa jest **w jednej gildii** (sync leci po jej kanale).
