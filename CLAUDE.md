# proton — working notes

## What this is

A Linux kernel module that exposes [libhydrogen](https://github.com/jedisct1/libhydrogen)
crypto as **kfuncs callable from XDP programs**.

The thing to be clear about, because it is easy to assume otherwise: the
crypto is **not** compiled to eBPF bytecode and **never faces the verifier**.
It is ordinary native kernel code in a module. What the verifier sees is only
the XDP program's *call* to a registered kfunc. That is why a full crypto
library can live here at all.

`proton.c` is 137 lines — it is a thin wrapper. The substance is
`hydrogen.c`, and the value is in the API boundary.

## The API surface is the design

Everything callable from XDP has to conform to the kfunc contract, and that
constraint shapes the whole interface:

- `__bpf_kfunc` on each exported function.
- Registered through `BTF_ID_FLAGS` in a kfunc id set, so BTF can type-check
  the call from the BPF side.
- **The `__sz` suffix is load-bearing**, not a naming style: a parameter named
  `data__sz` tells the verifier that the preceding pointer is a buffer of that
  many bytes, and the verifier then enforces the bound at the call site. Rename
  it and you silently lose the bounds check.
- Arguments arrive as pointers from a BPF program, so lifetime and
  addressability are the caller's contract, not assumptions this side may make.

Exported today: `proton_sha256`, `proton_sign_create`, `proton_sign_verify`,
`proton_secretbox_encrypt`, `proton_secretbox_decrypt`.

When adding a kfunc, the checklist is: `__bpf_kfunc`, a `__sz` companion for
every buffer, registration in the BTF id set, and a userspace-side equivalent
that produces identical bytes — see below.

## Why hydrogen and not something bigger

The requirement is crypto in an XDP program that is **compatible with clients
on arbitrary platforms** — PC, Mac, Linux, consoles. So the same primitives
have to be available, cheaply, on the client side too. libhydrogen is tiny,
dependency-free, and compiles essentially anywhere, so the client burden is
nil.

libsodium cannot take this path, and the reason is not the verifier: it is
that libhydrogen **already builds in-kernel** (upstream carries
`impl/random/linux_kernel.h` and a `__KERNEL__` branch), whereas libsodium
assumes libc, `mmap` and `mlock` and has no in-kernel build at all.

## Its relationship to mas-bandwidth/hydrogen

This repo carries its **own copy** of `hydrogen.c` / `hydrogen.h`, and it is
*almost* the same file as the one in
[mas-bandwidth/hydrogen](https://github.com/mas-bandwidth/hydrogen).

As of 2026-08-15 the delta is **zero — both files are byte-identical to
hydrogen's**, so parity is a checksum, not a diff review. How it got to zero:
the `warnings_fuck_off` prototype moved into hydrogen on 2026-08-14 (a
flattening artifact, harmless in userspace), and the `__KERNEL__` header
block this copy carried locally became upstream's own on 2026-08-14 —
jedisct1/libhydrogen `617036a`, fixing #165, which was filed from this
estate for exactly this divergence. Upstream's form has no typedefs;
`linux/types.h` supplies `uint8_t` through `uint64_t` itself.

Two consequences worth acting on:

1. **Upstream fixes have to be carried here too.** The hydrogen repo tracks
   jedisct1/libhydrogen by hand; this copy does not automatically follow. When
   a fix lands there, copy both files across — the delta is zero now, so a
   straight copy is the whole re-vendor. Pay particular attention to upstream
   changes in the `__KERNEL__` / `impl/random/linux_kernel.h` path — that is
   the branch this module actually compiles, and it is the one place where an
   upstream RNG change is directly load-bearing here rather than academic.
2. **The delta being zero makes it enforceable.** A CI parity check could
   compare checksums against mas-bandwidth/hydrogen instead of relying on
   someone remembering. A sentence claiming two files match stays true only
   until someone edits one of them.

## Equivalence is the property that matters

The point of this module is that an XDP program and a client on some other
platform agree on the bytes. Nothing in a build check proves that.

The test worth having is **differential**: run each kfunc and its userspace
libhydrogen counterpart over the same inputs and compare outputs byte for
byte — signatures verifying across the boundary, secretbox ciphertext
round-tripping in both directions, sha256 agreeing on the same buffers. Pinned
known-answer vectors are the cheaper version of the same idea and survive a
re-vendor, which is exactly when you want them.

## Build and install

`./install.sh` builds the module and sets it to load on boot; Ubuntu 24.04 LTS
or newer. Kernel modules are tied to kernel headers, so a kernel upgrade means
a rebuild — worth knowing before a server reboot surprises you.
