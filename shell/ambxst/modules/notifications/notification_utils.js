const getFriendlyNotifTimeString = (timestamp) => {
    if (!timestamp) return '';
    const messageTime = new Date(timestamp);
    const now = new Date();
    const diffMs = now.getTime() - messageTime.getTime();

    if (diffMs < 60000)
        return 'Now';

    if (messageTime.toDateString() === now.toDateString()) {
        const diffMinutes = Math.floor(diffMs / 60000);
        const diffHours = Math.floor(diffMs / 3600000);

        if (diffHours > 0) {
            return `${diffHours}h`;
        } else {
            return `${diffMinutes}m`;
        }
    }

    const diffDays = Math.floor(diffMs / 86400000);
    if (diffDays > 0) {
        return `${diffDays}d`;
    }

    if (messageTime.toDateString() === new Date(now.getTime() - 86400000).toDateString())
        return 'Yesterday';

    return Qt.formatDateTime(messageTime, "MMMM dd");
};

const processNotificationBody = (body, appName) => {
    if (!body)
        return "";

    let processedBody = body;

    // Limpiar notificaciones de navegadores basados en Chromium
    if (appName) {
        const lowerApp = appName.toLowerCase();
        const chromiumBrowsers = ["brave", "chrome", "chromium", "vivaldi", "opera", "microsoft edge"];

        if (chromiumBrowsers.some(name => lowerApp.includes(name))) {
            const lines = body.split('\n\n');

            if (lines.length > 1 && lines[0].startsWith('<a')) {
                processedBody = lines.slice(1).join('\n\n');
            }
        }
    }

    return processedBody;
};