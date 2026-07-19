// Spike: validate SeaweedFS S3 API coverage against CodeAlkimia requirements (doc 07 §5).
// Runs against a live endpoint; prints PASS/FAIL per criterion.
import {
  S3Client, CreateBucketCommand, PutObjectCommand, GetObjectCommand,
  PutBucketVersioningCommand, GetBucketVersioningCommand, ListObjectVersionsCommand,
  PutBucketLifecycleConfigurationCommand, GetBucketLifecycleConfigurationCommand,
  PutBucketCorsCommand, GetBucketCorsCommand,
  CreateMultipartUploadCommand, UploadPartCommand, CompleteMultipartUploadCommand,
} from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import { Upload } from "@aws-sdk/lib-storage";
import crypto from "node:crypto";

const endpoint = process.env.S3_ENDPOINT || "http://seaweedfs:8333";
const checksumMode = process.env.CHECKSUM_MODE || "default";

const cfg = {
  endpoint,
  region: "us-east-1",
  forcePathStyle: true,
  credentials: { accessKeyId: "spikekey", secretAccessKey: "spikesecret" },
};
if (checksumMode === "compat") {
  cfg.requestChecksumCalculation = "WHEN_REQUIRED";
  cfg.responseChecksumValidation = "WHEN_REQUIRED";
}
const s3 = new S3Client(cfg);

const results = [];
async function test(name, fn) {
  try {
    const detail = await fn();
    results.push([name, "PASS", detail || ""]);
  } catch (e) {
    results.push([name, "FAIL", `${e.name || "Error"}: ${String(e.message || e).slice(0, 180)}`]);
  }
}

const B = "spike-bucket";

await test("create-bucket", () => s3.send(new CreateBucketCommand({ Bucket: B })));

await test("put-object", () =>
  s3.send(new PutObjectCommand({ Bucket: B, Key: "hello.txt", Body: "hola codealkimia" })));

await test("get-object", async () => {
  const r = await s3.send(new GetObjectCommand({ Bucket: B, Key: "hello.txt" }));
  const body = await r.Body.transformToString();
  if (body !== "hola codealkimia") throw new Error("content mismatch: " + body);
});

await test("range-get", async () => {
  const r = await s3.send(new GetObjectCommand({ Bucket: B, Key: "hello.txt", Range: "bytes=0-3" }));
  const body = await r.Body.transformToString();
  if (body !== "hola") throw new Error("range mismatch: " + body);
});

await test("presigned-get", async () => {
  const url = await getSignedUrl(s3, new GetObjectCommand({ Bucket: B, Key: "hello.txt" }), { expiresIn: 300 });
  const res = await fetch(url);
  if (!res.ok) throw new Error(`HTTP ${res.status} ${(await res.text()).slice(0, 150)}`);
  const t = await res.text();
  if (t !== "hola codealkimia") throw new Error("content mismatch via presigned GET");
});

await test("presigned-put", async () => {
  const url = await getSignedUrl(s3, new PutObjectCommand({ Bucket: B, Key: "up.txt" }), { expiresIn: 300 });
  const res = await fetch(url, { method: "PUT", body: "subido por url prefirmada" });
  if (!res.ok) throw new Error(`HTTP ${res.status} ${(await res.text()).slice(0, 150)}`);
  const r = await s3.send(new GetObjectCommand({ Bucket: B, Key: "up.txt" }));
  if ((await r.Body.transformToString()) !== "subido por url prefirmada") throw new Error("roundtrip mismatch");
});

await test("presigned-put-expired-rejected", async () => {
  const url = await getSignedUrl(s3, new PutObjectCommand({ Bucket: B, Key: "exp.txt" }), { expiresIn: 1 });
  await new Promise((r) => setTimeout(r, 2500));
  const res = await fetch(url, { method: "PUT", body: "no deberia entrar" });
  if (res.ok) throw new Error("expired URL was accepted (security problem)");
  return `rejected with HTTP ${res.status}`;
});

await test("multipart-sdk-upload-10MB", async () => {
  const data = crypto.randomBytes(10 * 1024 * 1024);
  const up = new Upload({ client: s3, params: { Bucket: B, Key: "big.bin", Body: data }, partSize: 5 * 1024 * 1024 });
  await up.done();
  const r = await s3.send(new GetObjectCommand({ Bucket: B, Key: "big.bin" }));
  const got = Buffer.from(await r.Body.transformToByteArray());
  if (!got.equals(data)) throw new Error("content mismatch after multipart upload");
});

await test("presigned-multipart-part", async () => {
  const mp = await s3.send(new CreateMultipartUploadCommand({ Bucket: B, Key: "bigp.bin" }));
  const part = crypto.randomBytes(5 * 1024 * 1024);
  const url = await getSignedUrl(
    s3,
    new UploadPartCommand({ Bucket: B, Key: "bigp.bin", UploadId: mp.UploadId, PartNumber: 1 }),
    { expiresIn: 300 },
  );
  const res = await fetch(url, { method: "PUT", body: part });
  if (!res.ok) throw new Error(`HTTP ${res.status} ${(await res.text()).slice(0, 150)}`);
  const etag = res.headers.get("etag");
  await s3.send(new CompleteMultipartUploadCommand({
    Bucket: B, Key: "bigp.bin", UploadId: mp.UploadId,
    MultipartUpload: { Parts: [{ ETag: etag, PartNumber: 1 }] },
  }));
});

await test("versioning-enable", async () => {
  await s3.send(new PutBucketVersioningCommand({ Bucket: B, VersioningConfiguration: { Status: "Enabled" } }));
  const r = await s3.send(new GetBucketVersioningCommand({ Bucket: B }));
  if (r.Status !== "Enabled") throw new Error("status=" + r.Status);
});

await test("versioning-two-versions", async () => {
  await s3.send(new PutObjectCommand({ Bucket: B, Key: "v.txt", Body: "v1" }));
  await s3.send(new PutObjectCommand({ Bucket: B, Key: "v.txt", Body: "v2" }));
  const r = await s3.send(new ListObjectVersionsCommand({ Bucket: B, Prefix: "v.txt" }));
  const n = (r.Versions || []).length;
  if (n < 2) throw new Error("versions=" + n);
  return "versions=" + n;
});

await test("lifecycle-put-get", async () => {
  await s3.send(new PutBucketLifecycleConfigurationCommand({
    Bucket: B,
    LifecycleConfiguration: {
      Rules: [{ ID: "expire-tmp", Status: "Enabled", Filter: { Prefix: "tmp/" }, Expiration: { Days: 1 } }],
    },
  }));
  const r = await s3.send(new GetBucketLifecycleConfigurationCommand({ Bucket: B }));
  if (!r.Rules || !r.Rules.length) throw new Error("no rules returned");
  return JSON.stringify(r.Rules).slice(0, 120);
});

await test("cors-put-get", async () => {
  await s3.send(new PutBucketCorsCommand({
    Bucket: B,
    CORSConfiguration: {
      CORSRules: [{ AllowedMethods: ["GET", "PUT"], AllowedOrigins: ["https://console.example"], AllowedHeaders: ["*"] }],
    },
  }));
  const r = await s3.send(new GetBucketCorsCommand({ Bucket: B }));
  if (!r.CORSRules?.length) throw new Error("no cors rules returned");
});

await test("small-files-200-sequential", async () => {
  const t0 = Date.now();
  for (let i = 0; i < 200; i++) {
    await s3.send(new PutObjectCommand({ Bucket: B, Key: `tree/f${i}.txt`, Body: "x".repeat(1024) }));
  }
  return `${Date.now() - t0} ms total`;
});

console.log(`\n=== SeaweedFS spike results (checksumMode=${checksumMode}) ===`);
for (const [n, s, d] of results) console.log(s.padEnd(5), n.padEnd(32), d);
const fails = results.filter((r) => r[1] === "FAIL").length;
console.log(`\n${results.length - fails}/${results.length} PASS`);
