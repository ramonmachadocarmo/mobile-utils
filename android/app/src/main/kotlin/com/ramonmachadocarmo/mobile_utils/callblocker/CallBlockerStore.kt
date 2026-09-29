package com.ramonmachadocarmo.mobile_utils.callblocker

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.ContactsContract
import org.json.JSONArray
import org.json.JSONObject
import java.time.LocalDateTime

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
    fun addLog(number: String, block: Block, smsSent: Boolean) {
        val log = pruneOld(JSONArray(prefs.getString(KEY_LOG, null) ?: "[]"))
        log.put(
            JSONObject()
                .put("number", number)
                .put("reason", block.reason)
                .put("kind", block.kind)
                .put("sms", smsSent)
                .put("timestamp", System.currentTimeMillis())
        )
        prefs.edit().putString(KEY_LOG, log.toString()).commit()
    }

    /** Última vez que [number] foi rejeitado pelo horário de silêncio (0 se nunca). */
    private fun lastQuietBlock(number: String): Long {
        val log = JSONArray(prefs.getString(KEY_LOG, null) ?: "[]")
        val digits = number.filter { it.isDigit() }
        var last = 0L
        for (i in 0 until log.length()) {
            val entry = log.getJSONObject(i)
            if (entry.optString("kind") == KIND_QUIET &&
                matches(digits, entry.optString("number").filter { it.isDigit() })
            ) {
                last = maxOf(last, entry.optLong("timestamp"))
            }
        }
        return last
    }

    /** SMS de resposta para [number], ou null se não deve responder. */
    @Synchronized
    fun smsReplyFor(number: String, block: Block): String? {
        val config = JSONObject(configJson)
        val sms = config.optJSONObject("smsReply") ?: return null
        if (!sms.optBoolean("enabled", false)) return null
        if (sms.optBoolean("onlyQuietHours", true) && block.kind != KIND_QUIET) return null
        val message = sms.optString("message").trim()
        val digits = number.filter { it.isDigit() }
        if (message.isEmpty() || digits.length < MIN_SUFFIX_MATCH) return null

        // No máximo uma resposta por número a cada SMS_COOLDOWN_MS.
        val now = System.currentTimeMillis()
        val sent = JSONObject(prefs.getString(KEY_SMS_SENT, null) ?: "{}")
        val keys = sent.keys().asSequence().toList()
        for (key in keys) {
            if (now - sent.optLong(key) > SMS_COOLDOWN_MS) sent.remove(key)
        }
        if (keys.any { sent.has(it) && matches(digits, it) }) return null
        sent.put(digits, now)
        prefs.edit().putString(KEY_SMS_SENT, sent.toString()).commit()
        return message
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

    /** Motivo do bloqueio (mostrado no histórico) e o tipo da regra. */
    data class Block(val reason: String, val kind: String)

    /** Retorna o bloqueio, ou null se a chamada deve ser permitida. */
    fun blockReason(number: String, now: LocalDateTime = LocalDateTime.now()): Block? {
        val config = JSONObject(configJson)
        if (!config.optBoolean("enabled", false)) return null

        val digits = number.filter { it.isDigit() }
        val numbers = config.optJSONArray("numbers") ?: JSONArray()
        for (i in 0 until numbers.length()) {
            val entry = numbers.getJSONObject(i)
            if (matches(digits, entry.getString("number").filter { it.isDigit() })) {
                val label = entry.optString("label").takeIf { it.isNotEmpty() && it != "null" }
                return Block(if (label != null) "Na lista: $label" else "Na lista", KIND_LIST)
            }
        }

        val countryCode = config.optString("countryCode", "55")
        val prefixes = config.optJSONArray("prefixes") ?: JSONArray()
        for (i in 0 until prefixes.length()) {
            val entry = prefixes.getJSONObject(i)
            val prefix = entry.getString("prefix")
            if (matchesPrefix(number, prefix, countryCode)) {
                val label = entry.optString("label").takeIf { it.isNotEmpty() && it != "null" }
                return Block("Prefixo $prefix" + (label?.let { ": $it" } ?: ""), KIND_PREFIX)
            }
        }

        val quiet = config.optJSONObject("quietHours")
        if (quiet != null && isQuietTime(quiet, now)) {
            val allowed = when {
                // Sem a permissão não dá pra saber quem é contato; deixa passar.
                quiet.optBoolean("allowContacts", true) &&
                    (!hasContactsPermission() || (digits.isNotEmpty() && isInContacts(number))) -> true
                quiet.optBoolean("allowRepeated", true) && digits.isNotEmpty() &&
                    System.currentTimeMillis() - lastQuietBlock(number) <= REPEAT_WINDOW_MS -> true
                else -> false
            }
            if (!allowed) return Block("Horário de silêncio", KIND_QUIET)
        }

        if (config.optBoolean("blockUnknown", false)) {
            if (digits.isEmpty()) return Block("Número oculto", KIND_UNKNOWN)
            // Sem permissão de contatos não dá pra saber quem é desconhecido;
            // melhor deixar passar do que bloquear todo mundo.
            if (hasContactsPermission() && !isInContacts(number)) return Block("Desconhecido", KIND_UNKNOWN)
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
        private const val KEY_SMS_SENT = "sms_sent"
        private const val LOG_RETENTION_MS = 7L * 24 * 60 * 60 * 1000
        private const val MIN_SUFFIX_MATCH = 8
        private const val MIN_PREFIX_DIGITS = 2

        /** QuietHours.repeatWindow e SmsReply.cooldown em call_blocker_config.dart. */
        private const val REPEAT_WINDOW_MS = 3L * 60 * 1000
        private const val SMS_COOLDOWN_MS = 12L * 60 * 60 * 1000

        const val KIND_LIST = "list"
        const val KIND_PREFIX = "prefix"
        const val KIND_QUIET = "quiet"
        const val KIND_UNKNOWN = "unknown"

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

        /** Mesmo algoritmo de PhoneUtils.toInternational (Dart). */
        fun toInternational(number: String, countryCode: String): String {
            val trimmed = number.trim()
            val digits = trimmed.filter { it.isDigit() }
            if (trimmed.startsWith("+")) return digits
            val significant = digits.trimStart('0')
            if (significant.isEmpty()) return ""
            if (significant.startsWith(countryCode) && significant.length >= 12) return significant
            return countryCode + significant
        }

        /** Mesmo algoritmo de PhoneUtils.matchesPrefix (Dart). */
        fun matchesPrefix(number: String, prefix: String, countryCode: String): Boolean {
            val p = prefix.trim()
            val pDigits = p.filter { it.isDigit() }
            val intl = toInternational(number, countryCode)
            if (intl.isEmpty()) return false
            if (p.startsWith("+")) return pDigits.isNotEmpty() && intl.startsWith(pDigits)
            val significant = pDigits.trimStart('0')
            if (significant.length < MIN_PREFIX_DIGITS || !intl.startsWith(countryCode)) return false
            return intl.substring(countryCode.length).startsWith(significant)
        }

        /** Mesma lógica de QuietHours.isActiveAt (Dart). */
        fun isQuietTime(quiet: JSONObject, now: LocalDateTime): Boolean {
            if (!quiet.optBoolean("enabled", false)) return false
            val start = quiet.optInt("start", 22 * 60)
            val end = quiet.optInt("end", 7 * 60)
            val daysJson = quiet.optJSONArray("days")
            val days = if (daysJson == null) (1..7).toSet() else (0 until daysJson.length()).map { daysJson.getInt(it) }.toSet()
            val m = now.hour * 60 + now.minute
            val today = now.dayOfWeek.value
            val yesterday = if (today == 1) 7 else today - 1
            return when {
                start == end -> today in days
                start < end -> today in days && m >= start && m < end
                else -> (m >= start && today in days) || (m < end && yesterday in days)
            }
        }
    }
}
