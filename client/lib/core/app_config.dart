/// App-wide constants that are expected to change between delivery phases.
library;

const String kAppName = '课堂速记';

/// Phase 1 ships a demo transcript source so every UI state can be exercised
/// without the backend. Phase 2 switches this to the WebSocket session.
const bool kUseDemoSession = true;
