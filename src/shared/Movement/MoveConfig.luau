-- Movement tuning values. Speeds are studs per second, times are seconds.
return {
	WalkSpeed = 16,
	CrouchSpeed = 8,
	SprintSpeed = 24,
	SlideStartSpeed = 34,
	SlideDuration = 0.9,
	SlideCooldown = 0,
	CarryFade = 0.25,
	LandFade = 0.6, -- how long landing keeps jump speed before it fades

	-- Cheat checks. SpeedLimit is the slide start speed plus a margin.
	SpeedLimit = 39,
	SpeedWindow = 0.5,
	LagStuds = 4,
	MaxLagSeconds = 2, -- most stall time one position jump can be credited
	MaxRiseSpeed = 60,
	MaxStrikes = 5,
}
