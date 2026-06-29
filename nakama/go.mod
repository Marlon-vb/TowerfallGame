module arrowclash/backend

go 1.21

// Versions MUST match the Nakama server release these plugins load into
// (Nakama 3.22.0), or the Go plugin fails to load with a "built with a
// different version" error. These mirror nakama 3.22.0's go.mod.
require github.com/heroiclabs/nakama-common v1.32.0

require google.golang.org/protobuf v1.34.1 // indirect
