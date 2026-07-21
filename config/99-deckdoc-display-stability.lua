-- DeckDoc display-stability policy: keep Gamescope on one composed scanout plane.
-- This avoids the observed physical-LCD blackout boundary where captured frames
-- remain valid while multi-plane eDP scanout is black. It changes no power,
-- brightness, refresh, TDP, clock, charging, or firmware setting.
gamescope.convars.composite_force.value = true
