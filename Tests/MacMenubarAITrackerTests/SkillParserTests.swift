import Testing
@testable import MacMenubarAITracker

struct SkillParserTests {
    @Test func parsesFrontmatter() {
        let parsed = SkillParser.parse(
            markdown: """
            ---
            name: Test Skill
            description: Handles local test fixtures.
            tags: [testing, local]
            ---
            # Ignored Heading
            Body.
            """,
            fallbackName: "fallback"
        )

        #expect(parsed.name == "Test Skill")
        #expect(parsed.summary == "Handles local test fixtures.")
        #expect(parsed.tags == ["testing", "local"])
    }

    @Test func fallsBackToHeadingAndParagraph() {
        let parsed = SkillParser.parse(
            markdown: """
            # Heading Name

            First useful paragraph.
            """,
            fallbackName: "fallback"
        )

        #expect(parsed.name == "Heading Name")
        #expect(parsed.summary == "First useful paragraph.")
    }
}
