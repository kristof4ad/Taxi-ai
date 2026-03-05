import Foundation

/// Fetches the current USD exchange rate for the user's local currency
/// and provides conversion and formatting utilities.
@MainActor
@Observable
final class CurrencyService {
    /// The user's local currency code derived from their device locale (e.g. "EUR", "GBP", "JPY").
    let localCurrencyCode: String

    /// The exchange rate from USD to the local currency, or `nil` if not yet loaded.
    private(set) var exchangeRate: Double?

    /// Whether the exchange rate is currently being fetched.
    private(set) var isLoading = false

    init() {
        localCurrencyCode = Locale.current.currency?.identifier ?? "USD"
    }

    /// Converts a USD amount to the user's local currency.
    /// Falls back to the original USD amount if no exchange rate is available.
    func convertFromUSD(_ usdAmount: Double) -> Double {
        guard let rate = exchangeRate else { return usdAmount }
        return usdAmount * rate
    }

    /// The currency code to display — local if we have a rate, otherwise USD.
    var displayCurrencyCode: String {
        exchangeRate != nil ? localCurrencyCode : "USD"
    }

    /// Fetches the latest exchange rate from USD to the local currency.
    /// Skips the fetch if the local currency is already USD.
    func fetchExchangeRate() async {
        guard localCurrencyCode != "USD" else {
            exchangeRate = 1.0
            return
        }

        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            guard let url = URL(string: "https://open.er-api.com/v6/latest/USD") else { return }
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(ExchangeRateResponse.self, from: data)

            if let rate = response.rates[localCurrencyCode] {
                exchangeRate = rate
            }
        } catch {
            // If the fetch fails, prices will display in USD as a fallback.
        }
    }
}

// MARK: - API Response

private struct ExchangeRateResponse: Decodable {
    let rates: [String: Double]
}
