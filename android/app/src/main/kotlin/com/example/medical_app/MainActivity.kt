package com.example.medical_app

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Kontent himoyasi: skrinshot va ekran yozib olishni bloklaydi.
        // Butun ilova (video, darslar, kitoblar, testlar) qoplanadi.
        // Screen recorder'да ekran qora chiqadi, skrinshot olinmaydi.
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )
    }
}
