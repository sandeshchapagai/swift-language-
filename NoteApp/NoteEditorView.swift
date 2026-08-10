//
//  NoteEditorView.swift
//  NoteApp
//
//  Created by Undefine on 10/08/2026.
//

import SwiftUI

struct NoteEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let note: Note?                      // nil = create, value = edit
    let onSave: (Note) -> Void
    
    @State private var title = ""
    @State private var content = ""
    

    
    var body: some View {
        Form{
            TextField("Title", text: $title)
            TextField("Content",text: $content , axis: .vertical).lineLimit(5...)
        }
        
        .navigationTitle(note == nil ? "New Note" : "Edit Note")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar{
            ToolbarItem(placement: .confirmationAction){
                Button("Save"){
                    onSave(Note(title: title, content: content))
                    dismiss()
                }
                .disabled(title.isEmpty && content.isEmpty)
            }
            
            ToolbarItem(placement: .cancellationAction){
                Button("Cancel"){ dismiss()}.disabled(title.isEmpty && content.isEmpty)
                }
                
        }
        .onAppear{
            if let note{
                title = note.title
                content = note.content
            }
        }
    }
}
