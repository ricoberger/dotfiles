# LaunchAgents

- **stop:** `launchctl unload ~/Library/LaunchAgents/ai.opencode.serve.plist`
- **start:** `launchctl load ~/Library/LaunchAgents/ai.opencode.serve.plist`
- **status:** `launchctl list | grep ai.opencode.serve`

```bash
echo "\n- Install OpenCode Serve LaunchAgent"
mkdir -p ~/Library/LaunchAgents
cp $(pwd)/Library/LaunchAgents/ai.opencode.serve.plist ~/Library/LaunchAgents/ai.opencode.serve.plist
launchctl unload ~/Library/LaunchAgents/ai.opencode.serve.plist 2>/dev/null
launchctl load ~/Library/LaunchAgents/ai.opencode.serve.plist
```
