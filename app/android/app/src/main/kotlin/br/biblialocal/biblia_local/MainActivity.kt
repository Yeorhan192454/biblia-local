package br.biblialocal.biblia_local

import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // abre o instalador do Android para o APK da atualização baixado pelo app
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "biblia/atualizacao").setMethodCallHandler { call, result ->
            if (call.method != "instalarApk") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val file = File(call.arguments as String)
            val uri = FileProvider.getUriForFile(this, "$packageName.atualizacao", file)
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            result.success(null)
        }
    }
}
