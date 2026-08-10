import SwiftUI

struct ContentView: View {
    @State private var notes: [Note] = [
         Note(title: "First note", content: "Hello from Swift"),
         Note(title: "Shopping", content: "Milk, eggs, coffee"),
     ]
    @State private var showingEditor = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(notes){
                    note in
                    NavigationLink(value: note){
                        VStack(alignment: .leading, spacing:4) {
                            
                            Text(note.title)
                                .font(.headline)
                            Text(note.content)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                        
                    }.onDelete{indexSet in notes.remove(atOffsets: indexSet)
                    
                }
            }
               
               .navigationTitle("Notes")
               .navigationDestination(for: Note.self) { note in
                   NoteEditorView(note: note) { updated in
                       if let index = notes.firstIndex(where: { $0.id == updated.id }) {
                           notes[index] = updated
                       }
                   }
               }
               .toolbar{
                   
                   Button("Add", systemImage: "plus"){
                       showingEditor = true
                   }
               }
               .sheet(isPresented: $showingEditor){
                   NavigationStack{
                       NoteEditorView(note: nil ){ newNote in notes.append(newNote)}
                   }
               }
           }
       }
   }

   #Preview {
       ContentView()
   }
