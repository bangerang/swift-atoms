import Foundation

@MainActor
@discardableResult
func findObservables<R>(using id: UUID, operation: () -> R, observedChanged: @escaping (R) -> Void) -> R {
    Scope.$id.withValue(id) {
        let value = operation()
        let store = StoreConfig.store
        let used = store.usedAtoms[Scope.id]?.filter { $0.watching } ?? []
        
        for us in used {
            guard us.atom != id else {
                continue
            }
            if let publisher = store.getSetPublisher(for: us.atom) {
                publisher.setterPublisher.debounce(for: .seconds(us.debounced), scheduler: DispatchQueue.main).sink { _ in
                    StoreConfig.$store.withValue(store) {
                        observedChanged(value)
                    }
                }.store(in: &store.cancellables[id, default: []])
            }
        }
        store.usedAtoms[Scope.id]?.removeAll()
        return value
    }
}

func setDebugInfoForCurrentStorage(id: UUID, file: String, function: String, line: Int) {
    #if DEBUG
        Task { @MainActor in
            let store = StoreConfig.store
            guard store.debugInfo[id] == nil else {
                return
            }
            
            if let customLabel = store.customDebugLabels[id] {
                store.debugInfo[id] = .init(name: customLabel)
                return
            }
            
            do {
                let contents = try String(contentsOfFile: file)
                let linesRegex = try NSRegularExpression(pattern: "\n", options: .useUnixLineSeparators)
                let lineRanges = linesRegex.matches(in: contents, range: NSRange(contents.startIndex..., in: contents))
                let specificLineNSRange = lineRanges[line-1]
                let lineBeforeNSRange = lineRanges[line-2]
                
                if let specificLineRange = Range(specificLineNSRange.range(at: 0), in: contents), let lineBeforeRange = Range(lineBeforeNSRange.range(at: 0), in: contents) {
                    let line = String(contents[lineBeforeRange.upperBound..<specificLineRange.lowerBound])
                    let regex = try NSRegularExpression(pattern: #"(?<=(let|var) )\w+"#)
                    let matches = regex.matches(in: String(line), range: NSRange(line.startIndex..., in: line))
                    if let nsRange = matches.first?.range(at: 0) {
                        if let range = Range(nsRange, in: line) {
                            store.debugInfo[id] = .init(name: String(line[range]))
                        }

                    }
                }
            } catch {
                print("Error reading file:", error)
            }
        }
    #endif
}

extension Equatable {
    func isEqual(_ other: any Equatable) -> Bool {
        guard let other = other as? Self else {
            return other.isExactlyEqual(self)
        }
        return self == other
    }

    private func isExactlyEqual(_ other: any Equatable) -> Bool {
        guard let other = other as? Self else {
            return false
        }
        return self == other
    }
}

func areEqual(first: Any, second: Any) -> Bool {
    guard
        let equatableOne = first as? any Equatable,
        let equatableTwo = second as? any Equatable
    else {
        return false
        
    }
    
    return equatableOne.isEqual(equatableTwo)
}
