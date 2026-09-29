package com.ramonmachadocarmo.mobile_utils.callblocker

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.telecom.Call
import android.telecom.CallScreeningService
import android.telephony.SmsManager
import android.util.Log

/**
 * Chamado pelo sistema a cada chamada recebida, desde que o app seja o
 * "app de identificação de chamadas e spam" (ROLE_CALL_SCREENING).
 */
class CallBlockerService : CallScreeningService() {
    override fun onScreenCall(details: Call.Details) {
        if (details.callDirection != Call.Details.DIRECTION_INCOMING) {
            respondToCall(details, CallResponse.Builder().build())
            return
        }

        val number = details.handle?.schemeSpecificPart.orEmpty()
        val store = CallBlockerStore(this)
        val block = try {
            store.blockReason(number)
        } catch (e: Exception) {
            Log.e(TAG, "Erro ao avaliar chamada", e)
            null
        }

        val response = if (block == null) {
            CallResponse.Builder().build()
        } else {
            CallResponse.Builder()
                .setDisallowCall(true)
                .setRejectCall(true)
                .setSkipCallLog(false)
                .setSkipNotification(true)
                .build()
        }
        respondToCall(details, response)

        if (block != null) {
            val smsSent = try {
                store.smsReplyFor(number, block)?.let { sendSms(number, it) } ?: false
            } catch (e: Exception) {
                Log.e(TAG, "Erro ao responder por SMS", e)
                false
            }
            store.addLog(number, block, smsSent)
        }
    }

    private fun sendSms(number: String, message: String): Boolean {
        if (checkSelfPermission(Manifest.permission.SEND_SMS) != PackageManager.PERMISSION_GRANTED) return false
        val sms = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            getSystemService(SmsManager::class.java)
        } else {
            @Suppress("DEPRECATION")
            SmsManager.getDefault()
        } ?: return false
        sms.sendMultipartTextMessage(number, null, sms.divideMessage(message), null, null)
        return true
    }

    companion object {
        private const val TAG = "CallBlockerService"
    }
}
