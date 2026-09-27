package com.ramonmachadocarmo.mobile_utils.quicknotes

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import com.ramonmachadocarmo.mobile_utils.R

/** Fornece os itens da lista do [QuickNotesWidget]. */
class QuickNotesWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory = Factory(applicationContext)

    private class Factory(private val context: Context) : RemoteViewsFactory {
        private var notes = emptyList<WidgetNote>()

        override fun onCreate() {}
        override fun onDestroy() {}

        override fun onDataSetChanged() {
            notes = QuickNotesWidgetStore(context).notes()
        }

        override fun getCount() = notes.size

        override fun getViewAt(position: Int): RemoteViews {
            val note = notes[position]
            return RemoteViews(context.packageName, R.layout.quick_notes_widget_item).apply {
                setTextViewText(R.id.title, note.title)
                setTextViewText(R.id.content, note.content.replace('\n', ' '))
                setOnClickFillInIntent(
                    R.id.item,
                    Intent().putExtra(QuickNotesWidget.EXTRA_NOTE_ID, note.id),
                )
            }
        }

        override fun getLoadingView(): RemoteViews? = null
        override fun getViewTypeCount() = 1
        override fun getItemId(position: Int) = notes[position].id.hashCode().toLong()
        override fun hasStableIds() = true
    }
}
