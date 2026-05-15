import Foundation

struct ParsedSkill: Equatable {
    var name: String
    var summary: String
    var tags: [String]
}

enum SkillParser {
    static func parse(markdown: String, fallbackName: String) -> ParsedSkill {
        let lines = markdown.components(separatedBy: .newlines)
        var frontmatter: [String: String] = [:]
        var bodyStartIndex = 0

        if lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) == "---" {
            for index in 1..<lines.count {
                let trimmed = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed == "---" {
                    bodyStartIndex = index + 1
                    break
                }

                let parts = lines[index].split(separator: ":", maxSplits: 1).map(String.init)
                if parts.count == 2 {
                    frontmatter[parts[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()] =
                        parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }

        let headingName = lines
            .dropFirst(bodyStartIndex)
            .first { $0.trimmingCharacters(in: .whitespaces).hasPrefix("# ") }?
            .replacingOccurrences(of: "# ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let name = nonEmpty(frontmatter["name"]) ?? nonEmpty(headingName) ?? fallbackName
        let summary = nonEmpty(frontmatter["description"])
            ?? firstBodyParagraph(lines: Array(lines.dropFirst(bodyStartIndex)))
            ?? "Local skill"
        let tags = parseTags(frontmatter["tags"])

        return ParsedSkill(name: name, summary: summary, tags: tags)
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func firstBodyParagraph(lines: [String]) -> String? {
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.hasPrefix("#") || trimmed == "---" {
                continue
            }
            return trimmed
        }
        return nil
    }

    private static func parseTags(_ raw: String?) -> [String] {
        guard let raw else { return [] }
        return raw
            .trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "\"'")) }
            .filter { !$0.isEmpty }
    }
}
