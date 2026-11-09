// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.hyya.footprintinspector.rate

import android.app.Activity
import com.google.android.play.core.review.ReviewManagerFactory

/** Google Play's standard in-app rating prompt. Play decides whether it actually shows. */
object RatingPrompt {
    const val AVAILABLE = true

    fun ask(activity: Activity) {
        runCatching {
            val manager = ReviewManagerFactory.create(activity)
            manager.requestReviewFlow().addOnCompleteListener { request ->
                if (request.isSuccessful && !activity.isFinishing) manager.launchReviewFlow(activity, request.result)
            }
        }
    }
}
