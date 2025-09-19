const { AccessToken } = require("livekit-server-sdk");

const LIVEKIT_API_KEY = "APIMZLwnHhAKVr6";
const LIVEKIT_API_SECRET = "YcJfNAEYItVxK7SCdqaoJkpfhcRI2bSqcHAuWcOWpPM";

async function generateToken() {
  const at = new AccessToken(LIVEKIT_API_KEY, LIVEKIT_API_SECRET, {
    identity: "postman-user", // must be unique
  });

  at.addGrant({
    roomJoin: true,
    room: "test-room",
  });

  // ⬇️ await resolves the Promise
  const token = await at.toJwt();
  console.log("🔑 LiveKit Token:\n", token);
}

generateToken().catch((err) => console.error("❌ Error:", err));
