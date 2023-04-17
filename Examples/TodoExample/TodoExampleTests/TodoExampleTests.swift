//
//  TodoExampleTests.swift
//  TodoExampleTests
//
//  Created by Johan Thorell on 2023-04-17.
//

import XCTest
@testable import TodoExample
import AtomsTesting
import Atoms

final class TodoExampleTests: XCTestCase {
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
    
    @MainActor
    func testFilterNotCompletedTodos() async throws {
        try await TestStore { store in
            let firstMock = Todo(name: "Todo1")
            let secondMock = Todo(name: "Todo2", completed: true)
            let mock: [Todo] = [firstMock, secondMock]
            store.inject(todosAtom) {
                return mock
            }
            @CaptureAtom(filterTodosOptionAtom) var filterTodosOption: FilterOption
            @CaptureAtomValue(filteredTodosAtom) var filteredTodos: [Todo]
            filterTodosOption = .notCompleted
            try await expectEqual(filteredTodos, [firstMock])
        }
    }
    
    @MainActor
    func testSearchTodos() async throws {
        try await TestStore { store in
            let firstMock = Todo(name: "Todo1")
            let secondMock = Todo(name: "Todo2", completed: true)
            let mock: [Todo] = [firstMock, secondMock]
            store.inject(todosAtom) {
                return mock
            }
            @CaptureAtomValue(filteredTodosAtom) var filteredTodos: [Todo]
            @CaptureAtom(searchTodosAtom) var searchTodos: String
            searchTodos = "Todo2"
            try await expectEqual(filteredTodos, [secondMock])
        }
    }
    
    @MainActor
    func testSetCompletedTodo() async throws {
        try await TestStore { store in
            let firstMock = Todo(name: "Todo1")
            let secondMock = Todo(name: "Todo2")
            let mock: [Todo] = [firstMock, secondMock]
            @UseAtom(todosAtom) var todos: [Todo]
            todos = mock
            try await expectEqual(todos, mock)
            $todos[0].wrappedValue.completed = true
            try await expectEqual(todos.first?.completed, true)
        }
    }
    
}
