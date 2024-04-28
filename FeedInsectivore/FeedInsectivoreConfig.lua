-- To add a new dino, just duplicate existing dino info (including { and }) and change the values
-- {
	-- Species = "Compsognathus", - species name, must be same as in dinos db
	-- HungerThreshold = 0.45, - hunger at which feed would start
	-- RemoveThreshold = 0.85, - hunger at which feed would stop
	-- FeedTimeDelayMin = 7, - min delay between feeding, in seconds
	-- FeedTimeDelayMax = 15, - max delay between feeding, in seconds
	-- FeedAmountMin = 0.02, - min feed amount, interval between 0.0 and 1.0
	-- FeedAmountMax = 0.1, - max feed amount, interval between 0.0 and 1.0
	-- FeedWaterContentFraction = 0.25, - water content fraction from feed amount, in this case 25% of feed amount would be water
	-- IgnoreTime = 60.0 - time duration the dino is ignored after feeding is finished, in seconds
-- }
bLogAll = false -- logs all info (for debug). needs ACSEDebug in ovldata to display debug info (activated with tab key)
bLogOnlyFavoriteDinos = true -- logs only dinos that are favorited (for debug). needs ACSEDebug, same as bLogAll
CheckForNewHungryDinosTime = 30.0 -- interval in seconds at which hungry dinos are discovered. 
								  -- Once discovered this value doesn't affect feeding time of those dinos.
								  -- The greater value the better, but hungry dinos won't be discovered as quckly. 
								  -- If below or at 0.0 will check every frame, which is wastefull. 30 sec seems ideal.
FeedDinosInfo = {
	{
		Species = "Compsognathus",
		HungerThreshold = 0.45,
		RemoveThreshold = 0.85,
		FeedTimeDelayMin = 7,
		FeedTimeDelayMax = 15,
		FeedAmountMin = 0.02,
		FeedAmountMax = 0.1,
		FeedWaterContentFraction = 0.25,
		IgnoreTime = 60.0
	},
	{
		Species = "Coelophysis",
		HungerThreshold = 0.35,
		RemoveThreshold = 0.85,
		FeedTimeDelayMin = 4,
		FeedTimeDelayMax = 12,
		FeedAmountMin = 0.01,
		FeedAmountMax = 0.075,
		FeedWaterContentFraction = 0.25,
		IgnoreTime = 60.0
	},
	{
		Species = "MorosIntrepidus",
		HungerThreshold = 0.35,
		RemoveThreshold = 0.85,
		FeedTimeDelayMin = 7,
		FeedTimeDelayMax = 15,
		FeedAmountMin = 0.01,
		FeedAmountMax = 0.07,
		FeedWaterContentFraction = 0.25,
		IgnoreTime = 60.0
	},
	{
		Species = "Sinosauropteryx",
		HungerThreshold = 0.45,
		RemoveThreshold = 0.85,
		FeedTimeDelayMin = 7,
		FeedTimeDelayMax = 15,
		FeedAmountMin = 0.015,
		FeedAmountMax = 0.1,
		FeedWaterContentFraction = 0.25,
		IgnoreTime = 60.0
	},
	{
		Species = "Troodon",
		HungerThreshold = 0.3,
		RemoveThreshold = 0.85,
		FeedTimeDelayMin = 7,
		FeedTimeDelayMax = 15,
		FeedAmountMin = 0.02,
		FeedAmountMax = 0.07,
		FeedWaterContentFraction = 0.25,
		IgnoreTime = 60.0
	},
	{
		Species = "Oviraptor",
		HungerThreshold = 0.3,
		RemoveThreshold = 0.85,
		FeedTimeDelayMin = 7,
		FeedTimeDelayMax = 15,
		FeedAmountMin = 0.005,
		FeedAmountMax = 0.05,
		FeedWaterContentFraction = 0.25,
		IgnoreTime = 60.0
	}
}
