package com.ramonmachadocarmo.mobile_utils.callblocker

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.ContactsContract
import org.json.JSONArray
import org.json.JSONObject

/**
 * Guarda a configuração (JSON gerado pelo Flutter) e o histórico de chamadas
 * bloqueadas em SharedPreferences nativo, para o CallBlockerService ler sem
 * precisar do engine Flutter rodando.
 */
class CallBlockerStore(private val context: Context) {
    private val prefs = context.getSharedPreferences("call_blocker", Context.MODE_PRIVATE)

    var configJson: String
        get() = prefs.getString(KEY_CONFIG, null) ?: "{}"
        set(value) = prefs.edit().putString(KEY_CONFIG, value).apply()

    /** Chamadas rejeitadas dos últimos [LOG_RETENTION_MS] (7 dias). */
    val logJson: String
        @Synchronized get() {
            val stored = prefs.getString(KEY_LOG, null) ?: return "[]"
            val recent = pruneOld(JSONArray(stored))
            if (recent.length() != JSONArray(stored).length()) {
                prefs.edit().putString(KEY_LOG, recent.toString()).apply()
            }
            return recent.toString()
        }

    fun clearLog() = prefs.edit().remove(KEY_LOG).apply()

    @Synchronized
    fun addLog(number: String, reason: String) {
        val log = pruneOld(JSONArray(prefs.getString(KEY_LOG, null) ?: "[]"))
        log.put(JSONObject().put("number", number).put("reason", reason).put("timestamp", System.currentTimeMillis()))
        prefs.edit().putString(KEY_LOG, log.toString()).commit()
    }

    private fun pruneOld(log: JSONArray): JSONArray {
        val cutoff = System.currentTimeMillis() - LOG_RETENTION_MS
        val recent = JSONArray()
        for (i in 0 until log.length()) {
            val entry = log.getJSONObject(i)
            if (entry.optLong("timestamp") >= cutoff) recent.put(entry)
        }
        return recent
    }

    /** Retorna o motivo do bloqueio, ou null se a chamada deve ser permitida. */
    fun blockReason(number: String): String? {
        val config = JSONObject(configJson)
        if (!config.optBoolean("enabled", false)) return null

        val digits = number.filter { it.isDigit() }
        val numbers = config.optJSONArray("numbers") ?: JSONArray()
        for (i in 0 until numbers.length()) {
            val entry = numbers.getJSONObject(i)
            if (matches(digits, entry.getString("number").filter { it.isDigit() })) {
                val label = entry.optString("label").takeIf { it.isNotEmpty() && it != "null" }
                return if (label != null) "Na lista: $label" else "Na lista"
            }
        }

        if (config.optBoolean("blockUnknown", false)) {
            if (digits.isEmpty()) return "Número oculto"
            // Sem permissão de contatos não dá pra saber quem é desconhecido;
            // melhor deixar passar do que bloquear todo mundo.
            if (hasContactsPermission() && !isInContacts(number)) return "Desconhecido"
        }
        return null
    }

    private fun hasContactsPermission() =
        context.checkSelfPermission(Manifest.permission.READ_CONTACTS) == PackageManager.PERMISSION_GRANTED

    private fun isInContacts(number: String): Boolean {
        val uri = Uri.withAppendedPath(ContactsContract.PhoneLookup.CONTENT_FILTER_URI, Uri.encode(number))
        return context.contentResolver
            .query(uri, arrayOf(ContactsContract.PhoneLookup._ID), null, null, null)
            ?.use { it.count > 0 } ?: false
    }

    companion object {
        private const val KEY_CONFIG = "config"
        private const val KEY_LOG = "log"
        private const val LOG_RETENTION_MS = 7L * 24 * 60 * 60 * 1000
        private const val MIN_SUFFIX_MATCH = 8

        /** Mesmo algoritmo de lib/features/call_blocker/phone_utils.dart. */
        fun matches(rawA: String, rawB: String): Boolean {
            val a = rawA.trimStart('0')
            val b = rawB.trimStart('0')
            if (a.isEmpty() || b.isEmpty()) return false
            if (a == b) return true
            val n = minOf(a.length, b.length)
            if (n < MIN_SUFFIX_MATCH) return false
            return a.takeLast(n) == b.takeLast(n)
        }
    }
}
