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





struct ContentView: View {
    var Heartrate: Double = 0
    var Hydration: Double = 0
    var Stress: Double = 0
    var Activity: Double = 0
    var HealthScore: Double = 0
    
    var body: some View {
        ZStack {
            // background
            Color.yellow.opacity(0.15)
                .ignoresSafeArea()
                .shadow(radius: 20)

            VStack(spacing: 16) {
                Image("NeutralFace")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .shadow(radius: 20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white, lineWidth: 4)
                    )
                // Health Cluster
                Form {
                    Section(header: Text("Health Details")) {
                        HStack(alignment: .center) {
                            Spacer()

                            //HeartRate
                            Gauge(value: Heartrate, in: 40...180) {
                                Text("BPM")
                            } currentValueLabel: {
                                Text(String(Heartrate))
                            }
                            .gaugeStyle(.accessoryCircular)
                            .tint(.red)
                            
                            
                            
                            //Hydration Level
                            Gauge(value: Hydration, in: 0...100) {
                                Text("H20")
                            } currentValueLabel: {
                                Text(String(Hydration))
                            }
                            .gaugeStyle(.accessoryCircular)
                            .tint(.blue)
                            
                            
                            
                            
                            //Stress Gauge
                            Gauge(value: Stress, in: 0...100) {
                                Text("Stress")
                            } currentValueLabel: {
                                Text(String(Stress))
                            }
                            .gaugeStyle(.accessoryCircular)
                            .tint(.purple)
                            
                            
                            
                            //Activity Gauge
                            Gauge(value: Activity, in: 0...100){
                                Text("Activ")
                            } currentValueLabel: {
                                Text(String(Activity))
                            }
                            .gaugeStyle(.accessoryCircular)
                            .tint(.yellow)
                            
                            
                            //Health Level
                            Gauge(value: HealthScore, in: 0...100){
                                Text("Health")
                            } currentValueLabel: {
                                Text(String(HealthScore))
                            }
                            .gaugeStyle(.accessoryCircular)
                            .tint(.black)
                            
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    }
                   
                    
                    Section(header: Text("Health Alerts")) {
                        Text("tests")
                        
                    }
                }
            }
        }
    }
}



#Preview {
    ContentView()
}

