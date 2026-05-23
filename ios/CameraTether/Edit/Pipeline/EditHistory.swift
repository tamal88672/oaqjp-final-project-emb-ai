import Foundation

final class EditHistory: ObservableObject {
    @Published private(set) var canUndo: Bool = false
    @Published private(set) var canRedo: Bool = false

    private var undoStack: [[EditOperation]] = []
    private var redoStack: [[EditOperation]] = []
    private let maxDepth = 50

    func snapshot(_ operations: [EditOperation]) {
        undoStack.append(operations)
        if undoStack.count > maxDepth { undoStack.removeFirst() }
        redoStack.removeAll()
        updateFlags()
    }

    func undo() -> [EditOperation]? {
        guard let state = undoStack.popLast() else { return nil }
        redoStack.append(state)
        updateFlags()
        return undoStack.last
    }

    func redo() -> [EditOperation]? {
        guard let state = redoStack.popLast() else { return nil }
        undoStack.append(state)
        updateFlags()
        return state
    }

    func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
        updateFlags()
    }

    private func updateFlags() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }
}
