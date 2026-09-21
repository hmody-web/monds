# مندس 🎨🕵️

لعبة رسم وخداع اجتماعية عربية، مجانية بالكامل.

## الهوية

- الاسم: **مندس**
- Bundle ID: `com.scrptaty.mundas`
- اللون الرئيسي: `#219587`
- الخط: `Expo Arabic Bold`
- الأيقونة: `assets/images/app_icon.png`

## ما هو موجود الآن

### اللعب المحلي بدون إنترنت
- 3 إلى 12 لاعباً.
- اختيار فئة أو عدة فئات.
- اختيار مندس واحد عشوائياً.
- كشف الدور بطريقة الضغط المطوّل وإخفائه عند رفع الإصبع.
- رسم مشترك بالتتابع.
- نقاش ثم تصويت سري.
- تصويت فاصل عند التعادل.
- إذا انكشف المندس يحصل على محاولة أخيرة لتخمين الكلمة.
- جولة جديدة بنفس المجموعة.

### Multiplayer
- إنشاء غرفة برمز من 5 أحرف.
- انضمام بالكود أو QR.
- Lobby وقائمة اللاعبين.
- اختيار الفئات بواسطة المضيف.
- كشف الدور على كل جهاز.
- رسم مشترك متزامن.
- نقاش وتصويت ومراحل كشف النتيجة.
- تخمين المندس النهائي.
- إعادة جولة بنفس الغرفة.
- حالة اتصال لكل لاعب.

## الفئات

`assets/data/words_ar.json` يحتوي 21 فئة عربية محلية داخل التطبيق، لذلك اللعب المحلي لا يعتمد على الخادم.

## تشغيل المشروع لأول مرة

على Windows شغّل:

```bat
tool\bootstrap_windows.bat
```

أو يدوياً:

```bash
flutter create --platforms=android,ios,web --org com.scrptaty --project-name mundas .
python tool/configure_platforms.py
flutter pub get
dart run flutter_launcher_icons
flutter run -d chrome --web-browser-flag="--disable-web-security"
```

### Android APK

```bash
flutter build apk --release
```

### Android App Bundle

```bash
flutter build appbundle --release
```

### iOS

يحتاج macOS + Xcode:

```bash
flutter build ios --release
```

## الخادم

ارفع محتويات مجلد `server` إلى:

`public_html/apps/imposter/`

ثم افتح:

`https://scrptaty.com/apps/imposter/api/health.php`

يجب أن يظهر `ok: true`.

الخادم مبني بـ PHP فقط ويستخدم ملفات JSON مؤقتة مع `flock`، لذلك مناسب للاستضافة المشتركة ولا يحتاج MySQL أو Node.js.

## ملاحظة أمنية

الكلمة السرية وهوية المندس لا تُرسلان لكل الأجهزة. كل جهاز يستلم دوره فقط، وخادم المباراة يحتفظ بالحالة السرية حتى نهاية الجولة.
