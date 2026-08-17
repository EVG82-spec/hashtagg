# FiltersApiRepository - Документация по использованию

## Обзор

`FiltersApiRepository` предоставляет методы для работы с фильтрами поиска объявлений.

## Методы

### getFilterOptions()

Получает опции фильтров для категории, включая доступные переключатели (VIP, безопасная сделка и т.д.) и динамические фильтры.

```dart
final result = await filtersApi.getFilterOptions(
  categoryId: 17, // ID категории, 0 для всех категорий
  filters: {
    '123': ['456'], // Текущие выбранные фильтры для подфильтров
  },
);

if (result['status'] == true) {
  final data = result['data'];
  
  // Опции переключателей
  final options = data['options'] as Map<String, dynamic>?;
  // {
  //   'secure': 'Безопасная сделка',
  //   'online_view': 'Онлайн-показ',
  //   'auction': 'Аукцион',
  //   'vip': 'VIP объявления',
  //   'condition_status': 'Новые товары',
  //   'booking': 'Онлайн-бронирование'
  // }
  
  // Название поля цены
  final priceName = data['price_name'] as String?; // 'Цена' или 'Стоимость'
  
  // Динамические фильтры
  final filters = data['filters'] as List?;
  // [
  //   {
  //     'id': 123,
  //     'view': 'select', // или 'checkbox', 'input'
  //     'name': 'Тип',
  //     'items': [
  //       {'id': 456, 'name': 'Легковые', 'podfilter': false}
  //     ],
  //     'required': true,
  //     'podfilter': false,
  //     'ids_podfilter': [124, 125]
  //   }
  // ]
}
```

## Структура данных

### Options (Переключатели)

Доступные опции зависят от категории:

- `secure` - Безопасная сделка
- `online_view` - Онлайн-показ
- `auction` - Аукцион
- `vip` - VIP объявления (всегда доступно)
- `condition_status` - Новые товары
- `booking` - Онлайн-бронирование/аренда

### Filters (Динамические фильтры)

Каждый фильтр содержит:

- `id` (int) - ID фильтра
- `view` (string) - Тип отображения:
  - `select` - Выпадающий список (одиночный выбор)
  - `checkbox` - Чипсы (множественный выбор)
  - `input` - Текстовое поле
- `name` (string) - Название фильтра
- `items` (array) - Список значений фильтра:
  - `id` (int) - ID значения
  - `name` (string) - Название значения
  - `podfilter` (bool) - Есть ли подфильтры
- `required` (bool) - Обязательный ли фильтр
- `podfilter` (bool) - Есть ли подфильтры у этого фильтра
- `ids_podfilter` (array) - ID связанных подфильтров

## Использование в SearchFilters

```dart
class SearchFilters {
  final String? city;
  final int? cityId;
  final String? category;
  final int? categoryId;
  final Map<String, bool> options; // Переключатели
  final int? priceFrom;
  final int? priceTo;
  final Map<String, List<String>> filters; // Выбранные фильтры
}
```

### Формат выбранных фильтров

```dart
{
  '123': ['456'], // ID фильтра: [ID выбранного значения]
  '124': ['789', '790'], // Множественный выбор
  '125': ['100'] // Для input-фильтров - введенное значение
}
```

## Подфильтры

Если у фильтра `podfilter == true`, то при выборе значения нужно:

1. Обновить `filters` с выбранным значением
2. Вызвать `getFilterOptions()` снова с обновленными `filters`
3. API вернет дополнительные фильтры, зависящие от выбранного значения

Пример:
```dart
// Выбрали "Легковые" в фильтре "Тип"
setState(() {
  _selectedFilters['123'] = ['456'];
});

// Перезагружаем фильтры
if (filter['podfilter'] == true) {
  await _loadFilterOptions(); // Получим подфильтры для легковых
}
```

## Интеграция с поиском

При применении фильтров передавайте их в API поиска:

```dart
final searchResult = await searchApi.search(
  query: searchQuery,
  cityId: filters.cityId,
  categoryId: filters.categoryId,
  priceFrom: filters.priceFrom,
  priceTo: filters.priceTo,
  filters: filters.filters, // Динамические фильтры
  vip: filters.options['vip'] ?? false,
  secure: filters.options['secure'] ?? false,
  // и т.д.
);
```

## Примечания

1. При `categoryId = 0` возвращаются общие фильтры для всех категорий
2. Опции зависят от настроек категории в админке
3. Фильтры кэшируются на стороне сервера
4. При изменении категории нужно перезагружать фильтры
5. Подфильтры загружаются динамически при выборе родительского значения

## Логирование

Репозиторий автоматически логирует все операции с префиксами:
- 🔵 - информация
- ✅ - успех
- 🔴 - ошибка
