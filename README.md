# blobsProfiler
A powerful task-manager style &amp; profiling addon for garrysmod

![Preview](https://i.imgur.com/FmsdAVB.png)

More screenshots can be found [here](https://github.com/blobles-dev/blobsProfiler/wiki/Media "here")

## Very early development (lacking a lot of features)
Found an issue/bug or have an idea/suggestion? Use the [Issues](https://github.com/blobles-dev/blobsProfiler/issues "Issues") tab
### Overview
This addon will be the one-stop shop for your development & test server needs.
Early development access, feel free to contribute.
I suck at repo management, so bare with me.
Open the menu with `blobsprofiler`

### :exclamation: WARNING :exclamation:
I would highly recommend against using this on a production/live server, especially in its current state.
For now, the all modules are currently locked away behind only a usergroup == superadmin check (CL for client side area of modules, and SV checks for server side area of modules)


### Features & To-Do
##### Modules
| Module | Client | Server  |
| ------------ | ------------ | ------------ |
| _G explorer | :white_check_mark: | :white_check_mark: |
| Lua execute | :white_check_mark: | :white_check_mark: |
| Hooks | :white_check_mark: | :white_check_mark: |
| ConCommands  | :white_check_mark: | :white_check_mark: |
| Convar | :x: | :x: |
| Files | :white_check_mark: | :white_check_mark: |
| Network (Receivers) | :white_check_mark: | :white_check_mark: |
| Timers | :white_check_mark: | :white_check_mark: |
| Profiling | :x: | :x: |
| SQLite Schema | :white_check_mark: | :white_check_mark: |
| SQLite Data | :white_check_mark: | :white_check_mark: |
| SQLite Execute | :white_check_mark: | :white_check_mark: |
| Remote SQL Schema | :x: | :x: |
| Remote SQL Data | :x: | :x: |
| Remote SQL Execute | :x: | :x: |

##### Other
- Settings
  - :x: Theme
  - :x: Module enable/disable
  - :x: Module usergroup permission
- Cleanup
  - :wavy_dash: Module-system (Code refactor)

### Known issues
- Other addons detouring timer.Create can cause issues with obtaining correct source

### Credits
- [Ace Editor](https://ace.c9.io/ "Ace Editor")
   - Ingame Lua (and soon SQL) editors
- [Yogpod](https://github.com/Yogpod "Yogpod")
  - Posted a DTree script which sparked the whole idea behind this journey
- [Meta Construct](https://github.com/Metastruct "Meta Construct")
  - GLua mode for Ace Editor
- [Phoenixf](https://github.com/phoen1xf/ "Phoenixf")
  - Being an awesome friend <3
