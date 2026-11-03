# Integration Guide

Using your node from your own applications — wallets, dapps, backends, or scripts.

This assumes you're pointed at either a public reference RPC (`https://rpc.prismo.network` for mainnet, `https://rpc.glassnet.prismo.network` for testnet — both rate-limited) or a node you run yourself following [docs/nodes/rpc-node.md](nodes/rpc-node.md). Everything below applies to all of them; only the URL and chain ID change.

## Connect

| Network | Chain ID | RPC | Currency |
|---|---|---|---|
| Prismo Glass (mainnet) | `328` | `https://rpc.prismo.network` | PRL (Prismo Load), **18 decimals** |
| Glassnet (testnet) | `101001000` | `https://rpc.glassnet.prismo.network` | PRL (test), **18 decimals** |

> **Mainnet accepts only legacy (type-0) transactions.** Pin `type: 0` in every mainnet transaction you build (ethers: `{ type: 0, gasPrice }`; viem: `type: 'legacy'`). The reference RPC hides EIP-1559 so default wallets do the right thing, but a node run from this repo's upstream image does not — see [02-network-config.md](02-network-config.md#mainnet-facts-operators-must-know).

### ethers v6

```js
import { JsonRpcProvider } from "ethers";

// Mainnet (Prismo Glass)
const provider = new JsonRpcProvider(
  "https://rpc.prismo.network", // or http://127.0.0.1:8545 for your own node
  { chainId: 328, name: "prismo-glass" }
);
const network = await provider.getNetwork();
console.log(network.chainId); // 328n

// Sending on mainnet: force a legacy transaction
const tx = await signer.sendTransaction({ to, value, type: 0, gasPrice: await provider.send("eth_gasPrice", []) });

// Testnet (Glassnet): same shape with "https://rpc.glassnet.prismo.network" and
// { chainId: 101001000, name: "prismo-glassnet-testnet" }.
```

### viem

```js
import { createPublicClient, http, defineChain } from "viem";

export const prismoGlass = defineChain({
  id: 328,
  name: "Prismo Glass",
  nativeCurrency: { name: "Prismo Load", symbol: "PRL", decimals: 18 }, // see Currency semantics below — 18 decimals
  rpcUrls: { default: { http: ["https://rpc.prismo.network"] } },
  blockExplorers: { default: { name: "Prismo Explorer", url: "https://explorer.prismo.network" } },
  fees: { defaultPriorityFee: 0n },
});

export const glassnetTestnet = defineChain({
  id: 101001000,
  name: "Prismo Glassnet Testnet",
  nativeCurrency: { name: "Prismo Load", symbol: "PRL", decimals: 18 },
  rpcUrls: { default: { http: ["https://rpc.glassnet.prismo.network"] } },
});

const client = createPublicClient({ chain: prismoGlass, transport: http() });
console.log(await client.getChainId()); // 328

// Writes on mainnet: pass type: 'legacy' (and gasPrice) to every sendTransaction / writeContract.
```

## Currency semantics

The native gas token is **18-decimal** on both networks. It is **PRL (Prismo Load)** on both networks; each moved from USDC in its own migration:

| Network | Native currency | Status |
|---|---|---|
| Glassnet (testnet) | PRL (test) | Migrated. Test PRL has no value. |
| Prismo Glass (mainnet) | PRL | Migrated. Purchases open when Prismo unpauses the PRLIssuer (after its audit). |

- **Set `decimals: 18`** in any chain or wallet config (MetaMask "Add Network", viem `defineChain`, etc.). Using `6` (USDC's real decimal count) misdisplays balances by a factor of 10¹².
- Gas prices, `eth_getBalance` and `msg.value` are all in this 18-decimal unit, exactly like ETH on L1.
- **PRL** is an ERC-20 on L1 (Sepolia for glassnet; on Ethereum from mainnet's migration). Prismo sells it at **1 USDC per PRL** and **never buys it back**: PRL is not redeemable. To get it, buy on L1 from the PRLIssuer contract: approve USDC, then call `buyWithUSDC(usdcAmount, l2Recipient)`. `usdcAmount` is in USDC's 6-decimal units (the minimum, 1 USDC, is `1000000` and buys 1 PRL = 10¹⁸ base units); `l2Recipient` is the Glass address that receives the PRL. Where your wallet supports it, `buyWithUSDCPermit(usdcAmount, l2Recipient, deadline, v, r, s)` does both steps in one transaction with a USDC permit; Sepolia MockUSDC has no permit, so on testnet always approve first. The bridge UI (`https://app.glassnet.prismo.network` on testnet) does this for you. The PRL is bridged to your Glass address and claimed for you by the network's relayer, so you need no gas on Glass first. If you buy from a Safe or another contract wallet, name a Glass recipient you control: your contract's address on Glass is not automatically yours.
- **The L2 bridge's `gasTokenAddress()` is the authority** for which token is gas. The L1 rollup contract's `gasTokenAddress()` names the USDC18Wrapper, and keeps naming it after each network's PRL migration; that value has been informational since genesis.
- **Testnet:** get funds at `https://faucet.glassnet.prismo.network`, or buy test PRL with Sepolia MockUSDC. Test PRL has no value.
- **Mainnet:** buy PRL on Ethereum at `https://app.prismo.network` once purchases are open. The gas floor is 816 gwei ≈ 0.017 PRL per simple transfer. Withdrawals back to L1 are not claimable until settlement is enabled (see [02-network-config.md](02-network-config.md#mainnet-facts-operators-must-know)).

## Available RPC namespaces

Verified live against a Prismo node (`http://127.0.0.1:8545`, cdk-erigon v2.61.24):

| Namespace | Status | Notes |
|---|---|---|
| `eth`, `net`, `web3`, `txpool`, `zkevm` | **On** | Full read surface + tx submission |
| `debug`, `trace` | **Off** | `debug_traceTransaction`, `trace_transaction` → `-32601 method not found` |
| `admin`, `personal`, `miner` | **Off** | `admin_peers`, `personal_listAccounts` → `-32601 method not found` |

`debug`/`trace` are off by default for cost and security reasons: unfiltered historical tracing is expensive to serve and has been used as an RCE/DoS vector against misconfigured Ethereum nodes elsewhere (see [docs/04-security.md](04-security.md)). If you need historical traces, run your own archive node with those namespaces enabled internally — never expose them publicly.

## WebSocket

- **Public reference endpoints**: `wss://rpc.prismo.network` (mainnet) / `wss://rpc.glassnet.prismo.network` (testnet) — same hostname as the HTTP RPC. The ALB in front of it routes on the `Upgrade: websocket` header; there is no separate `/ws` path.
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

Query these with `zkevm_batchNumber` / `zkevm_virtualBatchNumber` / `zkevm_verifiedBatchNumber`.

> **Mainnet today: only the trusted head exists.** Settlement is not yet enabled on Prismo Glass, so `zkevm_virtualBatchNumber` stays at `1` and `zkevm_verifiedBatchNumber` at `0` until the core team turns it on. Treat every mainnet transaction as trusted-head-only finality for now, and do not build flows that wait on the verified tier until it starts advancing. See [02-network-config.md](02-network-config.md#mainnet-facts-operators-must-know).

Verified live outputs (testnet, 2026-07-08 — values will differ when you query, shown to confirm the methods and response shape):

```
$ curl -s localhost:8545 -d '{"jsonrpc":"2.0","method":"zkevm_batchNumber","params":[],"id":1}'
{"jsonrpc":"2.0","id":1,"result":"0x116"}          # 278 — latest trusted batch

$ curl -s localhost:8545 -d '{"jsonrpc":"2.0","method":"zkevm_virtualBatchNumber","params":[],"id":1}'
{"jsonrpc":"2.0","id":1,"result":"0x17"}            # 23 — latest batch posted to L1

$ curl -s localhost:8545 -d '{"jsonrpc":"2.0","method":"zkevm_verifiedBatchNumber","params":[],"id":1}'
{"jsonrpc":"2.0","id":1,"result":"0x1"}             # 1 — latest SNARK-verified batch
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

Claiming a withdrawal (L2 → L1) requires a Merkle proof from a bridge indexer — the reference ones are at `https://bridge.prismo.network` (mainnet) and `https://bridge.glassnet.prismo.network` (testnet) (`BRIDGE_API_URL`). See [docs/nodes/bridge-indexer.md](nodes/bridge-indexer.md) for the API surface (`/merkle-proof`, `/bridges/<address>`, `/claims/<address>`) and how to run your own if you don't want to depend on the official one. Claim proofs for a given deposit only become valid once the corresponding batch is **verified** (see Finality tiers above) — the bridge contract checks against a verified global exit root.
