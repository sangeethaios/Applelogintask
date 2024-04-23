//
//  ApplelogintaskApp.swift
//  Applelogintask
//
//  Created by SangeethaKalis on 22/04/24.
//

import SwiftUI

@main
struct Applelogintask: App {
    var body: some Scene {
        WindowGroup {
            LaunchScreenView()
        }
    }
}

struct LaunchScreenView: View {
    @State private var showContentView = false

    var body: some View {
        VStack {
            Image("launch icon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding()
            
        }
        .frame(width: 100, height: 100)
        .background(Color.white) // Optional: Set background color
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    showContentView = true
                }
            }
        }
        .fullScreenCover(isPresented: $showContentView) {
            ContentView()
        }
    }
}
