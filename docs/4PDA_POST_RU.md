# F2FS Guardian v1

**Автор:** Lolokeksu  
**Android:** 13–16, API 33–36  
**Root:** Magisk 20.4+, KernelSU, APatch  
**Требование:** `/data` на F2FS и доступные sysfs-узлы F2FS

F2FS Guardian — консервативный systemless-модуль для контролируемого обслуживания F2FS. Он не повышает частоты CPU/GPU, не обещает прирост FPS и не увеличивает физическую скорость UFS. Модуль переносит ограниченную штатную сборку мусора F2FS на безопасное время простоя, когда накопитель действительно сильно заполнен.

## Основные возможности

- определение точного F2FS-экземпляра `/data`;
- контроль заполнения, dirty- и free-сегментов;
- запуск только при выключенном экране, зарядке, допустимой температуре и низкой I/O-нагрузке;
- только стандартные режимы `gc_urgent=2` и `gc_urgent=1`;
- строгий лимит длительности;
- безопасный возврат принадлежащего модулю режима в `0`;
- обнаружение конфликтов с другими F2FS-твиками;
- локальный ограниченный журнал;
- отсутствие телеметрии, сети, сторонних бинарников и рекламных переходов.

## Проверено

Realme GT Neo 5 SE, Android 13 / API 33, APatch, `/data` F2FS (`dm-51`): установка, self-test, демон, статус, очередь и отмена подтверждены. Реальный GC намеренно не форсировался при заполнении 19%.

## Установка

1. Сделать резервную копию важных данных.
2. Установить `F2FS-Guardian-v1.zip` через менеджер Magisk, KernelSU или APatch.
3. Перезагрузить устройство.
4. Выполнить:

```sh
su -c /data/adb/modules/f2fs_guardian/f2fs-guardian.sh self-test
su -c /data/adb/modules/f2fs_guardian/f2fs-guardian.sh status
```

Ожидаемый результат self-test:

```text
PASS: runtime prerequisites are available
```

## Команды

```sh
su -c /data/adb/modules/f2fs_guardian/f2fs-guardian.sh status
su -c /data/adb/modules/f2fs_guardian/f2fs-guardian.sh check
su -c /data/adb/modules/f2fs_guardian/f2fs-guardian.sh request
su -c /data/adb/modules/f2fs_guardian/f2fs-guardian.sh cancel
su -c /data/adb/modules/f2fs_guardian/f2fs-guardian.sh logs
su -c /data/adb/modules/f2fs_guardian/f2fs-guardian.sh menu
```

## Ограничения

- На ext4 модуль бесполезен и установка отменяется.
- При низком заполнении F2FS сессия может никогда не потребоваться.
- GC создаёт дополнительные внутренние записи; частые ручные запросы не дают пользы.
- После смены прошивки или ядра нужно повторить `self-test`.
- Не сочетать с другими инструментами, которые записывают `/sys/fs/f2fs/*/gc_urgent`.

## Безопасность

В ZIP нет ELF-бинарников, `curl`, `wget`, `eval`, телеметрии, сетевых подключений, SELinux permissive, прав 777 и изменений загрузочных разделов. Конфигурация читается как данные и не выполняется shell-интерпретатором.

Лицензия: GPL-3.0-only.
