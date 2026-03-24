import FoundationModels
import Foundation

// MARK: - Configuration

let version = "0.1.0"
let appName = "apfel"
let modelName = "apple-foundationmodel"

// MARK: - Exit Codes

let exitSuccess: Int32 = 0
let exitRuntimeError: Int32 = 1
let exitUsageError: Int32 = 2

// MARK: - Signal Handling

signal(SIGINT) { _ in
    if isatty(STDOUT_FILENO) != 0 {
        FileHandle.standardOutput.write(Data("\u{001B}[0m".utf8))
    }
    FileHandle.standardError.write(Data("\n".utf8))
    _exit(130)
}

// MARK: - Output Format

enum OutputFormat: String {
    case plain
    case json
}

// MARK: - Global State

let noColorEnv = ProcessInfo.processInfo.environment["NO_COLOR"] != nil
nonisolated(unsafe) var noColorFlag = false
nonisolated(unsafe) var outputFormat: OutputFormat = .plain
nonisolated(unsafe) var quietMode = false

// MARK: - ANSI Colors

enum Color: String {
    case reset   = "\u{001B}[0m"
    case bold    = "\u{001B}[1m"
    case dim     = "\u{001B}[2m"
    case cyan    = "\u{001B}[36m"
    case green   = "\u{001B}[32m"
    case yellow  = "\u{001B}[33m"
    case magenta = "\u{001B}[35m"
    case red     = "\u{001B}[31m"
}

func styled(_ text: String, _ colors: Color...) -> String {
    let isTerminal = isatty(STDOUT_FILENO) != 0
    guard isTerminal, !noColorEnv, !noColorFlag else { return text }
    let prefix = colors.map(\.rawValue).joined()
    return "\(prefix)\(text)\(Color.reset.rawValue)"
}

// MARK: - Output Helpers

let stderr = FileHandle.standardError

func printStderr(_ message: String) {
    stderr.write(Data("\(message)\n".utf8))
}

func printError(_ message: String) {
    stderr.write(Data("\(styled("error:", .red, .bold)) \(message)\n".utf8))
}

func printHeader() {
    guard !quietMode else { return }
    let header = styled("Apple Intelligence", .cyan, .bold) + styled(" · on-device LLM · \(appName) v\(version)", .dim)
    let line = styled(String(repeating: "─", count: 56), .dim)
    if outputFormat == .json {
        printStderr(header)
        printStderr(line)
    } else {
        print(header)
        print(line)
    }
}

// MARK: - JSON Encoding

struct ApfelResponse: Encodable {
    let model: String
    let content: String
    let metadata: Metadata

    struct Metadata: Encodable {
        let onDevice: Bool
        let version: String

        enum CodingKeys: String, CodingKey {
            case onDevice = "on_device"
            case version
        }
    }
}

struct ChatMessage: Encodable {
    let role: String
    let content: String
    let model: String?
}

func jsonString(_ value: some Encodable, pretty: Bool = true) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    if pretty { encoder.outputFormatting.insert(.prettyPrinted) }
    guard let data = try? encoder.encode(value),
          let str = String(data: data, encoding: .utf8) else {
        return "{}"
    }
    return str
}

// MARK: - Session Factory

func makeSession(systemPrompt: String?) -> LanguageModelSession {
    if let sys = systemPrompt {
        return LanguageModelSession(instructions: sys)
    }
    return LanguageModelSession()
}

// MARK: - Stream Helper

func collectStream(_ session: LanguageModelSession, prompt: String, printDelta: Bool) async throws -> String {
    let response = session.streamResponse(to: prompt)
    var prev = ""
    for try await snapshot in response {
        let content = snapshot.content
        if content.count > prev.count {
            let idx = content.index(content.startIndex, offsetBy: prev.count)
            let delta = String(content[idx...])
            if printDelta {
                print(delta, terminator: "")
                fflush(stdout)
            }
        }
        prev = content
    }
    return prev
}

// MARK: - Commands

func singlePrompt(_ prompt: String, systemPrompt: String?, stream: Bool) async throws {
    let session = makeSession(systemPrompt: systemPrompt)

    switch outputFormat {
    case .plain:
        if stream {
            let _ = try await collectStream(session, prompt: prompt, printDelta: true)
            print()
        } else {
            let response = try await session.respond(to: prompt)
            print(response.content)
        }

    case .json:
        // Always buffer full response for valid JSON output
        let content: String
        if stream {
            content = try await collectStream(session, prompt: prompt, printDelta: false)
        } else {
            let response = try await session.respond(to: prompt)
            content = response.content
        }
        let obj = ApfelResponse(
            model: modelName,
            content: content,
            metadata: .init(onDevice: true, version: version)
        )
        print(jsonString(obj))
    }
}

func chat(systemPrompt: String?) async throws {
    // Chat requires a terminal
    guard isatty(STDIN_FILENO) != 0 else {
        printError("--chat requires an interactive terminal (stdin must be a TTY)")
        exit(exitUsageError)
    }

    let session = makeSession(systemPrompt: systemPrompt)
    var turn = 0

    printHeader()
    if !quietMode {
        if let sys = systemPrompt {
            let sysLine = styled("system: ", .magenta, .bold) + styled(sys, .dim)
            if outputFormat == .json {
                printStderr(sysLine)
            } else {
                print(sysLine)
            }
        }
        let hint = styled("Type 'quit' to exit.\n", .dim)
        if outputFormat == .json {
            printStderr(hint)
        } else {
            print(hint)
        }
    }

    while true {
        if !quietMode {
            let prompt = styled("you› ", .green, .bold)
            if outputFormat == .json {
                stderr.write(Data(prompt.utf8))
            } else {
                print(prompt, terminator: "")
            }
        }
        fflush(stdout)

        guard let input = readLine() else { break }
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { continue }
        if trimmed.lowercased() == "quit" || trimmed.lowercased() == "exit" { break }

        turn += 1

        if outputFormat == .json {
            // Emit user message as JSONL
            print(jsonString(ChatMessage(role: "user", content: trimmed, model: nil), pretty: false))
            fflush(stdout)
        }

        if !quietMode && outputFormat == .plain {
            print(styled(" ai› ", .cyan, .bold), terminator: "")
            fflush(stdout)
        }

        switch outputFormat {
        case .plain:
            let _ = try await collectStream(session, prompt: trimmed, printDelta: true)
            print("\n")

        case .json:
            let content = try await collectStream(session, prompt: trimmed, printDelta: false)
            print(jsonString(ChatMessage(role: "assistant", content: content, model: modelName), pretty: false))
            fflush(stdout)
        }
    }

    if !quietMode {
        let bye = styled("\nGoodbye.", .dim)
        if outputFormat == .json {
            printStderr(bye)
        } else {
            print(bye)
        }
    }
}

// MARK: - Usage

func printUsage() {
    print("""
    \(styled(appName, .cyan, .bold)) v\(version) — Apple Intelligence from the command line

    \(styled("USAGE:", .yellow, .bold))
      \(appName) [OPTIONS] <prompt>       Send a single prompt
      \(appName) --chat                   Interactive conversation
      \(appName) --stream <prompt>        Stream a single response

    \(styled("OPTIONS:", .yellow, .bold))
      -s, --system <text>     Set a system prompt
      -o, --output <format>   Output format: plain, json [default: plain]
      -q, --quiet             Suppress non-essential output
          --no-color           Disable colored output
      -h, --help              Show this help
      -v, --version           Print version

    \(styled("ENVIRONMENT:", .yellow, .bold))
      NO_COLOR                Disable colored output (https://no-color.org)

    \(styled("EXAMPLES:", .yellow, .bold))
      \(appName) "What is the capital of Austria?"
      \(appName) --stream "Write a haiku about code"
      \(appName) --system "You are a pirate" --chat
      \(appName) -s "Be concise" "Explain recursion"
      echo "Summarize this" | \(appName)
      \(appName) -o json "Translate to German: hello"
      \(appName) -o json "List 3 colors" | jq .content
    """)
}

// MARK: - Argument Parsing

var args = Array(CommandLine.arguments.dropFirst())

if args.isEmpty {
    // Check for stdin pipe
    if isatty(STDIN_FILENO) == 0 {
        var lines: [String] = []
        while let line = readLine(strippingNewline: false) {
            lines.append(line)
        }
        let input = lines.joined().trimmingCharacters(in: .whitespacesAndNewlines)
        if !input.isEmpty {
            do {
                try await singlePrompt(input, systemPrompt: nil, stream: true)
                exit(exitSuccess)
            } catch {
                printError(error.localizedDescription)
                exit(exitRuntimeError)
            }
        }
    }
    printUsage()
    exit(exitUsageError)
}

var systemPrompt: String? = nil
var mode: String = "single"
var prompt: String = ""

var i = 0
while i < args.count {
    switch args[i] {
    case "-h", "--help":
        printUsage()
        exit(exitSuccess)
    case "-v", "--version":
        print("\(appName) v\(version)")
        exit(exitSuccess)
    case "-s", "--system":
        i += 1
        guard i < args.count else {
            printError("--system requires a value")
            exit(exitUsageError)
        }
        systemPrompt = args[i]
    case "-o", "--output":
        i += 1
        guard i < args.count else {
            printError("--output requires a value (plain or json)")
            exit(exitUsageError)
        }
        guard let fmt = OutputFormat(rawValue: args[i]) else {
            printError("unknown output format: \(args[i]) (use plain or json)")
            exit(exitUsageError)
        }
        outputFormat = fmt
    case "-q", "--quiet":
        quietMode = true
    case "--no-color":
        noColorFlag = true
    case "--chat":
        mode = "chat"
    case "--stream":
        mode = "stream"
    default:
        if args[i].hasPrefix("-") {
            printError("unknown option: \(args[i])")
            exit(exitUsageError)
        }
        prompt = args[i...].joined(separator: " ")
        i = args.count
        continue
    }
    i += 1
}

// MARK: - Dispatch

do {
    switch mode {
    case "chat":
        try await chat(systemPrompt: systemPrompt)
    case "stream":
        guard !prompt.isEmpty else {
            printError("no prompt provided")
            exit(exitUsageError)
        }
        try await singlePrompt(prompt, systemPrompt: systemPrompt, stream: true)
    default:
        guard !prompt.isEmpty else {
            printError("no prompt provided")
            exit(exitUsageError)
        }
        try await singlePrompt(prompt, systemPrompt: systemPrompt, stream: false)
    }
} catch {
    printError(error.localizedDescription)
    exit(exitRuntimeError)
}
