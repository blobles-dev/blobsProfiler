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
| [Globals](https://github.com/blobles-dev/blobsProfiler/wiki/Media#profiling-module-wip) | :white_check_mark: | :white_check_mark: |
| [Lua execute](https://github.com/blobles-dev/blobsProfiler/wiki/Media#execute-lua-submodule) | :white_check_mark: | :white_check_mark: |
| [Hooks](https://github.com/blobles-dev/blobsProfiler/wiki/Media#hooks-module) | :white_check_mark: | :white_check_mark: |
| [ConCommands](https://github.com/blobles-dev/blobsProfiler/wiki/Media#concommands-module)  | :white_check_mark: | :white_check_mark: |
| Convar | :x: | :x: |
| [Files](https://github.com/blobles-dev/blobsProfiler/wiki/Media#files-module) | :white_check_mark: | :white_check_mark: |
| [Network (Receivers)](https://github.com/blobles-dev/blobsProfiler/wiki/Media#network-module) | :white_check_mark: | :white_check_mark: |
| [Timers](https://github.com/blobles-dev/blobsProfiler/wiki/Media#timers-module) | :white_check_mark: | :white_check_mark: |
| [Profiling](https://github.com/blobles-dev/blobsProfiler/wiki/Media#profiling-module-wip) | :x: | :x: |
| [SQLite Schema](https://github.com/blobles-dev/blobsProfiler/wiki/Media#schema-sqlite-submodule) | :white_check_mark: | :white_check_mark: |
| [SQLite Data](https://github.com/blobles-dev/blobsProfiler/wiki/Media#data-sqlite-submodule) | :white_check_mark: | :white_check_mark: |
| [SQLite Execute](https://github.com/blobles-dev/blobsProfiler/wiki/Media#execute-sqlite-submodule) | :white_check_mark: | :white_check_mark: |
| [Errors](https://github.com/blobles-dev/blobsProfiler/wiki/Media#errors-module) | :white_check_mark: | :white_check_mark: |
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
