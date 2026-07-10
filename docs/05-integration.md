# Integration Guide

Using your node from your own applications — wallets, dapps, backends, or scripts.

This assumes you're pointed at either the public reference RPC (`https://rpc.glassnet.prismo.network`, rate-limited) or a node you run yourself following [docs/nodes/rpc-node.md](nodes/rpc-node.md). Everything below applies to both; only the URL changes.

## Connect

Chain ID `101001000` (testnet). See [docs/02-network-config.md](02-network-config.md) for the mainnet value once it exists.

### ethers v6

```js
import { JsonRpcProvider } from "ethers";

const provider = new JsonRpcProvider(
  "https://rpc.glassnet.prismo.network", // or http://127.0.0.1:8545 for your own node
  { chainId: 101001000, name: "prismo-glassnet-testnet" }
);

const network = await provider.getNetwork();
console.log(network.chainId); // 101001000n
```

### viem

```js
import { createPublicClient, http, defineChain } from "viem";

export const glassnetTestnet = defineChain({
  id: 101001000,
  name: "Prismo Glassnet Testnet",
  nativeCurrency: { name: "USD Coin", symbol: "USDC", decimals: 18 }, // see Currency below — 18, not 6
  rpcUrls: {
    default: { http: ["https://rpc.glassnet.prismo.network"] },
  },
});

const client = createPublicClient({ chain: glassnetTestnet, transport: http() });
console.log(await client.getChainId()); // 101001000
```

## Currency semantics

The chain's **native gas token is USDC — but not canonical 6-decimal USDC.** It's an 18-decimal wrapper (`USDC18Wrapper`, see [docs/02-network-config.md](02-network-config.md#l1-contract-addresses) for the L1 contract address) over an open-mint testnet token. Symbol and name both read `USDC`, and 1 token displays as `1 USDC` — but:

- **Set `decimals: 18`** in any chain/wallet config (MetaMask "Add Network," viem `defineChain`, etc.). Using `6` (canonical USDC's real decimal count) will misdisplay balances by a factor of 10¹².
- Gas prices, `eth_getBalance`, and `msg.value` are all denominated in this 18-decimal unit, exactly like ETH on L1 — the only difference from a "normal" chain is the token's name/symbol.
- Get testnet funds: `https://faucet.glassnet.prismo.network`.
- This is a testnet-only convenience token. It is **not** bridgeable 1:1 with real USDC and has no independent value.

## Available RPC namespaces

Verified live against a Prismo node (`http://127.0.0.1:8545`, cdk-erigon v2.61.24):

| Namespace | Status | Notes |
|---|---|---|
| `eth`, `net`, `web3`, `txpool`, `zkevm` | **On** | Full read surface + tx submission |
| `debug`, `trace` | **Off** | `debug_traceTransaction`, `trace_transaction` → `-32601 method not found` |
| `admin`, `personal`, `miner` | **Off** | `admin_peers`, `personal_listAccounts` → `-32601 method not found` |

`debug`/`trace` are off by default for cost and security reasons: unfiltered historical tracing is expensive to serve and has been used as an RCE/DoS vector against misconfigured Ethereum nodes elsewhere (see [docs/04-security.md](04-security.md)). If you need historical traces, run your own archive node with those namespaces enabled internally — never expose them publicly.

## WebSocket

- **Public reference endpoint**: `wss://rpc.glassnet.prismo.network` — same hostname as the HTTP RPC. The ALB in front of it routes on the `Upgrade: websocket` header; there is no separate `/ws` path.
- **Your own node**: cdk-erigon serves WS on `:8546` (`ws://127.0.0.1:8546` locally). If you front it with nginx per the [reverse-proxy example](04-security.md#reverse-proxy-nginx), that example proxies WS at a `/ws` location — that's an operator-chosen convention for your own deployment, not a property of the protocol.

```js
import { WebSocketProvider } from "ethers";

const wsProvider = new WebSocketProvider("wss://rpc.glassnet.prismo.network");
wsProvider.on("block", (blockNumber) => console.log("new block", blockNumber));
```

## Transaction lifecycle

`eth_sendRawTransaction` on **any** operator RPC node is transparently forwarded to the trusted sequencer's own RPC (`SEQUENCER_RPC_URL`) — the node you're talking to doesn't order transactions itself. Implications:

- **Trust**: you're relying on the sequencer to include your transaction honestly and promptly. This is the same centralization point described in [docs/00-overview.md#trust-model-today](00-overview.md#trust-model-today) — the sequencer can censor or reorder, but it cannot forge state (the SNARK verifier rejects invalid state roots on L1).
- **Latency**: submission is near-instant (ordinary RPC round-trip) once the sequencer accepts it into the trusted head. Full finality still follows the tiers below.
- **If the sequencer is unreachable**: your `eth_sendRawTransaction` call will error or time out at the forwarding node — there's no local mempool fallback. Retry against the same or another operator RPC node once the sequencer recovers; do not assume the transaction was silently queued.

## Finality tiers

Query these with `zkevm_batchNumber` / `zkevm_virtualBatchNumber` / `zkevm_verifiedBatchNumber`. Verified live outputs (testnet, 2026-07-08 — values will differ when you query, shown to confirm the methods and response shape):

```
$ curl -s localhost:8545 -d '{"jsonrpc":"2.0","method":"zkevm_batchNumber","params":[],"id":1}'
{"jsonrpc":"2.0","id":1,"result":"0x116"}          # 278 — latest trusted batch

$ curl -s localhost:8545 -d '{"jsonrpc":"2.0","method":"zkevm_virtualBatchNumber","params":[],"id":1}'
{"jsonrpc":"2.0","id":1,"result":"0x1"}             # latest batch posted to L1

$ curl -s localhost:8545 -d '{"jsonrpc":"2.0","method":"zkevm_verifiedBatchNumber","params":[],"id":1}'
{"jsonrpc":"2.0","id":1,"result":"0x17"}            # 23 — latest SNARK-verified batch
```

| Tier | How to query | Typical latency | Use for |
|---|---|---|---|
| **Trusted head** | `eth_blockNumber`, or `zkevm_batchNumber` for the containing batch | Seconds (streamed from the sequencer) | UX — optimistic balance updates, "transaction sent" states, instant feedback |
| **Virtualized** | `zkevm_virtualBatchNumber` | Batches seal after ~1 h idle (`sequencer-batch-seal-time=1h`), so roughly 1–2 h cadence | Value-transfer confidence — the data is posted to L1 as calldata; the sequencer can no longer unilaterally rewrite it (still pre-proof) |
| **Verified** | `zkevm_verifiedBatchNumber` | Prover runs a daily window (02:00–06:00 UTC); proofs land in a burst, so up to ~24 h between updates | Settlement, bridge withdrawal claims, and anything irreversible — this is the only tier backed by an on-chain validity proof |

A transaction is "confirmed" at a given tier once `zkevm_batchNumber` (its batch) is ≤ the corresponding tier's counter. Concretely:

- **UI feedback** ("your tx was received"): trusted head is enough — don't make users wait.
- **Crediting a deposit / releasing goods for a same-chain transfer**: wait for virtualized. Reorg risk drops to L1's own reorg risk.
- **Bridging out, large/irreversible transfers, anything where you cannot tolerate a rollback**: wait for verified. This is the tier the L1 bridge contract itself relies on.

## Bridge API

Claiming a withdrawal (L2 → L1) requires a Merkle proof from a bridge indexer — the reference one is at `https://bridge.glassnet.prismo.network` (`BRIDGE_API_URL`). See [docs/nodes/bridge-indexer.md](nodes/bridge-indexer.md) for the API surface (`/merkle-proof`, `/bridges/<address>`, `/claims/<address>`) and how to run your own if you don't want to depend on the official one. Claim proofs for a given deposit only become valid once the corresponding batch is **verified** (see Finality tiers above) — the bridge contract checks against a verified global exit root.
