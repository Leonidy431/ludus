# Godot для Ludus: как он стоит у Claude и как поставить его оператору для тестов со шлемом

**Поручение оператора (дословно):** «документируй как ты ставил себе godot и мне пропиши как локально на машину поставить для тестов с шлема».

Версии закреплены в `.github/workflows/godot.yml`: `GODOT_VERSION: '4.7.1'` и `VENDORS_TAG: '5.1.0-stable'`. Ставить нужно **ровно эти версии**, иначе пакеты `.pck` и шаблоны не сойдутся.

---

## Часть 1. Как это стоит у Claude (дев-сервер, Linux x86-64, без GPU)

| Что | Как поставлено | Где | Зачем |
|---|---|---|---|
| Godot 4.7.1-stable | `scripts/godot/ci_setup.sh` — тот же скрипт, что в CI: скачивает `Godot_v4.7.1-stable_linux.x86_64.zip` с `github.com/godotengine/godot-builds/releases` | `/home/user/godot-deps/Godot_v4.7.1-stable_linux.x86_64` | тесты (`--headless`), импорт, замеры, кадры |
| Шаблоны экспорта | из архива `Godot_v4.7.1-stable_export_templates.tpz` (около 1,3 ГБ) распакованы только нужные файлы (`android_*`, `web_*`, `version.txt`), архив удалён | `~/.local/share/godot/export_templates/4.7.1.stable/` | экспорт APK и веба |
| Плагин Meta (OpenXR vendors) 5.1.0-stable | `godotopenxrvendorsaddon.zip` с GitHub GodotVR, в репо не коммитится | `godot/addons/godotopenxrvendors` (только в CI) | загрузчик OpenXR Meta, манифест Quest |
| Свой шаблон движка | `.github/workflows/godot-engine.yml` собирает из исходников 4.7.1 со своим профилем; на сервере — пробная Linux-сборка | `/home/user/godot-src/` | −30 % `libgodot_android.so` |
| Экран для кадров | Xvfb (`xvfb-run`), рендер llvmpipe (Mesa) | системные пакеты | кадры `docs/audit/`, бюджеты сцен |
| Vulkan программный | `apt-get install mesa-vulkan-drivers` (lavapipe) | `/usr/share/vulkan/icd.d/lvp_icd.json` | проверка Forward+ (проиграл выбору «SGI») |
| Наш «SGI» | `python3.11 -m venv /home/user/bpy-venv && pip install bpy==4.5.14 pillow` | `/home/user/bpy-venv` | пререндер и обороты (`scripts/prerender/`) |
| Черновой голос | `python3.11 -m venv /home/user/tts-venv && pip install piper-tts`; голоса Piper v0.0.2 с GitHub (ru irina, en kathleen, de thorsten, fr siwis, es carlfm, it riccardo) | `/home/user/tts-venv`, папка голосов в scratchpad | голос рассказчика (Д-22) |

**Команды, которыми проверяется всё:**

```bash
G=/home/user/godot-deps/Godot_v4.7.1-stable_linux.x86_64
$G --headless --path godot --import                                   # импорт
$G --headless --path godot --script res://tests/run_hub_tests.gd      # тесты хаба и пилота
xvfb-run -a -s "-screen 0 1280x720x24" $G --path godot --rendering-driver opengl3 \
   -s res://tools/measure_budgets.gd -- --scene=pilot --check         # бюджеты
xvfb-run -a -s "-screen 0 1280x720x24" $G --path godot --rendering-driver opengl3 \
   -s res://tools/pilot_shots.gd -- --out=../docs/audit/<дата>        # кадры
```

---

## Часть 2. Как поставить оператору на свой компьютер для тестов со шлемом Quest 3S

### Шаг 0. Что нужно

- Компьютер: Windows 10/11, macOS 12+ или Linux x86-64; 8 ГБ ОЗУ; около 10 ГБ свободного места.
- **Meta Quest 3S** с включённым **режимом разработчика**: телефон → приложение **Meta Horizon** → Устройства → шлем → Настройки шлема → Режим разработчика → вкл. Аккаунт разработчика (организация на developer.meta.com) нужен один раз.
- Кабель USB-C с передачей данных (не только зарядка) или Wi-Fi.

### Шаг 1. Godot 4.7.1-stable

1. Скачать **Godot 4.7.1-stable, Standard** (не .NET) для своей системы: страница релизов `github.com/godotengine/godot-builds/releases`, тег `4.7.1-stable`.
2. Распаковать и запустить. Установка не нужна.
3. В редакторе: **Editor → Manage Export Templates → Download and Install** (версия 4.7.1.stable).

### Шаг 2. Android: JDK 17 и SDK

1. Поставить **OpenJDK 17**, например Adoptium Temurin 17.
2. Поставить **Android Studio**, в SDK Manager отметить: Android SDK Platform 34, Build-Tools 34.0.0, Platform-Tools, Command-line Tools. Можно и без Android Studio, через `cmdline-tools` и `sdkmanager "platform-tools" "build-tools;34.0.0" "platforms;android-34"`.
3. В Godot: **Editor → Editor Settings → Export → Android**:
   - **Java SDK Path** — папка JDK 17;
   - **Android SDK Path** — папка SDK (Windows: `%LOCALAPPDATA%\Android\Sdk`).

### Шаг 3. Проект и плагин Meta

```bash
git clone https://github.com/Leonidy431/ludus.git
cd ludus
# Плагин Meta той же версии, что в CI:
curl -L -o vendors.zip https://github.com/GodotVR/godot_openxr_vendors/releases/download/5.1.0-stable/godotopenxrvendorsaddon.zip
unzip -o vendors.zip -d vendors && cp -r vendors/asset/addons/godotopenxrvendors godot/addons/
```

Открыть в Godot файл `godot/project.godot`, дождаться импорта. Проверить: **Project → Project Settings → Plugins** — плагин Godot OpenXR Vendors включён.

### Шаг 4. Ключ подписи (чтобы APK вставал поверх прежнего)

- Взять тот же отладочный ключ, что у CI (Д-1): `debug.keystore`, alias `androiddebugkey`, пароль `android`. Положить, например, в `~/.ludus-signing/debug.keystore`.
- В Godot: **Editor Settings → Export → Android → Debug Keystore**: путь, пользователь `androiddebugkey`, пароль `android`.
- С другим ключом шлем не поставит APK поверх версии из CI. Придётся удалить игру вместе с сохранениями.

### Шаг 5. Запуск в шлеме — три способа

**А. Одной кнопкой из Godot (быстрее всего для тестов).**
1. Подключить шлем кабелем. В шлеме разрешить «Отладку по USB».
2. Проверить: `adb devices` показывает устройство (`adb` лежит в `platform-tools`).
3. В Godot: **Project → Export → Android (Quest)**, должны быть галочки XR Mode = OpenXR и Meta plugin (они уже есть в `export_presets.cfg`).
4. В правом верхнем углу редактора нажать значок Android (**Remote Deploy**). Godot соберёт, поставит и запустит игру в шлеме. Лог — в нижней панели Output (Remote Debug).

**Б. Готовый APK из CI (без сборки).**
1. Скачать `ludus-headset.apk` и `.sha256` из релиза **headset-latest**: `github.com/Leonidy431/ludus/releases/tag/headset-latest`.
2. Сверить: `sha256sum -c ludus-headset.apk.sha256` (Windows: `certutil -hashfile ludus-headset.apk SHA256`).
3. Поставить: `adb install -r ludus-headset.apk`. Или через **Meta Quest Developer Hub** (перетащить APK), или через SideQuest.

**В. Своя сборка в файл.** **Project → Export → Export Project** → `ludus.apk` → `adb install -r ludus.apk`.

### Шаг 6. Где в шлеме игра и что проверить

- Шлем → Библиотека → Приложения → фильтр **Неизвестные источники** → Ludus.
- Первый запуск — пилот «Табу» (холодное начало). Повторный — двор. Пересмотреть пилот: удалить `user://pilot.json` (`adb shell run-as org.ludus.dive rm files/pilot.json`) или переустановить.
- Логи: `adb logcat -s godot` (ошибки скриптов и OpenXR).
- Пакеты подкачки лежат в `user://packs`. Без сети игра идёт без них.
- **Что записать для Д-17:** где сняли шлем, где ахнули, где спросили «а дальше?». Заметили ли детали, удобно ли присесть под стол, читается ли пререндер в очках, нет ли рывка при открытии видео.

### Частые ошибки

| Ошибка | Причина | Что сделать |
|---|---|---|
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | APK подписан другим ключом | Шаг 4 или удалить игру (потеряются сохранения) |
| Игра стартует плоским окном | плагин Meta не включён или нет XR Mode | Шаг 3, проверить пресет экспорта |
| `adb devices` пуст | нет режима разработчика или кабель без данных | Шаг 0, другой кабель, разрешить отладку в шлеме |
| Шаблоны не той версии | редактор не 4.7.1 | поставить ровно 4.7.1-stable |

**Честно:** этот путь проверен на сервере и в CI до сборки APK. Сам запуск в Quest 3S подтверждает только оператор (ТАБУ №0.02 п. 4).
