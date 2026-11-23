// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.hyya.footprintinspector.agesignal

import android.app.Activity
import com.google.android.play.agesignals.AgeSignalsAccessRequest
import com.google.android.play.agesignals.AgeSignalsManagerFactory
import com.google.android.play.agesignals.AgeSignalsRequest
import com.google.android.play.agesignals.ApplicableAgeFeaturesRequest
import com.google.android.play.agesignals.model.AgeSignalsStatus
import com.google.android.play.agesignals.model.ApplicableAgeFeature

/** Google Play's Age Signals: a silent check first, then Play's own request only where a law applies. */
object AgeSignal {
    fun runIfDue(activity: Activity) {
        if (!AgeSignalSchedule.isDue(activity)) return
        runCatching {
            val manager = AgeSignalsManagerFactory.create(activity)
            manager.getApplicableAgeFeatures(ApplicableAgeFeaturesRequest.builder().build()).addOnSuccessListener { applicable ->
                // Outside the places a law covers, the access request can prompt people for nothing: never call it there.
                if (ApplicableAgeFeature.MANDATORY_SHARING !in applicable.features() || activity.isFinishing) return@addOnSuccessListener
                AgeSignalSchedule.markChecked(activity)
                manager.requestAgeSignalsAccess(AgeSignalsAccessRequest.builder().setActivity(activity).build())
                    .addOnSuccessListener { access ->
                        // The signal is requested as the law asks, then dropped unread.
                        if (access.ageSignalsStatus() == AgeSignalsStatus.SHARED) {
                            manager.checkAgeSignals(AgeSignalsRequest.builder().build())
                        }
                    }
            }
        }
    }
}
