# BatteryGuard

Ограничение заряда и защита батареи от нагрева для старых MacBook на Intel.
Значок в строке меню показывает заряд, температуру и состояние службы.

*English summary below.*

## Что умеет

- Держит заряд на выбранном уровне: 70-100%, по умолчанию 80%. Дальше Mac работает от сети, батарея не заряжается.
- Останавливает зарядку, если батарея нагрелась выше порога (по умолчанию 40 °C), и возобновляет, когда остынет (ниже 35 °C).
- Значок в строке меню: шкала заряда, зеленая молния при зарядке, вилка при питании от сети без зарядки, желтый и красный цвет при низком заряде.
- Рядом со значком на выбор: процент заряда, температура, время работы от батареи или ничего.
- Пороги меняются прямо из меню значка.

## Какие Mac поддерживаются

MacBook на процессорах Intel, в контроллере питания (SMC) которых есть ключ `BCLM`. Приложение само проверяет это при первом запуске и сообщает, если Mac не подходит.

Проверено: MacBook Pro 11,3 (2013), macOS 14 Sonoma через OpenCore Legacy Patcher.
Нужна macOS 11 Big Sur или новее. Mac на Apple Silicon не поддерживаются.

Если вы проверили приложение на другой модели, напишите в Issues: модель, версия macOS, работает или нет.

## Установка

1. Скачайте `BatteryGuard-x.y.z.zip` в разделе [Releases](../../releases) и распакуйте.
2. Перетащите `BatteryGuard.app` в папку «Программы».
3. Откройте приложение. Оно не подписано сертификатом Apple, поэтому macOS его остановит.
   Откройте «Системные настройки», раздел «Конфиденциальность и безопасность», внизу нажмите «Все равно открыть».
4. Приложение предложит установить службу и попросит пароль администратора.

После этого значок появляется в строке меню и запускается сам при входе в систему.

## Удаление

Меню значка, пункт «Удалить службу». Лимит заряда вернется к 100%. Затем удалите `BatteryGuard.app` из «Программ».

## Как это работает

- Служба `/usr/local/battery-guard/battery-guard.sh` запускается от root раз в минуту (LaunchDaemon `local.batteryguard.daemon`).
- Лимит заряда задается ключом SMC `BCLM` через небольшую утилиту `smcctl` (исходник в `src/smcctl.c`).
- Контроллер батареи считает заряд на несколько процентов ниже, чем macOS. Поэтому когда macOS показывает лимит, служба ставит в `BCLM` текущий процент контроллера, и зарядка останавливается сразу.
- При нагреве служба так же фиксирует текущий процент, пока батарея не остынет.
- Пороги хранятся в `/usr/local/battery-guard/thresholds`. Файл принадлежит пользователю, служба принимает из него только числа в допустимых пределах.
- Журнал: `log show --last 1d --predicate 'process == "logger"' | grep battery-guard`

## Сборка из исходников

Нужны Xcode Command Line Tools.

```
./build.sh
```

Результат: `build/BatteryGuard.app` и `build/BatteryGuard-x.y.z.zip`.

## Предупреждение

Приложение записывает значения в контроллер питания Mac. Используйте на свой риск. Сброс SMC или удаление службы возвращает стандартное поведение зарядки.

---

## English summary

BatteryGuard limits battery charge (70-100%, default 80%) and pauses charging when the battery is hot (default above 40 °C, resumes below 35 °C) on older Intel MacBooks whose SMC has the `BCLM` key. A menu bar icon shows charge, temperature and service state; thresholds are set from the menu.

Install: download the zip from Releases, move `BatteryGuard.app` to Applications, open it, confirm "Open Anyway" in System Settings > Privacy & Security (the app is not notarized), then allow the service install with your admin password. Uninstall from the menu ("Удалить службу").

Requires macOS 11+, Intel. Tested on MacBook Pro 11,3 (2013) with macOS 14 via OpenCore Legacy Patcher. The UI is in Russian for now. Use at your own risk.

## License

MIT, see [LICENSE](LICENSE).
