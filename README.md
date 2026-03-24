# apfel

**Apple Intelligence from the command line.**

A lightweight CLI for Apple's on-device [FoundationModels](https://developer.apple.com/documentation/foundationmodels) framework. No API keys. No cloud. No dependencies. Just your Mac thinking locally.

```
$ apfel "What is the capital of Austria?"
The capital of Austria is Vienna.
```

## Features

- **Three modes** — single prompt, streaming, and interactive chat
- **JSON output** — pipe results to `jq`, scripts, or other tools
- **Zero dependencies** — only Apple frameworks (`FoundationModels` + `Foundation`)
- **Tiny binary** — ~95KB release build
- **Unix-native** — proper exit codes, stdin piping, stderr discipline, `NO_COLOR` support
- **Private** — everything runs on-device, nothing leaves your Mac

## Requirements

- **macOS 26** (Tahoe) or later
- **Swift 6.2+** command line tools (ships with Xcode 26+)
- **Apple Intelligence** enabled in System Settings

## Install

### From source

```bash
git clone https://github.com/Arthur-Ficial/apfel.git
cd apfel
make install
```

This builds a release binary and installs it to `/usr/local/bin/apfel`.

### Manual

```bash
swift build -c release
sudo cp .build/release/apfel /usr/local/bin/
```

### Uninstall

```bash
make uninstall
```

## Usage

### Single prompt

```bash
apfel "What is the capital of Austria?"
```

### Streaming

```bash
apfel --stream "Write a haiku about code"
```

### Interactive chat

```bash
apfel --chat
```

```
Apple Intelligence · on-device LLM · apfel v0.1.0
────────────────────────────────────────────────────────
Type 'quit' to exit.

you› What's the meaning of life?
 ai› That's a profound question...
```

### System prompts

```bash
apfel --system "You are a pirate. Respond only in pirate speak." --chat
apfel -s "Be concise. One sentence max." "Explain recursion"
```

### Piping

```bash
echo "Summarize this in one sentence" | apfel
cat essay.txt | apfel -s "Summarize the following text"
```

## JSON Output

Use `-o json` for machine-readable output:

```bash
$ apfel -o json "What is 2+2?"
```

```json
{
  "content" : "2 + 2 equals 4.",
  "metadata" : {
    "on_device" : true,
    "version" : "0.1.0"
  },
  "model" : "apple-foundationmodel"
}
```

### Pipe to jq

```bash
apfel -o json "List 3 colors" | jq -r .content
```

### Chat JSON (JSONL)

In chat mode with `-o json`, each message is output as a single JSON line:

```bash
apfel -o json --chat
```

```jsonl
{"content":"What is 2+2?","role":"user"}
{"content":"4.","model":"apple-foundationmodel","role":"assistant"}
```

## Options

| Flag | Description |
|------|-------------|
| `-s, --system <text>` | Set a system prompt |
| `-o, --output <format>` | Output format: `plain`, `json` (default: `plain`) |
| `-q, --quiet` | Suppress non-essential output (headers, prompts) |
| `--no-color` | Disable colored output |
| `--stream` | Stream the response as it generates |
| `--chat` | Start interactive chat mode |
| `-h, --help` | Show help |
| `-v, --version` | Print version |

## Environment Variables

| Variable | Description |
|----------|-------------|
| `NO_COLOR` | Disable colored output ([no-color.org](https://no-color.org)) |

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Success |
| `1` | Runtime error (model unavailable, generation failed) |
| `2` | Usage error (bad arguments, missing prompt) |
| `130` | Interrupted (Ctrl+C) |

## How It Works

`apfel` uses Apple's [FoundationModels](https://developer.apple.com/documentation/foundationmodels) framework, introduced in macOS 26. This framework provides direct access to Apple's on-device language model — the same model that powers Apple Intelligence features like Writing Tools, Mail summaries, and Siri.

Everything runs locally on your Mac's Neural Engine. No data is sent to any server. No API key is needed. The model is bundled with macOS.

## Building

```bash
# Debug build
swift build

# Release build
swift build -c release

# Clean
swift package clean
```

## License

MIT — see [LICENSE](LICENSE).

---

Built by [Arthur Ficial](https://github.com/Arthur-Ficial) — an AI assistant created by [Franz Enzenhofer](https://www.fullstackoptimization.com).
