import Testing

@testable import Taxi_ai

@MainActor
struct PlaceCategoryTests {
    // MARK: - All Cases

    @Test func allCasesContainsFiveCategories() {
        #expect(PlaceCategory.allCases.count == 5)
    }

    @Test func allCasesArePresent() {
        let cases = PlaceCategory.allCases
        #expect(cases.contains(.bars))
        #expect(cases.contains(.food))
        #expect(cases.contains(.fast))
        #expect(cases.contains(.fun))
        #expect(cases.contains(.shopping))
    }

    // MARK: - Labels

    @Test func labelsAreHumanReadable() {
        #expect(PlaceCategory.bars.label == "Bars")
        #expect(PlaceCategory.food.label == "Food")
        #expect(PlaceCategory.fast.label == "Fast Food")
        #expect(PlaceCategory.fun.label == "Fun")
        #expect(PlaceCategory.shopping.label == "Shopping")
    }

    // MARK: - System Images

    @Test func systemImagesAreNotEmpty() {
        for category in PlaceCategory.allCases {
            #expect(!category.systemImage.isEmpty)
        }
    }

    @Test func systemImagesAreCorrect() {
        #expect(PlaceCategory.bars.systemImage == "wineglass")
        #expect(PlaceCategory.food.systemImage == "fork.knife")
        #expect(PlaceCategory.fast.systemImage == "list.bullet")
        #expect(PlaceCategory.fun.systemImage == "tv")
        #expect(PlaceCategory.shopping.systemImage == "bag")
    }

    // MARK: - Search Queries

    @Test func searchQueriesAreNotEmpty() {
        for category in PlaceCategory.allCases {
            #expect(!category.searchQuery.isEmpty)
        }
    }

    @Test func searchQueriesAreCorrect() {
        #expect(PlaceCategory.bars.searchQuery == "bar")
        #expect(PlaceCategory.food.searchQuery == "restaurant")
        #expect(PlaceCategory.fast.searchQuery == "fast food")
        #expect(PlaceCategory.fun.searchQuery == "entertainment")
        #expect(PlaceCategory.shopping.searchQuery == "shopping")
    }

    // MARK: - Identifiable

    @Test func idMatchesRawValue() {
        for category in PlaceCategory.allCases {
            #expect(category.id == category.rawValue)
        }
    }

    // MARK: - Raw Values

    @Test func rawValuesAreUnique() {
        let rawValues = PlaceCategory.allCases.map(\.rawValue)
        let uniqueValues = Set(rawValues)
        #expect(rawValues.count == uniqueValues.count)
    }
}
