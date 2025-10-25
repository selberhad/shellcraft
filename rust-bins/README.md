# ShellCraft Rust Binaries

This workspace contains all Rust binaries that are compiled and embedded into the ShellCraft game image.

## Architecture

**Multi-stage Docker build:**
1. **Builder stage** - Compiles all Rust binaries with full toolchain
2. **Runtime stage** - Copies only the compiled binaries, no source/toolchain

**Benefits:**
- Fast compilation (shared workspace dependencies)
- Small final image (no Rust toolchain, ~70MB saved)
- Secure (players can't see binary source code)

## Binaries

### `quest`
Location: `/home/quest`

Quest management interface:
- Show active quests and progress
- Accept new quests based on player level
- Turn in completed quests for rewards

Reads/writes player quest state from `soul.dat`.

## Development

### Build locally
```bash
cd rust-bins
cargo build --release
```

### Test binary
```bash
./target/release/quest
```

### Add new binary
```bash
cargo new --bin mybinary
```

Then add `"mybinary"` to workspace members in root `Cargo.toml`.

## Integration with Docker

Binaries are built during Docker image creation:

```dockerfile
FROM alpine:3.19 AS builder
RUN apk add cargo rust musl-dev
COPY ../../rust-bins /build/rust-bins
RUN cargo build --release

FROM alpine:3.19
COPY --from=builder /build/rust-bins/target/release/quest /home/quest
```

The builder stage is discarded, keeping the final image small.

## Binary Guidelines

**Keep binaries small and focused:**
- Each binary should do one thing
- Minimize dependencies (prefer std library)
- Statically link (musl target)
- No network access needed

**Common patterns:**
- Read `soul.dat` for player state
- Check filesystem for quest conditions
- Write state back to `soul.dat`
- Print fantasy-themed output
