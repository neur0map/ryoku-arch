.pragma library

var data = {
    "disks": ["/"],
    "updateServiceEnabled": true,
    "idle": {
        "general": {
            "lock_cmd": "loginctl lock-session",
            "before_sleep_cmd": "loginctl lock-session",
            "after_sleep_cmd": "hyprctl dispatch dpms on"
        },
        "listeners": [
            {
                "timeout": 150,
                "onTimeout": "brightnessctl set 10% -s",
                "onResume": "brightnessctl -r"
            },
            {
                "timeout": 300,
                "onTimeout": "loginctl lock-session"
            },
            {
                "timeout": 330,
                "onTimeout": "hyprctl dispatch dpms off",
                "onResume": "hyprctl dispatch dpms on"
            },
            {
                "timeout": 1800,
                "onTimeout": "systemctl suspend"
            }
        ]
    },
    "ocr": {
        "eng": true,
        "spa": true,
        "lat": false,
        "jpn": false,
        "chi_sim": false,
        "chi_tra": false,
        "kor": false
    },
    "pomodoro": {
        "workTime": 1500,
        "restTime": 300,
        "autoStart": false,
        "syncSpotify": false
    }
}
