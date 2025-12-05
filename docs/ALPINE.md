# Alpine Linux vs Debian

## Why Alpine Linux?

We chose Alpine Linux for this project primarily for **performance** and **security**.

### 1. Minimal Footprint (Size)
- **Alpine**: The base image is incredibly small, typically around **5 MB**.
- **Debian**: The base image is significantly larger, usually starting around **100 MB**.
- **Benefit**: Smaller images mean faster download times, faster build times, and less disk usage. This aligns with the "performance reasons" mentioned in the subject.

### 2. Security
- **Attack Surface**: Because Alpine comes with very few pre-installed packages, the potential attack surface is much smaller. There are fewer things that can be exploited.
- **Hardening**: Alpine is built with security in mind (compiling user-space binaries as position-independent executables (PIE) with stack smashing protection).

### 3. Simplicity
- Alpine follows a "keep it simple" philosophy, which forces us to be explicit about dependencies. We only install exactly what we need for each service (NGINX, MariaDB, WordPress), keeping the containers clean.

---

## Particularities & Things to Know for Evaluation

When working with or evaluating Alpine Linux containers, there are several key differences from a standard Debian/Ubuntu environment:

### 1. Package Manager: `apk`
- Instead of `apt` or `apt-get`, Alpine uses **`apk`** (Alpine Package Keeper).
- **Common commands**:
  - Update index: `apk update`
  - Install package: `apk add <package>`
  - Search package: `apk search <query>`
  - No interactive prompts by default (unlike `apt` which often needs `-y`).

### 2. C Standard Library: `musl` vs `glibc`
- **Debian** uses **glibc** (GNU C Library), which is the standard for most Linux distributions.
- **Alpine** uses **musl libc**, which is lighter and more standards-compliant but **not 100% compatible** with glibc.
- **Impact**: Binaries compiled on a Debian system (dynamically linked to glibc) will **not run** on Alpine. Software must usually be compiled specifically for Alpine or installed via the Alpine repositories.

### 3. Default Shell: `ash` (BusyBox)
- Alpine uses **BusyBox** to provide standard Unix utilities (ls, cp, grep, sh, etc.) in a single executable to save space.
- The default shell is **`/bin/sh`**, which is actually **`ash`** (Almquist shell), not `bash`.
- **Impact**:
  - Scripts with `#!/bin/bash` shebangs will fail unless you explicitly install bash (`apk add bash`).
  - Some bash-isms (specific syntax) won't work in the default shell.
  - Command flags for tools like `grep`, `sed`, or `ps` might be more limited compared to their GNU counterparts.

### 4. User Management
- Creating users and groups works similarly (`adduser`, `addgroup`), but the flags might differ slightly from the Debian versions.
