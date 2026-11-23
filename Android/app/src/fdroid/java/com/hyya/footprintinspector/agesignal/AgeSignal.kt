// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.hyya.footprintinspector.agesignal

import android.app.Activity

/** F-Droid offers no age signal and the edition carries no Google library, so there is nothing to ask. */
object AgeSignal {
    @Suppress("UNUSED_PARAMETER")
    fun runIfDue(activity: Activity) {}
}
