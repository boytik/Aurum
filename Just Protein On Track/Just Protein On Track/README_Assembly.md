# 🍳 Price Kitchen — Assembly Guide & Roadmap

---

## 📁 Структура проекта (20 файлов)

```
PriceKitchen/
├── PriceKitchenApp + Coordinator
│   └── KitchenCoordinator.swift        ← @main, Router, TabView, XP-система
│
├── Foundation
│   ├── SpicePalette.swift              ← Цвета, AccentFlavor, Environment key
│   ├── FlavorFeedback.swift            ← Хаптики, ConfettiBurst
│   ├── PantryStore.swift               ← Core Data stack (5 entities)
│   ├── GamificationEngine.swift        ← XP, трофеи, daily challenge, тосты
│   └── KeyboardMeshHelper.swift        ← Keyboard adaption, shimmer, утилиты
│
├── Localization
│   ├── en.lproj/Localizable.strings    ← English (base)
│   ├── de.lproj/Localizable.strings    ← Deutsch
│   └── fr.lproj/Localizable.strings    ← Français
│
├── Splash & Onboarding
│   ├── SplashBurnerView.swift          ← Анимированный splash (~3 сек)
│   └── TastingMenuView.swift           ← 4-страничный onboarding
│
├── Tab 1 — Kitchen (Dashboard)
│   ├── KitchenDashboardViewModel.swift
│   └── KitchenDashboardView.swift
│
├── Tab 2 — Market Basket (Товары & Цены)
│   ├── MarketBasketViewModel.swift
│   └── MarketBasketView.swift
│
├── Tab 3 — Inflation Oven (Анализ) ⚠️ см. секцию "Альтернатива"
│   ├── InflationOvenViewModel.swift
│   └── InflationOvenView.swift
│
├── Tab 4 — Spice Rack (Настройки)
│   ├── SpiceRackViewModel.swift
│   └── SpiceRackView.swift
│
└── README_Assembly.md                  ← Этот файл
```

---







### Шаг 4 — Добавить локализации
1. Project → Info → Localizations → добавить **German** и **French**
2. Создать группы `en.lproj`, `de.lproj`, `fr.lproj`
3. Поместить в каждую соответствующий `Localizable.strings`
4. В File Inspector каждого `.strings` файла отметить нужный язык

### Шаг 5 — Удалить заглушки из KitchenCoordinator.swift
В конце файла `KitchenCoordinator.swift` есть секция **"Placeholder Views"**.
Удалите ВСЕ заглушки:
```swift
// ❌ УДАЛИТЬ ВСЁ после комментария "Placeholder Views":
struct SplashBurnerView: View { ... }
struct TastingMenuView: View { ... }
struct KitchenDashboardView: View { ... }
struct MarketBasketView: View { ... }
struct InflationOvenView: View { ... }
struct SpiceRackView: View { ... }
```

### Шаг 6 — (Опционально) Asset Catalog для цветов
Если хотите использовать именованные цвета вместо fallback:
1. Assets.xcassets → New Color Set для каждого цвета из `SpicePalette`
2. Имена: `BurntCrust`, `SmokedPaprika`, `SaffronGold`, `BasilLeaf` и т.д.
3. Установить значения Appearance → Dark из fallback-констант

Без этого приложение будет использовать `*Fallback` цвета — всё работает.

### Шаг 7 — Build & Run
- Cmd+B для сборки
- Cmd+R для запуска
- Первый запуск: Splash → Onboarding → Kitchen Dashboard

---

## ⚠️ ЗАМЕНА ЭКРАНА INFLATION OVEN

### Проблема
Экран «Inflation Oven» (анализ инфляции) выглядит чужеродно в кулинарном
приложении. Терминология вроде «Personal Inflation Rate» и «Hottest Risers»
звучит как финансовый отчёт, а не как часть кулинарного опыта.

### 🍲 Альтернатива: «Flavor Lab» — Лаборатория рецептов и затрат

**Концепция:** Вместо абстрактной инфляции — практичный экран, где
пользователь собирает «рецепты» из отслеживаемых продуктов и видит,
сколько стоит приготовить блюдо. Это органично вписывается в кулинарную
тематику и решает ту же задачу (отслеживание роста цен), но через
понятную призму: «Мой борщ подорожал на 15% за полгода».

**Три ключевых фичи:**

#### Фича 1: Recipe Builder (Конструктор рецептов)
- Пользователь создаёт рецепт: «Паста Карбонара»
- Добавляет ингредиенты из своего Market Basket: спагетти, яйца, бекон, пармезан
- Указывает количество каждого ингредиента
- Система автоматически рассчитывает стоимость рецепта по последним ценам
- **Кулинарное название:** `RecipeCauldron` (котёл рецептов)

#### Фича 2: Cost Timeline (Стоимость блюда во времени)
- График стоимости рецепта за неделю/месяц/квартал/год
- Видно, какой ингредиент «виноват» в подорожании (breakdown)
- Вместо «Inflation +3.2%» → «Карбонара подорожала на €0.85 за месяц»
- **Кулинарное название:** `SimmerTimeline` (линия тушения)

#### Фича 3: Store Showdown (Битва магазинов за рецепт)
- «Где дешевле приготовить Карбонару — в Lidl или Rewe?»
- Суммирует стоимость ВСЕХ ингредиентов рецепта по ценам из разных магазинов
- Показывает экономию и рекомендует оптимальный магазин
- **Кулинарное название:** `MarketShowdown` (рыночная битва)

**Дополнительные идеи для Flavor Lab:**
- «Dish of the Week» — самый дешёвый рецепт на этой неделе
- «Price Alert» — уведомление, когда ингредиент рецепта подорожал на >10%
- «Budget Meal Planner» — «Что приготовить на €20?»
- Sharing: поделиться рецептом с раскладкой стоимости

**Новая Core Data сущность (добавить в PantryStore):**
```
RecipePot (рецепт)
├── potID: String (UUID)
├── dishName: String ("Pasta Carbonara")
├── dishEmoji: String ("🍝")
├── servings: Int32 (4)
├── dateCreated: Date
└── notes: String?

RecipeIngredientLink (связь рецепт↔продукт, без прямых references)
├── linkID: String (UUID)
├── potID: String (FK → RecipePot)
├── groceryItemID: String (FK → GroceryItem)
├── quantityNeeded: Double (0.5)
├── quantityUnit: String ("kg")
```

**Переименования в табе и навигации:**
```
Tab icon:  "flame.fill" → "flask.fill" или "testtube.2"
Tab label: "Oven" → "Lab"
Tab key:   "tab.oven" → "tab.lab"
```

---

## 📋 ЧТО УЛУЧШИТЬ В ТЕКУЩЕМ КОДЕ

> **Принцип:** Один таргет, полностью офлайн, без внешних зависимостей и сторонних SDK.
> Все фичи работают на устройстве без интернета. Единственное исключение —
> UIActivityViewController для экспорта (пользователь сам решает, куда отправить файл).

### 🔴 Критические улучшения

1. **NSManagedObject subclasses**
   Сейчас используется `setValue/value(forKey:)` — это хрупко и не типобезопасно.
   Создать proper NSManagedObject subclasses с typed properties:
   ```swift
   @objc(GroceryItem)
   public class GroceryItem: NSManagedObject {
       @NSManaged public var itemID: String
       @NSManaged public var recipeName: String
       // ...
   }
   ```

2. **Error handling**
   Добавить полноценную обработку ошибок при сохранении Core Data.
   Показывать пользователю alert при сбое вместо тихого `print()`.

3. **Input Validation**
   - Проверка дублей: нельзя добавить продукт с тем же именем в том же магазине
   - Проверка цены: отрицательные значения, слишком большие числа
   - Sanitize текстовых полей (trim, max length)

4. **Accessibility**
   - Добавить `accessibilityLabel` / `accessibilityHint` ко ВСЕМ интерактивным элементам
   - Поддержка Dynamic Type (сейчас фиксированные размеры шрифтов)
   - Проверить VoiceOver навигацию
   - Добавить `accessibilityValue` для progress bar и gauge

5. **Data Migration**
   Если схема Core Data изменится, нужна lightweight migration.
   Добавить `NSMigratePersistentStoresAutomaticallyOption` в container options.

### 🟡 Важные улучшения

6. **Фотографии чеков**
   - Камера / галерея для прикрепления фото чека к PriceTag
   - Сохранение в Documents directory, путь в Core Data
   - OCR через Vision framework для автоматического считывания цен

7. **Графики на Charts framework**
   Заменить кастомный `PriceLineChart` на Swift Charts (iOS 16+):
   ```swift
   import Charts
   Chart(crumbs) { crumb in
       LineMark(x: .value("Date", crumb.date),
                y: .value("Price", crumb.amount))
   }
   ```

8. **Quick Entry (Spotlight-стиль)**
   - Floating кнопка «+ Quick Price» доступная с любого таба
   - Поле автокомплита по существующим продуктам (локальный поиск Core Data)
   - Запись цены в 2 тапа: выбрал продукт → ввёл цену → готово
   - Запоминание последнего магазина для автоподстановки

9. **PDF / Image Export отчётов**
   - Генерация PDF-отчёта «Мой месяц» с графиками через UIGraphicsPDFRenderer
   - Рендер графиков как UIImage и вставка в PDF (всё локально, без сети)
   - Экспорт красивой карточки «My Inflation Card» как картинки для соцсетей
   - Share через UIActivityViewController (файл, не ссылка)

10. **Barcode Scanner (офлайн)**
    - Сканирование штрих-кода через камеру (AVFoundation, всё на устройстве)
    - Локальная привязка штрих-кода к GroceryItem (хранится в Core Data)
    - Повторное сканирование → моментальное открытие формы записи цены
    - Без внешних API — штрих-код это просто ID для быстрого доступа

### 🟢 Приятные дополнения

11. **Animations Polish (нативный SwiftUI, без сторонних SDK)**
    - Canvas + TimelineView для кастомных particle-эффектов при level-up
    - Matched geometry effect при переходах между табами
    - Parallax-эффект в карточках на scroll
    - Micro-interaction: числа XP «накручиваются» анимированно (Text + AnimatableModifier)

12. **Local Notifications (без сервера)**
    - Локальные напоминания через UNUserNotificationCenter (полностью офлайн)
    - «Ты не записывал цены 3 дня — streak горит!»
    - Напоминание при достижении трофея (local trigger)
    - Настраиваемое время напоминания в SpiceRack

13. **Haptic Cookbook (расширенные паттерны обратной связи)**
    - Уникальные хаптик-последовательности для каждого трофея
    - «Price Drop Dance» — особый паттерн когда цена упала
    - «Streak Fire» — нарастающая вибрация при streak 7, 14, 30 дней
    - Настройка интенсивности хаптиков в SpiceRack

14. **Budget Planner (планировщик бюджета)**
    - Установить недельный / месячный лимит на продукты
    - Трекинг потраченного на основе записанных цен
    - Визуальный индикатор «бюджетного здоровья» (зелёный → жёлтый → красный)
    - «Что приготовить на €20?» — подбор рецептов из Flavor Lab по бюджету

15. **Themes Beyond Accent**
    - Кастомные иконки приложения (alternate app icons)
    - Seasonal themes: новогодняя, хэллоуин, пасхальная палитра
    - Animated backgrounds в dashboard

16. **Sharing & Offline Social**
    - Поделиться рецептом с раскладкой стоимости (как картинка / PDF)
    - «Price Report Card» — красивая карточка «Мои расходы за месяц» для Stories
    - Экспорт отдельного продукта с историей цен (мини-CSV или картинка)
    - Копировать текст: «Молоко в Lidl: €1.29 → €1.49 (+15.5%)» в буфер обмена

17. **Smart Insights (локальная аналитика, без ML)**
    - Простая статистическая экстраполяция: «Если тренд сохранится, через месяц молоко будет €1.60»
    - Сезонные паттерны по собранным данным: «Молоко обычно дорожает в январе»
    - Обнаружение аномалий: цена изменилась на >20% — подсветить и спросить «Это точно?»
    - «Самый стабильный продукт» / «Самый непредсказуемый продукт» — на основе стандартного отклонения

18. **Data Import & Backup (офлайн)**
    - Импорт из CSV (обратная операция к экспорту) — через Files.app / Share Sheet
    - JSON backup / restore на устройстве (Documents directory)
    - «Duplicate Recipe» — копирование рецепта с изменением ингредиентов
    - Массовое добавление цен: вставить список «продукт, цена» из буфера обмена

---

## 🎮 ФИЧИ ГЕЙМИФИКАЦИИ ДЛЯ ДОБАВЛЕНИЯ

### Новые трофеи
| Трофей | Условие | XP |
|--------|---------|-----|
| 🌍 Globe Trotter | Использовал 3+ разных валюты | +50 |
| 📸 Receipt Hunter | Прикрепил 10 фото чеков | +75 |
| 🧮 Math Wizard | Создал 5 рецептов в Flavor Lab | +60 |
| 🏃 Speed Logger | Записал 5 цен за 1 минуту | +40 |
| 🌙 Night Owl | Записал цену после 23:00 | +15 |
| 🌅 Early Bird | Записал цену до 07:00 | +15 |
| 📅 Monthly Master | Логировал цены каждый день месяца | +300 |
| 💯 Centurion | Отслеживает 100+ продуктов | +500 |
| 🎂 Anniversary | Использует приложение год | +1000 |

### Система рангов (расширенная)
```
Level 1-2:    Apprentice Cook     🥄
Level 3-4:    Line Cook           🍴
Level 5-7:    Prep Chef           🔪
Level 8-10:   Station Chef        🍳
Level 11-14:  Sous Chef           👨‍🍳
Level 15-19:  Head Chef           🎩
Level 20-24:  Executive Chef      ⭐
Level 25-29:  Master Chef         🏆
Level 30-39:  Culinary Director   💎
Level 40-49:  Kitchen Legend       👑
Level 50+:    Gastronomic God     🌟
```

### Weekly Challenges (недельные испытания)
- «Log prices from 5 different stores this week» → +100 XP
- «Track a new product every day this week» → +150 XP
- «Build 2 new recipes in Flavor Lab» → +80 XP

### Seasonal Events
- «Black Friday Tracker»: залогируй 20 цен в чёрную пятницу → уникальный badge
- «New Year Price Check»: сравни цены 1 января с 1 декабря → уникальный badge
- «Summer Sale Hunter»: найди продукт, подешевевший на 20%+ → уникальный badge

---

## 🛠 ТЕХНИЧЕСКИЙ ДОЛГ

1. **Unit Tests**
   - Тесты для `KitchenCoordinator` (phase transitions, XP calculations)
   - Тесты для `GamificationEngine` (trophy conditions, streak computation)
   - Тесты для ViewModels (Core Data CRUD через in-memory store)
   - Snapshot tests для ключевых экранов

2. **UI Tests**
   - Полный flow: onboarding → add item → log price → check dashboard
   - Accessibility audit

3. **Performance**
   - Lazy loading для больших списков PriceTag
   - Background context для тяжёлых вычислений (inflation computation)
   - Profiling Core Data fetch frequency (Instruments)

4. **Architecture**
   - Dependency Injection container вместо `PantryStore.shared`
   - Protocol abstractions для testability
   - Combine pipelines вместо manual fetch в ViewModels

5. **CI/CD**
   - GitHub Actions: build + test on push
   - Fastlane для автоматического деплоя в TestFlight
   - SwiftLint для code style consistency

---

## 📱 ПОДДЕРЖКА iOS ВЕРСИЙ

| Фича | iOS 16 | iOS 17 | iOS 18 | iOS 26 |
|-------|--------|--------|--------|--------|
| Core UI | ✅ | ✅ | ✅ | ✅ |
| ScrollView dismiss keyboard | ✅ | ✅ | ✅ | ✅ |
| Swift Charts (upgrade) | ✅ | ✅ | ✅ | ✅ |
| TipKit onboarding hints | ❌ | ✅ | ✅ | ✅ |
| Observation framework | ❌ | ✅ | ✅ | ✅ |
| PDF export | ✅ | ✅ | ✅ | ✅ |
| AVFoundation barcode | ✅ | ✅ | ✅ | ✅ |
| Liquid Glass | ❌ | ❌ | ❌ | ✅ |

Всё работает в **одном таргете**, полностью **офлайн**, без внешних зависимостей.
Для iOS 26 Liquid Glass: стили навигации и TabBar подхватятся автоматически
через стандартные SwiftUI компоненты.

---

## 🚀 ПРИОРИТЕТЫ РАЗРАБОТКИ (рекомендуемый порядок)

### Phase 1 — MVP Polish
- [ ] NSManagedObject subclasses
- [ ] Input validation
- [ ] Accessibility basics
- [ ] Замена Inflation Oven → Flavor Lab (Recipe Builder)

### Phase 2 — Engagement
- [ ] Notifications (streak reminders)
- [ ] Weekly challenges
- [ ] Extended trophy system
- [ ] Swift Charts integration

### Phase 3 — Power Features
- [ ] Barcode scanner (офлайн, AVFoundation)
- [ ] Photo receipts + OCR (Vision, на устройстве)
- [ ] Flavor Lab: Cost Timeline + Store Showdown
- [ ] PDF / Image export отчётов

### Phase 4 — Depth & Polish
- [ ] Budget Planner (лимиты + трекинг)
- [ ] Smart Insights (локальная статистика, экстраполяция)
- [ ] Data Import из CSV / JSON backup
- [ ] Haptic Cookbook (расширенные паттерны)

---

*Built with 🧂 and ❤️ in Price Kitchen.*
