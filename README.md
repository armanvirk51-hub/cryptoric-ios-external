# Cryptoric

هذا هو المشروع الكامل المرسل في أرشيف MediaFire، وليس نموذجًا جديدًا. يحتوي على مشروع Xcode الأصلي، الشاشات، الخدمات، الأصول، ملفات الـpatch، ووحدات العمل الداخلية.

## البنية

- `ThreeOneOSFive/views`: واجهات التطبيق ونظام التصميم.
- `ThreeOneOSFive/helpers`: الخدمات الداخلية مثل إدارة الملفات، المشاريع، التنظيف، التخزين، الأرشفة، وإدارة التفعيل.
- `ThreeOneOSFive/Assets.xcassets`: الأيقونات والصور والخلفيات.
- `ThreeOneOSFive/Patches`: حزم patch المضمنة في التطبيق.
- `ThreeOneOSFive/exploit` و`ThreeOneOSFive/kexploit`: ملفات الدعم الأصلية للمشروع كما وردت في المصدر.
- `ThreeOneOSFive.xcodeproj`: مشروع Xcode الكامل.
- `build_unsigned.sh`: بناء IPA غير موقّع على macOS.

## التفعيل

يتم التحقق من التراخيص عبر CryptoricAuth API مباشرة داخل `helpers/LicenseManager.swift`. يتحقق التطبيق تلقائياً من صلاحية المفتاح عند كل فتح للتطبيق، ويتم إلغاء التفعيل فوراً في حال تم حذف المفتاح أو انتهاء صلاحيته على الخادم.

## البناء

يتطلب البناء جهاز macOS مع Xcode. يمكن تشغيل:

```bash
./build_unsigned.sh
```

ثم استخدام GitHub Actions من خلال Workflow البناء الموجود في `.github/workflows/build.yml`.

<!-- Updated timestamp: 2026-09-21 -->




