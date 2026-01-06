import Foundation

/// 記事検索サービス
struct SearchService {
    /// 検索範囲
    enum SearchScope: String, CaseIterable {
        case all = "All"
        case currentFeed = "Current Feed"
        case currentFolder = "Current Folder"
    }

    /// 記事がクエリにマッチするかチェック
    /// - Parameters:
    ///   - article: 検索対象の記事
    ///   - query: 検索クエリ
    /// - Returns: マッチする場合はtrue
    static func matches(article: Article, query: String) -> Bool {
        guard !query.isEmpty else { return true }

        let lowercasedQuery = query.lowercased()

        // タイトル検索
        if article.title.lowercased().contains(lowercasedQuery) {
            return true
        }

        // サマリー検索
        if let summary = article.summary,
            summary.lowercased().contains(lowercasedQuery)
        {
            return true
        }

        // 本文（HTML）検索
        if let contentHTML = article.contentHTML {
            // HTMLタグを除去してテキストのみで検索
            let plainText = stripHTMLTags(from: contentHTML)
            if plainText.lowercased().contains(lowercasedQuery) {
                return true
            }
        }

        // フィード名検索
        if let feedTitle = article.feed?.title,
            feedTitle.lowercased().contains(lowercasedQuery)
        {
            return true
        }

        // 著者名検索
        if let author = article.author,
            author.lowercased().contains(lowercasedQuery)
        {
            return true
        }

        return false
    }

    /// 検索結果からマッチした箇所のスニペットを取得
    /// - Parameters:
    ///   - article: 記事
    ///   - query: 検索クエリ
    /// - Returns: マッチした箇所を含むスニペット（オプショナル）
    static func findMatchSnippet(in article: Article, for query: String) -> String? {
        guard !query.isEmpty else { return nil }

        let lowercasedQuery = query.lowercased()

        // タイトルでマッチ
        if article.title.lowercased().contains(lowercasedQuery) {
            return article.title
        }

        // サマリーでマッチ
        if let summary = article.summary,
            summary.lowercased().contains(lowercasedQuery)
        {
            return extractSnippet(from: summary, around: query)
        }

        // 本文でマッチ
        if let contentHTML = article.contentHTML {
            let plainText = stripHTMLTags(from: contentHTML)
            if plainText.lowercased().contains(lowercasedQuery) {
                return extractSnippet(from: plainText, around: query)
            }
        }

        return nil
    }

    /// HTMLタグを除去してプレーンテキストを取得
    /// - Parameter html: HTML文字列
    /// - Returns: プレーンテキスト
    static func stripHTMLTags(from html: String) -> String {
        // 正規表現でHTMLタグを除去
        guard let regex = try? NSRegularExpression(pattern: "<[^>]+>", options: [])
        else {
            return html
        }
        let range = NSRange(html.startIndex..., in: html)
        let plainText = regex.stringByReplacingMatches(
            in: html, options: [], range: range, withTemplate: "")
        // 連続する空白を1つにまとめる
        return
            plainText
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// テキストから検索クエリ周辺のスニペットを抽出
    /// - Parameters:
    ///   - text: 元テキスト
    ///   - query: 検索クエリ
    ///   - contextLength: クエリ前後の文字数
    /// - Returns: スニペット文字列
    static func extractSnippet(from text: String, around query: String, contextLength: Int = 50)
        -> String
    {
        let lowercasedText = text.lowercased()
        let lowercasedQuery = query.lowercased()

        guard let range = lowercasedText.range(of: lowercasedQuery) else {
            return String(text.prefix(100))
        }

        // マッチ位置を計算
        let matchIndex = text.distance(from: text.startIndex, to: range.lowerBound)
        let startIndex = max(0, matchIndex - contextLength)
        let endIndex = min(text.count, matchIndex + query.count + contextLength)

        let startStringIndex = text.index(text.startIndex, offsetBy: startIndex)
        let endStringIndex = text.index(text.startIndex, offsetBy: endIndex)

        var snippet = String(text[startStringIndex..<endStringIndex])

        // 前後に省略記号を追加
        if startIndex > 0 {
            snippet = "..." + snippet
        }
        if endIndex < text.count {
            snippet = snippet + "..."
        }

        return snippet
    }

    /// テキスト内のクエリをハイライト用にマーキング
    /// - Parameters:
    ///   - text: 元テキスト
    ///   - query: 検索クエリ
    /// - Returns: マッチした範囲の配列
    static func findMatchRanges(in text: String, for query: String) -> [Range<String.Index>] {
        guard !query.isEmpty else { return [] }

        var ranges: [Range<String.Index>] = []
        let lowercasedText = text.lowercased()
        let lowercasedQuery = query.lowercased()

        var searchStartIndex = lowercasedText.startIndex
        while searchStartIndex < lowercasedText.endIndex {
            guard
                let range = lowercasedText.range(
                    of: lowercasedQuery, range: searchStartIndex..<lowercasedText.endIndex)
            else {
                break
            }
            // 元のテキストの範囲に変換
            ranges.append(range)
            searchStartIndex = range.upperBound
        }

        return ranges
    }
}
