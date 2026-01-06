import Foundation

extension String {
    /// Strips HTML tags from a string and returns plain text
    func strippingHTMLTags() -> String {
        guard let data = self.data(using: .utf8) else { return self }

        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue,
        ]

        if let attributedString = try? NSAttributedString(
            data: data, options: options, documentAttributes: nil)
        {
            return attributedString.string
        }

        // Fallback: simple regex-based stripping
        return self.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }
}
