// shared/types/base-outputs.ts
// TypeScript type for base_outputs.json — used by all add-on stacks.
// Add-on bin/app.ts files call loadBaseOutputs() to get these values.

export interface BaseOutputs {
  version:    string;
  aws_region: string;
  auth: {
    user_pool_id:        string;
    user_pool_client_id: string;
    user_pool_provider:  string;
    identity_pool_id:    string;
    auth_role_arn:       string;
  };
  storage: {
    public_bucket:  string;
    private_bucket: string;
  };
}

// Loads and validates base_outputs.json from the repo root.
// Throws a clear error if the base stack hasn't been deployed yet.
import * as fs   from "fs";
import * as path from "path";

export function loadBaseOutputs(repoRoot: string): BaseOutputs {
  const outputPath = path.join(repoRoot, "base_outputs.json");
  if (!fs.existsSync(outputPath)) {
    throw new Error(
      `base_outputs.json not found at ${outputPath}\n` +
      `Deploy the base stack first:\n` +
      `  cd base && ./scripts/deploy.sh`
    );
  }
  return JSON.parse(fs.readFileSync(outputPath, "utf-8")) as BaseOutputs;
}
