-- Movement tuning values. Speeds are studs per second, times are seconds.
return {
	WalkSpeed = 15,
	CardSpeed = 1.15, -- ground speeds are multiplied by this while the cards are in hand
	CrouchSpeed = 6,
	SprintSpeed = 18.5, -- 30, then 27, 20 and 16.5 on 2026-11-10: River wants the game way less fast paced (and playable on phones)
	SlideStartSpeed = 31,
	SlideRampTime = 0.18, -- the boost builds from sprint speed over this long
	SlideFadeTime = 0.9, -- slows to sprint speed over this long; lasts while crouch is held
	SlideCooldown = 0,
	DashFadeTime = 3, -- how long a dash takes to ease down to normal speed (0.4, then 1, until River asked to keep the momentum "a long time")
	CarryFade = 0.25,
	-- How fast the air follows the move keys (a share closed per second, as an ease rate). On the ground the keys
	-- take hold at once. Without this the Humanoid eases in slowly at this gravity, which River called thick air.
	ResponseSlack = 1.5, -- studs a second the velocity may be off before the game sets it itself
	SlideBlip = 0.3, -- a slide that leaves the ground for less than this carries on where it was, with no new boost
	SlideJumpBoost = 3.5, -- added to current speed when a jump cancels a slide
	ChainJumpBoost = 6.5, -- the same, from a slide reached by a fast fall
	JumpHeight = 6,
	StrideStuds = 9, -- ground covered between footsteps
	MinAirTime = 0.1, -- the ground check can lag a jump by a frame or two
	LandFade = 0.6, -- how long landing keeps jump speed before it fades
	HardLandSpeed = 60, -- falling this fast plays the hard landing; a chain jump lands at about 49

	-- Heights are studs above the feet.
	ParryMinHeight = 1,
	ParryMinFlatness = 0.98, -- upward share of the surface normal
	ParryMaxHeight = 4.5,
	ParryClearance = 1.5,
	ParryBoost = 3.5,
	ParryMaxSpeed = 37.5, -- matches the fastest chain jump

	-- Wall jump: jump again in the air beside a wall to kick off it.
	WallJumpReach = 2.4, -- studs from the middle of the body to the wall
	WallJumpHeight = 6.5, -- 5 until River asked for more push (2026-11-11)
	WallJumpBoost = 5, -- added to the current speed (was 2), up to ParryMaxSpeed
	WallJumpGap = 0.25, -- seconds between wall jumps
	WallJumpMinAir = 0.12, -- seconds in the air before the first, so a jump beside a wall isn't spent on it
	WallJumps = math.huge, -- in one time in the air: no limit
	WallJumpsPerWall = 2, -- off any one wall in one time in the air
	WallJumpSame = 0.85, -- two walls facing this much the same way count as the same wall
	WallJumpSteep = 0.3, -- the most a wall can lean (the upward share of its normal)
	WallJumpLook = 0.6, -- how much of the kick goes where the player is looking, against straight off the wall

	-- Cheat checks. SpeedLimit is the fastest chain jump plus a margin.
	SpeedLimit = 48, -- 43 before the card bonus
	SpeedWindow = 0.5,
	LagStuds = 4,
	MaxLagSeconds = 1.3, -- most stall time one position jump can be credited
	MaxRiseSpeed = 60,
	MaxStrikes = 5,
}
