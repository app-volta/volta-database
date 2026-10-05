db = db.getSiblingDB("volta_chat");

if (!db.getCollectionNames().includes("sessions")) {
    db.createCollection("sessions", {
        validator: {
            $jsonSchema: {
                bsonType: "object",
                required: [
                    "user_id",
                    "started_at",
                    "last_message_at",
                    "status",
                    "expires_at"
                ],
                properties: {
                    user_id: {
                        bsonType: "string"
                    },
                    started_at: {
                        bsonType: "date"
                    },
                    last_message_at: {
                        bsonType: "date"
                    },
                    status: {
                        enum: ["active", "inactive", "closed"]
                    },
                    expires_at: {
                        bsonType: "date"
                    }
                }
            }
        }
    });

    print("Collection 'sessions' criada.");
} else {
    print("Collection 'sessions' ja existe.");
}


if (!db.getCollectionNames().includes("messages")) {
    db.createCollection("messages", {
        validator: {
            $jsonSchema: {
                bsonType: "object",
                required: [
                    "session_id",
                    "sender_id",
                    "content",
                    "type",
                    "created_at"
                ],
                properties: {
                    session_id: {
                        bsonType: "objectId"
                    },
                    sender_id: {
                        bsonType: "string"
                    },
                    content: {
                        bsonType: "string"
                    },
                    type: {
                        enum: ["user", "ai", "system"]
                    },
                    response_to: {
                        bsonType: ["objectId", "null"]
                    },
                    created_at: {
                        bsonType: "date"
                    }
                }
            }
        }
    });

    print("Collection 'messages' criada.");
} else {
    print("Collection 'messages' ja existe.");
}

print("Inicializacao do VOLTA Chat concluida.");

db.messages.createIndex(
    {
        session_id: 1,
        created_at: 1
    },
    {
        name: "idx_messages_session_created"
    }
);

db.sessions.createIndex(
    {
        expires_at: 1
    },
    {
        expireAfterSeconds: 0,
        name: "idx_sessions_expires_ttl"
    }
);

print("Indices do VOLTA Chat configurados.");