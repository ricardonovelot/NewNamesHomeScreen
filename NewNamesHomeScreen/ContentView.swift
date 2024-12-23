//
//  ContentView.swift
//  NewNamesHomeScreen
//
//  Created by Ricardo on 21/12/24.
//

import SwiftUI
import SwiftData

@Model
class Contact{
    var name: String?
    var summary: String? = ""
    var isMetLongAgo: Bool = false
    var notes = [Note]()
    var tags = [Tag]()
    var timestamp: Date
    var photo: Data
    var group: String
    var cropOffsetX: Float
    var cropOffsetY: Float
    var cropScale: Float
    
    init(name: String = String(), summary: String = "", isMetLongAgo: Bool = false, timestamp: Date, notes: [Note], tags: [Tag] = [], photo: Data, group: String = "", cropOffsetX: Float = 0.0, cropOffsetY: Float = 0.0, cropScale: Float = 1.0) {
        self.name = name
        self.summary = summary
        self.isMetLongAgo = isMetLongAgo
        self.notes = notes
        self.tags = tags
        self.timestamp = timestamp
        self.photo = photo
        self.group = group
        self.cropOffsetX = cropOffsetX
        self.cropOffsetY = cropOffsetY
        self.cropScale = cropScale
    }
}

@Model
final class Note {
    var content: String
    var creationDate: Date
    
    init( content: String, creationDate: Date) {
        self.content = content
        self.creationDate = creationDate
    }
}

@Model
final class Tag {
    var name: String
    
    init(name: String) {
        self.name = name
    }
}


struct StringItem: Identifiable {
    let id = UUID()
    let value: String
}

var columns = [
    GridItem(.flexible(), spacing: 10.0),
    GridItem(.flexible(), spacing: 10.0),
    GridItem(.flexible(), spacing: 10.0),
    GridItem(.flexible(), spacing: 10.0)
]

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Query private var Scontacts: [Contact]
    @State private var text = ""
    @State private var position = ScrollPosition()
    @State private var isBeyondZero: Bool = false
    @FocusState private var fieldIsFocused: Bool
    
    @State private var contacts: [Contact]
    @State private var parsedContacts: [Contact] = []
    
    init() {
        _contacts = State(initialValue: Array(1...10).map { _ in Contact(name: ContentView.randomString(),timestamp: Date(), notes: [], photo: Data()) })
    }
    
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    Spacer()
                    LazyVGrid(columns: Array(repeating: GridItem(spacing: 10), count: 4), spacing: 10) {
                        ForEach(contacts, id: \.self) { contact in
                            HStack {
                                Text("\(contact.name ?? "Contact")")
                                Spacer()
                            }
                            .padding(.leading)
                        }
                        
                        ForEach(parsedContacts, id: \.self) { contact in
                            HStack {
                                Text("\(contact.name ?? "Contact")")
                                    .foregroundStyle(Color(UIColor.placeholderText))
                                Spacer()
                            }
                            .padding(.leading)
                        }
                    }
                    .id(UUID()) // make updates work but throws : LazyVStackLayout: the ID AddQuickly.Contact is used by multiple child views, this will give undefined results!
                    
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 5)
                        .onChanged { value in
                            let verticalTranslation = value.translation.height
                            if verticalTranslation > 0 {
                                // Detecting downward swipe
                                fieldIsFocused = false
                            } else if verticalTranslation < 0 && fieldIsFocused == false {
                                // Detecting upward swipe
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    if isBeyondZero {fieldIsFocused = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                            position.scrollTo(edge: .bottom)
                                        }
                                    }
                                }
                            }
                        }
                )
                .scrollPosition($position)
                .defaultScrollAnchor(.bottom)
                .onScrollGeometryChange(for: Bool.self) { geometry in
                    return geometry.contentSize.height < geometry.visibleRect.maxY - geometry.contentInsets.bottom - 85
                } action: { wasBeyondZero, isBeyondZero in
                    self.isBeyondZero = isBeyondZero
                    print(isBeyondZero)
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack{
                    TextField("", text: $text, axis: .vertical)
                        .focused($fieldIsFocused)
                        .padding(.horizontal,16)
                        .padding(.vertical,8)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.bottom)
                        .padding(.horizontal)
                        .onChange(of: text) { oldValue, newValue in
                            if let last = newValue.last, last == "\n" {
                                contacts = contacts + parsedContacts
                                text = ""
                            } else {
                                parseContacts()
                            }
                            position.scrollTo(edge: .bottom)
                        }
                }
                .padding(.top)
            }
            .background(Color(uiColor: .systemGroupedBackground))
        }
        
    }
    
    static func randomString(length: Int = 10) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyz"
        return String((0..<length).compactMap { _ in letters.randomElement() })
    }
    
    private func parseContacts() {
        
        let input = text
        // Split the input by commas for each contact entry
        let nameEntries = input.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        var contacts: [Contact] = []
        var globalTags: [Tag] = []
        
        // First, find all unique hashtags across the entire input
        let allWords = input.split(separator: " ").map { String($0) }
        for word in allWords {
            if word.starts(with: "#") {
                let tagName = word.dropFirst().trimmingCharacters(in: .punctuationCharacters)
                if !tagName.isEmpty && !globalTags.contains(where: { $0.name == tagName }) {
                    globalTags.append(Tag(name: String(tagName)))
                }
            }
        }
        
        // Now parse each contact entry, attaching the global tags to each
        for entry in nameEntries {
            var nameComponents: [String] = []
            
            // Split each entry by spaces to find words (ignore hashtags here as they’re in globalTags)
            let words = entry.split(separator: " ").map { String($0) }
            
            for word in words {
                if !word.starts(with: "#") {
                    nameComponents.append(word)
                }
            }
            
            let name = nameComponents.joined(separator: " ")
            if !name.isEmpty {
                let contact = Contact(name: name, timestamp: Date(), notes: [], tags: globalTags, photo: Data())
                contacts.append(contact)
            }
        }
        parsedContacts = contacts
    }
    
}





#Preview {
        ContentView()
}
