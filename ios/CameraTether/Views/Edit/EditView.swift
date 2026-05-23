import SwiftUI

struct EditView: View {
    @EnvironmentObject var editVM: EditViewModel
    @EnvironmentObject var maskingVM: MaskingViewModel
    @EnvironmentObject var libraryVM: LibraryViewModel
    @State private var showMasking = false
    @State private var showRetouch = false
    @State private var showExportAlert = false

    var body: some View {
        VStack(spacing: 0) {
            // Canvas
            CanvasView(image: editVM.previewImage)
                .frame(maxWidth: .infinity)
                .aspectRatio(4/3, contentMode: .fit)
                .overlay(alignment: .topTrailing) {
                    if editVM.isProcessing {
                        ProgressView().padding(8).background(.ultraThinMaterial).cornerRadius(8).padding(8)
                    }
                }

            Divider()

            // Tool selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(EditTool.allCases, id: \.self) { tool in
                        Button {
                            withAnimation { editVM.activeTool = tool }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: toolIcon(tool))
                                Text(tool.rawValue.capitalized).font(.caption2)
                            }
                            .frame(width: 64, height: 52)
                            .foregroundColor(editVM.activeTool == tool ? .accentColor : .primary)
                        }
                    }
                }
            }
            .background(Color(.secondarySystemBackground))

            Divider()

            // Active panel
            Group {
                switch editVM.activeTool {
                case .none:
                    PresetSelectorView()
                case .adjust:
                    AdjustmentPanelView()
                case .mask:
                    MaskingView()
                case .retouch, .heal, .clone, .dodgeBurn:
                    RetouchView()
                }
            }
            .frame(maxHeight: 220)
        }
        .navigationTitle(libraryVM.selectedPhoto?.filename ?? "Edit")
        .navigationBarItems(
            leading: HStack {
                Button(action: editVM.undo) { Image(systemName: "arrow.uturn.backward") }
                    .disabled(!editVM.history.canUndo)
                Button(action: editVM.redo) { Image(systemName: "arrow.uturn.forward") }
                    .disabled(!editVM.history.canRedo)
            },
            trailing: Button("Export") { showExportAlert = true }
        )
        .alert("Export to Photos?", isPresented: $showExportAlert) {
            Button("Export") {
                Task {
                    if let img = await editVM.exportFinal() {
                        if let photo = libraryVM.selectedPhoto {
                            _ = try? await PhotoLibraryService.shared.saveToLibrary(img)
                        }
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func toolIcon(_ tool: EditTool) -> String {
        switch tool {
        case .none:     return "wand.and.stars"
        case .adjust:   return "slider.horizontal.3"
        case .mask:     return "person.and.background.dotted"
        case .retouch:  return "paintbrush.pointed"
        case .heal:     return "bandage"
        case .clone:    return "doc.on.doc"
        case .dodgeBurn: return "circle.lefthalf.filled"
        }
    }
}
