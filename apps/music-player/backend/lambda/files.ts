// apps/music-player/backend/lambda/files.ts
// Lists S3 folders/files and returns presigned download URLs.

import { S3Client, ListObjectsV2Command, GetObjectCommand } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import { APIGatewayProxyEvent, APIGatewayProxyResult } from "aws-lambda";

const s3     = new S3Client({});
const BUCKET = process.env.PRIVATE_BUCKET!;

export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
  const keyParam = event.pathParameters?.key;

  try {
    // GET /files/{key} — presigned download URL
    if (keyParam) {
      const key = decodeURIComponent(keyParam);
      const url = await getSignedUrl(s3, new GetObjectCommand({ Bucket: BUCKET, Key: key }), { expiresIn: 3600 });
      return ok({ url, key });
    }

    // GET /files?prefix=Music/ — list folders and files
    const prefix    = event.queryStringParameters?.prefix ?? "";
    const delimiter = "/";

    const result = await s3.send(new ListObjectsV2Command({ Bucket: BUCKET, Prefix: prefix, Delimiter: delimiter }));

    const folders = (result.CommonPrefixes ?? []).map(p => ({
      key:  p.Prefix!,
      name: p.Prefix!.replace(prefix, "").replace("/", ""),
      hasMp3s: true, hasSubFolders: true,
    }));

    const files = (result.Contents ?? [])
      .filter(o => o.Key !== prefix)
      .map(o => ({ key: o.Key!, name: o.Key!.split("/").pop()!, size: o.Size ?? 0 }));

    return ok({ folders, files });
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    console.error(e);
    return { statusCode: 500, headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }, body: JSON.stringify({ error: msg }) };
  }
};

const ok = (body: unknown): APIGatewayProxyResult => ({
  statusCode: 200,
  headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
  body: JSON.stringify(body),
});
