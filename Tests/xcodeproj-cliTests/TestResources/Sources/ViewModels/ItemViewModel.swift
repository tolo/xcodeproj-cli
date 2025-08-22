import Foundation

class ItemViewModel: ObservableObject {
  @Published var items: [Item] = []
}
