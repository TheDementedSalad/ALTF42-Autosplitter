//ALTF2 Autosplitter V1.0 - 5th June 2024
//Supports Load Remover & Autosplits
//By TheDementedSalad & Rumii
//Special thanks to Rumii for doing the code injection to get the loading progress bar

state("ALTF42-Win64-Shipping"){}

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
	vars.completedSplits.Clear();

	// This makes sure the timer always starts at 0.00
	timer.IsGameTimePaused = true;
}

init
{
	IntPtr gWorld = vars.Helper.ScanRel(3, "48 8B 05 ???????? 48 3B C? 48 0F 44 C? 48 89 05 ???????? E8");
	IntPtr gEngine = vars.Helper.ScanRel(3, "48 89 05 ???????? 48 85 c9 74 ?? e8 ???????? 48 8d 4d");
	vars.FNames = vars.Helper.ScanRel(25, "66 0F 7F 44 24 20 E8 ???????? EB ?? 80 3D ???????? 00");

	vars.Helper["cantMove"] = vars.Helper.Make<bool>(gEngine, 0x1080, 0x38, 0x0, 0x30, 0x2E8, 0xB19);

	vars.Helper["Level"] = vars.Helper.MakeString(gEngine, 0xB98, 0x20);
	vars.Helper["Level"].FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull;

	vars.Helper["localPlayer"] = vars.Helper.Make<long>(gWorld, 0x1B8, 0x38, 0x0, 0x30);
	vars.Helper["localPlayer"].FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull;

	vars.GetObjectName = (Func<IntPtr, string>)((uObject) =>
	{
		ulong fName = memory.ReadValue<ulong>(uObject + 0x18);
		if (fName != 0)
		{
			var nameIdx = (fName & 0x000000000000FFFF) >> 0x00;
			var chunkIdx = (fName & 0x00000000FFFF0000) >> 0x10;
			var number = (fName & 0xFFFFFFFF00000000) >> 0x20;

			IntPtr chunk = memory.ReadValue<IntPtr>((IntPtr)vars.FNames + 0x10 + (int)chunkIdx * 0x8);
			IntPtr entry = chunk + (int)nameIdx * sizeof(short);

			int length = memory.ReadValue<short>(entry) >> 6;
			string name = memory.ReadString(entry + sizeof(short), length);

			return number == 0 ? name : name + "_" + number;
		}
		else return "";
	});

	vars.ProgressBarPtr = 0;
	ulong updateProgressBar = (ulong)vars.Helper.Scan(-0x1F, "C6 44 24 24 01 0F 11 44 24 30 48 8D 54 24 20 48 89 44 24");
	if (updateProgressBar != 0)
	{
		byte[] longJump = { 0xFF, 0x25, 0x00, 0x00, 0x00, 0x00 };
		byte[] goodBytes = { 0xF3, 0x0F, 0x11, 0x81, 0x10, 0x04, 0x00, 0x00, 0x48, 0x8B, 0x89, 0x58, 0x04, 0x00, 0x00 };
		byte[] foundBytes = memory.ReadBytes((IntPtr)updateProgressBar, goodBytes.Length);

		if (foundBytes.Length == goodBytes.Length)
		{
			if (goodBytes.SequenceEqual(foundBytes))
			{
				ulong allocated = (ulong)memory.AllocateMemory(0x1000);

				if (allocated != 0)
				{
					vars.ProgressBarPtr = allocated + 0x100;
					byte[] s1 = { 0xFF, 0x25, 0x00, 0x00, 0x00, 0x00 };
					byte[] s2 = BitConverter.GetBytes((ulong)allocated);
					byte[] s3 = { 0x90 };
					byte[] start = s1.Concat(s2).Concat(s3).ToArray();

					byte[] e1 = { 0x48, 0x89, 0x0D, 0xF9, 0x00, 0x00, 0x00, 0x90 };
					byte[] e2 = goodBytes;
					byte[] e3 = { 0xFF, 0x25, 0x00, 0x00, 0x00, 0x00 };
					byte[] e4 = BitConverter.GetBytes((ulong)updateProgressBar + (ulong)start.Length);
					byte[] end = e1.Concat(e2).Concat(e3).Concat(e4).ToArray();

					memory.WriteBytes((IntPtr)allocated, end);
					memory.WriteBytes((IntPtr)updateProgressBar, start);
				}
			}
			else
			{
				byte[] couldBeJump = new byte[longJump.Length];
				Array.Copy(foundBytes, couldBeJump, longJump.Length);

				if (couldBeJump.SequenceEqual(longJump))
				{
					vars.ProgressBarPtr = memory.ReadValue<ulong>((IntPtr)updateProgressBar + longJump.Length, 8) + 0x100;
				}
			}
		}
	}
}

update
{
	vars.Helper.Update();
	vars.Helper.MapPointers();

	//print("");
	//print("----------------------------------------------------------------------------------------------------------------");
	//print("Base: " + vars.GetObjectName((IntPtr)memory.ReadValue<ulong>((IntPtr)vars.ProgressBarPtr)));
	//print("Progress: " + memory.ReadValue<float>((IntPtr)memory.ReadValue<ulong>((IntPtr)(vars.ProgressBarPtr)) + 0x410).ToString());
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
	return vars.GetObjectName((IntPtr)memory.ReadValue<ulong>((IntPtr)vars.ProgressBarPtr)) == "LoadingProgressBar" || current.Level == "MainMenu";
	//return vars.GetObjectName((IntPtr)memory.ReadValue<ulong>((IntPtr)vars.ProgressBarPtr)) == "LoadingProgressBar" &&
		//memory.ReadValue<float>((IntPtr)memory.ReadValue<ulong>((IntPtr)(vars.ProgressBarPtr)) + 0x410) != 1;
}

reset
{
}

exit
{
	//pauses timer if the game crashes
	timer.IsGameTimePaused = true;
}
