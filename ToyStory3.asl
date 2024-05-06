state("Game-TS3") {}

startup
{
    settings.Add("story_mode", true, "Story Mode");
    
    settings.Add("level1", true, "Loco Motives", "story_mode");
    settings.Add("sub1", true, "1", "level1");
    settings.Add("sub2", true, "2", "level1");

    settings.Add("level2", true, "Hold the Phone", "story_mode");
    settings.Add("sub3", true, "1", "level2");
    settings.Add("sub4", true, "2", "level2");

    settings.Add("level3", true, "To Infinity and Beyond", "story_mode");
    settings.Add("sub5", true, "1", "level3");
    settings.Add("sub6", true, "2", "level3");
    settings.Add("sub7", true, "3", "level3");

    settings.Add("sub8", true, "Fair Play", "story_mode");

    settings.Add("level5", true, "Witch Way Out", "story_mode");
    settings.Add("sub9", true, "1", "level5");
    settings.Add("sub10", true, "2", "level5");

    settings.Add("sub11", true, "Hide and Sneak", "story_mode");

    settings.Add("sub12", true, "Trash Thrash", "story_mode");

    settings.Add("sub13", true, "Muffin to Fear", "story_mode");
}

init
{
    var module = modules.First(m => m.ModuleName == "Game-TS3.exe");
    var scanner = new SignatureScanner(game, module.BaseAddress, module.ModuleMemorySize);
    var retry = true;

    var levelFile_basePtr = scanner.Scan(new SigScanTarget(2, "8B 0D ?? ?? ?? ?? E8 ?? ?? ?? ?? 8B 4D E8 89 4D BC"));
    var load_basePtr = scanner.Scan(new SigScanTarget(6, "C7 05 ?? ?? ?? ?? ?? ?? ?? ?? 8B 45 08 50 8B 0D"));
    var save_basePtr = scanner.Scan(new SigScanTarget(1, "3D ?? ?? ?? ?? 00 75 09 8B 55 E4 89 15"));
    var levelSave_basePtr = scanner.Scan(new SigScanTarget(17, "89 4D FC 8B 55 FC 52 E8 ?? ?? ?? ?? 83 C4 04 C7 05"));
    var boss_basePtr = scanner.Scan(new SigScanTarget(3, "EB 47 A1 ?? ?? ?? ?? 89 45 90 8B 4D 90"));
    
    if (levelFile_basePtr != IntPtr.Zero && load_basePtr != IntPtr.Zero && save_basePtr != IntPtr.Zero && levelSave_basePtr != IntPtr.Zero && boss_basePtr != IntPtr.Zero) {
        print("All base addresses found.");
        retry = false;
    } else {
        print("Not all base addresses found. Retrying...");
        Thread.Sleep(500);
        throw new Exception();
    }
    
    vars.levelFile = new StringWatcher(new DeepPointer(levelFile_basePtr, 0x0, 0x138), 128);
    vars.load = new MemoryWatcher<int>(new DeepPointer(load_basePtr, 0x1C, 0x138, 0xFFB0));
    vars.gameReady = new MemoryWatcher<int>(new DeepPointer(load_basePtr, 0x1C, 0x138));
    vars.levelSave1 = new MemoryWatcher<float>(new DeepPointer(save_basePtr, 0x0, 0x154, 0xC1C, 0x15C, 0xE8, 0x39C));
    vars.levelSave2 = new MemoryWatcher<byte>(new DeepPointer(levelSave_basePtr, 0x1C, 0x3C));
    vars.exitSave = new MemoryWatcher<float>(new DeepPointer(save_basePtr, 0x0, 0x154, 0x3C, 0x2C, 0x14, 0x8, 0x138, 0x58, 0x40));
    vars.exitSaveToyBarn = new MemoryWatcher<float>(new DeepPointer(save_basePtr, 0x0, 0x154, 0x3C, 0x2C, 0x8, 0x18C, 0x2C, 0x8, 0x138, 0x58, 0x40));
    vars.bossHealth = new MemoryWatcher<float>(new DeepPointer(boss_basePtr, 0x0, 0xF4, 0x14, 0x8, 0x1C0));
    vars.bossPhase = new MemoryWatcher<int>(new DeepPointer(boss_basePtr, 0x0, 0xF4, 0x14, 0x8, 0x1D4));
    vars.watchers = new MemoryWatcherList() {vars.levelFile, vars.load, vars.gameReady,
                                             vars.levelSave1, vars.levelSave2,
                                             vars.exitSave, vars.exitSaveToyBarn,
                                             vars.bossHealth, vars.bossPhase};
    vars.preMenu = true;
}

update
{
    if (timer.CurrentSplitIndex == -1) {current.subLevel = 1; current.isLoading = false; current.isSaving = false; vars.endSplitReady = false;}

    if (vars.preMenu) {
        if (vars.gameReady.Current == 0) {
            print("Waiting until game ready...");
            vars.watchers.UpdateAll(game);
        } else {
            print("Game ready!");

            vars.preMenu = false;
            timer.IsGameTimePaused = false;
            current.isSaving = false;
            current.isLoading = false;
            vars.endSplitReady = false;
        }
    } else {
        vars.watchers.UpdateAll(game);

        if ((vars.exitSave.Current != 1 && vars.exitSave.Current > 0.9 && vars.exitSave.Current < 1.1) ||
            (vars.exitSaveToyBarn.Current != 1 && vars.exitSaveToyBarn.Current > 0.9 && vars.exitSaveToyBarn.Current < 1.1) ||
            (vars.levelSave1.Current > 0.01 && vars.levelSave1.Current < 0.9) ||
            (vars.levelSave1.Current == 1 && vars.levelSave2.Current == 1)) {current.isSaving = true;}

        if (vars.load.Old == 0 && vars.load.Current > 0) {current.isLoading = true; current.isSaving = false;}
        if (vars.load.Old > 0 && vars.load.Current == 0) {current.isLoading = false;}

        if (current.isSaving && !old.isSaving && vars.levelFile.Current != "particles/wtwii_town_wii.dbl") {current.subLevel++;}
        
        if (vars.levelFile.Current == "particles/st_hauntedbakery_wii.dbl" &&
            vars.bossPhase.Current == 4 &&
            vars.bossHealth.Current > 0.3 &&
            vars.bossHealth.Current < 0.7) {vars.endSplitReady = true;}
    }
}

start
{
    return vars.levelFile.Current == "particles/st_train_wii.dbl" && (vars.load.Old > 0 && vars.load.Current == 0);
}

split
{
    if (current.subLevel > old.subLevel && settings["sub" + old.subLevel]) {return true;}

    return vars.levelFile.Current == "particles/st_hauntedbakery_wii.dbl" &&
           vars.bossHealth.Old > 0.05 && vars.bossHealth.Old < 0.4 &&
           vars.bossHealth.Current > 0.8 && vars.bossHealth.Current < 1.3 &&
           vars.bossPhase.Current == 4 &&
           vars.endSplitReady;
}

isLoading
{
    return current.isLoading || current.isSaving || vars.preMenu;
}

exit
{
    timer.IsGameTimePaused = true;
}
