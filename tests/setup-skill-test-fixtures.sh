#!/usr/bin/env bash
# setup-skill-test-fixtures.sh
# Build 2026-10-14.3
#
# Makes the scratch repos for the manual test plan of the adapted
# Matt Pocock skills. It writes only inside the target folder.
# It does not change your git config, and it deletes nothing.
#
# Usage:  bash setup-skill-test-fixtures.sh [target-folder]
# Default target folder: $HOME/skills-test
#
# Works with the macOS default bash (3.2) and with Linux bash.

set -euo pipefail

TARGET="${1:-$HOME/skills-test}"

case "$TARGET" in
  *" "*) echo "STOP: the target path has a space. Use a path with no spaces." >&2; exit 1 ;;
esac

if [ -e "$TARGET" ]; then
  echo "STOP: $TARGET exists. Move it away, or give a different target folder." >&2
  exit 1
fi

for tool in git zip; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "STOP: '$tool' is not installed." >&2
    exit 1
  fi
done

mkdir -p "$TARGET"
TARGET="$(cd "$TARGET" && pwd -P)"

# Commit with a fixed test identity. No signing, no hooks, no change to your config.
gcommit() {
  git -c user.name="Skill Test" -c user.email="skill-test@example.invalid" \
      -c commit.gpgsign=false -c core.hooksPath=/dev/null \
      commit -q -m "$1"
}

newrepo() {
  mkdir -p "$1"
  cd "$1"
  git init -q
  git symbolic-ref HEAD refs/heads/main
}

# wf <path>: write stdin to <path>, and make the parent folders.
wf() {
  mkdir -p "$(dirname "$1")"
  cat > "$1"
}

###########################################################################
# 1. review-fixture: for two-axis-review and pr
###########################################################################
newrepo "$TARGET/review-fixture"

wf README.md <<'EOF'
# Cart service (test fixture)

Small fixture for the two-axis-review and pr skills. Not real code.
EOF

wf CONTRIBUTING.md <<'EOF'
# Coding standards

1. Use `const` or `let`. Do not use `var`.
2. Every exported function has a JSDoc comment.
3. Do not call `console.log` in `src/`. Use `log()` from `src/logger.js`.
4. Money values are integers in cents. Do not use floating-point money.
EOF

wf src/logger.js <<'EOF'
/**
 * Write a log line with a timestamp.
 * @param {string} message
 */
export function log(message) {
  process.stdout.write(`[${new Date().toISOString()}] ${message}\n`);
}
EOF

wf src/cart.js <<'EOF'
import { log } from "./logger.js";

/**
 * Create an empty cart.
 */
export function createCart() {
  return { items: [] };
}

/**
 * Add an item to the cart. Prices are integers in cents.
 */
export function addItem(cart, sku, priceCents, qty) {
  cart.items.push({ sku, priceCents, qty });
  log(`added ${sku}`);
  return cart;
}

/**
 * Cart total in cents.
 */
export function totalCents(cart) {
  return cart.items.reduce((sum, i) => sum + i.priceCents * i.qty, 0);
}
EOF

wf docs/specs/discount-codes.md <<'EOF'
# Spec: discount codes

Issue: local spec, no tracker.

- R1. A customer can apply a percentage discount code to the cart. The discount applies to the cart total.
- R2. An expired code is rejected with the error "CODE_EXPIRED". A code is expired when today is after its expiry date. On the expiry date itself, the code is still valid.
- R3. A cart can have at most one discount code. A second code is rejected with the error "ONE_CODE_ONLY".
- R4. The receipt shows the discount as its own line: "Discount (CODE): -amount".

Out of scope: shipping rules.
EOF

git add -A
gcommit "Cart service with logger, coding standards and discount-code spec"

git checkout -q -b feature/discount-codes

wf src/discount.js <<'EOF'
import { totalCents } from "./cart.js";

var CODES = {
  SAVE10: { percent: 10, expires: "2026-12-31" },
  OLD5: { percent: 5, expires: "2020-01-01" },
};

export function applyCode(cart, code, today) {
  var entry = CODES[code];
  if (!entry) throw new Error("UNKNOWN_CODE");
  if (today >= entry.expires) throw new Error("CODE_EXPIRED");
  cart.code = code;
  console.log("applied " + code);
  return cart;
}

export function discountedTotal(cart) {
  var total = totalCents(cart);
  if (!cart.code) return total;
  var pct = CODES[cart.code].percent;
  return total - total * (pct / 100);
}
EOF
git add -A
gcommit "Add discount codes (spec: docs/specs/discount-codes.md)"

wf src/shipping.js <<'EOF'
export function shippingCents(cart, totalCents) {
  if (totalCents > 5000) return 0;
  return 499;
}
EOF
git add -A
gcommit "Add free shipping over 50"

git checkout -q main
git checkout -q feature/discount-codes

###########################################################################
# 2. review-fixture-shallow: a shallow, one-branch clone of review-fixture
###########################################################################
cd "$TARGET"
git clone -q --depth 1 --branch feature/discount-codes \
  "file://$TARGET/review-fixture" review-fixture-shallow

###########################################################################
# 3. arch-fixture: for improve-codebase-architecture
###########################################################################
newrepo "$TARGET/arch-fixture"

wf README.md <<'EOF'
# Order intake (test fixture)

Small fixture for the improve-codebase-architecture skill. Not real code.
EOF

wf GLOSSARY.md <<'EOF'
# Order intake

## Language

**Order**:
A customer's request to buy one or more Line Items.
_Avoid_: purchase, basket

**Line Item**:
One product and its quantity inside an Order.
_Avoid_: row, entry

**Quote**:
The prices that the pricing service returns for the Line Items of an Order.
_Avoid_: price list
EOF

wf docs/adr/0001-pricing-stays-remote.md <<'EOF'
# Pricing stays a remote service

The finance team owns the pricing rules, and the rules change every week. So Order intake asks the remote pricing service for a Quote for every Order, and never computes prices locally.
EOF

wf src/order/OrderHandler.js <<'EOF'
import { validateOrder } from "./OrderValidator.js";
import { toRecord } from "./OrderMapper.js";
import { saveOrder } from "./OrderRepo.js";
import { quote } from "../pricing/PricingClient.js";

export async function handleOrder(input) {
  validateOrder(input);
  const priced = await quote(input.lines);
  const record = toRecord(input, priced);
  return saveOrder(record);
}
EOF

wf src/order/OrderValidator.js <<'EOF'
export function validateOrder(input) {
  if (!input.customerId) throw new Error("customerId required");
}
EOF

wf src/order/OrderMapper.js <<'EOF'
export function toRecord(input, priced) {
  return { customerId: input.customerId, lines: priced.lines };
}
EOF

wf src/order/OrderRepo.js <<'EOF'
const db = new Map();

export function saveOrder(record) {
  const id = String(db.size + 1);
  db.set(id, record);
  return { id, ...record };
}

export function getOrder(id) {
  return db.get(id);
}
EOF

wf src/pricing/PricingClient.js <<'EOF'
// Remote pricing service call. Stubbed for the fixture.
export async function quote(lines) {
  return { lines: lines.map((l) => ({ ...l, unitCents: 1000 })) };
}
EOF

git add -A
gcommit "Initial Order intake"

wf src/order/OrderValidator.js <<'EOF'
export function validateOrder(input) {
  if (!input.customerId) throw new Error("customerId required");
  if (!Array.isArray(input.lines) || input.lines.length === 0) {
    throw new Error("lines required");
  }
}
EOF
git add -A
gcommit "Reject Orders with no Line Items"

wf src/utils/priceUtils.js <<'EOF'
export function sumLines(lines) {
  return lines.reduce((s, l) => s + l.unitCents * l.qty, 0);
}
EOF
wf src/order/OrderMapper.js <<'EOF'
import { sumLines } from "../utils/priceUtils.js";

export function toRecord(input, priced) {
  return {
    customerId: input.customerId,
    lines: priced.lines,
    totalCents: sumLines(priced.lines),
  };
}
EOF
git add -A
gcommit "Put the Order total on the record"

wf src/services/orderService.js <<'EOF'
import { handleOrder } from "../order/OrderHandler.js";

export function placeOrder(input) {
  return handleOrder(input);
}
EOF
git add -A
gcommit "Add orderService wrapper"

wf src/utils/priceUtils.js <<'EOF'
export function sumLines(lines) {
  return lines.reduce((s, l) => s + Math.round(l.unitCents) * l.qty, 0);
}

export function lineTotal(line) {
  return Math.round(line.unitCents) * line.qty;
}
EOF
git add -A
gcommit "Fix total rounding"

wf src/users/userStore.js <<'EOF'
const users = new Map();

export function addUser(id, name) {
  users.set(id, { id, name });
}

export function getUser(id) {
  return users.get(id);
}
EOF
git add -A
gcommit "Add user store"

wf src/order/OrderHandler.js <<'EOF'
import { validateOrder } from "./OrderValidator.js";
import { toRecord } from "./OrderMapper.js";
import { saveOrder } from "./OrderRepo.js";
import { quote } from "../pricing/PricingClient.js";

export async function handleOrder(input) {
  validateOrder(input);
  let priced;
  try {
    priced = await quote(input.lines);
  } catch (e) {
    throw new Error("pricing unavailable");
  }
  const record = toRecord(input, priced);
  return saveOrder(record);
}
EOF
wf src/pricing/PricingClient.js <<'EOF'
// Remote pricing service call. Stubbed for the fixture.
export async function quote(lines, timeoutMs = 2000) {
  return { lines: lines.map((l) => ({ ...l, unitCents: 1000 })) };
}
EOF
git add -A
gcommit "Handle pricing timeout"

wf test/order.test.js <<'EOF'
// Each module is tested alone, with every neighbour mocked.
// No test calls handleOrder or placeOrder end to end.
import { validateOrder } from "../src/order/OrderValidator.js";
import { toRecord } from "../src/order/OrderMapper.js";

export function testValidatorRejectsMissingCustomer() {
  let threw = false;
  try { validateOrder({ lines: [{ sku: "A", qty: 1 }] }); } catch (e) { threw = true; }
  if (!threw) throw new Error("expected a throw");
}

export function testMapperCopiesCustomer() {
  const fakePriced = { lines: [] };
  const r = toRecord({ customerId: "c1" }, fakePriced);
  if (r.customerId !== "c1") throw new Error("bad customer");
}
EOF
git add -A
gcommit "Add Order tests with mocks"

###########################################################################
# 4. grill-fixture: for grill-with-docs (no glossary yet)
###########################################################################
newrepo "$TARGET/grill-fixture"
wf PLAN.md <<'EOF'
# Plan: reading list

Users can save an article to read later. Saved articles show in a list.
Users can mark an article as read. Later, we may share lists with friends.
EOF
git add -A
gcommit "Add reading-list plan"

###########################################################################
# 5. legacy-glossary-fixture: old CONTEXT.md name, no GLOSSARY.md
###########################################################################
newrepo "$TARGET/legacy-glossary-fixture"
wf CONTEXT.md <<'EOF'
# Reading list

## Language

**Article**:
A web page that a user saves to read later.
_Avoid_: link, post

**Shelf**:
The ordered set of Articles that one user saved.
_Avoid_: list, queue
EOF
wf PLAN.md <<'EOF'
# Plan: sorting and archive

Let users sort their list by date, and archive old links after 30 days.
EOF
git add -A
gcommit "Add glossary (old CONTEXT.md name) and sorting plan"

###########################################################################
# 6. handoff-fixture: a folder that has its own handoff file
###########################################################################
mkdir -p "$TARGET/handoff-fixture"
cd "$TARGET/handoff-fixture"
wf MISSION.md <<'EOF'
# Mission (test fixture)

Learn how a cart service applies discount codes.
EOF
wf COURSE-HANDOFF.md <<'EOF'
# Handoff (test fixture)

Last session: read the discount-code spec. Next: review the feature branch.
EOF

###########################################################################
# 7. ZIPs for cloud surfaces (each includes its .git folder)
###########################################################################
mkdir -p "$TARGET/zips"
cd "$TARGET"
for f in review-fixture arch-fixture grill-fixture legacy-glossary-fixture; do
  zip -qr "zips/$f.zip" "$f"
done

###########################################################################
# Summary
###########################################################################
echo "Fixtures are ready in: $TARGET"
echo
echo "review-fixture           branch: $(git -C "$TARGET/review-fixture" branch --show-current), base: main"
echo "review-fixture-shallow   shallow: $(git -C "$TARGET/review-fixture-shallow" rev-parse --is-shallow-repository)"
echo "arch-fixture             commits: $(git -C "$TARGET/arch-fixture" rev-list --count HEAD)"
echo "grill-fixture            files: $(cd "$TARGET/grill-fixture" && ls | tr '\n' ' ')"
echo "legacy-glossary-fixture  files: $(cd "$TARGET/legacy-glossary-fixture" && ls | tr '\n' ' ')"
echo "handoff-fixture          files: $(cd "$TARGET/handoff-fixture" && ls | tr '\n' ' ')"
echo "zips (for cloud tests):  $(cd "$TARGET/zips" && ls | tr '\n' ' ')"
