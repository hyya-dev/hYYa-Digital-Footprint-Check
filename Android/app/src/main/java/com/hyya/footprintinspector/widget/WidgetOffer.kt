// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.hyya.footprintinspector.widget

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context

/**
 * The "add the widget" card on the Score page (owner, 2026-11-13). Offered only where one tap can add it: the
 * launcher supports pinning, no score widget is placed yet, and the person hasn't said "Not now".
 */
object WidgetOffer {
    private const val DISMISSED = "widgetOfferDismissed"

    fun shouldOffer(c: Context): Boolean = runCatching {
        val m = AppWidgetManager.getInstance(c)
        val placed = listOf(ScoreWidget::class.java, ScoreWidgetMedium::class.java)
            .sumOf { m.getAppWidgetIds(ComponentName(c, it)).size }
        m.isRequestPinAppWidgetSupported && placed == 0 &&
            !c.getSharedPreferences("app", Context.MODE_PRIVATE).getBoolean(DISMISSED, false)
    }.getOrDefault(false)

    /** Opens the launcher's own "Add" sheet for the wide 4 x 2 widget, like iOS's medium one (owner, 2026-11-16:
     *  the 2 x 2 left blank space); the small one stays in the widget picker. */
    fun pin(c: Context): Boolean = runCatching {
        AppWidgetManager.getInstance(c).requestPinAppWidget(ComponentName(c, ScoreWidgetMedium::class.java), null, null)
    }.getOrDefault(false)

    fun dismiss(c: Context) {
        c.getSharedPreferences("app", Context.MODE_PRIVATE).edit().putBoolean(DISMISSED, true).apply()
    }
}
