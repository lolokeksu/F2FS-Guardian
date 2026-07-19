<h1 align="center">F2FS Guardian</h1>

<hr>

<h2 align="center">Прозрачное и безопасно ограниченное обслуживание F2FS для Android 13–16 с root</h2>

<p align="center">
  <a href="https://github.com/lolokeksu/F2FS-Guardian/releases/tag/v1"><img alt="Релиз v1" src="https://img.shields.io/badge/release-v1-0ea5e9"></a>
  <a href="https://github.com/lolokeksu/F2FS-Guardian/actions/workflows/ci.yml"><img alt="Проверка и сборка" src="https://github.com/lolokeksu/F2FS-Guardian/actions/workflows/ci.yml/badge.svg"></a>
  <img alt="Android 13–16" src="https://img.shields.io/badge/Android-13--16-3ddc84?logo=android&logoColor=white">
</p>

<p align="center">
  <img alt="Tested device" src="https://img.shields.io/badge/tested-Realme%20GT%20Neo%205%20SE-64748b">
  <img alt="Root APatch tested" src="https://img.shields.io/badge/root-APatch%20tested-f97316">
  <img alt="Filesystem F2FS" src="https://img.shields.io/badge/filesystem-F2FS-334155">
</p>

<p align="center">
  <img alt="POSIX shell runtime" src="https://img.shields.io/badge/runtime-POSIX%20shell-a3a3a3?logo=gnu-bash&logoColor=111827">
  <a href="LICENSE"><img alt="GPL-3.0-only" src="https://img.shields.io/badge/license-GPL--3.0--only-0ea5e9"></a>
  <img alt="No telemetry" src="https://img.shields.io/badge/telemetry-none-22c55e">
</p>

<p align="center"><a href="README.md">English</a> · <a href="https://github.com/lolokeksu/F2FS-Guardian/releases">Релизы</a> · <a href="https://github.com/lolokeksu/F2FS-Guardian/issues">Проблема</a> · <a href="SECURITY.md">Безопасность</a></p>
---

## Назначение

F2FS Guardian контролирует реальный экземпляр F2FS, на котором расположен `/data`, и может запустить короткую штатную сессию сборки мусора только при высокой заполненности файловой системы и в подтверждённом безопасном окне.

Это не CPU/GPU-твик, не модуль повышения FPS и не средство увеличения максимальной скорости UFS. Модуль решает узкую задачу: переносит тяжёлое обслуживание F2FS на время простоя и снижает вероятность его совпадения с активным использованием телефона.

## Статус релиза

**v1 — первый стабильный релиз автора Lolokeksu.**

Аппаратная интеграция проверена на:

| Устройство | Android | Root | `/data` | Результат |
|---|---:|---|---|---|
| Realme GT Neo 5 SE | 13 / API 33 | APatch | F2FS, `dm-51` | Установка, self-test, демон, статус, очередь и отмена подтверждены |

Реальная сессия GC намеренно не форсировалась: заполнение накопителя составляло 19%, поэтому политика корректно выдала `no trigger`. Это штатное защитное поведение.

## Принцип работы

F2FS уже имеет собственный сборщик мусора. F2FS Guardian не заменяет его, а добавляет консервативный контроллер стандартного sysfs-интерфейса `gc_urgent`:

1. определяет точный F2FS-раздел `/data`;
2. читает заполнение, свободные и dirty-сегменты;
3. проверяет экран, зарядку, батарею, температуру и I/O-нагрузку;
4. включает только документированный режим GC;
5. ограничивает длительность;
6. возвращает принадлежащий модулю режим в `gc_urgent=0`;
7. прекращает работу при изменении условий или конфликте с другим инструментом.

## Совместимость

Требуется:

- Android 13–16, API 33–36;
- Magisk 20.4+, KernelSU или APatch;
- F2FS на `/data`;
- записываемый `/sys/fs/f2fs/<instance>/gc_urgent`;
- доступные `free_segments` и `dirty_segments` для автоматического режима;
- статистика блочного устройства для проверки I/O-простоя.

Не требуется:

- Zygisk;
- LSPosed;
- Termux для фоновой работы;
- отдельный BusyBox-модуль;
- кастомное ядро, если штатное ядро предоставляет необходимые F2FS-узлы.

Версия Android сама по себе не гарантирует совместимость. После смены прошивки или ядра нужно снова выполнить `self-test`.

## Гарантии безопасной логики

F2FS Guardian v1:

- использует `gc_urgent=2` для обычной и `gc_urgent=1` для короткой критической сессии;
- не использует недокументированный режим `4`;
- не меняет `gc_urgent_sleep_time`;
- не меняет права файлов в `/sys`;
- не перезаписывает уже активный чужой режим GC;
- постоянно перепроверяет условия во время активной сессии;
- сбрасывает только тот режим, владение которым может подтвердить;
- читает конфигурацию как данные и не выполняет её через `source` или `eval`;
- не содержит ELF-бинарников, загрузчиков, телеметрии и удалённого кода;
- не меняет SELinux, AVB, dm-verity, `boot`, `init_boot`, `vendor_boot`, `dtbo`, `vbmeta` и динамические разделы;
- не использует физические кнопки при установке.

## Параметры сбалансированного профиля

Все защитные условия обязательны:

| Условие | Значение |
|---|---:|
| Проверка состояния | раз в 60 минут |
| Интервал между успешными сессиями | минимум 24 часа |
| Выключенный экран | минимум 20 минут |
| Зарядка | обязательна |
| Заряд аккумулятора | не ниже 50% |
| Температура аккумулятора | не выше 39,0 °C |
| I/O-активность | не выше 25 операций/с |

Обычная сессия:

| Параметр | Значение |
|---|---:|
| Заполнение `/data` | от 84% |
| Dirty-сегменты | от 256 |
| Режим | `gc_urgent=2` |
| Максимальная длительность | 480 секунд |

Критическая сессия:

| Параметр | Значение |
|---|---:|
| Заполнение `/data` | от 95% |
| Dirty-сегменты | от 128 |
| Свободные сегменты | не более 96 |
| Режим | `gc_urgent=1` |
| Максимальная длительность | 90 секунд |

Пороговые значения являются консервативной политикой модуля, а не универсальными константами F2FS.

## Установка

1. Сохранить важные пользовательские данные.
2. Скачать `F2FS-Guardian-v1.zip` из GitHub Releases.
3. Установить ZIP через Magisk, KernelSU или APatch Manager.
4. Перезагрузить устройство.
5. Выполнить проверку:

```sh
su -c /data/adb/modules/f2fs_guardian/f2fs-guardian.sh self-test
```

Ожидаемый результат:

```text
PASS: runtime prerequisites are available
```

6. Проверить состояние:

```sh
su -c /data/adb/modules/f2fs_guardian/f2fs-guardian.sh status
```

Результат `no trigger` при низкой заполненности является правильным. Не следует принудительно запускать GC только ради проверки записи в sysfs.

## Основные команды

```sh
# Полный статус
su -c /data/adb/modules/f2fs_guardian/f2fs-guardian.sh status

# Проверка условий без запуска
su -c /data/adb/modules/f2fs_guardian/f2fs-guardian.sh check

# Безопасный запрос в очередь
su -c /data/adb/modules/f2fs_guardian/f2fs-guardian.sh request

# Отмена очереди или активной сессии модуля
su -c /data/adb/modules/f2fs_guardian/f2fs-guardian.sh cancel

# Последние строки журнала
su -c /data/adb/modules/f2fs_guardian/f2fs-guardian.sh logs

# Текущая конфигурация
su -c /data/adb/modules/f2fs_guardian/f2fs-guardian.sh config

# Интерактивное меню
su -c /data/adb/modules/f2fs_guardian/f2fs-guardian.sh menu

# Профили
su -c '/data/adb/modules/f2fs_guardian/f2fs-guardian.sh profile balanced'
su -c '/data/adb/modules/f2fs_guardian/f2fs-guardian.sh profile conservative'
su -c '/data/adb/modules/f2fs_guardian/f2fs-guardian.sh profile manual'
```

Termux необязателен и используется только как удобный терминал.

## Профили

**Balanced:** стандартный режим, проверка раз в 60 минут, интервал 24 часа, экран выключен 20 минут, обычный порог 84% и 256 dirty-сегментов.

**Conservative:** проверка раз в 120 минут, интервал 48 часов, экран выключен 30 минут, порог 88% и 512 dirty-сегментов, сокращённые сессии.

**Manual:** автоматическое обслуживание отключено; мониторинг и безопасная очередь остаются доступны.

## Конфигурация

Пользовательская конфигурация:

```text
/data/adb/f2fs_guardian/config.conf
```

Заводской шаблон:

```text
/data/adb/modules/f2fs_guardian/config/default.conf
```

Парсер принимает только фиксированный список целочисленных параметров. Неизвестные и некорректные значения игнорируются. Конфигурация сохраняется при обновлении и удаляется при штатном удалении модуля.

## Расшифровка статуса

| Строка | Значение |
|---|---|
| `gc_urgent: 0` | Принудительный GC модуля не активен |
| `Last run: never` | Успешная сессия ещё не выполнялась |
| `no trigger` | Состояние F2FS не требует обслуживания |
| `waiting: not charging` | Триггер или запрос есть, но зарядка не подключена |
| `Manual request: queued` | Запрос ожидает безопасного окна |
| `manual maintenance cancelled` | Очередь успешно отменена |

Команда Android `ps -A` может отображать демон только как `sh`. Авторитетный PID хранится в:

```text
/data/adb/f2fs_guardian/state/daemon.lock/pid
```

## Журнал и приватность

```text
/data/adb/f2fs_guardian/logs/guardian.log
/data/adb/f2fs_guardian/state/
```

Размер журнала ограничен. Модуль не отправляет логи, идентификаторы устройства или телеметрию.

## Конфликты

Не следует использовать F2FS Guardian одновременно с другим модулем, kernel manager или загрузочным скриптом, который меняет те же F2FS-узлы. Модуль откажется запускаться при уже установленном ненулевом `gc_urgent`. Если сторонний инструмент изменит значение во время сессии, F2FS Guardian зафиксирует потерю владения и не станет перезаписывать чужой режим.

## Удаление и восстановление

Штатное удаление через менеджер root запускает `uninstall.sh`, останавливает принадлежащую модулю сессию, возвращает её режим в `0` и удаляет конфигурацию, состояние и журнал.

При невозможности загрузить интерфейс менеджера:

```sh
adb shell su -c 'touch /data/adb/modules/f2fs_guardian/disable'
adb reboot
```

Recovery сможет применить такой способ только при доступном расшифрованном `/data`.

## Ограничения

- На `ext4` модуль бесполезен и не устанавливается.
- При низкой заполненности F2FS сессии могут никогда не запускаться.
- Любой GC создаёт дополнительные внутренние записи; частые ручные запросы не дают пользы.
- Модуль не исправляет повреждение файловой системы.
- Задержки из-за нагрева, RAM, приложений, компиляции шейдеров или CPU/GPU не относятся к его задаче.
- После обновления прошивки или ядра совместимость нужно проверить заново.

## Сборка и проверка

```sh
./tests/static_checks.sh
./tests/mock_runtime_test.sh
./tests/mock_cancel_test.sh
./tests/mock_conflict_test.sh
./tests/mock_cli_state_test.sh
./scripts/build.sh
sha256sum -c dist/SHA256SUMS
```

GitHub Actions выполняет тот же набор проверок. Сборка воспроизводима: порядок файлов и временные метки нормализуются.

## Авторство

**Автор и сопровождающий: Lolokeksu.**

F2FS Guardian является самостоятельной реализацией. В нём отсутствуют код, бинарники, телеметрия и рекламные действия F2FS-SuperGC.

## Лицензия

Copyright © 2026 Lolokeksu.

[GPL-3.0-only](LICENSE).
