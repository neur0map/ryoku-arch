// ryoku-hub is the Go backend for the Ryoku Settings GUI. The Quickshell front end
// (qs -c hub) shells out to it the same way the rest of the desktop talks to
// ryoku-shell: a subcommand prints data on stdout or mutates persisted state.
//
//	ryoku-hub keybinds            print the keybind legend as JSON
//	ryoku-hub config get <key>    print a stored config value
//	ryoku-hub config set <k> <v>  persist a config value (TOML)
package main

import (
	"encoding/json"
	"fmt"
	"os"
)

func main() {
	args := os.Args[1:]
	if len(args) == 0 {
		usage()
		os.Exit(2)
	}

	switch args[0] {
	case "keybinds":
		b, err := json.Marshal(keybinds())
		if err != nil {
			fmt.Fprintln(os.Stderr, "ryoku-hub:", err)
			os.Exit(1)
		}
		os.Stdout.Write(b)
		fmt.Println()
	case "config":
		if err := runConfig(args[1:]); err != nil {
			fmt.Fprintln(os.Stderr, "ryoku-hub:", err)
			os.Exit(1)
		}
	case "hypr":
		if err := runHypr(args[1:]); err != nil {
			fmt.Fprintln(os.Stderr, "ryoku-hub:", err)
			os.Exit(1)
		}
	case "extras":
		if err := runExtras(args[1:]); err != nil {
			fmt.Fprintln(os.Stderr, "ryoku-hub:", err)
			os.Exit(1)
		}
	case "lock":
		if err := runLock(args[1:]); err != nil {
			fmt.Fprintln(os.Stderr, "ryoku-hub:", err)
			os.Exit(1)
		}
	case "gpu":
		if err := runGpu(args[1:]); err != nil {
			fmt.Fprintln(os.Stderr, "ryoku-hub:", err)
			os.Exit(1)
		}
	case "voxtype":
		if err := runVoxtype(args[1:]); err != nil {
			fmt.Fprintln(os.Stderr, "ryoku-hub:", err)
			os.Exit(1)
		}
	default:
		usage()
		os.Exit(2)
	}
}

func runConfig(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("config needs get|set")
	}
	switch args[0] {
	case "get":
		if len(args) < 2 {
			return fmt.Errorf("config get needs a key")
		}
		v, ok := configGet(args[1])
		if !ok {
			return fmt.Errorf("unknown config key: %s", args[1])
		}
		fmt.Println(v)
		return nil
	case "set":
		if len(args) < 3 {
			return fmt.Errorf("config set needs a key and value")
		}
		return configSet(args[1], args[2])
	default:
		return fmt.Errorf("config needs get|set")
	}
}

func usage() {
	fmt.Fprintln(os.Stderr, "usage:")
	fmt.Fprintln(os.Stderr, "  ryoku-hub keybinds")
	fmt.Fprintln(os.Stderr, "  ryoku-hub config get <key>")
	fmt.Fprintln(os.Stderr, "  ryoku-hub config set <key> <value>")
	fmt.Fprintln(os.Stderr, "  ryoku-hub hypr get|defaults|cursors|layouts")
	fmt.Fprintln(os.Stderr, "  ryoku-hub hypr variants <layout>")
	fmt.Fprintln(os.Stderr, "  ryoku-hub hypr save|preview <json>")
	fmt.Fprintln(os.Stderr, "  ryoku-hub hypr restore")
	fmt.Fprintln(os.Stderr, "  ryoku-hub extras catalog|cache")
	fmt.Fprintln(os.Stderr, "  ryoku-hub extras installer <name>")
	fmt.Fprintln(os.Stderr, "  ryoku-hub lock list")
	fmt.Fprintln(os.Stderr, "  ryoku-hub lock set <slug>")
	fmt.Fprintln(os.Stderr, "  ryoku-hub gpu caps|mode")
	fmt.Fprintln(os.Stderr, "  ryoku-hub voxtype get|ensure")
	fmt.Fprintln(os.Stderr, "  ryoku-hub voxtype set <json>")
}
