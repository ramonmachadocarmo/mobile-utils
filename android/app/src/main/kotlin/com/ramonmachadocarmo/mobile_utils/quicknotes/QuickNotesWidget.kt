package com.ramonmachadocarmo.mobile_utils.quicknotes

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ClipData
import android.content.ClipboardManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.widget.RemoteViews
import android.widget.Toast
import com.ramonmachadocarmo.mobile_utils.MainActivity
import com.ramonmachadocarmo.mobile_utils.R
import org.json.JSONArray

/**
 * Widget da tela inicial com as notas fixadas (e não ocultas).
 * - 1x1 (padrão): botão que abre o [QuickNotesPickerActivity] para escolher e copiar.
 * - 2x2 ou maior: lista; tocar numa nota copia sem abrir o app e o título abre o app.
 */
class QuickNotesWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) manager.updateAppWidget(id, buildViews(context, manager, id))
        manager.notifyAppWidgetViewDataChanged(ids, R.id.list)
    }

    // Redimensionado: troca entre botão e lista.
    override fun onAppWidgetOptionsChanged(
        context: Context,
        manager: AppWidgetManager,
        id: Int,
        newOptions: Bundle,
    ) {
        manager.updateAppWidget(id, buildViews(context, manager, id))
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action != ACTION_COPY) return
        val id = intent.getStringExtra(EXTRA_NOTE_ID) ?: return
        val note = QuickNotesWidgetStore(context).notes().firstOrNull { it.id == id } ?: return

        val clipboard = context.getSystemService(ClipboardManager::class.java)
        clipboard.setPrimaryClip(ClipData.newPlainText(note.title, note.content))
        // A partir do Android 13 o próprio sistema avisa que copiou.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            Toast.makeText(context, "\"${note.title}\" copiado", Toast.LENGTH_SHORT).show()
        }
    }

    private fun buildViews(context: Context, manager: AppWidgetManager, widgetId: Int): RemoteViews {
        // Em retrato: largura = MIN_WIDTH, altura = MAX_HEIGHT (dp). 2 células ≈ 110dp.
        val options = manager.getAppWidgetOptions(widgetId)
        val width = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
        val height = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0)
        return if (width < 100 || height < 100) buildCompactViews(context) else buildListViews(context, widgetId)
    }

    private fun buildCompactViews(context: Context): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.quick_notes_widget_compact)
        val pickerIntent = Intent(context, QuickNotesPickerActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
        views.setOnClickPendingIntent(
            R.id.compact,
            PendingIntent.getActivity(
                context, 1, pickerIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            ),
        )
        return views
    }

    @Suppress("DEPRECATION") // setRemoteAdapter(Int, Intent): a alternativa só existe a partir da API 31.
    private fun buildListViews(context: Context, widgetId: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.quick_notes_widget)

        val serviceIntent = Intent(context, QuickNotesWidgetService::class.java).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
        }
        views.setRemoteAdapter(R.id.list, serviceIntent)
        views.setEmptyView(R.id.list, R.id.empty)

        // Template dos toques na lista; cada item completa com o id da nota.
        val copyIntent = Intent(context, QuickNotesWidget::class.java).setAction(ACTION_COPY)
        views.setPendingIntentTemplate(
            R.id.list,
            PendingIntent.getBroadcast(
                context, 0, copyIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
            ),
        )

        // Deep link tratado pelo Flutter (onGenerateRoute em main.dart).
        val openIntent = Intent(Intent.ACTION_VIEW, Uri.parse("mobileutils://app/quick_notes"), context, MainActivity::class.java)
        val openPending = PendingIntent.getActivity(
            context, 0, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        views.setOnClickPendingIntent(R.id.header, openPending)
        views.setOnClickPendingIntent(R.id.empty, openPending)
        return views
    }

    companion object {
        const val ACTION_COPY = "com.ramonmachadocarmo.mobile_utils.COPY_NOTE"
        const val EXTRA_NOTE_ID = "note_id"

        /** Salva as notas vindas do Flutter e redesenha todos os widgets. */
        fun update(context: Context, notesJson: String) {
            QuickNotesWidgetStore(context).save(notesJson)
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, QuickNotesWidget::class.java))
            if (ids.isNotEmpty()) manager.notifyAppWidgetViewDataChanged(ids, R.id.list)
        }
    }
}

data class WidgetNote(val id: String, val title: String, val content: String)

class QuickNotesWidgetStore(context: Context) {
    private val prefs = context.getSharedPreferences("quick_notes_widget", Context.MODE_PRIVATE)

    fun save(json: String) = prefs.edit().putString(KEY_NOTES, json).apply()

    fun notes(): List<WidgetNote> {
        val array = JSONArray(prefs.getString(KEY_NOTES, null) ?: "[]")
        return (0 until array.length()).map {
            val o = array.getJSONObject(it)
            WidgetNote(o.getString("id"), o.optString("title"), o.optString("content"))
        }
    }

    private companion object {
        const val KEY_NOTES = "notes"
    }
}
