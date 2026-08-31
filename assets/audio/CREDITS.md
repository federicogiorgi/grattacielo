# Audio credits

Every sound effect and every ambience bed in Grattacielo was cut from the
**Sonniss GDC Game Audio Bundle**, which the project owner holds. The bundle's
licence permits modification and commercial use in games and asks for no
attribution; this file exists anyway, because in a year nobody will remember
which recording a two-second lift chime came out of, and because a file whose
provenance is unknown cannot safely be shipped.

Regions are given as start-end in seconds within the source recording. Each
clip was downmixed, resampled to 44.1 kHz, level-matched on RMS against the
others in its group, and encoded to Ogg Vorbis. `tools/make_audio.py` does all
of that and can regenerate every file from the bundle; this list is written by
the same tool, so it cannot drift from what is on disk.

The music is not from the bundle -- the bundle is an effects library with no
music in it. The three loops in `music/` are synthesized by
`tools/make_music.py`; see its docstring for what they are and why.


## Sound effects

- `ding.ogg` -- two-note xylophone, used as the car's arrival chime.
  Source: `CB_Sounddesign - Applicable Sounds - Organic UI and Building Games SFX/UIMisc_Xylophone Ringtone 2_CB Sounddesign_APPlicable Sounds.wav`, 0.00-0.75s.

- `doors.ogg` -- a heavy door, used for the service lift.
  Source: `InMotionAudio - USA Hotel/DOORMetl_StairWellDoor01_InMotionAudio_USAHotel.wav`, 0.00-1.10s.

- `cash.ogg` -- coins, for income arriving.
  Source: `Cinematic Sound Design - UI Interaction Elements/Ting Coins.wav`, 0.00-1.10s.

- `spend.ogg` -- a single coin, for money going out.
  Source: `Cinematic Sound Design - Hybrid Game & UI Elements/Foley Coin Flip Single Fast.wav`, whole file.

- `build.ogg` -- a burst of a street jackhammer, for placing a facility.
  Source: `Epic Stock Media - Public Spaces - Urban Life Exteriors/AMBCnst_Baltimore Construction Streetside Heavy Machinery And Jakchammers 01_ESM_CPS.wav`, 12.00-12.85s.

- `wreck.ogg` -- falling debris, for demolition.
  Source: `Cinematic Sound Design - Colossal Impacts/Woosh Debris.wav`, 0.00-1.40s.

- `click.ogg` -- a vintage button, for picking a tool.
  Source: `Epic Stock Media - Board Game - Sound Set Kit for Tabletop and Digital Games/UIClick_UI Button Analog Vintage Double Click Neutral Dry Press 11_ESM_BG.wav`, 0.00-0.28s.

- `deny.ogg` -- for a build the tower refuses.
  Source: `Cinematic Sound Design - System & UI Feedback Elements/Interface Deny Low Fat Dark.wav`, 0.00-0.80s.

- `bad.ogg` -- something has gone wrong: cockroaches, an unhappy VIP.
  Source: `Cinematic Sound Design - UI Interaction Elements/Deny Muted.wav`, whole file.

- `fanfare.ogg` -- the tower gains a star.
  Source: `Cinematic Sound Design - Hybrid Game & UI Elements/Game Entry Happy Short.wav`, whole file.

- `alarm.ogg` -- fire, and the terrorist's threat.
  Source: `Federico Soler - Effective Trailer Alarms Vol. 2/EffectiveTrailer_Alarms_Vol2_QuarterNotes_013.wav`, 0.00-2.60s.

- `boom.ogg` -- the bomb going off.
  Source: `Federico Soler - Effective Trailer Booms Vol. 2/EffectiveTrailer_Booms_Vol2_011.wav`, 0.00-2.60s.

- `treasure.ogg` -- buried treasure, and the VIP arriving.
  Source: `CB_Sounddesign - Applicable Sounds - Organic UI and Building Games SFX/UIMisc_Kalimba 3 Up_CB Sounddesign_APPlicable Sounds.wav`, 0.00-2.00s.

- `church.ogg` -- the cathedral, and the wedding.
  Source: `Ivo Vicic - Church Bells/04 Church Bells, Near Distance, In Church Tower-3 Different Bell 02.wav`, 6.00-13.00s.

- `bells.ogg` -- Santa Claus, on the last night of the year.
  Source: `344 Audio - Christmas Vol. 1/MAGMisc_Magic Christmas Bells 2_344 Audio_Christmas.wav`, 0.00-4.00s.

- `sleigh.ogg` -- the sleigh crossing the sky.
  Source: `344 Audio - Christmas Vol. 1/MAGMisc_Sleigh Movement, Pulling_344 Audio_Christmas.wav`, 0.00-3.00s.

- `train.ogg` -- a train at the metro station.
  Source: `Epic Stock Media - Public Spaces - Basic Transportation Sounds/TRNElec_Electric Train Passby 02 Long Subway Slow_ESM_CPS.wav`, 4.00-9.00s.


## Ambience beds

- `amb_day.ogg` -- the city outside, daytime.
  Source: `Sonik Sound Library - Urban Life/AMBUrbn_Ambience, City, Madrid, Spain, Soft Traffic and Human Activity, Some Birds-Surround_KSL_KS016.wav`, 20.00-60.00s.

- `amb_night.ogg` -- the city outside, after dark.
  Source: `Epic Stock Media - Public Spaces - Urban Life Exteriors/AMBUrbn_City Nightlife Ext Street In Reutersplatz German Walla Traffic 01_ESM_CPS.wav`, 30.00-70.00s.

- `amb_lobby.ogg` -- a busy concourse: fades up with the tower's population.
  Source: `Epic Stock Media - Public Spaces - Crowds Walla and Everyday Ambiences/AMBPubl_Metro Station Entrance Hall Dings Walla Footsteps 01 Women Shopping_ESM_CPS.wav`, 8.00-44.00s.

- `amb_rain.ogg` -- rain against the glass.
  Source: `Jake Fielding - Interior Wind Rain and Storms/RAINInt_Heavy Rain on Window,  Constant _JF_INT Storm.wav`, 2.00-28.00s.

- `amb_fire.ogg` -- a fire burning somewhere in the tower.
  Source: `Epic Stock Media - Synthesized Nature Loops and Sounds/FIREBurn_Loop Elements Fire Crackling Crunchy Flame Burn 03_ESM_SNLS.wav`, 0.50-10.50s.

