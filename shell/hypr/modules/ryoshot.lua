hl.bind("Print", hl.dsp.exec_cmd("flock -n -o /tmp/ryoshot.lock qs -c ryoshot"))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd("flock -n -o /tmp/ryoshot.lock env RYOSHOT_MODE=monitor qs -c ryoshot"))
