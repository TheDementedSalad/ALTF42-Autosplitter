//ALTF2 Autosplitter V1.0 - 5th June 2024
//Supports Load Remover & Autosplits
//By TheDementedSalad & Rumii
//Special thanks to Rumii for doing the code injection to get the loading progress bar

state("ALTF42-Win64-Shipping"){ }

startup
{
	vars.ItemSettingFormat = "[{0}] {1} ({2})";

	Assembly.Load(File.ReadAllBytes("Components/asl-help")).CreateInstance("Basic");
	Assembly.Load(File.ReadAllBytes("Components/uhara8")).CreateInstance("Main");
	vars.Helper.Settings.CreateFromXml("Components/ALTF42.Settings.xml");
	vars.Helper.GameName = "ALTF4 2 (2024)";
	vars.Uhara.EnableDebug();
	//vars.Helper.StartFileLogger("ALTF42_LOG.txt");

	vars.completedSplits = new HashSet<string>();
	vars.LoadingStatus = 0;
	vars.NowLoading = false;
}

onStart
{
	vars.completedSplits.Clear();
	timer.IsGameTimePaused = true;
	vars.NowLoading = false;
	vars.LoadingStatus = 0;
}

init
{
	// default
	IntPtr GEngine = vars.Helper.ScanRel(3, "48 89 05 ???????? 48 85 C9 74 ?? E8 ???????? 48 8D 4D");
	vars.Helper["cantMove"] = vars.Helper.Make<bool>(GEngine, 0x1080, 0x38, 0x0, 0x30, 0x2E8, 0xB1F);
	vars.Helper["Level"] = vars.Helper.MakeString(GEngine, 0xB98, 0x20);
	vars.Helper["Level"].FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull;
	
	// uhara
	var Events = vars.Uhara.CreateTool("UnrealEngine", "Events");
	vars.Helper["StartLoading"] = vars.Helper.Make<ulong>(Events.FunctionFlag("", "WBP_LoadingScreenMenu_Silence_C", "OnInitialized"));
	vars.Helper["LoadingAdvance"] = vars.Helper.Make<ulong>(Events.InstanceFlag("MovieSceneEvalTimeSystem", "MovieSceneEvalTimeSystem"));
	vars.Helper["EndLoading"] = vars.Helper.Make<uint>(Events.InstancePtr("MovieSceneEvalTimeSystem", "MovieSceneEvalTimeSystem"), 0x40);
	vars.Helper["EndLoading"].FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull;
	vars.Helper["ProgressBar"] = vars.Helper.Make<float>(Events.InstancePtr("ProgressBar", "LoadingProgressBar"), 0x410);
}

update
{
	vars.Helper.Update();
	vars.Helper.MapPointers();
	
	if (vars.LoadingStatus > 0)
	{
		//print(vars.LoadingStatus.ToString() + ". " + current.EndLoading.ToString() + " | " + old.EndLoading.ToString());
	}
	
	// ---------------------------
	
	if (current.StartLoading != old.StartLoading && current.StartLoading != 0)
	{
		vars.NowLoading = true;
		vars.LoadingStatus = 0;
	}
	
	if (current.ProgressBar == 1f && old.ProgressBar < 1f)
	{
		vars.LoadingStatus = 1;
	}

	if (vars.LoadingStatus == 1 && current.LoadingAdvance != old.LoadingAdvance && current.LoadingAdvance != 0)
	{
		vars.LoadingStatus = 2;
	}
	
	if (vars.LoadingStatus == 2 && old.EndLoading > 0 && current.EndLoading > old.EndLoading)
	{
		//vars.Log("DISABLED");
		vars.LoadingStatus = 0;
		vars.NowLoading = false;
	}
}

start
{
	return (current.Level == "Map_A_01_Persistent" || current.Level == "Map_A_03_Persistent") && !current.cantMove && old.cantMove;
}

split
{
	string setting = "";

	if (current.Level != old.Level)
	{
		setting = current.Level;
	}

	if (settings.ContainsKey(setting) && settings[setting] && vars.completedSplits.Add(setting))
	{
		return true;
	}
}

isLoading
{
	return vars.NowLoading || current.Level == "MainMenu";
}

exit
{
	//pauses timer if the game crashes
	timer.IsGameTimePaused = true;
}
