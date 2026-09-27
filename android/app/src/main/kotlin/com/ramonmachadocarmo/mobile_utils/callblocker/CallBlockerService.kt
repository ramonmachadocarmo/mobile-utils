package com.ramonmachadocarmo.mobile_utils.callblocker

import android.telecom.Call
import android.telecom.CallScreeningService
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
        val reason = try {
            store.blockReason(number)
        } catch (e: Exception) {
            Log.e(TAG, "Erro ao avaliar chamada", e)
            null
        }

        val response = if (reason == null) {
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

        if (reason != null) store.addLog(number, reason)
    }

    companion object {
        private const val TAG = "CallBlockerService"
    }
}
