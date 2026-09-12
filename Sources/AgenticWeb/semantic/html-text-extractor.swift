import Foundation

public struct HTMLTextExtractor: Sendable {
    public init() {}

    public func extract(
        from data: Data
    ) throws -> HTMLTextDocument {
        let html = try decodedHTML(
            from: data
        )
        let title = extractedTitle(
            from: html
        )
        let body = extractedBody(
            from: html
        )

        var value = body
        value = replacing(
            pattern: #"(?is)<!--.*?-->"#,
            with: " ",
            in: value
        )
        value = replacing(
            pattern: #"(?is)<(script|style|noscript|svg|canvas|template)[^>]*>.*?</\1>"#,
            with: " ",
            in: value
        )
        value = replacing(
            pattern: #"(?i)<br\s*/?>"#,
            with: "\n",
            in: value
        )
        value = replacing(
            pattern: #"(?i)</(p|div|section|article|aside|main|header|footer|li|ul|ol|blockquote|pre|table|tr|td|th|h1|h2|h3|h4|h5|h6)>"#,
            with: "\n",
            in: value
        )
        value = replacing(
            pattern: #"(?is)<[^>]+>"#,
            with: " ",
            in: value
        )
        value = decodeEntities(
            in: value
        )
        value = normalizeWhitespace(
            in: value
        )

        return .init(
            title: title,
            text: value
        )
    }
}

private extension HTMLTextExtractor {
    func decodedHTML(
        from data: Data
    ) throws -> String {
        if let value = String(
            data: data,
            encoding: .utf8
        ) {
            return value
        }

        if let value = String(
            data: data,
            encoding: .isoLatin1
        ) {
            return value
        }

        if let value = String(
            data: data,
            encoding: .windowsCP1252
        ) {
            return value
        }

        throw WebToolError.failedTextDecoding
    }

    func extractedTitle(
        from html: String
    ) -> String? {
        guard let captured = firstCapture(
            pattern: #"(?is)<title[^>]*>(.*?)</title>"#,
            in: html
        ) else {
            return nil
        }

        let decoded = decodeEntities(
            in: captured
        ).trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        return decoded.isEmpty ? nil : decoded
    }

    func extractedBody(
        from html: String
    ) -> String {
        firstCapture(
            pattern: #"(?is)<body[^>]*>(.*?)</body>"#,
            in: html
        ) ?? html
    }

    func firstCapture(
        pattern: String,
        in value: String
    ) -> String? {
        guard let regex = try? NSRegularExpression(
            pattern: pattern
        ) else {
            return nil
        }

        let range = NSRange(
            value.startIndex..<value.endIndex,
            in: value
        )

        guard let match = regex.firstMatch(
            in: value,
            range: range
        ),
        match.numberOfRanges > 1,
        let captureRange = Range(
            match.range(at: 1),
            in: value
        ) else {
            return nil
        }

        return String(value[captureRange])
    }

    func replacing(
        pattern: String,
        with replacement: String,
        in value: String
    ) -> String {
        value.replacingOccurrences(
            of: pattern,
            with: replacement,
            options: .regularExpression
        )
    }

    func decodeEntities(
        in value: String
    ) -> String {
        var result = value

        let replacements: [String: String] = [
            "&nbsp;": " ",
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&apos;": "'",
            "&#39;": "'"
        ]

        for (entity, replacement) in replacements {
            result = result.replacingOccurrences(
                of: entity,
                with: replacement
            )
        }

        result = decodeNumericEntities(
            pattern: #"&#([0-9]+);"#,
            radix: 10,
            in: result
        )
        result = decodeNumericEntities(
            pattern: #"&#x([0-9A-Fa-f]+);"#,
            radix: 16,
            in: result
        )

        return result
    }

    func decodeNumericEntities(
        pattern: String,
        radix: Int,
        in value: String
    ) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: pattern
        ) else {
            return value
        }

        var result = value
        let range = NSRange(
            result.startIndex..<result.endIndex,
            in: result
        )
        let matches = regex.matches(
            in: result,
            range: range
        )

        for match in matches.reversed() {
            guard match.numberOfRanges > 1,
                  let wholeRange = Range(
                      match.range(at: 0),
                      in: result
                  ),
                  let captureRange = Range(
                      match.range(at: 1),
                      in: result
                  ) else {
                continue
            }

            let scalarText = String(
                result[captureRange]
            )

            guard let value = Int(
                scalarText,
                radix: radix
            ),
            let unicodeScalar = UnicodeScalar(
                value
            ) else {
                continue
            }

            result.replaceSubrange(
                wholeRange,
                with: String(unicodeScalar)
            )
        }

        return result
    }

    func normalizeWhitespace(
        in value: String
    ) -> String {
        let normalizedLineEndings = value
            .replacingOccurrences(
                of: "\r\n",
                with: "\n"
            )
            .replacingOccurrences(
                of: "\r",
                with: "\n"
            )

        let lines = normalizedLineEndings
            .split(
                separator: "\n",
                omittingEmptySubsequences: false
            )
            .map { rawLine in
                rawLine.replacingOccurrences(
                    of: #"\s+"#,
                    with: " ",
                    options: .regularExpression
                ).trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            }
            .filter {
                !$0.isEmpty
            }

        return lines.joined(
            separator: "\n"
        )
    }
}
