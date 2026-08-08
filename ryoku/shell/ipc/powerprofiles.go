package main

import (
	"encoding/json"
	"fmt"
	"log"

	"github.com/godbus/dbus/v5"
)

// powerprofiles.go owns the power-profile daemon integration: it reads the
// active profile and the ordered profile list from power-profiles-daemon over
// the system bus, streams them to QML on the "powerprofiles" state topic, and
// sets the active profile on request. The bus name, object path, and interface
// are the freedesktop PowerProfiles spec, reproduced as-is; they are
// third-party protocol, not reference API. Contract 06 sec 2.9 / contract 11
// sec 3.1 (power profiles): the list is service order with no client sort, and
// "Unknown" maps to the balanced icon on the QML side.
const (
	ppBusName = "org.freedesktop.UPower.PowerProfiles"
	ppPath    = "/org/freedesktop/UPower/PowerProfiles"
	ppIface   = "org.freedesktop.UPower.PowerProfiles"
)

// powerProfilesState holds the one system-bus connection and the topic the
// active-profile and profile-list frames publish to.
type powerProfilesState struct {
	conn  *dbus.Conn
	obj   dbus.BusObject
	topic *stateTopic
}

// startPowerProfiles brings the power-profile integration up, registers the
// topic and the setProfile call, watches PropertiesChanged, and publishes the
// first frame. A missing system bus or absent daemon disables the feature
// without failing the daemon (the QML view simply stays empty).
func (d *daemon) startPowerProfiles() {
	conn, err := dbus.ConnectSystemBus()
	if err != nil {
		log.Printf("ryoku-shell: power profiles disabled: %v", err)
		return
	}
	p := &powerProfilesState{
		conn:  conn,
		obj:   conn.Object(ppBusName, dbus.ObjectPath(ppPath)),
		topic: d.registerTopic("powerprofiles"),
	}

	if err := conn.AddMatchSignal(
		dbus.WithMatchObjectPath(dbus.ObjectPath(ppPath)),
		dbus.WithMatchInterface("org.freedesktop.DBus.Properties"),
		dbus.WithMatchMember("PropertiesChanged"),
	); err != nil {
		log.Printf("ryoku-shell: power profiles signal match failed: %v", err)
	}
	sigs := make(chan *dbus.Signal, 8)
	conn.Signal(sigs)
	go func() {
		for range sigs {
			p.publish()
		}
	}()

	d.registerCall("powerprofiles.setProfile", func(raw json.RawMessage) (any, error) {
		var a struct {
			Profile string `json:"profile"`
		}
		if err := json.Unmarshal(raw, &a); err != nil {
			return nil, err
		}
		return nil, p.setProfile(a.Profile)
	})

	p.publish()
}

// publish marshals the whole power-profile state and hands it to the topic,
// which drops it if byte-identical to the last frame.
func (p *powerProfilesState) publish() {
	if p.topic == nil {
		return
	}
	frame, err := json.Marshal(map[string]any{
		"active_profile": p.activeProfile(),
		"profiles":       p.profiles(),
	})
	if err != nil {
		return
	}
	p.topic.publish(frame)
}

// activeProfile reads the current profile name ("power-saver"/"balanced"/
// "performance"), empty when the property is unreadable.
func (p *powerProfilesState) activeProfile() string {
	v, err := p.obj.GetProperty(ppIface + ".ActiveProfile")
	if err != nil {
		return ""
	}
	s, _ := v.Value().(string)
	return s
}

// profiles reads the ordered profile list. The daemon returns an array of
// dicts; the "Profile" key of each carries the name. Order is the daemon's
// (service order); no client sort.
func (p *powerProfilesState) profiles() []string {
	v, err := p.obj.GetProperty(ppIface + ".Profiles")
	if err != nil {
		return nil
	}
	return profileNames(v.Value())
}

// setProfile writes the active-profile property. An empty or unknown name is
// rejected before the bus call so a bad request never reaches the daemon.
func (p *powerProfilesState) setProfile(name string) error {
	if name == "" {
		return fmt.Errorf("empty profile")
	}
	known := false
	for _, n := range p.profiles() {
		if n == name {
			known = true
			break
		}
	}
	if !known {
		return fmt.Errorf("unknown profile: %s", name)
	}
	return p.obj.Call("org.freedesktop.DBus.Properties.Set", 0,
		ppIface, "ActiveProfile", dbus.MakeVariant(name)).Err
}

// profileNames extracts profile names from the raw Profiles property value
// (aa{sv}). It is pure so the extraction is unit-tested without a live bus.
func profileNames(v any) []string {
	rows, ok := v.([]map[string]dbus.Variant)
	if !ok {
		return nil
	}
	out := make([]string, 0, len(rows))
	for _, row := range rows {
		if pv, ok := row["Profile"]; ok {
			if name, ok := pv.Value().(string); ok && name != "" {
				out = append(out, name)
			}
		}
	}
	return out
}
