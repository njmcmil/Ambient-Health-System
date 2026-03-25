//
//  ContentView.swift
//  Ambient Health Interface
//
//  Created by Nathan Mcmillan on 3/23/26.
//


import SwiftUI
import Combine
import HealthKit
import HealthKitUI


var alerts: [String] = ["Low Heart Rate", "Low Hydration",
"High Stress", "Low Activity", "Low Health Score"]


var face: [String] = ["HappyFace","NeutralFace", "HydratedFace", "BoredFace", "StressedFace"]



//Request for HealthKit Access

final class HealthManager {
    static let shared = HealthManager()
    let healthStore = HKHealthStore()

    private init() {}

    // Request read authorization for heart rate
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let readTypes: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!
        ]

        try await healthStore.requestAuthorization(toShare: [], read: readTypes)
    }

    // Fetch most recent heart rate in BPM
    func fetchMostRecentHeartRate() async throws -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: .heartRate) else { return nil }

        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let predicate: NSPredicate? = nil // last sample across time
        let limit = 1

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: limit, sortDescriptors: [sort]) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard
                    let quantitySample = samples?.first as? HKQuantitySample
                else {
                    continuation.resume(returning: nil)
                    return
                }

                // Heart rate is stored as count/min
                let unit = HKUnit.count().unitDivided(by: .minute())
                let bpm = quantitySample.quantity.doubleValue(for: unit)
                continuation.resume(returning: bpm)
            }
            self.healthStore.execute(query)
        }
    }
}




struct ContentView: View {
   
    @State private var heartRate: Double = 0
    @State private var hydration: Double = 0
    @State private var stress: Double = 0
    @State private var activity: Double = 0
    @State private var healthScore: Double = 0
    @State private var isFetchingHeartRate = false
    @State private var heartRateStatus = "Tap Get BPM to refresh"
    
    @State private var waterInput: String = ""
    @FocusState private var waterFieldFocused: Bool
    
    // Clamped values to keep Gauges within bounds
    private var clampedHeartRate: Double { min(max(heartRate, 40), 180) }
    private var clampedHydration: Double { min(max(hydration, 0), 100) }
    private var clampedStress: Double { min(max(stress, 0), 100) }
    private var clampedActivity: Double { min(max(activity, 0), 100) }
    private var clampedHealthScore: Double { min(max(healthScore, 0), 100) }
    
    private var selectedFace: String {
        // Priority: critical first, then warnings, then hydration, then neutral
        //if heartRate > 100 || heartRate < 50 { return face[4] }   // StressedFace for HR out of range
        //if healthScore < 50 { return face[4] }                     // StressedFace for low health score
        //if stress > 50 { return face[4] }                          // StressedFace for high stress
        //if activity < 50 { return face[3] }                        // BoredFace for low activity
        if hydration < 50 { return face[2] }                       // Hydration face indicates need to drink water
        return face[1]                                             // NeutralFace fallback
    }
    
    private var overlayColor: Color {
        if healthScore > 50 {return .green}
        //else if stress > 50 { return .purple }
        else if hydration < 50 { return .blue }
        //else if activity < 50 { return .yellow}
        //else if healthScore < 50 { return .purple }
        //else if heartRate > 100 || heartRate < 50 { return .purple}
        
        

        return .white
    }
    
    
    private var overlayGradient: LinearGradient? {
        if hydration < 50 {
            return LinearGradient(colors: [.blue, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        
        //if healthScore < 50 {
        //    return LinearGradient(colors: [.red, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
        //}
        
        //if stress > 50 {
        //    return LinearGradient(colors: [.purple, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
       // }
        
        
        else {
            return nil
        }
    }
    
    private func refreshHeartRate() async {
        guard !isFetchingHeartRate else { return }

        isFetchingHeartRate = true
        defer { isFetchingHeartRate = false }

        do {
            if let bpm = try await HealthManager.shared.fetchMostRecentHeartRate() {
                heartRate = bpm
                heartRateStatus = "Last reading: \(Int(bpm.rounded())) BPM"
            } else {
                heartRateStatus = "No heart rate data available"
            }
        } catch {
            heartRateStatus = "Unable to refresh BPM"
        }
    }
    
    
    var body: some View {
        ZStack {
            // background
            Color.blue.opacity(0.40)
                .ignoresSafeArea()
                .shadow(radius: 20)

            
            VStack(spacing: 16) {
                Image(selectedFace)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .shadow(radius: 20)
                    .overlay(
                        Group {
                            if let gradient = overlayGradient {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(gradient, lineWidth: 10)
                            } else {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(overlayColor, lineWidth: 10)
                            }
                        }
                    )
                    .animation(.easeInOut, value: hydration).animation(.easeInOut, value: stress)
                
                
                
                
                // Health Cluster
                Form {
                    
                    Section(header: Text("Health Details")) {
                                            HStack(alignment: .center) {
                                                Spacer()

                                                //HeartRate
                                                Gauge(value: clampedHeartRate, in: 40...180) {
                                                    Text("BPM")
                                                } currentValueLabel: {
                                                    Text("\(Int(clampedHeartRate))")
                                                }
                                                .gaugeStyle(.accessoryCircular)
                                                .tint(.red)
                                                
                                                
                                                
                                                //Hydration Level
                                                Gauge(value: clampedHydration, in: 0...100) {
                                                    Text("H20")
                                                } currentValueLabel: {
                                                    Text("\(Int(clampedHydration))")
                                                }
                                                .gaugeStyle(.accessoryCircular)
                                                .tint(.blue)
                                                
                                                
                                                
                                                
                                                //Stress Gauge
                                                Gauge(value: clampedStress, in: 0...100) {
                                                    Text("Stress")
                                                } currentValueLabel: {
                                                    Text("\(Int(clampedStress))")
                                                }
                                                .gaugeStyle(.accessoryCircular)
                                                .tint(.purple)
                                                
                                                
                                                
                                                //Activity Gauge
                                                Gauge(value: clampedActivity, in: 0...100){
                                                    Text("Activ")
                                                } currentValueLabel: {
                                                    Text("\(Int(clampedActivity))")
                                                }
                                                .gaugeStyle(.accessoryCircular)
                                                .tint(.yellow)
                                                
                                                
                                                //Health Level
                                                Gauge(value: clampedHealthScore, in: 0...100){
                                                    Text("Health")
                                                } currentValueLabel: {
                                                    Text("\(Int(clampedHealthScore))")
                                                }
                                                .gaugeStyle(.accessoryCircular)
                                                .tint(.black)
                                                
                                                Spacer()
                                            }
                                            .frame(maxWidth: .infinity)
                                        }

                    
                    
                    Section(header: Text("Heart Health")){
                        Button {
                            Task {
                                await refreshHeartRate()
                            }
                        } label: {
                            Text(isFetchingHeartRate ? "Refreshing..." : "Get BPM")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isFetchingHeartRate)
                        
                        Text(heartRateStatus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            
                    }
                    
                    
                   
                    
                    Section(header: Text("Health Alerts")) {
                        
                        VStack{
                            if hydration < 50 {
                                Text(alerts[1])
                            }
                            
                            
                            
                        
                            
                        }
                    }
                    
                    Section(header: Text("Water")) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("How much water have you drank today?")

                            // Cups input
                            HStack {
                                TextField("Enter cups", text: $waterInput)
                                    .textFieldStyle(.roundedBorder)
                                    .keyboardType(.decimalPad)
                                    .focused($waterFieldFocused)
                                    .submitLabel(.done)
                                    .onChange(of: waterInput) { oldValue, newValue in
                                        // cups -> hydration (8 cups == 100%)
                                        if let cups = Double(newValue) {
                                            hydration = min(100, max(0, cups / 8.0 * 100.0))
                                        } else if newValue.isEmpty {
                                            hydration = 0
                                        }
                                    }
                                    .toolbar {
                                        ToolbarItemGroup(placement: .keyboard) {
                                            Spacer()
                                            Button("Done") {
                                                waterFieldFocused = false
                                            }
                                        }
                                    }
                                    .onSubmit {
                                        waterFieldFocused = false
                                    }

                                Text("cups")
                            }

                            // Hydration slider
                            Slider(value: $hydration, in: 0...100, step: 1)
                                .onChange(of: hydration) { oldValue, newValue in
                                    // hydration -> cups
                                    let cups = newValue / 100.0 * 8.0
                                    waterInput = String(format: "%.1f", cups)
                                }

                            // Helpful readouts
                            Text("Hydration: \(Int(hydration))%")
                            Text("Cups: \(waterInput)")
                        }
                    }
                    
                    
                    
                    
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                waterFieldFocused = false
            }
        }
        .task {
            do {
                try await HealthManager.shared.requestAuthorization()
            } catch {
                heartRateStatus = "Health access not granted"
            }
        }
    }
}



#Preview {
    ContentView()
}
