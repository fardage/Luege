import Foundation

/// A section grouping items by their first letter (A-Z or "#" for non-letter characters)
struct AlphabetSection<Item>: Identifiable {
    let letter: String
    let items: [Item]
    var id: String { letter }
}

/// Groups items into alphabetical sections based on a name key path.
///
/// - Parameters:
///   - items: The items to group
///   - nameKeyPath: Key path to the string property used for grouping
/// - Returns: Sections ordered A-Z then "#", with empty sections omitted
func alphabeticalSections<Item>(
    from items: [Item],
    nameKeyPath: KeyPath<Item, String>
) -> [AlphabetSection<Item>] {
    var grouped: [String: [Item]] = [:]

    for item in items {
        let name = item[keyPath: nameKeyPath]
        let firstChar = name.first.map { String($0).uppercased() } ?? "#"
        let letter = firstChar.first?.isLetter == true ? firstChar : "#"
        grouped[letter, default: []].append(item)
    }

    let letters = (UInt32(65)...UInt32(90)).compactMap { Unicode.Scalar($0).map { String($0) } }
    var sections: [AlphabetSection<Item>] = []

    for letter in letters {
        if let items = grouped[letter] {
            sections.append(AlphabetSection(letter: letter, items: items))
        }
    }

    if let numberItems = grouped["#"] {
        sections.append(AlphabetSection(letter: "#", items: numberItems))
    }

    return sections
}
