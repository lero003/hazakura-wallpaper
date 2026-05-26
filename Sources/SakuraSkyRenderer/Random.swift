import CoreGraphics
import Foundation

enum Random {
    private static let deterministicGeneratorKey = "com.hazakuralab.hazakurawallpaper.deterministicRandomGenerator"

    static func withSeed<T>(_ seed: UInt64, _ body: () throws -> T) rethrows -> T {
        let threadDictionary = Thread.current.threadDictionary
        let previousGenerator = threadDictionary[deterministicGeneratorKey]
        threadDictionary[deterministicGeneratorKey] = SeededRandomNumberGeneratorBox(seed: seed)
        defer {
            if let previousGenerator {
                threadDictionary[deterministicGeneratorKey] = previousGenerator
            } else {
                threadDictionary.removeObject(forKey: deterministicGeneratorKey)
            }
        }
        return try body()
    }

    static func cgFloat(_ range: ClosedRange<CGFloat>) -> CGFloat {
        if let generatorBox = deterministicGeneratorBox {
            let value = CGFloat.random(in: range, using: &generatorBox.generator)
            return value
        }
        return CGFloat.random(in: range)
    }

    static func double(_ range: ClosedRange<Double>) -> Double {
        if let generatorBox = deterministicGeneratorBox {
            let value = Double.random(in: range, using: &generatorBox.generator)
            return value
        }
        return Double.random(in: range)
    }

    static func bool(probability: Double = 0.5) -> Bool {
        double(0...1) < probability
    }

    static func element<T>(in values: [T]) -> T? {
        guard !values.isEmpty else { return nil }

        if let generatorBox = deterministicGeneratorBox {
            let index = Int(generatorBox.generator.next() % UInt64(values.count))
            return values[index]
        }

        return values.randomElement()
    }

    private static var deterministicGeneratorBox: SeededRandomNumberGeneratorBox? {
        Thread.current.threadDictionary[deterministicGeneratorKey] as? SeededRandomNumberGeneratorBox
    }
}

private final class SeededRandomNumberGeneratorBox {
    var generator: SeededRandomNumberGenerator

    init(seed: UInt64) {
        self.generator = SeededRandomNumberGenerator(seed: seed)
    }
}

private struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0x6a09e667f3bcc909 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var value = state
        value = (value ^ (value >> 30)) &* 0xbf58476d1ce4e5b9
        value = (value ^ (value >> 27)) &* 0x94d049bb133111eb
        return value ^ (value >> 31)
    }
}
