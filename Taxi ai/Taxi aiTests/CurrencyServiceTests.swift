import Testing

@testable import Taxi_ai

@MainActor
struct CurrencyServiceTests {
    // MARK: - Initial State

    @Test func localCurrencyCodeIsNotEmpty() {
        let service = CurrencyService()
        #expect(!service.localCurrencyCode.isEmpty)
    }

    @Test func exchangeRateIsNilInitially() {
        let service = CurrencyService()
        #expect(service.exchangeRate == nil)
    }

    @Test func isLoadingIsFalseInitially() {
        let service = CurrencyService()
        #expect(service.isLoading == false)
    }

    // MARK: - convertFromUSD

    @Test func convertFromUSDReturnsOriginalWithoutRate() {
        let service = CurrencyService()
        // No exchange rate set, so should return the original USD amount.
        let result = service.convertFromUSD(10.0)
        #expect(result == 10.0)
    }

    @Test func convertFromUSDReturnsOriginalForZero() {
        let service = CurrencyService()
        let result = service.convertFromUSD(0)
        #expect(result == 0)
    }

    @Test func convertFromUSDReturnsOriginalForNegative() {
        let service = CurrencyService()
        let result = service.convertFromUSD(-5.0)
        #expect(result == -5.0)
    }

    // MARK: - displayCurrencyCode

    @Test func displayCurrencyCodeIsUSDWithoutRate() {
        let service = CurrencyService()
        // Without an exchange rate, should fall back to "USD".
        #expect(service.displayCurrencyCode == "USD")
    }

    // MARK: - Fallback Behavior

    @Test func conversionFallsBackGracefully() {
        let service = CurrencyService()
        // Multiple conversions without a rate should all return USD amounts.
        let amounts = [1.0, 5.5, 100.0, 0.01]
        for amount in amounts {
            #expect(service.convertFromUSD(amount) == amount)
        }
    }

    @Test func displayCurrencyCodeConsistentWithoutRate() {
        let service = CurrencyService()
        // Calling multiple times should be consistent.
        let code1 = service.displayCurrencyCode
        let code2 = service.displayCurrencyCode
        #expect(code1 == code2)
        #expect(code1 == "USD")
    }
}
