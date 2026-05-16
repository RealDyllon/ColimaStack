## ADDED Requirements

### Requirement: Send HTTP GET requests over a Unix domain socket
The client SHALL send HTTP/1.1 GET requests to a Docker Engine API endpoint by connecting to a Unix domain socket path using `Network.framework` `NWConnection`.

#### Scenario: Successful GET request
- **WHEN** a valid socket path and request path are provided
- **THEN** the client establishes a connection, sends a well-formed HTTP/1.1 GET request, and returns the response body as `Data`

#### Scenario: Socket path does not exist
- **WHEN** the socket path points to a file that does not exist
- **THEN** the client throws a descriptive error without hanging

#### Scenario: Connection refused or daemon not running
- **WHEN** the socket exists but the Docker daemon is not listening
- **THEN** the client throws an error within the specified timeout

### Requirement: Respect a per-request timeout
The client SHALL enforce a configurable timeout on each request and throw a timeout error if the response is not received within that duration.

#### Scenario: Request exceeds timeout
- **WHEN** the daemon accepts the connection but does not respond within the timeout period
- **THEN** the client cancels the connection and throws a timeout error

### Requirement: Parse standard HTTP responses
The client SHALL parse the HTTP status line and body from the response, distinguishing 2xx success from error status codes.

#### Scenario: 200 OK response
- **WHEN** the server returns HTTP 200 with a JSON body
- **THEN** the client returns the body data to the caller

#### Scenario: Non-2xx response
- **WHEN** the server returns HTTP 4xx or 5xx
- **THEN** the client throws an error containing the status code and response body

### Requirement: Handle chunked transfer encoding
The client SHALL correctly reassemble chunked HTTP/1.1 response bodies into complete `Data` before returning.

#### Scenario: Chunked response with multiple chunks
- **WHEN** the server sends a response with `Transfer-Encoding: chunked` containing N chunks
- **THEN** the client returns the fully assembled body as a single contiguous `Data` value

#### Scenario: Chunked response terminator
- **WHEN** the server sends the terminal zero-size chunk (`0\r\n\r\n`)
- **THEN** the client treats the response as complete and returns

### Requirement: Support query string parameters
The client SHALL allow callers to pass query parameters that are appended to the request URL path.

#### Scenario: Query parameters are included in the request line
- **WHEN** the caller provides query parameters (e.g., `all=1`)
- **THEN** the request line contains `?key=value` appended to the path

### Requirement: Swift concurrency compatibility
The client SHALL be `Sendable` and callable from `async` contexts without blocking the calling actor.

#### Scenario: Concurrent requests
- **WHEN** multiple callers invoke the client concurrently from async tasks
- **THEN** each request is handled independently without data races
