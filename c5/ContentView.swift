import SwiftUI
import UIKit

struct ContentView: View {
    @State private var display: String = ""
    @State private var working: String = ""
    @State private var isToggled: Bool = false
    @State private var showSettings: Bool = false
    @State private var fractionResolution: Int = 64
    @State private var history: [(display: String, working: String)] = []
    
    let buttons: [CalculatorButton] = [
        // Row 1
        .init(label: "feet", color: .gray), .init(label: "inch", color: .gray), .init(label: "/", color: .gray), .init(label: "setting", color: .green),
        // Row 2
        .init(label: "7", color: .gray), .init(label: "8", color: .gray), .init(label: "9", color: .gray), .init(label: "÷", color: .orange),
        // Row 3
        .init(label: "4", color: .gray), .init(label: "5", color: .gray), .init(label: "6", color: .gray), .init(label: "x", color: .orange),
        // Row 4
        .init(label: "1", color: .gray), .init(label: "2", color: .gray), .init(label: "3", color: .gray), .init(label: "-", color: .orange),
        // Row 5
        .init(label: "0", color: .gray), .init(label: ".", color: .gray), .init(label: "=", color: .orange), .init(label: "+", color: .orange),
        // Row 6
        .init(label: "run", color: .orange), .init(label: "rise", color: .orange), .init(label: "diag", color: .orange), .init(label: "rad", color: .orange),
        // Row 7 (updated)
        .init(label: "save", color: .green), .init(label: "cutist", color: .green), .init(label: "undo", color: .red), .init(label: "clear", color: .red)
    ]
    
    // Helper to parse a measurement string into inches (Double)
    // Supports feet (′), inches (″), fractions (e.g. 1/2), decimal inches, and plain numbers
    private func parseMeasurement(_ str: String) -> Double? {
        // Remove spaces
        let trimmed = str.replacingOccurrences(of: " ", with: "")
        
        var feet: Double = 0
        var inches: Double = 0
        
        var working = trimmed
        
        if let footRange = working.range(of: "′") {
            let feetStr = String(working[..<footRange.lowerBound])
            if let f = Double(feetStr) {
                feet = f
            }
            working.removeSubrange(..<footRange.upperBound)
        }
        
        if let inchRange = working.range(of: "″") {
            let inchStr = String(working[..<inchRange.lowerBound])
            // Handle inches possibly with fraction like "3 1/2"
            if inchStr.contains("/") {
                let components = inchStr.split(separator: " ")
                var wholeInch: Double = 0
                var fracInch: Double = 0
                
                if components.count == 2 {
                    if let whole = Double(components[0]) {
                        wholeInch = whole
                    }
                    let fractionPart = String(components[1])
                    let fracParts = fractionPart.split(separator: "/")
                    if fracParts.count == 2,
                       let numerator = Double(fracParts[0]),
                       let denominator = Double(fracParts[1]),
                       denominator != 0 {
                        fracInch = numerator / denominator
                    }
                } else if components.count == 1 {
                    let fractionPart = String(components[0])
                    let fracParts = fractionPart.split(separator: "/")
                    if fracParts.count == 2,
                       let numerator = Double(fracParts[0]),
                       let denominator = Double(fracParts[1]),
                       denominator != 0 {
                        fracInch = numerator / denominator
                    }
                }
                inches = wholeInch + fracInch
            } else if let inchNum = Double(inchStr) {
                inches = inchNum
            }
            working.removeSubrange(..<inchRange.upperBound)
        } else {
            // No inch symbol, check if fraction or whole number in remaining string
            if working.contains("/") {
                let fracParts = working.split(separator: "/")
                if fracParts.count == 2,
                   let numerator = Double(fracParts[0]),
                   let denominator = Double(fracParts[1]),
                   denominator != 0 {
                    inches = numerator / denominator
                }
            } else if let val = Double(working), !working.isEmpty {
                inches = val
            }
        }
        
        return feet * 12 + inches
    }
    
    // Feet/inches/fraction formatting from inches (Double) to String like "3′ 5 1/2″"
    private func formatFeetInches(_ totalInches: Double) -> String {
        let feet = Int(totalInches / 12)
        var remainderInches = totalInches.truncatingRemainder(dividingBy: 12)
        
        // Round to nearest 1/16 inch
        let precision = 16
        var fractionNumerator = Int(round(remainderInches * Double(precision)))
        
        if fractionNumerator == 0 {
            // no fraction, just inches 0
            return feet > 0 ? "\(feet)′" : "0″"
        }
        
        if fractionNumerator == precision * 12 {
            // equals to 12 inches, so increment feet by 1
            return "\(feet + 1)′"
        }
        
        // Extract inches and fraction numerator
        var inchesPart = fractionNumerator / precision
        var numerator = fractionNumerator % precision
        
        // Simplify fraction
        func gcd(_ a: Int, _ b: Int) -> Int {
            var a = a
            var b = b
            while b != 0 {
                let temp = b
                b = a % b
                a = temp
            }
            return a
        }
        
        var fractionStr = ""
        if numerator != 0 {
            let divisor = gcd(numerator, precision)
            let reducedNumerator = numerator / divisor
            let reducedDenominator = precision / divisor
            fractionStr = "\(reducedNumerator)/\(reducedDenominator)"
        }
        
        var result = ""
        if feet > 0 {
            result += "\(feet)′"
        }
        
        if inchesPart > 0 || !fractionStr.isEmpty {
            if !result.isEmpty {
                result += " "
            }
            result += "\(inchesPart)"
        }
        
        if !fractionStr.isEmpty {
            result += " \(fractionStr)"
        }
        
        if inchesPart > 0 || !fractionStr.isEmpty {
            result += "″"
        }
        
        if result.isEmpty {
            result = "0″"
        }
        
        return result
    }
    
    // Computed property returning the mm conversion string or empty if invalid
    private var millimeterConversion: String {
        // If display is empty, return empty string (show blank)
        guard !display.isEmpty else {
            return ""
        }
        
        // Check if last calculation was a square footage calculation:
        if display.hasSuffix("ft²") {
            // Extract the numeric value before "ft²"
            let trimmed = display.replacingOccurrences(of: "ft²", with: "").trimmingCharacters(in: .whitespaces)
            if let squareFeet = Double(trimmed) {
                let squareMeters = squareFeet * 0.092903
                if squareMeters.truncatingRemainder(dividingBy: 1) == 0 {
                    return "\(Int(squareMeters)) m²"
                } else {
                    return String(format: "%.2f m²", squareMeters)
                }
            } else {
                return ""
            }
        }
        
        // Try to parse display as a measurement string
        // The display may contain an operator (e.g. "3′ + 4′"), in which case conversion is empty
        
        // We consider conversion only if the display is a single measurement, not an expression
        let operators = [" + ", " - ", " x ", " ÷ "]
        for op in operators {
            if display.contains(op) {
                return ""
            }
        }
        
        // Parse measurement
        guard let inches = parseMeasurement(display) else {
            return ""
        }
        
        // Convert inches to mm
        let mm = inches * 25.4
        
        // Format mm with no decimal if integer, else one decimal place
        if mm.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(mm)) mm"
        } else {
            return String(format: "%.1f mm", mm)
        }
    }
    
    // Computed property returning the sheets count string or empty if invalid/not square footage
    private var sheetsCountDisplay: String {
        if display.hasSuffix("ft²") {
            // Extract numeric area before "ft²"
            let trimmed = display.replacingOccurrences(of: "ft²", with: "").trimmingCharacters(in: .whitespaces)
            if let squareFeet = Double(trimmed), squareFeet > 0 {
                // Calculate sheets needed (8' x 4' = 32 sq ft)
                let sheets = Int(ceil(squareFeet / 32.0))
                return "8' x 4': \(sheets)"
            }
        }
        return ""
    }
    
    var body: some View {
        ZStack {
            Color(red: 23/255, green: 24/255, blue: 25/255).ignoresSafeArea()
            VStack(spacing: 24) {
                // Top Panel
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(red: 10/255, green: 10/255, blue: 10/255))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.07), lineWidth: 1)
                    )
                    .overlay(
                        VStack(spacing: 8) {
                            // Normal mode: existing layout with 4 rows
                            VStack(spacing: 0) {
                                HStack(spacing: 8) {
                                    Text(working)
                                        .foregroundColor(Color(red: 174/255, green: 255/255, blue: 201/255))
                                        .font(.system(size: 28, weight: .medium, design: .monospaced))
                                        .frame(maxWidth: .infinity, alignment: .center)
                                    Spacer(minLength: 0)
                                }
                                .frame(height: 48)
                                Rectangle()
                                    .fill(Color.gray.opacity(0.15))
                                    .frame(height: 1)
                                    .padding(.horizontal, 4)
                                HStack(spacing: 8) {
                                    Spacer()
                                    Text(display)
                                        .foregroundColor(Color(red: 174/255, green: 255/255, blue: 201/255))
                                        .font(.system(size: 28, weight: .medium, design: .monospaced))
                                    Spacer()
                                }
                                .frame(height: 48)
                                Rectangle()
                                    .fill(Color.gray.opacity(0.15))
                                    .frame(height: 1)
                                    .padding(.horizontal, 4)
                                HStack(spacing: 8) {
                                    Spacer()
                                    Text(millimeterConversion)
                                        .foregroundColor(Color(red: 174/255, green: 255/255, blue: 201/255))
                                        .font(.system(size: 28, weight: .medium, design: .monospaced))
                                    Spacer()
                                }
                                .frame(height: 48)
                                Rectangle()
                                    .fill(Color.gray.opacity(0.15))
                                    .frame(height: 1)
                                    .padding(.horizontal, 4)
                                HStack(spacing: 8) {
                                    Spacer()
                                    Text(sheetsCountDisplay)
                                        .foregroundColor(Color(red: 174/255, green: 255/255, blue: 201/255))
                                        .font(.system(size: 28, weight: .medium, design: .monospaced))
                                    Spacer()
                                }
                                .frame(height: 48)
                            }
                        }
                        .padding(.horizontal, 20)
                        .background(
                            Color(red: 30/255, green: 44/255, blue: 31/255)
                                .shadow(color: Color(red: 30/255, green: 44/255, blue: 31/255).opacity(0.9), radius: 12, x: 0, y: 2)
                                .shadow(color: Color(red: 174/255, green: 255/255, blue: 201/255).opacity(0.15), radius: 14, x: 0, y: 0)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    )
                    .frame(height: 208)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                
                Toggle(isOn: $isToggled) { EmptyView() }
                .toggleStyle(SwitchToggleStyle(tint: Color(red: 44/255, green: 126/255, blue: 79/255)))
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, 32)

                // Button Grid as LazyVGrid
                let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(buttons.indices, id: \.self) { idx in
                        CalculatorButtonView(button: buttons[idx]) { label in
                            if label == "setting" {
                                showSettings = true
                                return
                            }
                            
                            if label == "undo" {
                                if !history.isEmpty {
                                    let lastState = history.removeLast()
                                    display = lastState.display
                                    working = lastState.working
                                }
                                return
                            }
                            
                            // For all other buttons, push current state to history before modifying
                            history.append((display: display, working: working))
                            
                            // Helper: Find last operator index and split display into operands
                            func splitOperands(_ text: String) -> (left: String, right: String?, operatorSymbol: String?) {
                                let operators = [" + ", " - ", " x ", " ÷ "]
                                for op in operators {
                                    if let range = text.range(of: op, options: .backwards) {
                                        let left = String(text[..<range.lowerBound])
                                        let right = String(text[range.upperBound...])
                                        return (left, right, op.trimmingCharacters(in: .whitespaces))
                                    }
                                }
                                return (text, nil, nil)
                            }
                            
                            let operatorsSet = ["+", "-", "x", "÷"]
                            let footSymbol = "′"
                            let inchSymbol = "″"
                            
                            if label == "clear" {
                                display = ""
                                working = ""
                            } else if "0123456789.".contains(label) {
                                display.append(label)
                            } else if label == "feet" {
                                // Replace any occurrence of " ft" or " in" with the corresponding symbols globally
                                display = display.replacingOccurrences(of: " ft", with: footSymbol)
                                display = display.replacingOccurrences(of: " in", with: inchSymbol)
                                
                                let (leftOperand, rightOperand, _) = splitOperands(display)
                                let operand = rightOperand ?? leftOperand
                                
                                // Validation per operand: only allow feet symbol if operand does NOT already contain feet or inch symbols
                                if !operand.contains(footSymbol) && !operand.contains(inchSymbol) {
                                    // Append foot symbol only if last char (of whole display) is not foot or inch symbol or slash
                                    if let lastChar = display.last {
                                        if lastChar != Character(footSymbol) && lastChar != Character(inchSymbol) && lastChar != "/" {
                                            display.append(footSymbol)
                                        }
                                    } else {
                                        display.append(footSymbol)
                                    }
                                }
                            } else if label == "inch" {
                                // Replace any occurrence of " ft" or " in" with the corresponding symbols globally
                                display = display.replacingOccurrences(of: " ft", with: footSymbol)
                                display = display.replacingOccurrences(of: " in", with: inchSymbol)
                                
                                let (leftOperand, rightOperand, _) = splitOperands(display)
                                let operand = rightOperand ?? leftOperand
                                
                                // Validation per operand:
                                // Only allow inch symbol if operand does NOT already contain inch symbol, and does NOT end with foot symbol
                                if !operand.contains(inchSymbol) && (operand.last != Character(footSymbol)) {
                                    // Append inch symbol only if last char (of whole display) is not foot or inch symbol or slash
                                    if let lastChar = display.last {
                                        if lastChar != Character(footSymbol) && lastChar != Character(inchSymbol) && lastChar != "/" {
                                            display.append(inchSymbol)
                                        }
                                    } else {
                                        display.append(inchSymbol)
                                    }
                                }
                            } else if label == "/" {
                                let (leftOperand, rightOperand, _) = splitOperands(display)
                                let operand = rightOperand ?? leftOperand
                                
                                // Only allow slash if last char of display is a number,
                                // operand does not already contain slash,
                                // and display does not end with '/'
                                if let lastChar = display.last,
                                   lastChar.isNumber,
                                   !operand.contains("/"),
                                   !display.hasSuffix("/") {
                                    display.append("/")
                                }
                            } else if operatorsSet.contains(label) {
                                // Append operator with validation:
                                // Only append if display is not empty and does not end with an operator or space.
                                // Also ensure only one operator (binary) is allowed.
                                let lastChar = display.last
                                if !display.isEmpty,
                                   let last = lastChar,
                                   !operatorsSet.contains(String(last)),
                                   !last.isWhitespace {
                                    // Check if display already contains an operator (only one allowed)
                                    // We check globally because only one operator allowed
                                    if !operatorsSet.contains(where: { display.contains($0) }) {
                                        display.append(" \(label) ")
                                    }
                                }
                            } else if label == "=" {
                                // Evaluate the expression if it is in the form "measurement operator measurement"
                                // Support only one operator, binary operation
                                
                                // Operators symbols for splitting
                                let operatorSymbols = [" + ", " - ", " x ", " ÷ "]
                                var opFound: String?
                                
                                for opSym in operatorSymbols {
                                    if display.contains(opSym) {
                                        opFound = opSym.trimmingCharacters(in: .whitespaces)
                                        break
                                    }
                                }
                                
                                guard let op = opFound else {
                                    // No operator found, do nothing
                                    return
                                }
                                
                                // Split the display by the operator substring with spaces
                                let parts = display.components(separatedBy: " \(op) ")
                                guard parts.count == 2 else {
                                    // Invalid input format, do nothing
                                    return
                                }
                                
                                let lhsString = parts[0]
                                let rhsString = parts[1]
                                
                                // Helper to parse measurement string into inches (Double)
                                // Parse feet (′), inches (″), and optional fraction (e.g. 1/2)
                                func parseMeasurement(_ str: String) -> Double? {
                                    // Remove spaces
                                    let trimmed = str.replacingOccurrences(of: " ", with: "")
                                    
                                    var feet: Double = 0
                                    var inches: Double = 0
                                    var fraction: Double = 0
                                    
                                    var working = trimmed
                                    
                                    if let footRange = working.range(of: "′") {
                                        let feetStr = String(working[..<footRange.lowerBound])
                                        if let f = Double(feetStr) {
                                            feet = f
                                        }
                                        working.removeSubrange(..<footRange.upperBound)
                                    }
                                    
                                    if let inchRange = working.range(of: "″") {
                                        let inchStr = String(working[..<inchRange.lowerBound])
                                        // Handle inches possibly with fraction like "3 1/2"
                                        if inchStr.contains("/") {
                                            // Possible formats: "3 1/2" or just "1/2"
                                            let components = inchStr.split(separator: " ")
                                            var wholeInch: Double = 0
                                            var fracInch: Double = 0
                                            
                                            if components.count == 2 {
                                                if let whole = Double(components[0]) {
                                                    wholeInch = whole
                                                }
                                                let fractionPart = String(components[1])
                                                let fracParts = fractionPart.split(separator: "/")
                                                if fracParts.count == 2,
                                                   let numerator = Double(fracParts[0]),
                                                   let denominator = Double(fracParts[1]),
                                                   denominator != 0 {
                                                    fracInch = numerator / denominator
                                                }
                                            } else if components.count == 1 {
                                                // Only fraction part
                                                let fractionPart = String(components[0])
                                                let fracParts = fractionPart.split(separator: "/")
                                                if fracParts.count == 2,
                                                   let numerator = Double(fracParts[0]),
                                                   let denominator = Double(fracParts[1]),
                                                   denominator != 0 {
                                                    fracInch = numerator / denominator
                                                }
                                            }
                                            inches = wholeInch + fracInch
                                        } else if let inchNum = Double(inchStr) {
                                            inches = inchNum
                                        }
                                        working.removeSubrange(..<inchRange.upperBound)
                                    } else {
                                        // No inch symbol, check if fraction or whole number in remaining string
                                        if working.contains("/") {
                                            let fracParts = working.split(separator: "/")
                                            if fracParts.count == 2,
                                               let numerator = Double(fracParts[0]),
                                               let denominator = Double(fracParts[1]),
                                               denominator != 0 {
                                                fraction = numerator / denominator
                                                inches = fraction
                                            }
                                        } else if let val = Double(working), !working.isEmpty {
                                            inches = val
                                        }
                                    }
                                    
                                    return feet * 12 + inches
                                }
                                
                                // Set working to current display before calculation result update
                                working = display
                                
                                // Parse lhs and rhs into inches
                                guard let lhsInches = parseMeasurement(lhsString),
                                      let rhsInches = parseMeasurement(rhsString) else {
                                    return
                                }
                                
                                // Compute result
                                if op == "x" {
                                    // Multiplication: compute square feet
                                    let lhsFeet = lhsInches / 12
                                    let rhsFeet = rhsInches / 12
                                    let squareFeet = lhsFeet * rhsFeet
                                    
                                    // Format square feet with no decimals if integer, else up to 2 decimals
                                    let formatted: String
                                    if squareFeet.truncatingRemainder(dividingBy: 1) == 0 {
                                        formatted = "\(Int(squareFeet)) ft²"
                                    } else {
                                        formatted = String(format: "%.2f ft²", squareFeet)
                                    }
                                    
                                    display = formatted
                                } else {
                                    var resultInches: Double = 0
                                    switch op {
                                    case "+":
                                        resultInches = lhsInches + rhsInches
                                    case "-":
                                        resultInches = lhsInches - rhsInches
                                    case "÷":
                                        guard rhsInches != 0 else {
                                            // Avoid division by zero
                                            return
                                        }
                                        resultInches = lhsInches / rhsInches
                                    default:
                                        return
                                    }
                                    
                                    // Convert result to feet, inches, fraction
                                    // Advanced rounding and formatting:
                                    let totalInches = resultInches
                                    
                                    var feetPart = Int(totalInches / 12)
                                    var remainderInches = totalInches.truncatingRemainder(dividingBy: 12)
                                    
                                    // Round the remainderInches smartly to nearest 1/16 inch
                                    let precision = 16
                                    var fractionNumerator = Int(round(remainderInches * Double(precision)))
                                    
                                    // Handle cases where rounding causes fractionNumerator == precision (e.g., 0.9999 rounds to 1)
                                    if fractionNumerator == 0 {
                                        // fraction is zero, nothing to do
                                    } else if fractionNumerator == precision {
                                        // carry over 1 inch
                                        fractionNumerator = 0
                                        remainderInches = 0
                                        feetPart += 0 // no need to adjust feet here
                                        // Add 1 inch to inchesPart below after we compute it
                                    }
                                    
                                    // Compute inches part and adjust for carry from fraction rounding
                                    var inchesPart = fractionNumerator / precision
                                    // inchesPart will always be 0 since fractionNumerator < precision, so use Int(remainderInches)
                                    inchesPart = Int(remainderInches)
                                    
                                    // Reduce numerator and denominator for fraction part
                                    func gcd(_ a: Int, _ b: Int) -> Int {
                                        var a = a
                                        var b = b
                                        while b != 0 {
                                            let temp = b
                                            b = a % b
                                            a = temp
                                        }
                                        return a
                                    }
                                    
                                    var numerator = fractionNumerator - (inchesPart * precision)
                                    
                                    var fractionStr = ""
                                    if numerator > 0 {
                                        let divisor = gcd(numerator, precision)
                                        let reducedNumerator = numerator / divisor
                                        let reducedDenominator = precision / divisor
                                        fractionStr = "\(reducedNumerator)/\(reducedDenominator)"
                                    }
                                    
                                    // Handle carry from fraction rounding causing inchesPart increment
                                    // For example if fractionNumerator == precision handled above
                                    if fractionNumerator == precision {
                                        feetPart += (inchesPart + 1) / 12
                                        inchesPart = (inchesPart + 1) % 12
                                        fractionStr = ""
                                    }
                                    
                                    // Compose the string according to format: "{feet}′ {inches} {fraction}″"
                                    // with spaces as required, omit parts if zero
                                    var resultStr = ""
                                    if feetPart > 0 {
                                        resultStr += "\(feetPart)′"
                                    }
                                    
                                    if inchesPart > 0 || !fractionStr.isEmpty {
                                        if !resultStr.isEmpty {
                                            resultStr += " "
                                        }
                                        resultStr += "\(inchesPart)"
                                    }
                                    
                                    if !fractionStr.isEmpty {
                                        resultStr += " \(fractionStr)"
                                    }
                                    
                                    if inchesPart > 0 || !fractionStr.isEmpty {
                                        resultStr += "″"
                                    }
                                    
                                    // If no feet, inches, fraction, show 0″
                                    if resultStr.isEmpty {
                                        resultStr = "0″"
                                    }
                                    
                                    display = resultStr
                                }
                                
                                // Future: extend to multi-step calculations, parentheses, etc.
                            }
                            // For other buttons: do nothing for now
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
            .padding(.vertical)
        }
        .sheet(isPresented: $showSettings) {
            VStack(spacing: 24) {
                Text("Settings")
                    .font(.largeTitle)
                    .bold()
                
                Picker("Fraction Resolution", selection: $fractionResolution) {
                    ForEach([64, 32, 16, 8, 4, 2], id: \.self) { value in
                        Text("1/\(value)").tag(value)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .labelsHidden()
                
                Text("Current: 1/\(fractionResolution)")
                    .font(.title2)
                
                Button("Done") {
                    showSettings = false
                }
                .font(.title3)
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.8))
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding(40)
        }
    }
}

struct CalculatorButton {
    let label: String
    let color: Color
}

struct CalculatorButtonView: View {
    let button: CalculatorButton
    let onTap: (String) -> Void
    @State private var isPressed: Bool = false
    
    // Colors for retro look
    private var bgColor: Color {
        switch button.color {
        case .gray:
            return Color(red: 64/255, green: 64/255, blue: 64/255) // metallic gray
        case .orange:
            return Color(red: 199/255, green: 127/255, blue: 0) // dark orange
        case .red:
            return Color(red: 194/255, green: 16/255, blue: 0) // bold red
        case .green:
            return Color(red: 44/255, green: 126/255, blue: 79/255) // retro green
        default:
            return button.color
        }
    }
    
    private var gradientOverlay: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.12),
                Color.black.opacity(0.25),
                Color.black.opacity(0.6)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    var body: some View {
        if button.label.isEmpty {
            Color.clear.frame(minWidth: 0, maxWidth: .infinity, minHeight: 58)
        } else {
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.12, dampingFraction: 0.5)) {
                    isPressed = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) {
                    withAnimation(.spring(response: 0.12, dampingFraction: 0.5)) {
                        isPressed = false
                    }
                }
                onTap(button.label)
            }) {
                Text(button.label)
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 58)
                    .padding(.vertical, 6)
                    .background(
                        ZStack {
                            bgColor
                            gradientOverlay
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.45), radius: 2, x: 1, y: 2)
            }
            .buttonStyle(PlainButtonStyle())
            .scaleEffect(isPressed ? 0.8 : 1.0)
        }
    }
}

#Preview {
    ContentView()
}
