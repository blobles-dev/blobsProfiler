# blobsProfiler
A powerful task-manager style &amp; profiling addon for garrysmod

## Very early development (lacking a lot of features)
Found an issue/bug or have an idea/suggestion? Use the [Issues](https://github.com/blobles-dev/blobsProfiler/issues "Issues") tab
### Overview
This addon will be the one-stop shop for your development & test server needs.
Early development access, feel free to contribute.
I suck at repo management, so bare with me.

### :exclamation: WARNING :exclamation:
I would highly recommend against using this on a production/live server, especially in its current state.

For now, the `blobsprofiler` command is currently locked away behind only a **clientside** usergroup == superadmin check.

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

### Known issues
- Probably something, just nothing obvious

### Credits
- [Ace Editor](https://ace.c9.io/ "Ace Editor")
   - Ingame Lua (and soon SQL) editors
- [Yogpod](https://github.com/Yogpod "Yogpod")
  - Posted a DTree script which sparked the whole idea behind this journey
- [wyozi](https://github.com/wyozi/ "wyozi")
  - GLua mode for Ace Editor JS
- [Phoenixf](https://github.com/phoen1xf/ "Phoenixf")
  - Hosting the Ace Editor glua mode & being an awesome friend <3
