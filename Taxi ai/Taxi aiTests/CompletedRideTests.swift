import Foundation
import SwiftData
import Testing

@testable import Taxi_ai

@MainActor
struct CompletedRideTests {
    // MARK: - Initialization

    @Test func initializesWithRequiredProperties() {
        let ride = CompletedRide(
            date: Date(timeIntervalSince1970: 1_000_000),
            pickupName: "123 Main St",
            destinationName: "Airport",
            price: 25.50,
            currencyCode: "USD"
        )

        #expect(ride.pickupName == "123 Main St")
        #expect(ride.destinationName == "Airport")
        #expect(ride.price == 25.50)
        #expect(ride.currencyCode == "USD")
        #expect(ride.date == Date(timeIntervalSince1970: 1_000_000))
    }

    @Test func optionalFieldsDefaultToNil() {
        let ride = CompletedRide(
            date: .now,
            pickupName: "A",
            destinationName: "B",
            price: 10,
            currencyCode: "EUR"
        )

        #expect(ride.mapSnapshotData == nil)
        #expect(ride.starRating == nil)
        #expect(ride.feedbackText == nil)
        #expect(ride.tipPercentage == nil)
        #expect(ride.tipAmount == nil)
    }

    @Test func initializesWithAllProperties() {
        let snapshotData = Data([0x89, 0x50, 0x4E, 0x47]) // PNG header bytes
        let ride = CompletedRide(
            date: .now,
            pickupName: "Home",
            destinationName: "Office",
            price: 15.00,
            currencyCode: "GBP",
            mapSnapshotData: snapshotData,
            starRating: 5,
            feedbackText: "Great ride!",
            tipPercentage: 20,
            tipAmount: 3.00
        )

        #expect(ride.mapSnapshotData == snapshotData)
        #expect(ride.starRating == 5)
        #expect(ride.feedbackText == "Great ride!")
        #expect(ride.tipPercentage == 20)
        #expect(ride.tipAmount == 3.00)
    }

    @Test func eachInstanceGetsUniqueID() {
        let ride1 = CompletedRide(
            date: .now,
            pickupName: "A",
            destinationName: "B",
            price: 10,
            currencyCode: "USD"
        )
        let ride2 = CompletedRide(
            date: .now,
            pickupName: "A",
            destinationName: "B",
            price: 10,
            currencyCode: "USD"
        )

        #expect(ride1.id != ride2.id)
    }

    // MARK: - SwiftData Persistence

    @Test func persistsAndFetchesFromSwiftData() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: CompletedRide.self,
            configurations: config
        )
        let context = container.mainContext

        let ride = CompletedRide(
            date: Date(timeIntervalSince1970: 1_700_000_000),
            pickupName: "Central Station",
            destinationName: "Beach Hotel",
            price: 42.50,
            currencyCode: "PLN",
            starRating: 4,
            feedbackText: "Smooth ride"
        )
        context.insert(ride)
        try context.save()

        let descriptor = FetchDescriptor<CompletedRide>()
        let fetched = try context.fetch(descriptor)

        #expect(fetched.count == 1)
        #expect(fetched[0].pickupName == "Central Station")
        #expect(fetched[0].destinationName == "Beach Hotel")
        #expect(fetched[0].price == 42.50)
        #expect(fetched[0].currencyCode == "PLN")
        #expect(fetched[0].starRating == 4)
        #expect(fetched[0].feedbackText == "Smooth ride")
    }

    @Test func persistsMultipleRides() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: CompletedRide.self,
            configurations: config
        )
        let context = container.mainContext

        for i in 0..<5 {
            let ride = CompletedRide(
                date: Date(timeIntervalSince1970: Double(i) * 1000),
                pickupName: "Pickup \(i)",
                destinationName: "Dest \(i)",
                price: Double(i) * 10,
                currencyCode: "USD"
            )
            context.insert(ride)
        }
        try context.save()

        let descriptor = FetchDescriptor<CompletedRide>()
        let fetched = try context.fetch(descriptor)

        #expect(fetched.count == 5)
    }

    @Test func fetchesSortedByDateDescending() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: CompletedRide.self,
            configurations: config
        )
        let context = container.mainContext

        let dates = [
            Date(timeIntervalSince1970: 1000),
            Date(timeIntervalSince1970: 3000),
            Date(timeIntervalSince1970: 2000),
        ]
        for (i, date) in dates.enumerated() {
            let ride = CompletedRide(
                date: date,
                pickupName: "P\(i)",
                destinationName: "D\(i)",
                price: 10,
                currencyCode: "USD"
            )
            context.insert(ride)
        }
        try context.save()

        let descriptor = FetchDescriptor<CompletedRide>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let fetched = try context.fetch(descriptor)

        #expect(fetched[0].date == dates[1]) // 3000 first
        #expect(fetched[1].date == dates[2]) // 2000 second
        #expect(fetched[2].date == dates[0]) // 1000 last
    }

    @Test func deletesRideFromSwiftData() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: CompletedRide.self,
            configurations: config
        )
        let context = container.mainContext

        let ride = CompletedRide(
            date: .now,
            pickupName: "A",
            destinationName: "B",
            price: 10,
            currencyCode: "USD"
        )
        context.insert(ride)
        try context.save()

        context.delete(ride)
        try context.save()

        let descriptor = FetchDescriptor<CompletedRide>()
        let fetched = try context.fetch(descriptor)
        #expect(fetched.isEmpty)
    }
}
