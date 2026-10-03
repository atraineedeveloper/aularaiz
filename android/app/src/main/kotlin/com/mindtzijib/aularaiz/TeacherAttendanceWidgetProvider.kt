package com.mindtzijib.aularaiz

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class TeacherAttendanceWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val schoolName = widgetData.getString("teacher_attendance_school_name", null)
            val savedStatus = widgetData.getString(
                "teacher_attendance_status",
                context.getString(R.string.teacher_widget_open_app),
            ) ?: context.getString(R.string.teacher_widget_open_app)
            val savedAction = widgetData.getString("teacher_attendance_action", "open") ?: "open"
            val savedActionLabel = widgetData.getString(
                "teacher_attendance_action_label",
                context.getString(R.string.teacher_widget_open_app),
            ) ?: context.getString(R.string.teacher_widget_open_app)
            val schoolId = widgetData.getString("teacher_attendance_school_id", null)
            val profile = widgetData.getString("teacher_attendance_profile", "production") ?: "production"
            val savedDate = widgetData.getString("teacher_attendance_date", null)
            val today = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
            val newDay = schoolId != null && savedDate != today
            val status = if (newDay) {
                context.getString(R.string.teacher_widget_arrival_pending)
            } else {
                savedStatus
            }
            val action = if (newDay) "arrival" else savedAction
            val actionLabel = if (newDay) {
                context.getString(R.string.teacher_widget_record_arrival)
            } else {
                savedActionLabel
            }

            val views = RemoteViews(context.packageName, R.layout.teacher_attendance_widget).apply {
                setTextViewText(
                    R.id.teacher_widget_school,
                    schoolName ?: context.getString(R.string.teacher_widget_title),
                )
                setTextViewText(R.id.teacher_widget_status, status)
                setTextViewText(R.id.teacher_widget_action, actionLabel)

                val actionPendingIntent = widgetPendingIntent(
                    context = context,
                    schoolId = schoolId,
                    action = action,
                    date = today,
                    profile = profile,
                )
                setOnClickPendingIntent(R.id.teacher_widget_action, actionPendingIntent)

                val openPendingIntent = widgetPendingIntent(
                    context = context,
                    schoolId = schoolId,
                    action = "open",
                    date = today,
                    profile = profile,
                )
                setOnClickPendingIntent(R.id.teacher_widget_root, openPendingIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun widgetPendingIntent(
        context: Context,
        schoolId: String?,
        action: String,
        date: String,
        profile: String,
    ) = run {
        val uriBuilder = Uri.Builder()
            .scheme("aularaiz")
            .authority("teacher-attendance")
            .appendQueryParameter("action", action)
            .appendQueryParameter("date", date)
            .appendQueryParameter("profile", profile)
        if (schoolId != null) {
            uriBuilder.appendQueryParameter("schoolId", schoolId)
        }
        val uri = uriBuilder.build()
        if (schoolId != null && (action == "arrival" || action == "departure")) {
            HomeWidgetBackgroundIntent.getBroadcast(context, uri)
        } else {
            HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, uri)
        }
    }
}
