-- Secret Admirer database schema
-- Portable between SQL Server and PostgreSQL with minor type tweaks.
-- This file targets SQL Server (T-SQL). For PostgreSQL, replace
-- UNIQUEIDENTIFIER -> UUID, NVARCHAR -> TEXT, DATETIME2 -> TIMESTAMPTZ,
-- GETUTCDATE() -> NOW().

IF DB_ID('SecretAdmirer') IS NULL
    CREATE DATABASE SecretAdmirer;
GO

USE SecretAdmirer;
GO

-- ---------------------------------------------------------------------------
-- Auth service tables
-- ---------------------------------------------------------------------------

IF OBJECT_ID('dbo.users', 'U') IS NULL
CREATE TABLE dbo.users (
    id                UNIQUEIDENTIFIER NOT NULL PRIMARY KEY DEFAULT NEWID(),
    handle            NVARCHAR(40)     NOT NULL UNIQUE,
    email             NVARCHAR(256)    NOT NULL UNIQUE,
    password_hash     NVARCHAR(512)    NOT NULL,
    password_salt     NVARCHAR(128)    NOT NULL,
    email_verified    BIT              NOT NULL DEFAULT 0,
    created_at        DATETIME2        NOT NULL DEFAULT GETUTCDATE(),
    updated_at        DATETIME2        NOT NULL DEFAULT GETUTCDATE(),
    last_login_at     DATETIME2        NULL,
    status            NVARCHAR(20)     NOT NULL DEFAULT 'active'
);
GO

IF OBJECT_ID('dbo.refresh_tokens', 'U') IS NULL
CREATE TABLE dbo.refresh_tokens (
    id              UNIQUEIDENTIFIER NOT NULL PRIMARY KEY DEFAULT NEWID(),
    user_id         UNIQUEIDENTIFIER NOT NULL REFERENCES dbo.users(id) ON DELETE CASCADE,
    token_hash      NVARCHAR(256)    NOT NULL,
    device_label    NVARCHAR(100)    NULL,
    ip_address      NVARCHAR(64)     NULL,
    user_agent      NVARCHAR(512)    NULL,
    issued_at       DATETIME2        NOT NULL DEFAULT GETUTCDATE(),
    expires_at      DATETIME2        NOT NULL,
    revoked_at      DATETIME2        NULL,
    last_used_at    DATETIME2        NULL
);
GO

CREATE INDEX IF NOT EXISTS ix_refresh_tokens_user ON dbo.refresh_tokens(user_id);
GO

-- ---------------------------------------------------------------------------
-- Profile service tables
-- ---------------------------------------------------------------------------

IF OBJECT_ID('dbo.profiles', 'U') IS NULL
CREATE TABLE dbo.profiles (
    user_id        UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
    handle         NVARCHAR(40)     NOT NULL UNIQUE,
    display_name   NVARCHAR(80)     NULL,
    bio            NVARCHAR(280)    NULL,
    avatar_url     NVARCHAR(512)    NULL,
    theme          NVARCHAR(20)     NOT NULL DEFAULT 'velvet',
    allow_replies  BIT              NOT NULL DEFAULT 1,
    created_at     DATETIME2        NOT NULL DEFAULT GETUTCDATE(),
    updated_at     DATETIME2        NOT NULL DEFAULT GETUTCDATE()
);
GO

-- ---------------------------------------------------------------------------
-- Message service tables
-- ---------------------------------------------------------------------------

IF OBJECT_ID('dbo.messages', 'U') IS NULL
CREATE TABLE dbo.messages (
    id                UNIQUEIDENTIFIER NOT NULL PRIMARY KEY DEFAULT NEWID(),
    receiver_id       UNIQUEIDENTIFIER NOT NULL,
    body              NVARCHAR(500)    NOT NULL,
    sender_fingerprint NVARCHAR(128)   NOT NULL, -- hash(sender_ip + receiver_id + day)
    received_at       DATETIME2        NOT NULL DEFAULT GETUTCDATE(),
    read_at           DATETIME2        NULL,
    deleted_at        DATETIME2        NULL
);
GO

CREATE INDEX IF NOT EXISTS ix_messages_receiver_received
    ON dbo.messages(receiver_id, received_at DESC)
    WHERE deleted_at IS NULL;
GO

IF OBJECT_ID('dbo.inbox_counters', 'U') IS NULL
CREATE TABLE dbo.inbox_counters (
    user_id       UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
    unread_count  INT              NOT NULL DEFAULT 0,
    total_count   INT              NOT NULL DEFAULT 0,
    updated_at    DATETIME2        NOT NULL DEFAULT GETUTCDATE()
);
GO

IF OBJECT_ID('dbo.send_quotas', 'U') IS NULL
CREATE TABLE dbo.send_quotas (
    fingerprint   NVARCHAR(128)    NOT NULL,
    day_bucket    DATE             NOT NULL,
    count         INT              NOT NULL DEFAULT 1,
    PRIMARY KEY (fingerprint, day_bucket)
);
GO

-- ---------------------------------------------------------------------------
-- Notification service tables
-- ---------------------------------------------------------------------------

IF OBJECT_ID('dbo.notifications', 'U') IS NULL
CREATE TABLE dbo.notifications (
    id           UNIQUEIDENTIFIER NOT NULL PRIMARY KEY DEFAULT NEWID(),
    user_id      UNIQUEIDENTIFIER NOT NULL,
    type         NVARCHAR(40)     NOT NULL,    -- 'message.received', 'profile.welcome'
    message_id   UNIQUEIDENTIFIER NULL,        -- REAL link, never synthetic
    title        NVARCHAR(120)    NOT NULL,
    body         NVARCHAR(280)    NULL,
    created_at   DATETIME2        NOT NULL DEFAULT GETUTCDATE(),
    read_at      DATETIME2        NULL
);
GO

CREATE INDEX IF NOT EXISTS ix_notifications_user_unread
    ON dbo.notifications(user_id, created_at DESC)
    WHERE read_at IS NULL;
GO

IF OBJECT_ID('dbo.device_tokens', 'U') IS NULL
CREATE TABLE dbo.device_tokens (
    id           UNIQUEIDENTIFIER NOT NULL PRIMARY KEY DEFAULT NEWID(),
    user_id      UNIQUEIDENTIFIER NOT NULL,
    platform     NVARCHAR(20)     NOT NULL,    -- 'apns' | 'webpush'
    token        NVARCHAR(512)    NOT NULL,
    created_at   DATETIME2        NOT NULL DEFAULT GETUTCDATE(),
    revoked_at   DATETIME2        NULL
);
GO

-- ---------------------------------------------------------------------------
-- Saga orchestrator tables
-- ---------------------------------------------------------------------------

IF OBJECT_ID('dbo.saga_state', 'U') IS NULL
CREATE TABLE dbo.saga_state (
    id            UNIQUEIDENTIFIER NOT NULL PRIMARY KEY DEFAULT NEWID(),
    saga_name     NVARCHAR(80)     NOT NULL,
    status        NVARCHAR(30)     NOT NULL,   -- 'running' | 'completed' | 'compensated' | 'failed'
    current_step  INT              NOT NULL DEFAULT 0,
    payload_json  NVARCHAR(MAX)    NOT NULL,
    last_error    NVARCHAR(MAX)    NULL,
    created_at    DATETIME2        NOT NULL DEFAULT GETUTCDATE(),
    updated_at    DATETIME2        NOT NULL DEFAULT GETUTCDATE()
);
GO

IF OBJECT_ID('dbo.saga_step_log', 'U') IS NULL
CREATE TABLE dbo.saga_step_log (
    id         UNIQUEIDENTIFIER NOT NULL PRIMARY KEY DEFAULT NEWID(),
    saga_id    UNIQUEIDENTIFIER NOT NULL REFERENCES dbo.saga_state(id) ON DELETE CASCADE,
    step_index INT              NOT NULL,
    step_name  NVARCHAR(80)     NOT NULL,
    direction  NVARCHAR(20)     NOT NULL,   -- 'forward' | 'compensate'
    status     NVARCHAR(20)     NOT NULL,   -- 'ok' | 'failed'
    detail     NVARCHAR(MAX)    NULL,
    occurred_at DATETIME2       NOT NULL DEFAULT GETUTCDATE()
);
GO

-- ---------------------------------------------------------------------------
-- Outbox table for the pub/sub bus (at-least-once delivery)
-- ---------------------------------------------------------------------------

IF OBJECT_ID('dbo.event_outbox', 'U') IS NULL
CREATE TABLE dbo.event_outbox (
    id            UNIQUEIDENTIFIER NOT NULL PRIMARY KEY DEFAULT NEWID(),
    event_type    NVARCHAR(120)    NOT NULL,
    payload_json  NVARCHAR(MAX)    NOT NULL,
    created_at    DATETIME2        NOT NULL DEFAULT GETUTCDATE(),
    dispatched_at DATETIME2        NULL
);
GO

CREATE INDEX IF NOT EXISTS ix_event_outbox_pending
    ON dbo.event_outbox(created_at)
    WHERE dispatched_at IS NULL;
GO
