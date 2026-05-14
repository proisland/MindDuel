-- CreateTable
CREATE TABLE "User" (
    "id" TEXT NOT NULL,
    "appleUserId" TEXT NOT NULL,
    "username" TEXT,
    "birthDate" TIMESTAMP(3),
    "avatarEmoji" TEXT NOT NULL DEFAULT '🧠',
    "isPremium" BOOLEAN NOT NULL DEFAULT false,
    "isFlagged" BOOLEAN NOT NULL DEFAULT false,
    "isSuspended" BOOLEAN NOT NULL DEFAULT false,
    "flagReason" TEXT,
    "fastRoundCount" INTEGER NOT NULL DEFAULT 0,
    "totalRoundsPlayed" INTEGER NOT NULL DEFAULT 0,
    "totalCorrectAnswers" INTEGER NOT NULL DEFAULT 0,
    "totalCorrectAnswerTimeMs" BIGINT NOT NULL DEFAULT 0,
    "lastActiveAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Progression" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "mode" TEXT NOT NULL,
    "position" INTEGER NOT NULL DEFAULT 0,
    "progress" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Progression_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Score" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "mode" TEXT NOT NULL,
    "value" DOUBLE PRECISION NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Score_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "DailyQuota" (
    "userId" TEXT NOT NULL,
    "date" TEXT NOT NULL,
    "count" INTEGER NOT NULL DEFAULT 0,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "DailyQuota_pkey" PRIMARY KEY ("userId")
);

-- CreateTable
CREATE TABLE "Friendship" (
    "senderId" TEXT NOT NULL,
    "receiverId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Friendship_pkey" PRIMARY KEY ("senderId","receiverId")
);

-- CreateTable
CREATE TABLE "FriendRequest" (
    "id" TEXT NOT NULL,
    "fromUserId" TEXT NOT NULL,
    "toUserId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "FriendRequest_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "GameSession" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "mode" TEXT NOT NULL,
    "sessionToken" TEXT NOT NULL,
    "isTraining" BOOLEAN NOT NULL DEFAULT false,
    "isMultiplayer" BOOLEAN NOT NULL DEFAULT false,
    "roomId" TEXT,
    "score" DOUBLE PRECISION,
    "correctCount" INTEGER NOT NULL DEFAULT 0,
    "totalCount" INTEGER NOT NULL DEFAULT 0,
    "startedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "endedAt" TIMESTAMP(3),

    CONSTRAINT "GameSession_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "GameAnswer" (
    "id" TEXT NOT NULL,
    "sessionId" TEXT NOT NULL,
    "questionRef" TEXT NOT NULL,
    "userAnswer" TEXT NOT NULL,
    "isCorrect" BOOLEAN NOT NULL,
    "answerTimeMs" INTEGER NOT NULL,
    "waitTimeMs" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "GameAnswer_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "QuestionPack" (
    "id" TEXT NOT NULL,
    "mode" TEXT NOT NULL,
    "version" INTEGER NOT NULL,
    "data" JSONB NOT NULL,
    "isActive" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "QuestionPack_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "GameMode" (
    "id" TEXT NOT NULL,
    "slug" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "startsAt" TIMESTAMP(3),
    "endsAt" TIMESTAMP(3),
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "GameMode_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MultiplayerRoom" (
    "id" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "hostUserId" TEXT NOT NULL,
    "mode" TEXT NOT NULL,
    "startLevel" INTEGER NOT NULL DEFAULT 0,
    "status" TEXT NOT NULL DEFAULT 'waiting',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "MultiplayerRoom_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MultiplayerParticipant" (
    "roomId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "lives" INTEGER NOT NULL DEFAULT 5,
    "skips" INTEGER NOT NULL DEFAULT 5,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "score" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "joinedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "MultiplayerParticipant_pkey" PRIMARY KEY ("roomId","userId")
);

-- CreateTable
CREATE TABLE "PushToken" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "deviceToken" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "PushToken_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Feedback" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "message" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'open',
    "adminResponse" TEXT,
    "respondedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Feedback_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "TelemetryEvent" (
    "id" TEXT NOT NULL,
    "userId" TEXT,
    "eventType" TEXT NOT NULL,
    "properties" JSONB NOT NULL DEFAULT '{}',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "TelemetryEvent_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AppImage" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "objectKey" TEXT NOT NULL,
    "contentHash" TEXT NOT NULL,
    "mimeType" TEXT NOT NULL DEFAULT 'image/png',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "AppImage_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AdminUser" (
    "id" TEXT NOT NULL,
    "username" TEXT NOT NULL,
    "passwordHash" TEXT NOT NULL,
    "role" TEXT NOT NULL DEFAULT 'admin',
    "totpSecret" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "AdminUser_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "User_appleUserId_key" ON "User"("appleUserId");

-- CreateIndex
CREATE UNIQUE INDEX "User_username_key" ON "User"("username");

-- CreateIndex
CREATE INDEX "Progression_userId_mode_idx" ON "Progression"("userId", "mode");

-- CreateIndex
CREATE UNIQUE INDEX "Progression_userId_mode_key" ON "Progression"("userId", "mode");

-- CreateIndex
CREATE INDEX "Score_userId_mode_idx" ON "Score"("userId", "mode");

-- CreateIndex
CREATE INDEX "Score_mode_value_idx" ON "Score"("mode", "value" DESC);

-- CreateIndex
CREATE INDEX "Score_userId_mode_createdAt_idx" ON "Score"("userId", "mode", "createdAt" DESC);

-- CreateIndex
CREATE INDEX "Friendship_senderId_idx" ON "Friendship"("senderId");

-- CreateIndex
CREATE INDEX "Friendship_receiverId_idx" ON "Friendship"("receiverId");

-- CreateIndex
CREATE INDEX "FriendRequest_toUserId_idx" ON "FriendRequest"("toUserId");

-- CreateIndex
CREATE UNIQUE INDEX "FriendRequest_fromUserId_toUserId_key" ON "FriendRequest"("fromUserId", "toUserId");

-- CreateIndex
CREATE UNIQUE INDEX "GameSession_sessionToken_key" ON "GameSession"("sessionToken");

-- CreateIndex
CREATE INDEX "GameSession_userId_mode_startedAt_idx" ON "GameSession"("userId", "mode", "startedAt" DESC);

-- CreateIndex
CREATE INDEX "GameSession_sessionToken_idx" ON "GameSession"("sessionToken");

-- CreateIndex
CREATE INDEX "GameAnswer_sessionId_idx" ON "GameAnswer"("sessionId");

-- CreateIndex
CREATE INDEX "QuestionPack_mode_isActive_idx" ON "QuestionPack"("mode", "isActive");

-- CreateIndex
CREATE UNIQUE INDEX "QuestionPack_mode_version_key" ON "QuestionPack"("mode", "version");

-- CreateIndex
CREATE UNIQUE INDEX "GameMode_slug_key" ON "GameMode"("slug");

-- CreateIndex
CREATE UNIQUE INDEX "MultiplayerRoom_code_key" ON "MultiplayerRoom"("code");

-- CreateIndex
CREATE INDEX "MultiplayerRoom_code_idx" ON "MultiplayerRoom"("code");

-- CreateIndex
CREATE INDEX "MultiplayerRoom_status_createdAt_idx" ON "MultiplayerRoom"("status", "createdAt" DESC);

-- CreateIndex
CREATE INDEX "MultiplayerParticipant_roomId_idx" ON "MultiplayerParticipant"("roomId");

-- CreateIndex
CREATE UNIQUE INDEX "PushToken_deviceToken_key" ON "PushToken"("deviceToken");

-- CreateIndex
CREATE INDEX "PushToken_userId_idx" ON "PushToken"("userId");

-- CreateIndex
CREATE INDEX "Feedback_status_createdAt_idx" ON "Feedback"("status", "createdAt" DESC);

-- CreateIndex
CREATE INDEX "TelemetryEvent_eventType_createdAt_idx" ON "TelemetryEvent"("eventType", "createdAt" DESC);

-- CreateIndex
CREATE INDEX "TelemetryEvent_createdAt_idx" ON "TelemetryEvent"("createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "AppImage_name_key" ON "AppImage"("name");

-- CreateIndex
CREATE UNIQUE INDEX "AdminUser_username_key" ON "AdminUser"("username");

-- AddForeignKey
ALTER TABLE "Progression" ADD CONSTRAINT "Progression_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Score" ADD CONSTRAINT "Score_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "DailyQuota" ADD CONSTRAINT "DailyQuota_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Friendship" ADD CONSTRAINT "Friendship_senderId_fkey" FOREIGN KEY ("senderId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Friendship" ADD CONSTRAINT "Friendship_receiverId_fkey" FOREIGN KEY ("receiverId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FriendRequest" ADD CONSTRAINT "FriendRequest_fromUserId_fkey" FOREIGN KEY ("fromUserId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FriendRequest" ADD CONSTRAINT "FriendRequest_toUserId_fkey" FOREIGN KEY ("toUserId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "GameSession" ADD CONSTRAINT "GameSession_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "GameAnswer" ADD CONSTRAINT "GameAnswer_sessionId_fkey" FOREIGN KEY ("sessionId") REFERENCES "GameSession"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MultiplayerRoom" ADD CONSTRAINT "MultiplayerRoom_hostUserId_fkey" FOREIGN KEY ("hostUserId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MultiplayerParticipant" ADD CONSTRAINT "MultiplayerParticipant_roomId_fkey" FOREIGN KEY ("roomId") REFERENCES "MultiplayerRoom"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MultiplayerParticipant" ADD CONSTRAINT "MultiplayerParticipant_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PushToken" ADD CONSTRAINT "PushToken_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Feedback" ADD CONSTRAINT "Feedback_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
