package com.ramonmachadocarmo.mobile_utils.quicknotes

import android.app.Activity
import android.app.AlertDialog
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Intent
import android.content.res.Configuration
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.widget.Toast
import com.ramonmachadocarmo.mobile_utils.MainActivity
import com.ramonmachadocarmo.mobile_utils.R

/**
 * Janela aberta pelo widget 1x1: lista as notas fixadas; tocar numa copia e
 * fecha, sem abrir o app Flutter.
 */
class QuickNotesPickerActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val notes = QuickNotesWidgetStore(this).notes()

        val night = resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK ==
            Configuration.UI_MODE_NIGHT_YES
        val theme = if (night) {
            android.R.style.Theme_DeviceDefault_Dialog_Alert
        } else {
            android.R.style.Theme_DeviceDefault_Light_Dialog_Alert
        }

        val builder = AlertDialog.Builder(this, theme)
            .setTitle(R.string.quick_notes_widget_title)
            .setNeutralButton(R.string.quick_notes_picker_open) { _, _ -> openApp() }
            .setOnDismissListener { finish() }

        if (notes.isEmpty()) {
            builder.setMessage(R.string.quick_notes_widget_empty)
        } else {
            builder.setItems(notes.map { it.title }.toTypedArray()) { _, which -> copy(notes[which]) }
        }
        builder.show()
    }

    private fun copy(note: WidgetNote) {
        getSystemService(ClipboardManager::class.java)
            .setPrimaryClip(ClipData.newPlainText(note.title, note.content))
        // A partir do Android 13 o próprio sistema avisa que copiou.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            Toast.makeText(this, "\"${note.title}\" copiado", Toast.LENGTH_SHORT).show()
        }
    }

    private fun openApp() {
        startActivity(
            Intent(Intent.ACTION_VIEW, Uri.parse("mobileutils://app/quick_notes"), this, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
    }
}
