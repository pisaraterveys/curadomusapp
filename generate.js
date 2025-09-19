const { AccessToken } = require("livekit-server-sdk");

const LIVEKIT_URL = "wss://curadomus-mup4xuym.livekit.cloud";
const LIVEKIT_KEY = "APIMZLwnHhAKVr6";
const LIVEKIT_SECRET = "YcJfNAEYItVxK7SCdqaoJkpfhcRI2bSqcHAuWcOWpPM";

const room = "test_room";
const identity = "test_user";
const name = "Test User";

(async () => {
  const at = new AccessToken(LIVEKIT_KEY, LIVEKIT_SECRET, {
    identity,
    name,
    ttl: "1h",
  });

  at.addGrant({
    room,
    roomJoin: true,
    canPublish: true,
    canSubscribe: true,
  });

  const token = await at.toJwt();  // ✅ now inside async block
  console.log(" LiveKit URL:", LIVEKIT_URL);
  console.log(" Identity:", identity);
  console.log(" Room:", room);
  console.log(" Token:", token);
})();
