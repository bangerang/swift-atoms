# Atoms

**Atoms** is a powerful and flexible atomic state management library for Swift, designed to create compact, independent global state components with seamless adaptability and composition.

```swift
// Create a text atom
let textAtom = Atom("")

// Create a derived atom that depends on textAtom.
// Atoms automatically update their state when any of their dependencies change.
let extractedNumbersAtom = DerivedAtom {
    @UseAtomValue(textAtom) var text
    return text.filter {
        $0.isNumber
    }
}

struct ContentView: View {
    // Provide write access to the textAtom
    @UseAtom(textAtom) var text
    // Provide read-only access to the extractedNumbersAtom
    @UseAtomValue(extractedNumbersAtom) var numbers
    
    var body: some View {
        VStack {
            TextField("", text: $text)
            Text("Extracted numbers: \(numbers)")
        }
    }
}
```

## Motivation

SwiftUI provides great built-in support for handling state, but its object-oriented approach can make code splitting challenging. That's where **Atoms** can help.

**Atoms** provide a more granular level of state management, allowing you to focus on what you need without worrying about where to put things. By avoiding large observable objects with many published properties, **Atoms** help you steer clear of performance bottlenecks due to rendering, while maintaining a single source of truth in your app's architecture.

## Overview

**Atoms** comes with 9 different atom types that should cover most of your needs, such as dealing with asyncronousy.

```swift
let searchTextAtom = Atom("")

let apiAtom = Atom(...)

// Define a dogsAtom for fetching dogs based on the search text
let dogsAtom = AsyncAtom<[Dog]> {
    @UseAtomValue(searchTextAtom, debounce: 0.3) var searchText
    @UseAtomValue(apiAtom) var api
    return try await api.searchDogs(searchText)
}

struct SearchDogsView: View {
    @UseAtom(searchTextAtom) var searchText
    @UseAtomValue(dogsAtom) var dogsState
    
    var body: some View {
        NavigationStack {
            List {
                switch dogsState {
                case .loading:
                    ProgressView()
                case .success(let dogs):
                    ForEach(dogs) {
                        Text($0.name)
                    }
                case .failure(let error):
                    Text(error.localizedDescription)
                    Button("Try again") {
                        dogsAtom.reload()
                    }
                }
            }
            .searchable(text: $searchText)
        }
    }
}
```

## List of atoms

All atoms that accept a closure as their initial argument will update automatically when their dependencies change.

- [**Atom**](https://bangerang.github.io/swift-atoms/documentation/atoms/atom): Represents a state for a given value of type `T`.
- [**DerivedAtom**](https://bangerang.github.io/swift-atoms/documentation/atoms/derivedatom): A read-only state derived from other atom states.
- [**AsyncAtom**](https://bangerang.github.io/swift-atoms/documentation/atoms/asyncatom): Manages asynchronous operations that produce a value of type `T` or throw an error, with states represented as `AsyncState<T>`.
- [**AsyncSequenceAtom**](https://bangerang.github.io/swift-atoms/documentation/atoms/asyncsequenceatom): Manages the state of an asynchronous sequence producing values of type `T` or throwing an error, with states represented as `AsyncState<T>`.
- [**GetSetAtom**](https://bangerang.github.io/swift-atoms/documentation/atoms/getsetatom): Custom getter and setter for values of type `T`.
- [**ObservableObjectAtom**](https://bangerang.github.io/swift-atoms/documentation/atoms/observableobjectatom): Represents a readable state for a given value of type `T` that conforms to `ObservableObject`.
- [**PublisherAtom**](https://bangerang.github.io/swift-atoms/documentation/atoms/publisheratom): Represents a readable state from a `Publisher`, with states represented as `AsyncState<T>`.
- [**PublishedAtom**](https://bangerang.github.io/swift-atoms/documentation/atoms/publishedatom): Represents a readable state from a `Published` property of type `T`.
- [**WillSetAtom**](https://bangerang.github.io/swift-atoms/documentation/atoms/willsetatom): Stores values of type `T` and performs custom logic before updating the stored value.

## Property Wrappers

- [**UseAtom**](https://bangerang.github.io/swift-atoms/documentation/atoms/useatom): Provides read and write access to the atom's value, and it's reactive to changes.
- [**UseAtomValue**](https://bangerang.github.io/swift-atoms/documentation/atoms/useatomvalue): Provides read-only access to the atom's value, and it's reactive to changes.
- [**CaptureAtom**](https://bangerang.github.io/swift-atoms/documentation/atoms/captureatom): Captures the atom's value and provides read and write access without being reactive to changes.
- [**CaptureAtomValue**](https://bangerang.github.io/swift-atoms/documentation/atoms/captureatomvalue): Captures the atom's value as a constant and provides read-only access without being reactive to changes.
- [**CaptureAtomPublisher**](https://bangerang.github.io/swift-atoms/documentation/atoms/captureatompublisher):  Provides an `AnyPublisher<T, Never>` that emits the current value of the atom and any subsequent updates.

## Dependency injection

**Atoms** supports testing and overriding values through dependency injection.

```swift
struct SearchDogsView_Previews: PreviewProvider {
    static var previews: some View {
        SearchDogsView()
            .inject(dogsAtom) {
                return .success([
                    .init(name: "Pluto"),
                    .init(name: "Lassie")
                ])
            }
    }
}
```

For testing, one can use the `TestStore`.

```swift
@MainActor
func testDogsSuccess() async throws {
    let mock: [Dog] = [.init(name: "Pluto"), .init(name: "Lassie")]
    try await TestStore { store in
        store.inject(apiAtom) {
            .init(searchDogs: { _ in
                return mock
            })
        }
        @CaptureAtomValue(dogsAtom) var dogsState: AsyncState<[Dog]>
        @CaptureAtom(searchTextAtom) var searchText: String
        searchText = "Foo"
        try await expectEqual(dogsState, .success(mock))
    }
}
```

## Adaptive Memory Management

By default, atom values are stored in memory only while they are actively being used. However, it is still possible to keep certain values alive if needed by passing `keepAlive: true` when creating an atom.

## Debugging

Atoms provides built-in debugging support to help you track state changes. Use the `enableAtomLogging` method on a `View`.

```swift
Text("Hello, World!")
    .enableAtomLogging()
```
Or directly through the `AtomStore`.
```swift
AtomStore.shared.enableAtomLogging(debugScope: .include([counterAtom]))
```

## Installation

### Swift Package Manager

1. Open your project in Xcode.
2. Go to **File > Add Packages...**.
3. In the search bar, enter the URL of the Atoms repository: `https://github.com/bangerang/swift-atoms.git`.
4. Click **Add Package**.
5. Choose the appropriate package options and click **Add Package** again to confirm.

## Testing

**Atoms** comes bundled with [**AsyncExpectations**](https://github.com/bangerang/swift-async-expectations), which makes writing asynchronous tests easy. Using the `TestStore` guarantees that your tests run in an isolated context.

```swift
@MainActor
func testFilterCompletedTodos() async throws {
    try await TestStore { store in
        let firstMock = Todo(name: "Todo1")
        let secondMock = Todo(name: "Todo2", completed: true)
        let mock: [Todo] = [firstMock, secondMock]
        store.inject(todosAtom) {
            return mock
        }
        @CaptureAtom(filterTodosOptionAtom) var filterTodosOption: FilterOption
        @CaptureAtomValue(filteredTodosAtom) var filteredTodos: [Todo]
        filterTodosOption = .completed
        try await expectEqual(filteredTodos, [secondMock])
    }
}
```

## Examples
- [Todo App](https://github.com/bangerang/swift-atoms/tree/main/Examples/TodoExample)
- [Simple signup](https://github.com/bangerang/swift-atoms/tree/main/Examples/SignupExample)
- [Search and favorite cocktails](https://github.com/bangerang/swift-atoms/tree/main/Examples/CocktailExample)

## FAQ/Docs
Many questions can be answered by looking through the  [documentation](https://bangerang.github.io/swift-atoms/documentation/atoms/). Also, feel free to ask questions in the discussions section.

#### Namespacing

If the global namespace is not your thing, you can always create static let properties for scoping.

```swift
enum MyAtoms {
    static let atom = Atom("")
    static let derived = DerivedAtom {
        @UseAtomValue(atom) var someValue
        return someValue.filter {
            $0.isNumber
        }
    }
}
```

#### Use with UIKit

**Atoms** can also be used with UIKit in addition to SwiftUI. You can use `@CaptureAtomPublisher` to subscribe to any atom value changes.

```swift
class ViewController: UIViewController {
    @CaptureAtomPublisher(searchTextAtom) var searchTextPublisher
    
    private let label = UILabel()
    private var cancellable: AnyCancellable?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(label)
        cancellable = searchTextPublisher
            .sink { [weak self] text in
                self?.label.text = text
            }
    }
}
```

#### Known Issues

Using property wrappers inline without a following keyword will lead to a compiler error in Xcode < 14.3. The workaround is to either add a semicolon or explicitlly state the type.

```swift
let someAtom = DerivedAtom {
    @UseAtomValue(someOtherAtom) var value: String
    print(value)
    return "Hello " + value
}
```

#### Scope

Atoms will be in most cases be defined in the global scope. But it is possible to create new atoms on the fly, or use standard SwiftUI conventions such as bindings to avoid this.

Using a binding.

```swift
let personsAtom = Atom<[Person]>([Person(name: "John", age: 26)])

struct ParentView: View {
    @UseAtom(personsAtom) var persons
    var body: some View {
        List($persons) { $person in
            PersonView(person: $person)
        }
    }
}
struct PersonView: View {
    @Binding var person: Person
    var body: some View {
        TextField("Name", text: $person.name)
    }
}
```

Or create a new atom for more control.

```swift
let personsAtom = Atom<[Person]>([Person(name: "John", age: 26)])

struct ParentView: View {
    @UseAtom(personsAtom) var persons
    var body: some View {
        List(persons) { person in
            PersonView(personAtom: Atom(person).onUpdate(skip: 1, { newValue in
                guard let index = persons.firstIndex(where: { $0.id == newValue.id }) else {
                    return
                }
                persons[index] = newValue
            }))
        }
    }
}
struct PersonView: View {
    @UseAtom var person: Person
    init(personAtom: Atom<Person>) {
        self._person = UseAtom(personAtom)
    }
    
    var body: some View {
        TextField("Name", text: $person.name)
    }
}
```
