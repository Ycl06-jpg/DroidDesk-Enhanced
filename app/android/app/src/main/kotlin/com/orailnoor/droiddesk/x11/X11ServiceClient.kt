package com.orailnoor.droiddesk.x11

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.ParcelFileDescriptor
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/** Binds a UI-side LorieView to the X server process without running Binder calls on the UI. */
class X11ServiceClient(
    context: Context,
    private val onConnected: (ParcelFileDescriptor, ParcelFileDescriptor?) -> Unit,
    private val onError: (String, Throwable?) -> Unit,
) {
    private val appContext = context.applicationContext
    private val mainHandler = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "X11BinderClient")
    }
    private val active = AtomicBoolean(false)
    private var bound = false

    private val connection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName, binder: IBinder) {
            val service = IX11Service.Stub.asInterface(binder)
            executor.execute {
                try {
                    if (!active.get()) return@execute
                    if (!service.startServer()) {
                        postError("X11 hizmeti yerel sunucuyu başlatamadı", null)
                        return@execute
                    }

                    val connectionFd = service.xConnection
                    if (connectionFd == null) {
                        postError("X11 hizmeti istemci bağlantısı döndürmedi", null)
                        return@execute
                    }
                    val logcatFd = service.logcatOutput

                    mainHandler.post {
                        if (active.get()) {
                            onConnected(connectionFd, logcatFd)
                        } else {
                            connectionFd.close()
                            logcatFd?.close()
                        }
                    }
                } catch (error: Throwable) {
                    postError("X11 hizmetiyle iletişim kurulamadı", error)
                }
            }
        }

        override fun onServiceDisconnected(name: ComponentName) {
            if (active.get()) postError("X11 hizmet süreci bağlantıyı kesti", null)
        }

        override fun onBindingDied(name: ComponentName) {
            if (active.get()) postError("X11 hizmet bağlantısı koptu", null)
        }

        override fun onNullBinding(name: ComponentName) {
            if (active.get()) postError("X11 hizmeti boş bir bağlantı döndürdü", null)
        }
    }

    fun connect() {
        if (!active.compareAndSet(false, true)) return
        val intent = Intent(appContext, X11ServerService::class.java)
        // A bound-only service is destroyed as soon as DesktopActivity goes
        // away. Keep the isolated X server started while the Linux session is
        // running so returning to the desktop can reuse the live connection.
        appContext.startService(intent)
        bound = appContext.bindService(intent, connection, Context.BIND_AUTO_CREATE)
        if (!bound) postError("Android, X11 hizmet bağlantısını reddetti", null)
    }

    fun disconnect() {
        if (!active.getAndSet(false)) return
        if (bound) {
            appContext.unbindService(connection)
            bound = false
        }
        executor.shutdownNow()
    }

    private fun postError(message: String, error: Throwable?) {
        mainHandler.post {
            if (active.get()) onError(message, error)
        }
    }
}
