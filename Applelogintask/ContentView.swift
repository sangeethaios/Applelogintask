//
//  ContentView.swift
//  Applelogintask
//
//  Created by SangeethaKalis on 22/04/24.
//

import SwiftUI
import AuthenticationServices
import HealthKit

struct AppleUser: Codable {
    let userId: String
    let firstName: String
    let lastName: String
    let email: String
    
    init?(credentials: ASAuthorizationAppleIDCredential) {
        guard
            let firstName = credentials.fullName?.givenName,
            let lastName = credentials.fullName?.familyName,
            let email = credentials.email
        else { return nil }
        
        self.userId = credentials.user
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
    }
}

struct ContentView: View {
    @State private var isAuthenticated = false
    
    var body: some View {
           NavigationView {
               VStack {
                   HStack {
                       Text("Sign In")
                           .font(.title)
                           .font(.system(size: 30)) // Set the font size to 30 points
                           .fontWeight(.bold) // Apply bold font
                           .padding()
                   }
                   Spacer()
                   SignInWithAppleButton { request in
                       request.requestedScopes = [.fullName, .email]
                   } onCompletion: { result in
                       switch result {
                       case .success(let authorization):
                           if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                               if let appleUser = AppleUser(credentials: appleIDCredential),
                                                 let appleUserData = try? JSONEncoder().encode(appleUser) {
                                                  UserDefaults.standard.setValue(appleUserData, forKey: appleUser.userId)
                                          isAuthenticated = true

                                                  print("saved apple user", appleUser)
                                              } else {
                                                  print("missing some fields", appleIDCredential.email ?? "", appleIDCredential.fullName ?? "", appleIDCredential.user)
                                                  
                                                  guard
                                                      let appleUserData = UserDefaults.standard.data(forKey: appleIDCredential.user),
                                                      let appleUser = try? JSONDecoder().decode(AppleUser.self, from: appleUserData)
                                                  else { return }
                                                  
                                                  print(appleUser)
                                              }
                                              print("Authorization successful with user: \(appleIDCredential.user)")
                               // Use the user identifier for further actions
                               let userID = appleIDCredential.user
                               // Set authentication flag and clear error message
                               isAuthenticated = true
                           }
                           
                       case .failure(let error):
                           // Handle error
                           print("Authorization failed: \(error.localizedDescription)")
                           isAuthenticated = true
                       }
                   }
                   .frame(height: 44)
                   .padding([.leading, .trailing], 20)// Adjust height if needed
                   
                   Spacer()
               }
               .navigationTitle("") // Empty navigation title to allow custom title layout
               .navigationBarHidden(true) // Hide navigation bar
           }
           .fullScreenCover(isPresented: $isAuthenticated, content: HealthCareView.init)

       }
}

struct HealthCareView: View {
    // Initialize HealthKit store
    private var healthStore = HKHealthStore()
    
    // State variables for health data and error handling
    @State private var steps: Double = 0
    @State private var heartRate: Double = 0
    @State private var caloriesBurned: Double = 0
    @State private var errorMessage: String = ""
    
    var body: some View {
        
        HStack {
            Text("Fitness Details")
                .font(.title)
            
        }
        .padding()
        
        VStack {
            // Images for metrics
            HStack {
                MetricView(imageName: "figure.walk", title: "Steps", value: "\(Int(steps))")
                MetricView(imageName: "heart.fill", title: "Heart Rate", value: "\(Int(heartRate)) bpm")
                MetricView(imageName: "flame.fill", title: "Calories Burned", value: "\(Int(caloriesBurned)) kcal")
            }
            
            // Chart View
            ChartView(steps: steps, heartRate: heartRate, caloriesBurned: caloriesBurned)
            
            // Error message
            Text(errorMessage)
                .foregroundColor(.red)
            
            // Button to fetch health data
            Button("Fetch Health Data") {
                fetchHealthData()
            }
            .padding()
        }
        .onAppear {
            // Request authorization to access health data
            requestAuthorization()
        }
    }
    
    // Function to request authorization to access health data
    private func requestAuthorization() {
        let typesToRead: Set<HKObjectType> = [HKObjectType.quantityType(forIdentifier: .stepCount)!,
                                              HKObjectType.quantityType(forIdentifier: .heartRate)!,
                                              HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!]
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            if !success {
                errorMessage = "Failed to authorize access to health data."
            }
        }
    }
    
    // Function to fetch health data
    private func fetchHealthData() {
        guard HKHealthStore.isHealthDataAvailable() else {
            errorMessage = "Health data is not available."
            return
        }
        
        // Define the health data types to fetch
        let typesToRead: Set<HKObjectType> = [HKObjectType.quantityType(forIdentifier: .stepCount)!,
                                              HKObjectType.quantityType(forIdentifier: .heartRate)!,
                                              HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!]
        
        // Fetch health data
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            if success {
                // Fetch steps data
                fetchStepCount()
                
                // Fetch heart rate data
                fetchHeartRate()
                
                // Fetch calories burned data
                fetchCaloriesBurned()
            } else {
                errorMessage = "Failed to authorize access to health data."
            }
        }
    }
    
    // Function to fetch step count data
    private func fetchStepCount() {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: nil, options: .cumulativeSum) { query, result, error in
            if let result = result, let sum = result.sumQuantity() {
                DispatchQueue.main.async {
                    self.steps = sum.doubleValue(for: HKUnit.count())
                    
                }
            } else {
                DispatchQueue.main.async {
                    errorMessage = "Failed to fetch step count data."
                }
            }
        }
        healthStore.execute(query)
    }
    
    // Function to fetch heart rate data
    private func fetchHeartRate() {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let query = HKStatisticsQuery(quantityType: heartRateType, quantitySamplePredicate: nil, options: .discreteMostRecent) { query, result, error in
            if let result = result, let mostRecent = result.mostRecentQuantity() {
                DispatchQueue.main.async {
                    self.heartRate = mostRecent.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                }
            } else {
                DispatchQueue.main.async {
                    errorMessage = "Failed to fetch heart rate data."
                }
            }
        }
        healthStore.execute(query)
    }
    
    // Function to fetch active calories burned data
    private func fetchCaloriesBurned() {
        let calorieType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        let query = HKStatisticsQuery(quantityType: calorieType, quantitySamplePredicate: nil, options: .cumulativeSum) { query, result, error in
            if let result = result, let sum = result.sumQuantity() {
                DispatchQueue.main.async {
                    self.caloriesBurned = sum.doubleValue(for: HKUnit.kilocalorie())
                }
            } else {
                DispatchQueue.main.async {
                    errorMessage = "Failed to fetch calories burned data."
                }
            }
        }
        healthStore.execute(query)
    }
}

struct ChartView: View {
    let steps: Double
    let heartRate: Double
    let caloriesBurned: Double
    
    var body: some View {
        VStack {
            Text("Health Metrics")
                .font(.title)
                .padding(.top, 20)
            
            HStack(spacing: 15) {
                ChartBar(label: "Steps", value: steps, maxValue: max(steps, heartRate, caloriesBurned), color: .blue)
                ChartBar(label: "Heart Rate", value: heartRate, maxValue: max(steps, heartRate, caloriesBurned), color: .red)
                ChartBar(label: "Calories Burned", value: caloriesBurned, maxValue: max(steps, heartRate, caloriesBurned), color: .green)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
    }
}

struct ChartBar: View {
    let label: String
    let value: Double
    let maxValue: Double
    let color: Color
    
    var body: some View {
        VStack {
            Text(label)
                .font(.headline)
                .foregroundColor(.gray)
            ZStack(alignment: .bottom) {
                Capsule()
                    .frame(width: 30, height: 200)
                    .foregroundColor(Color(white: 0.9))
                Capsule()
                    .frame(width: 30, height: CGFloat(value / maxValue * 200)) // Dynamically calculate the height
                    .foregroundColor(color)
            }
            Text("\(Int(value))")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}

// Metric View
struct MetricView: View {
    let imageName: String
    let title: String
    let value: String
    
    var body: some View {
        VStack {
            Image(systemName: imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 50, height: 50)
            Text(title)
            Text(value)
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
