# GigaKloce — pomysły / TODO

Lista pomysłów na rozbudowę (kolejność = priorytet wg wartości do M+).

## 🔥 Najmocniejsze do M+
- [x] **1. Flagowanie w Group Finderze** — aplikant z listy podświetla się `[KLOC]`/`[CHAD]`. ✅
- [ ] **2. Tooltip gracza** — najedź na kogokolwiek (świat, ramka party, /who) → w dymku
      dopisek `[KLOC]/[CHAD]` + notatka. Wszędzie, bez otwierania okna. *(mało roboty, duży zysk)*

## ❌ Wycofane
- **Lista gildii (guild-kloce) + skan /who** — usunięte. `GetGuildInfo(unit)` na Tauri zwraca
      nil dla party/raid, więc detekcja w składzie wymagała skanu `/who`, a ten hijackował panel
      Who (migotanie). Za dużo problemów jak na zysk. Kopia z tą funkcją jest w rarze.
      Gdyby kiedyś wracać: trzeba czystszego sposobu na nick→gildia albo akceptacji migotania.

## 📝 Pamięć / kontekst
- [x] **3. Notatka do wpisu** — free-text notatka w oknie Details (klik w wiersz Kloce). ✅
- [x] **4. Data dodania / kto dodał** — zapisywane przy dodaniu, widoczne w Details (lokalnie;
      przy syncu `by` = nadawca). ✅
- [~] **5. Kategorie / tagi** — tag na wpisie Kloce (noob/leaver/mooron/ninja, default noob),
      widoczny w liście + zmiana w Details. ✅ Brakuje jeszcze: **filtrowanie po tagu**.
- [x] **Sync tagu + notatki** — edycja w Details oraz Share rozsyłają `K+:nick\031tag\031notatka`
      (separator \031, notatka cięta do 180 zn., bez znaków kontrolnych). Strategia: **ostatni wygrywa**.
      Zwykłe dodanie wysyła sam nick (nie nadpisuje cudzych detali). Data/„kto" pozostają lokalne.

## 🔍 Wygoda UI
- [ ] **6. Pole szukania** nad listą (gdy dużo wpisów).
- [ ] **7. Tooltip na ikonce minimapy** — „Kloce: 42 | Chads: 13 | w grupie: 1 kloc".
      Plus PPM = szybkie menu (mute, przełącz zakładkę).
- [ ] **8. Sortowanie** listy (alfabetycznie / wg daty).

## 🛡️ Ochrona przed trollami (zrobione)
- [x] **Snapshoty** — dzienna kopia na wejście (max 10, rolling). Import przez kółko zębate
      (prawy górny róg) → „Import snapshot" → nadpisuje wszystko lokalnie. Siatka bezpieczeństwa.
- [x] **Accept sync from others (toggle)** — w kółku zębatym. OFF = ignorujesz cały sync
      list/detali od innych (trolle nic nie zrobią); REPARTY działa zawsze.

## ⚙️ Akcje
- [ ] **9. Auto-decline inva od kloca** (opcjonalne) + osobny pozytywny „ding" gdy wbije chad.
- [ ] **10. Dodaj do Ignore** jednym klikiem przy kicku kloca.
- [ ] **11. Import / Export stringiem** — przeklejenie listy między gildiami (poza addon-sync).

---
*Realizujemy po kolei. #1 w toku.*
