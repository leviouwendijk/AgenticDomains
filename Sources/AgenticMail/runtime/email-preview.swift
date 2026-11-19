import DSL
import Foundation
import Reporting

extension Email {
    /// The message as the owner approves it: headers as facts, the text it
    /// reads as underneath, in paragraphs.
    static func messageCard(
        from sender: String,
        input: Composition,
        subject: String,
        text: String,
        attachments: [String]
    ) throws -> ReportDocument {
        var facts: [ReportBlock.Facts.Fact] = [.init("from", sender)]
        for (label, addresses) in [("to", input.to), ("cc", input.cc), ("bcc", input.bcc)] {
            if let addresses, !addresses.isEmpty {
                facts.append(.init(label, addresses.joined(separator: ", ")))
            }
        }
        facts.append(.init("subject", subject))
        if !attachments.isEmpty {
            facts.append(.init("attachments", attachments.joined(separator: ", ")))
        }
        if input.html.flatMap(nonEmpty) != nil {
            facts.append(.init("format", "HTML, shown as text"))
        }

        let limit = 4000
        let shown = text.count > limit ? String(text.prefix(limit)) + " …" : text
        let paragraphs = shown
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { StructuredContent.paragraph([.text($0)]) }

        return try ReportDocument(
            title: subject,
            datasets: [],
            blocks: [.facts(.init(facts: facts))]
                + (paragraphs.isEmpty ? [] : [.narrative(.collection(paragraphs))])
        )
    }
}
