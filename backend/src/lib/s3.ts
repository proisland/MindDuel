import type { S3Client } from '@aws-sdk/client-s3'
import { DeleteObjectCommand } from '@aws-sdk/client-s3'
import { config } from '../config'

export function avatarKeyForUser(userId: string): string {
  return `avatars/${userId}.jpg`
}

export async function deleteAvatarByUserId(s3: S3Client, userId: string): Promise<void> {
  try {
    await s3.send(new DeleteObjectCommand({
      Bucket: config.s3.bucket,
      Key: avatarKeyForUser(userId),
    }))
  } catch {
    // Non-fatal — object may not exist
  }
}
