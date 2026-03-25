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


func GetHealthData(){
    
    
    
}




struct ContentView: View {
    @State private var heartRate: Double = 0
    @State private var hydration: Double = 0
    @State private var stress: Double = 0
    @State private var activity: Double = 0
    @State private var healthScore: Double = 0
    
    @State private var waterInput: String = ""
    
    var body: some View {
        ZStack {
            // background
            Color.blue.opacity(0.40)
                .ignoresSafeArea()
                .shadow(radius: 20)

            VStack(spacing: 16) {
                Image("HappyFace")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .shadow(radius: 20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.green, lineWidth: 10)
                    )
                // Health Cluster
                Form {
                    Section(header: Text("Health Details")) {
                        HStack(alignment: .center) {
                            Spacer()

                            //HeartRate
                            Gauge(value: heartRate, in: 40...180) {
                                Text("BPM")
                            } currentValueLabel: {
                                Text("\(Int(heartRate))")
                            }
                            .gaugeStyle(.accessoryCircular)
                            .tint(.red)
                            
                            
                            
                            //Hydration Level
                            Gauge(value: hydration, in: 0...100) {
                                Text("H20")
                            } currentValueLabel: {
                                Text("\(Int(hydration))")
                            }
                            .gaugeStyle(.accessoryCircular)
                            .tint(.blue)
                            
                            
                            
                            
                            //Stress Gauge
                            Gauge(value: stress, in: 0...100) {
                                Text("Stress")
                            } currentValueLabel: {
                                Text("\(Int(stress))")
                            }
                            .gaugeStyle(.accessoryCircular)
                            .tint(.purple)
                            
                            
                            
                            //Activity Gauge
                            Gauge(value: activity, in: 0...100){
                                Text("Activ")
                            } currentValueLabel: {
                                Text("\(Int(activity))")
                            }
                            .gaugeStyle(.accessoryCircular)
                            .tint(.yellow)
                            
                            
                            //Health Level
                            Gauge(value: healthScore, in: 0...100){
                                Text("Health")
                            } currentValueLabel: {
                                Text("\(Int(healthScore))")
                            }
                            .gaugeStyle(.accessoryCircular)
                            .tint(.black)
                            
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    }
                   
                    
                    Section(header: Text("Health Alerts")) {
                        if hydration < 50 {
                            Text("Low Hydration. Drink more water!")
                        }
                        
                    }
                    
                    Section(header: Text("Water")){
                        VStack(alignment: .center){
                            Text("How much water have you drank today?")
                            TextField("Enter a number in cups", text: $waterInput)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.numberPad)
                                .onChange(of: waterInput) { oldValue, newValue in
                                    if let cups = Double(newValue) {
                                        // Convert cups to a 0-100 hydration percentage as an example mapping
                                        hydration = min(100, max(0, cups / 8.0 * 100))
                                    } else if newValue.isEmpty {
                                        hydration = 0
                                    }
                                }
                            
                            
                        }
                    }
                }
            }
        }
    }
}



#Preview {
    ContentView()
}

