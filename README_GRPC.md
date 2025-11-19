# Spectral Optimization Service (gRPC)

This directory contains the gRPC service implementation for the Spectral-Multiplicative Framework.

## Prerequisites

You need to install the Protocol Buffers compiler (`protoc`) and the Crystal gRPC plugin.

### Ubuntu/Debian
```bash
sudo apt install protobuf-compiler
```

### MacOS
```bash
brew install protobuf
```

## Setup & Generation

1.  **Install Dependencies**:
    ```bash
    shards install
    ```

2.  **Generate Crystal Bindings**:
    You must generate the Crystal code from the `.proto` definition before running the server.
    ```bash
    mkdir -p src/proto
    protoc -I proto --crystal_out=src/proto proto/optimization_service.proto
    ```

## Running the Service

### Start the Server
The server listens on port `50051`.
```bash
crystal src/server.cr
```

### Run the Test Client
```bash
crystal src/client.cr
```

## API Definition

See `proto/optimization_service.proto` for the full service definition.

### Methods
*   `Solve(GraphRequest)`: Solves a general graph partitioning problem.
*   `Diagnose(DiagnosticRequest)`: Runs the Casimir Force Diagnostic on a SAT problem.
