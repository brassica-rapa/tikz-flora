// The garden's clock (src/lib/garden.js): growth by local hour, seasons
// by month and hemisphere, and the day and hour read in the visitor's own
// time zone, not the server's or UTC. Run with `node site/tests/garden.mjs`.
import assert from "node:assert/strict";
import { growAt, seasonAt, southern, gardenAt, DAWN, FULL, NIGHT } from "../src/lib/garden.js";

// A seedling overnight, opening from dawn, full by mid-afternoon, never
// shrinking through the day.
for (let h = 0; h < DAWN; h++) assert.equal(growAt(h), NIGHT, `hour ${h} is not night`);
assert.equal(growAt(DAWN), NIGHT);
assert.equal(growAt(FULL), 1);
assert.equal(growAt(23), 1);
assert.ok(NIGHT > 0, "night is bare: the page would show nothing");
for (let h = 1; h < 24; h++) assert.ok(growAt(h) >= growAt(h - 1), `growth shrinks at ${h}:00`);
assert.ok(growAt(8) > 0.1 && growAt(8) < 0.5, `8:00 grows ${growAt(8)}`);
for (const bad of [-1, 24, NaN, undefined]) assert.throws(() => growAt(bad), RangeError);

// Seasons turn on the meteorological months, and flip south of the equator.
assert.deepEqual([1, 3, 6, 9, 12].map((m) => seasonAt(m)), ["winter", "spring", "summer", "autumn", "winter"]);
assert.deepEqual([1, 3, 6, 9, 12].map((m) => seasonAt(m, true)), ["summer", "autumn", "winter", "spring", "summer"]);
for (const bad of [0, 13]) assert.throws(() => seasonAt(bad), RangeError);
for (const z of ["Australia/Sydney", "Pacific/Auckland", "America/Argentina/Buenos_Aires", "Africa/Johannesburg"]) assert.ok(southern(z), z);
for (const z of ["Europe/London", "America/New_York", "Asia/Tokyo", "Pacific/Honolulu", "Africa/Cairo", "America/Sao_Paulo_X"]) assert.ok(!southern(z), z);

// One instant, three zones: each reads its own day and hour. 2026-11-02
// 22:30 UTC is 17:30 that day in New York, 09:30 the next day in Sydney.
const t = new Date("2026-11-02T22:30:00Z");
const ny = gardenAt(t, "America/New_York");
assert.equal(ny.day, "2026-11-02");
assert.equal(ny.hour, 17);
assert.equal(ny.seed, 20261102);
assert.equal(ny.grow, 1);
assert.equal(ny.colourway, "autumn");
const syd = gardenAt(t, "Australia/Sydney");
assert.equal(syd.day, "2026-11-03");
assert.equal(syd.hour, 9);
assert.equal(syd.seed, 20261103);
assert.equal(syd.grow, growAt(9));
assert.equal(syd.colourway, "spring");
const utc = gardenAt(t, "UTC");
assert.equal(utc.hour, 22);
assert.equal(utc.seed, 20261102);

// The garden changes at local midnight, not UTC midnight, and the hour
// reads 0 (not 24) just after it.
const before = gardenAt(new Date("2026-11-03T04:59:00Z"), "America/New_York");
const after = gardenAt(new Date("2026-11-03T05:01:00Z"), "America/New_York");
assert.equal(before.seed, 20261102);
assert.equal(after.seed, 20261103);
assert.equal(after.hour, 0);
assert.equal(after.grow, NIGHT);

// Across a DST change the local hour still comes from the zone's rules:
// 2026-03-08 07:30 UTC is 03:30 EDT, just after New York springs forward.
assert.equal(gardenAt(new Date("2026-03-08T07:30:00Z"), "America/New_York").hour, 3);

console.log("garden clock: ok");
