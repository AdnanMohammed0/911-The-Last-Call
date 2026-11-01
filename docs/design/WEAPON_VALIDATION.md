# P3-01 weapon validation follow-up

The host now accepts only the two declared weapon slots for firing, reloading, dropping and ammo changes. Previously an unknown slot read the sidearm while using a separate rate-limit bucket, so a client could rotate forged slot numbers to bypass sidearm fire timing. Shot origins and directions must also have finite coordinates before ray casting.

Verified by 20 weapon and ballistics tests, including lag-compensated target rewind, and a real two-peer ENet test: a forged slot leaves host ammo unchanged; a valid client shot consumes one round. The earlier moving-target comparison in the progress log recorded 13/14 hits with rewind versus 4/14 without it. Live weapon feel and Steam transport remain separate release playtest items.
