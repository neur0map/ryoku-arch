module ryoku-hub

go 1.26.4

toolchain go1.26.5

require (
	github.com/BurntSushi/toml v1.6.0
	ryostore v0.0.0
)

replace ryostore => ../../apps/ryostore/backend
