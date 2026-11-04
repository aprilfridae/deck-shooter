-- Movement tuning values. Speeds are studs per second, times are seconds.
return {
	WalkSpeed = 16,
	CrouchSpeed = 8,
	SprintSpeed = 24,
	SlideStartSpeed = 42,
	SlideDuration = 0.9,
	SlideCooldown = 0,
	CarryFade = 0.25,
	SlideJumpBoost = 8, -- added to current speed when a jump cancels a slide
	ChainJumpBoost = 16, -- the same, from a slide reached by a fast fall
	JumpHeight = 6,
	ChainJumpHeight = 10,
	FastFallAcceleration = 350,
	FastFallMaxSpeed = 110,
	MinAirTime = 0.1, -- the ground check can lag a jump by a frame or two
	LandFade = 0.6, -- how long landing keeps jump speed before it fades

	-- Cheat checks. SpeedLimit is the fastest chain jump plus a margin.
	SpeedLimit = 63,
	SpeedWindow = 0.5,
	LagStuds = 4,
	MaxLagSeconds = 1.3, -- most stall time one position jump can be credited
	MaxRiseSpeed = 60,
	MaxStrikes = 5,
}
