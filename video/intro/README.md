# Видео: заставка «Ранее в „Атласе воды“» (90 с, три варианта)

`intro-virtue.mp4`, `intro-captive.mp4`, `intro-unresolved.mp4`: 1280×720, H.264 + AAC, ровно 90 с, по 5 МБ. Три ветки выбора серии 1: отвернулся (добродетель), отдал координаты (плен), не решил. Собрано по 16 планам хора (`godot/data/intro-ep1.json`); что изменено и что удалено — `docs/review/REVIEW_INTRO_2026-10-03.md`, разбор хора — `docs/review/REVIEW_INTRO_CHORUS_2026-10-03.md`. Принято оператором 2026-10-03 («все ревью ок го»).

Голос — черновой (Piper, ru_RU-irina-medium, помечен «черновой голос · превью» в кадре), чистовой — живая запись по ТАБУ №0.019 п. 5. В APK заставки пока нет (сцена Godot её не читает) и видео в APK не идут.

## Как собрать заново

```bash
for v in virtue captive unresolved; do
    python3 scripts/prerender/build_intro.py --variant $v --out video/intro
done
```

Нужны Python 3 с Pillow, ffmpeg (libx264, aac), шрифты DejaVu и модель Piper `ru_RU-irina-medium` (скачивается с rhasspy/piper-voices).
