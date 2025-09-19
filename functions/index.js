const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { AccessToken } = require("livekit-server-sdk");

admin.initializeApp();

const LIVEKIT_API_KEY = "APIMZLwnHhAKVr6";
const LIVEKIT_API_SECRET = "YcJfNAEYItVxK7SCdqaoJkpfhcRI2bSqcHAuWcOWpPM";
// ✅ Correct LiveKit Cloud server URL
const LIVEKIT_URL = "wss://curadomus-mup4xuym.livekit.cloud";

exports.createLiveKitToken = functions.https.onRequest(async (req, res) => {
  // CORS headers (needed for Flutter Web / browsers)
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");

  if (req.method === "OPTIONS") {
    return res.status(204).send(""); // Preflight OK
  }

  try {
    // Verify Firebase ID token
    const authHeader = req.headers.authorization || "";
    if (!authHeader.startsWith("Bearer ")) {
      return res.status(401).json({ error: "Missing Authorization header" });
    }
    const idToken = authHeader.split("Bearer ")[1];
    const decoded = await admin.auth().verifyIdToken(idToken);

    // Parse JSON manually
    let body = {};
    try {
      body = JSON.parse(req.rawBody.toString());
    } catch (e) {
      console.error("❌ Failed to parse body:", e);
      return res.status(400).json({ error: "Invalid JSON body" });
    }

    console.log("📥 Incoming body:", body);

    const { room, identity, name } = body;
    if (!room || !identity) {
      return res.status(400).json({ error: "room and identity required" });
    }

    // Create LiveKit token
    const at = new AccessToken(LIVEKIT_API_KEY, LIVEKIT_API_SECRET, {
      identity,
      name: name || decoded.name || "Anonymous",
    });

    at.addGrant({
      roomJoin: true,
      room,
      canPublish: true,
      canSubscribe: true,
    });

    const token = await at.toJwt();
    console.log("✅ Token created for", identity, "room", room);

    return res.json({ token, url: LIVEKIT_URL });
  } catch (err) {
    console.error("❌ Error generating LiveKit token:", err);
    return res.status(500).json({ error: err.message });
  }
});

