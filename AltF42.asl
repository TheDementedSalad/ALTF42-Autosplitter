// Made by Nikoehart & TheDementedSalad
// Big shoutouts to the Ero for assistance within the Items logic and splitting
// Shoutouts to Rumii & Hntd for their assistance within for all the efforts of finding some of the values needed 
state("ALTF42-Win64-Shipping") {}

startup
{
	vars.ItemSettingFormat = "[{0}] {1} ({2})";
	
	Assembly.Load(File.ReadAllBytes("Components/asl-help")).CreateInstance("Basic");
	vars.Helper.Settings.CreateFromXml("Components/ALTF42.Settings.xml");
	vars.Helper.GameName = "ALTF4 2 (2024)";
	//vars.Helper.StartFileLogger("AitD_Log.txt");
	
	vars.completedSplits = new HashSet<string>();
}

onStart
{
	vars.CompletedSplits.Clear();
	
	// This makes sure the timer always starts at 0.00
	timer.IsGameTimePaused = true;
}

init
{
	IntPtr gWorld = vars.Helper.ScanRel(3, "48 8B 05 ???????? 48 3B C? 48 0F 44 C? 48 89 05 ???????? E8");
	IntPtr gEngine = vars.Helper.ScanRel(3, "48 89 05 ???????? 48 85 c9 74 ?? e8 ???????? 48 8d 4d");
	
	vars.Helper["cantMove"] = vars.Helper.Make<bool>(gEngine, 0x1080, 0x38, 0x0, 0x30, 0x2E8, 0xB19);
	
	vars.Helper["Level"] = vars.Helper.MakeString(gEngine, 0xB98, 0xC);
	vars.Helper["Level"].FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull;
	
	vars.Helper["localPlayer"] = vars.Helper.Make<long>(gWorld, 0x1B8, 0x38, 0x0, 0x30);
	vars.Helper["localPlayer"].FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull;
}

update
{
	vars.Helper.Update();
	vars.Helper.MapPointers();
}

start
{
	return current.Level == "0-0_Level/Map_A_01_Persistent" && !current.cantMove && old.cantMove;
}

split
{
	string setting = "";
	
	if(current.Level != old.Level){
		setting = "Map_" + current.Level;
	}
	
	if (settings.ContainsKey(setting) && settings[setting] && vars.CompletedSplits.Add(setting)){
		return true;
	}
}

isLoading
{
	return current.Level == "0-0_Level/MainMenu";
}

reset
{
}

exit
{
	 //pauses timer if the game crashes
	timer.IsGameTimePaused = true;
}