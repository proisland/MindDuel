import type { S3Client } from '@aws-sdk/client-s3'
import { DeleteObjectCommand } from '@aws-sdk/client-s3'
import { config } from '../config'

export function avatarS3Key(avatarUrl: string): string | null {
  const prefix = config.s3.publicUrl + '/'
  if (!avatarUrl.startsWith(prefix)) return null
  return avatarUrl.slice(prefix.length)
}

export async function deleteAvatarFromS3(s3: S3Client, avatarUrl: string): Promise<void> {
  const key = avatarS3Key(avatarUrl)
  if (!key) return
  try {
    await s3.send(new DeleteObjectCommand({ Bucket: config.s3.bucket, Key: key }))
  } catch {
    // Non-fatal — object may already be gone
  }
}
