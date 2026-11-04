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
	JumpHeight = 6,
	LandFade = 0.6, -- how long landing keeps jump speed before it fades

	-- Cheat checks. SpeedLimit is the fastest slide jump plus a margin.
	SpeedLimit = 55,
	SpeedWindow = 0.5,
	LagStuds = 4,
	MaxLagSeconds = 1.5, -- most stall time one position jump can be credited
	MaxRiseSpeed = 60,
	MaxStrikes = 5,
}
