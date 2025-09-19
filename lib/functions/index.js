const functions = require("firebase-functions/v1");  // use v1 runtime
const admin = require("firebase-admin");
const { AccessToken } = require("livekit-server-sdk");

admin.initializeApp();

// ✅ Cloud Function: Create LiveKit Token
exports.createLiveKitToken = functions
  .region("us-central1")
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "You must be logged in."
      );
    }

    const cfg = functions.config();
    const LIVEKIT_URL = cfg.livekit && cfg.livekit.url;
    const LIVEKIT_KEY = cfg.livekit && cfg.livekit.key;
    const LIVEKIT_SECRET = cfg.livekit && cfg.livekit.secret;

    if (!LIVEKIT_URL || !LIVEKIT_KEY || !LIVEKIT_SECRET) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "LiveKit not configured."
      );
    }

    const { room, identity, name } = data || {};
    if (!room) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "room required"
      );
    }

    const userId = identity || context.auth.uid;
    const displayName = name || "Guest";

    // Generate JWT token
    const at = new AccessToken(LIVEKIT_KEY, LIVEKIT_SECRET, {
      identity: userId,
      name: displayName,
      ttl: "1h",
    });

    at.addGrant({
      room,
      roomJoin: true,
      canPublish: true,
      canSubscribe: true,
    });

    const token = at.toJwt();
    return { token, url: LIVEKIT_URL };
  });
