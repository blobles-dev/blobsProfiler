# blobsProfiler
A powerful task-manager style &amp; profiling addon for garrysmod

## Very early development (lacking a lot of features)

### Overview
This addon will be the one-stop shop for your development & test server needs.
Early development access, feel free to contribute.
I suck at repo management, so bare with me.

### :exclamation: WARNING :exclamation:
I would highly recommend against using this on a production/live server, especially in its current state.

### Features & To-Do
##### Modules
| Module | Client | Server  |
| ------------ | ------------ | ------------ |
| _G explorer | :white_check_mark: | :x: |
| Lua execute | :white_check_mark: | :x: |
| Hooks | :white_check_mark: | :x: |
| ConCommands  | :white_check_mark: | :x: |
| Convar | :x: | :x: |
| Files | :white_check_mark: | :x: |
|  Network (Receivers)  | :white_check_mark: | :x: |
| Profiling | :x: | :x: |
| SQLite Schema | :white_check_mark: | :x: |
| SQLite Data | :white_check_mark: | :x: |
| SQLite Execute | :x: | :x: |
| Remote SQL Schema | :x: | :x: |
| Remote SQL Data | :x: | :x: |
| Remote SQL Execute | :x: | :x: |

##### Other
- Settings
  - :x: Theme
  - :x: Module enable/disable
  - :x: Module usergroup permission
- Cleanup
  - :x: Module-system (Code refactor)

### Installation
- Download the repository
- Extract the folder to garrysmod/addons on your server
- You should now have a `blobsProfiler-main` folder in your addons directory.
  - You can rename this folder to `!blobsprofiler` to ensure the addon before others
- Access the blobsProfiler menu with the console command `blobsprofiler`
  
### Known issues
- Function/File view source option fails for addon/custom gamemode paths

### Credits
- [Ace Editor](https://ace.c9.io/ "Ace Editor")
-- Ingame Lua (and soon SQL) editors
- [Yogpod](https://github.com/Yogpod "Yogpod")
-- Posted a DTree script which sparked the whole idea behind this journey
