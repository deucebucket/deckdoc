-- DeckDoc display-stability policy: keep Gamescope on one composed scanout plane.
-- This avoids the observed physical-LCD blackout boundary where captured frames
-- remain valid while multi-plane eDP scanout is black. It changes no power,
-- brightness, refresh, TDP, clock, charging, or firmware setting.
gamescope.convars.composite_force.value = true

-- Steam's per-application transition can restore direct scanout after this file
-- is loaded. Reassert only when another component clears the convar so the
-- physical-LCD regression guard survives launcher-to-game transitions without
-- changing any display timing or electrical control.
gamescope.hook("OnPostPaint", function()
    if not gamescope.convars.composite_force.value then
        gamescope.convars.composite_force.value = true
        warn("DeckDoc restored composite_force after an application transition.")
    end
end)
