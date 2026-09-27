package com.ramonmachadocarmo.mobile_utils

import android.app.role.RoleManager
import android.content.Intent
import com.ramonmachadocarmo.mobile_utils.callblocker.CallBlockerStore
import com.ramonmachadocarmo.mobile_utils.quicknotes.QuickNotesWidget
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity: exigido pelo local_auth (digital nas notas ocultas).
class MainActivity : FlutterFragmentActivity() {
    private var pendingRoleResult: MethodChannel.Result? = null

    private val roleManager by lazy { getSystemService(RoleManager::class.java) }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val store = CallBlockerStore(applicationContext)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mobile_utils/call_blocker")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getConfig" -> result.success(store.configJson)
                    "saveConfig" -> {
                        store.configJson = call.arguments as String
                        result.success(null)
                    }
                    "isServiceEnabled" -> result.success(roleManager.isRoleHeld(RoleManager.ROLE_CALL_SCREENING))
                    "requestServiceEnabled" -> requestScreeningRole(result)
                    "getLog" -> result.success(store.logJson)
                    "clearLog" -> {
                        store.clearLog()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mobile_utils/widgets")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "updateQuickNotes" -> {
                        QuickNotesWidget.update(applicationContext, call.arguments as String)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun requestScreeningRole(result: MethodChannel.Result) {
        if (roleManager.isRoleHeld(RoleManager.ROLE_CALL_SCREENING)) {
            result.success(true)
            return
        }
        pendingRoleResult?.success(false)
        pendingRoleResult = result
        startActivityForResult(roleManager.createRequestRoleIntent(RoleManager.ROLE_CALL_SCREENING), REQUEST_ROLE)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_ROLE) {
            pendingRoleResult?.success(roleManager.isRoleHeld(RoleManager.ROLE_CALL_SCREENING))
            pendingRoleResult = null
        }
    }

    companion object {
        private const val REQUEST_ROLE = 4201
    }
}
