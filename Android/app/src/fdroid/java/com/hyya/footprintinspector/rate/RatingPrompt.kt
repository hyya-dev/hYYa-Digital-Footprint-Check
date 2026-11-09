// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.hyya.footprintinspector.rate

import android.app.Activity

/** The F-Droid edition carries no Google library, so there is no in-app rating prompt. */
object RatingPrompt {
    const val AVAILABLE = false

    @Suppress("UNUSED_PARAMETER")
    fun ask(activity: Activity) {}
}
