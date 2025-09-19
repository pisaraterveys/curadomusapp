// gen-token.js
const livekit = require("livekit-server-sdk");

const LIVEKIT_API_KEY = "APIMZLwnHhAKVr6";
const LIVEKIT_API_SECRET = "YcJfNAEYItVxK7SCdqaoJkpfhcRI2bSqcHAuWcOWpPM";

function generateToken() {
  // Notice we use livekit.AccessToken instead of destructuring import
  const at = new livekit.AccessToken(LIVEKIT_API_KEY, LIVEKIT_API_SECRET, {
    identity: "postman-user",
  });

  at.addGrant({
    roomJoin: true,
    room: "test-room",
  });

  return at.toJwt(); // this should be a string, not a Promise
}

const token = generateToken();
console.log("🔑 LiveKit Token:\n", token);
