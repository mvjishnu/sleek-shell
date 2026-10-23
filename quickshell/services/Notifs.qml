pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Notification server, session history and the active pop-up stack.
// DND comes from Settings (persisted); critical notifications always pop up.
Singleton {
    id: ns

    property var history: []      // newest first: { id, ref, time, appName, appIcon, image, summary, body, urgency, actions }
    property var toasts: []       // ids currently shown as pop-ups, newest first

    function iconFor(n) {
        if (n.image && n.image !== "") return n.image
        if (n.appIcon && n.appIcon !== "") {
            if (n.appIcon.indexOf("/") === 0 || n.appIcon.indexOf("file://") === 0) return n.appIcon
            return Quickshell.iconPath(n.appIcon, true)
        }
        return ""
    }

    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: false
        imageSupported: true
        persistenceSupported: true
        onNotification: n => {
            n.tracked = true
            var acts = []
            for (var i = 0; i < n.actions.length; ++i)
                if (n.actions[i].identifier !== "default") acts.push({ id: n.actions[i].identifier, text: n.actions[i].text })
            var item = {
                id: n.id, ref: n, time: Date.now(),
                appName: n.appName || "Notification", appIcon: ns.iconFor(n),
                summary: n.summary || "", body: n.body || "", urgency: n.urgency,
                actions: acts, hasDefault: n.actions.some(function (a) { return a.identifier === "default" }),
                timeout: n.expireTimeout > 0 ? n.expireTimeout : 0
            }
            var next = [item]
            for (var j = 0; j < ns.history.length; ++j) if (ns.history[j].id !== n.id) next.push(ns.history[j])
            ns.history = next.slice(0, Settings.historyMax)
            if (!n.lastGeneration && (!Settings.dnd || n.urgency === NotificationUrgency.Critical)) {
                var t = ns.toasts.filter(function (x) { return x !== n.id })
                t.unshift(n.id)
                ns.toasts = t.slice(0, Settings.toastMax)
            }
            n.closed.connect(function () { ns.forget(item.id) })
        }
    }

    function find(id) { for (var i = 0; i < history.length; ++i) if (history[i].id === id) return history[i]; return null }
    function forget(id) {
        history = history.filter(function (x) { return x.id !== id })
        hideToast(id)
    }
    function hideToast(id) { if (toasts.indexOf(id) >= 0) toasts = toasts.filter(function (x) { return x !== id }) }
    function dismiss(id) {
        var it = find(id)
        if (it) { try { it.ref.dismiss() } catch (e) {} }
        forget(id)
    }
    function clear() {
        var h = history
        history = []; toasts = []
        h.forEach(function (it) { try { it.ref.dismiss() } catch (e) {} })
    }
    function invoke(id, actionId) {
        var it = find(id)
        if (!it) return
        try {
            var acts = it.ref.actions
            for (var i = 0; i < acts.length; ++i) if (acts[i].identifier === actionId) { acts[i].invoke(); break }
        } catch (e) {}
        hideToast(id)
    }
}
