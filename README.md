# X Video Saver

Небольшое Flutter-приложение для iPhone: пользователь вставляет ссылку на пост X, приложение валидирует ссылку, получает MP4 через `VideoResolver` и сохраняет его в «Фото» через `photo_manager`.

## Что готово

- Экран с одним полем ссылки и кнопкой вставки из буфера обмена.
- Нормализация `x.com` и `twitter.com` в канонический URL `x.com`.
- Проверка пути `/status/<numeric-id>` и понятные состояния idle, loading, error, success.
- Резолвер публичных постов X без официального API и без cookies, возвращающий байты MP4.
- Реальное сохранение готового MP4 в медиатеку iOS через `PhotoManager.editor.saveVideo`.
- `NSPhotoLibraryAddUsageDescription` и `NSPhotoLibraryUsageDescription` в `Info.plist`.
- Targeted unit tests для parser-а URL и выбора MP4-варианта.

## Как извлекается видео

Приложение обращается напрямую к публичному syndication endpoint X, получает список вариантов медиа и скачивает самый качественный MP4. Официальный X API, Bearer Token и cookies в приложение не добавляются.

Этот endpoint не является стабильным публичным API. X может ограничить конкретный пост, вернуть пустой ответ или отдавать только HLS. В таких случаях приложение покажет понятную ошибку, а не сохранит повреждённый файл.

Источники:

- [yt-dlp Twitter extractor](https://github.com/yt-dlp/yt-dlp/blob/master/yt_dlp/extractor/twitter.py)
- [Apple URLSession](https://developer.apple.com/documentation/foundation/urlsession)
- [Apple PHPhotoLibrary](https://developer.apple.com/documentation/photos/phphotolibrary)

## Проверка

```bash
flutter analyze
flutter test
```

Физическая установка выполняется поверх уже установленного приложения на подключённый iPhone. Проверка содержимого медиатеки остаётся за Alex.
