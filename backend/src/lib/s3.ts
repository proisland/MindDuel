import type { S3Client } from '@aws-sdk/client-s3'
import { DeleteObjectCommand, PutObjectCommand } from '@aws-sdk/client-s3'
import { config } from '../config'

export function avatarKeyForUser(userId: string): string {
  return `avatars/${userId}.jpg`
}

export async function deleteAvatarByUserId(s3: S3Client, userId: string): Promise<void> {
  await deleteS3Key(s3, avatarKeyForUser(userId))
}

export async function deleteS3Key(s3: S3Client, key: string): Promise<void> {
  try {
    await s3.send(new DeleteObjectCommand({ Bucket: config.s3.bucket, Key: key }))
  } catch {
    // Non-fatal — object may not exist
  }
}

export async function uploadJpegToS3(s3: S3Client, key: string, data: Buffer): Promise<string> {
  await s3.send(new PutObjectCommand({
    Bucket: config.s3.bucket,
    Key: key,
    Body: data,
    ContentType: 'image/jpeg',
  }))
  return `${config.s3.publicUrl}/${key}`
}
