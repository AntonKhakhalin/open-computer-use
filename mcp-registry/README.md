# MCP Registry metadata

This directory holds the [MCP Registry](https://github.com/modelcontextprotocol/registry) publication
metadata for the fork. The server name follows the official GitHub-verified namespace pattern:

```
io.github.<github-owner>/<server-name>
```

## Status

- `server.json` — prepared and validated against the official
  `2025-12-11` server schema.
- **Not published yet.** Publication requires interactive credentials that this
  repository cannot provide on its own.

## Publish steps (manual, in order)

1. Publish the npm package first (the Registry only indexes metadata; the
   package must exist on npm with a matching `mcpName` — `build-packages.mjs`
   already writes `mcpName` into the staged package.json):

   ```sh
   npm login
   npm publish --access public   # from dist/npm/@antonkhakhalin/open-computer-use
   ```

2. Install the official publisher CLI:

   ```sh
   npm install -g mcp-publisher   # or build from github.com/modelcontextprotocol/registry
   ```

3. Log in with the GitHub account that owns this repository (device flow):

   ```sh
   mcp-publisher login github
   ```

4. Validate locally (no auth needed):

   ```sh
   mcp-publisher validate mcp-registry/server.json
   ```

5. Publish:

   ```sh
   mcp-publisher publish mcp-registry/server.json
   ```

If the namespace is rejected, verify that the GitHub login is
`AntonKhakhalin` — the `io.github.<owner>` namespace must match the
authenticated identity.
