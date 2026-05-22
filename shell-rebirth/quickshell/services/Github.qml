import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root
    property int contribution_number
    property string author: "neur0map"
    property var contributions: []

    Timer {
        interval: 600000 // 10 minutes
        running: true
        repeat: true
        onTriggered: getContributions.running = true
    }

    Process {
        id: getContributions
        running: true
        command: ["curl", `https://github-contributions-api.jogruber.de/v4/${root.author}`]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const json = JSON.parse(text);

                    if (!json.contributions || !Array.isArray(json.contributions)) {
                        console.error("Invalid API response:", json);
                        return;
                    }

                    // Calculate level based on contribution count
                    function getContributionLevel(count) {
                        if (count === 0) return 0;
                        if (count <= 3) return 1;
                        if (count <= 6) return 2;
                        if (count <= 9) return 3;
                        return 4;
                    }

                    // Total contributions in the last 365 days
                    const oneYearAgo = new Date();
                    oneYearAgo.setDate(oneYearAgo.getDate() - 365);

                    root.contribution_number = json.contributions
                        .filter(c => new Date(c.date) >= oneYearAgo)
                        .reduce((sum, c) => sum + (c.count || 0), 0);

                    // Last 280 days for the calendar grid (40 weeks × 7 days)
                    const today = new Date();
                    today.setHours(0, 0, 0, 0); // Normalize to start of day

                    const cutoff = new Date(today);
                    cutoff.setDate(cutoff.getDate() - 279); // -279 to include today? Let's check

                    // Transform contributions to include level
                    root.contributions = json.contributions
                        .filter(c => {
                        const date = new Date(c.date);
                        return date >= cutoff && date <= today;
                    })
                        .sort((a, b) => new Date(a.date) - new Date(b.date))
                        .map(c => ({
                        date: c.date,
                        count: c.count || 0,
                        level: getContributionLevel(c.count || 0),
                        intensity: c.intensity || 0 // Keep original if needed
                    }));

                    console.log(`Loaded ${root.contributions.length} contributions, total: ${root.contribution_number}`);

                } catch (e) {
                    console.error("Failed to parse GitHub contributions:", e);
                }
            }
        }
    }
}
