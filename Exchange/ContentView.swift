//
//  ContentView.swift
//  Exchange
//
//  Created by Louis Chang on 2024/12/18.
//

import SwiftUI

struct Currency: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let code: String
    var rate: Double
    
    static func == (lhs: Currency, rhs: Currency) -> Bool {
        return lhs.code == rhs.code
    }
}

class CurrencyViewModel: ObservableObject {
    @Published var amount: String = ""
    @Published var fromCurrency = Currency(name: "新台幣", code: "TWD", rate: 1.0)
    @Published var toCurrency = Currency(name: "日圓", code: "JPY", rate: 4.3)
    @Published var availableCurrencies: [Currency] = []
    @Published var isLoading = false
    
    private var updateTimer: Timer?
    
    init() {
        loadAvailableCurrencies()
        fetchExchangeRates()
        setupUpdateTimer()
    }
    
    deinit {
        updateTimer?.invalidate()
    }
    
    private func setupUpdateTimer() {
        // 每小時更新一次匯率
        updateTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            self?.fetchExchangeRates()
        }
        updateTimer?.tolerance = 60 // 允許60秒的誤差，以優化系統性能
    }
    
    func loadAvailableCurrencies() {
        availableCurrencies = [
            Currency(name: "新台幣", code: "TWD", rate: 1.0),
            Currency(name: "美元", code: "USD", rate: 0.0),
            Currency(name: "日圓", code: "JPY", rate: 0.0),
            Currency(name: "歐元", code: "EUR", rate: 0.0),
            // 可以添加更多幣別
        ]
    }
    
    func fetchExchangeRates() {
        isLoading = true
        // 這裡使用您選擇的匯率 API，以下是示例 URL
        guard let url = URL(string: "https://api.exchangerate-api.com/v4/latest/TWD") else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                guard let data = data,
                      let response = try? JSONDecoder().decode(ExchangeRateResponse.self, from: data)
                else { return }
                
                self?.updateCurrencyRates(with: response.rates)
            }
        }.resume()
    }
    
    private func updateCurrencyRates(with rates: [String: Double]) {
        for index in availableCurrencies.indices {
            if let rate = rates[availableCurrencies[index].code] {
                availableCurrencies[index].rate = rate
            }
        }
    }
    
    var convertedAmount: Double {
        guard let inputAmount = Double(amount),
              let fromRate = availableCurrencies.first(where: { $0.code == fromCurrency.code })?.rate,
              let toRate = availableCurrencies.first(where: { $0.code == toCurrency.code })?.rate
        else { return 0.0 }
        
        return inputAmount * (toRate / fromRate)
    }
}

// 添加解碼匯率 API 響應的結構體
struct ExchangeRateResponse: Codable {
    let rates: [String: Double]
}

// 添加幣別選擇視圖
struct CurrencyPickerView: View {
    @ObservedObject var viewModel: CurrencyViewModel
    @Binding var isPresented: Bool
    let isFromCurrency: Bool
    
    var body: some View {
        NavigationView {
            List(viewModel.availableCurrencies) { currency in
                Button(action: {
                    if isFromCurrency {
                        viewModel.fromCurrency = currency
                    } else {
                        viewModel.toCurrency = currency
                    }
                    isPresented = false
                }) {
                    HStack {
                        Text(currency.name)
                        Spacer()
                        Text(currency.code)
                    }
                }
            }
            .navigationTitle(isFromCurrency ? "選擇起始幣別" : "選擇目標幣別")
            .navigationBarItems(trailing: Button("關閉") {
                isPresented = false
            })
        }
    }
}

// 添加一個顯示幣別和金額的元件
struct CurrencyRow: View {
    let currencyCode: String
    let currencyName: String
    let amount: String
    let isInput: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(currencyCode)
                    .font(.headline)
                    .foregroundColor(isInput ? .white : .gray)
                Text(currencyName)
                    .font(.subheadline)
                    .foregroundColor(isInput ? .white.opacity(0.7) : .gray.opacity(0.7))
            }
            Spacer()
            Text(amount)
                .font(.system(size: isInput ? 40 : 34))
                .foregroundColor(isInput ? .white : .gray)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .padding(.horizontal)
        .frame(height: 70)
    }
}

// 主視圖
struct CurrencyConverterView: View {
    @StateObject private var viewModel = CurrencyViewModel()
    @State private var showingFromCurrencyPicker = false
    @State private var showingToCurrencyPicker = false
    @State private var currentOperation: String? = nil
    @State private var previousAmount: Double? = nil
    
    private let buttonSpacing: CGFloat = 12
    private let operatorColor = Color.orange
    private let numberColor = Color(.darkGray)
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 12) {
                    // 顯示區域
                    VStack(alignment: .trailing, spacing: 12) {
                        Button(action: { showingFromCurrencyPicker = true }) {
                            CurrencyRow(
                                currencyCode: viewModel.fromCurrency.code,
                                currencyName: viewModel.fromCurrency.name,
                                amount: viewModel.amount.isEmpty ? "0" : viewModel.amount,
                                isInput: true
                            )
                        }
                        
                        Button(action: { showingToCurrencyPicker = true }) {
                            CurrencyRow(
                                currencyCode: viewModel.toCurrency.code,
                                currencyName: viewModel.toCurrency.name,
                                amount: String(format: "%.2f", viewModel.convertedAmount),
                                isInput: false
                            )
                        }
                        
                        Button(action: swapCurrencies) {
                            Image(systemName: "arrow.up.arrow.down.circle.fill")
                                .font(.title)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding()
                    
                    Spacer()
                    
                    // 修改數字鍵盤佈局
                    VStack(spacing: buttonSpacing) {
                        ForEach([
                            ["C", "±", "%", "÷"],
                            ["7", "8", "9", "×"],
                            ["4", "5", "6", "-"],
                            ["1", "2", "3", "+"],
                            ["C", "0", ".", "="]
                        ], id: \.self) { row in
                            HStack(spacing: buttonSpacing) {
                                ForEach(row, id: \.self) { key in
                                    if key == "0" {
                                        CalculatorButton(
                                            key: key,
                                            color: isOperator(key) ? operatorColor : numberColor,
                                            width: .double
                                        ) {
                                            handleKeyPress(key)
                                        }
                                    } else {
                                        CalculatorButton(
                                            key: key,
                                            color: isOperator(key) ? operatorColor : numberColor
                                        ) {
                                            handleKeyPress(key)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("匯率換算")
            .sheet(isPresented: $showingFromCurrencyPicker) {
                CurrencyPickerView(viewModel: viewModel, isPresented: $showingFromCurrencyPicker, isFromCurrency: true)
            }
            .sheet(isPresented: $showingToCurrencyPicker) {
                CurrencyPickerView(viewModel: viewModel, isPresented: $showingToCurrencyPicker, isFromCurrency: false)
            }
        }
    }
    
    private func isOperator(_ key: String) -> Bool {
        return "C±%÷×-+=".contains(key)
    }
    
    private func handleKeyPress(_ key: String) {
        switch key {
        case "C":
            viewModel.amount = ""
            currentOperation = nil
            previousAmount = nil
        case ".":
            if !viewModel.amount.contains(".") {
                viewModel.amount += key
            }
        case "0"..."9":
            viewModel.amount += key
        case "🖩":
            // 計算機圖示按鈕 - 不執行任何操作
            break
        case "±":
            if let amount = Double(viewModel.amount) {
                viewModel.amount = String(-amount)
            }
        case "%":
            if let amount = Double(viewModel.amount) {
                viewModel.amount = String(amount / 100)
            }
        case "÷", "×", "-", "+":
            if let amount = Double(viewModel.amount) {
                previousAmount = amount
                currentOperation = key
                viewModel.amount = ""
            }
        case "=":
            if let current = Double(viewModel.amount),
               let previous = previousAmount,
               let operation = currentOperation {
                let result: Double
                switch operation {
                case "÷": result = previous / current
                case "×": result = previous * current
                case "-": result = previous - current
                case "+": result = previous + current
                default: result = current
                }
                viewModel.amount = String(format: "%.2f", result)
                currentOperation = nil
                previousAmount = nil
            }
        default:
            break
        }
    }
    
    private func swapCurrencies() {
        let temp = viewModel.fromCurrency
        viewModel.fromCurrency = viewModel.toCurrency
        viewModel.toCurrency = temp
    }
}

// 更新 CalculatorButton 視圖
struct CalculatorButton: View {
    let key: String
    let color: Color
    var width: ButtonWidth = .single
    let action: () -> Void
    
    enum ButtonWidth {
        case single
        case double
    }
    
    var body: some View {
        Button(action: action) {
            Text(key)
                .font(.system(size: 32))
                .fontWeight(.medium)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(color)
                .clipShape(Capsule())
        }
        .frame(width: width == .double ? nil : nil)
        .opacity(key == "🖩" ? 0.5 : 1) // 只有計算機圖示按鈕是半透明的
    }
}

#Preview {
    CurrencyConverterView()
}
