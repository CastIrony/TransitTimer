//
//  ContentView.swift
//  TransitTimer
//
//  Created by Joel Bernstein on 11/5/21.
//

import SwiftUI

struct ContentView: View {
    @State var stopIDs: [Int] = [ 8377, 7751, 13171 ]
    @State var lastUpdateBegan = Date()
    @State var schedule: Model.Schedule?
    var body: some View {
        TabView {
            ForEach(Array(stopIDs.enumerated()), id: \.element) { index, stopID in
                StopView(schedule: schedule, stop: schedule?.stopsByStopID[stopID], refreshAction: refresh)
            }
        }
        .tabViewStyle(.page)
        .ignoresSafeArea(.all, edges: .bottom)
        .padding(.horizontal, -20)
        .task(id: lastUpdateBegan) {
            do {
                print("starting download")
                let appID = "Enter Trimet App ID here"
                let url = URL(string: "https://developer.trimet.org/ws/v2/arrivals?appID=\(appID)&locIDs=\(stopIDs.map({ String($0) }).joined(separator: ","))&showPosition=true&minutes=60&arrivals=20")!
                let (data, _) = try await URLSession.shared.data(from: url)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .millisecondsSince1970
                var newSchedule = try decoder.decode(Model.Response.self, from: data).schedule
                newSchedule.postProcess()
                
                withAnimation(.spring()) {
                    schedule = newSchedule
                }
                print("download complete")
            } catch {
                print("error with download/parse \(error)")
            }
        }
    }
    
    func refresh() {
        lastUpdateBegan = Date()
    }
}

extension View {
    func debugPrint(_ value: Any) -> some View {
        #if DEBUG
        print(value)
        #endif
        return self
    }
}



struct StopView: View {
    let schedule: Model.Schedule?
    let stop: Model.Stop?
    let refreshAction: () -> Void
    var arrivals: [Model.Arrival] {
        guard let stopID = stop?.stopID else { return [] }
        return schedule?.arrivalsByStopID[stopID] ?? []
    }
    @State var frames: [String : CGRect] = [:]
    
    func rowVisibility(for arrivalID: String) -> Double {
        guard let scrollViewFrame = frames["foo"] else { print("missing scrollViewFrame"); return 0.5 }
        guard let rowFrame = frames[arrivalID] else { print("missing rowFrame[\(arrivalID)]"); return 0.5 }
        
        let scrollViewMinY = scrollViewFrame.minY + 50

        if scrollViewMinY > rowFrame.maxY { return 0 }
        if scrollViewFrame.maxY < rowFrame.minY { return 0 }
        
        if scrollViewMinY > rowFrame.minY && scrollViewMinY < rowFrame.maxY {
            return (rowFrame.maxY - scrollViewMinY) / rowFrame.height
        }

        if scrollViewFrame.maxY > rowFrame.minY && scrollViewFrame.maxY < rowFrame.maxY {
            return (scrollViewFrame.maxY - rowFrame.minY) / rowFrame.height
        }
        
        return 1
    }

    func rowOpacity(for arrivalID: String) -> Double {
        guard let scrollViewFrame = frames["foo"] else { print("missing scrollViewFrame"); return 0.5 }
        guard let rowFrame = frames[arrivalID] else { print("missing rowFrame[\(arrivalID)]"); return 0.5 }
        
        let scrollViewMinY = scrollViewFrame.minY + 50
        
        if scrollViewMinY > rowFrame.maxY { return 0 }
        
        if scrollViewMinY > rowFrame.minY && scrollViewMinY < rowFrame.maxY {
            return (rowFrame.maxY - scrollViewMinY) / rowFrame.height
        }
        
        return 1
    }

    var arrivalOpacities: [String : Double] {
        Dictionary(uniqueKeysWithValues: arrivals.map{ arrival in (arrival.id, rowVisibility(for: arrival.id)) })
    }

    
    var body: some View {
        GeometryReader { proxy in
            let frame = proxy.frame(in: .global)
            VStack(spacing: 0){
                HStack {
                    Text(stop?.name ?? "--")
                }
                .font(.title2)
                .padding(10)
                .offset(x: -0.75 * frame.minX, y: 0)
                .opacity((frame.width - abs(frame.minX)) / frame.width)
                
                let dialRadius = (frame.width - 40) * 0.46
                
                TimelineView(.animation(minimumInterval: 0.2)) { context in
                    DialView(arrivalOpacities: arrivalOpacities, currentDate: context.date, arrivals: arrivals, dialRadius: dialRadius, centerRadius: dialRadius * 0.15, ringMargin: dialRadius * 0.015)
                    .overlay(
                        Button(action: refreshAction) {
                            Label("Refresh", systemImage: "arrow.triangle.2.circlepath").labelStyle(.iconOnly)
                        }
                    )
                    .padding(.vertical, 10)
                }
                
                ScrollView {
                    TimelineView(.periodic(from: .now, by: 2)) { context in
                        VStack {
                            ForEach(arrivals) { arrival in
                                ArrivalView(arrival: arrival, currentDate: context.date)
                                .measureFrame(in: .global, key: arrival.id)
                                .opacity(rowOpacity(for: arrival.id))
                                .blur(radius: (1 - rowOpacity(for: arrival.id)) * 20 )
                            }
                        }
                        .padding(.vertical, 50)
                        .padding(.horizontal, 10)
                    }
                }
                .padding(.horizontal, 20)
                .measureFrame(in: .global, key: "foo")
                .padding(.top, -30)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .onPreferenceChange(MeasureFramePreferenceKey.self) { newFrames in
            frames = newFrames
        }
    }
}

struct DialView: View {
    let arrivalOpacities: [String : Double]
    let currentDate: Date
    let arrivals: [Model.Arrival]
    let dialRadius: CGFloat
    let centerRadius: CGFloat
    let ringMargin: CGFloat
    let dialColor: Color = .white
    var body: some View {
        ZStack {
            Circle()
                .fill(dialColor)
                .frame(width: dialRadius * 2, height: dialRadius * 2, alignment: .center)
            ForEach(Array(arrivals.enumerated()), id: \.element.id) { index, arrival in
                RingView(
                    dialRadius: dialRadius,
                    ringColor: Color(arrival.route.color),
                    ringOpacity: arrivalOpacities[arrival.id] ?? 0,
                    ringSymbol: arrival.route.symbol,
                    ringWidth: ringWidth(for: index),
                    ringRadius: ringRadius(for: index),
                    ringAngle: ringAngle(for: arrival)
                )
            }
        }
    }
    
    func ringAngle(for arrival: Model.Arrival) -> Angle {
        var degrees: Double = arrival.scheduledDate.timeIntervalSince(currentDate) / 10
        if degrees < 1 { degrees = 1 }
        if degrees > 360 { degrees = 360 }
        return Angle(degrees: degrees)
    }

    func ringSpace(for index: Int) -> Double {
        guard index >= 0 && index < arrivals.count else { return 0 }
        let arrival = arrivals[index]
        return 10 * (arrivalOpacities[arrival.id] ?? 0)
    }
    
    func cumulativeRingSpace(through limit: Int) -> Double{
        var total: Double = 0
        for index in 0 ..< limit {
            total += ringSpace(for: index)
        }
        return total
    }
    
    func totalRingSpace() -> Double {
        cumulativeRingSpace(through: arrivals.count)
    }
    
    func ringRadius(for index: Int) -> Double {
        let totalRingSpace = totalRingSpace()
        let cumulativeRingSpace = cumulativeRingSpace(through: index)
        let ringSpace = ringSpace(for: index)
        
        return dialRadius - (((cumulativeRingSpace + 0.5 * ringSpace) / totalRingSpace) * (dialRadius - centerRadius))
    }
    
    func ringWidth(for index: Int) -> Double {
        let ringSpace = ringSpace(for: index)
        let totalRingSpace = totalRingSpace()
        return (ringSpace / totalRingSpace) * (dialRadius - centerRadius)
    }
    
}

struct RingView: View {
    let dialRadius: CGFloat
    let ringColor: Color
    let ringOpacity: Double
    let ringSymbol: String

    var ringWidth: CGFloat
//    {
//        let totalWidth = dialRadius - centerRadius
//        let marginWidth = ringMargin * CGFloat(ringCount + 1)
//
//        return (totalWidth - marginWidth) / CGFloat(ringCount)
//    }
    
    var ringRadius: CGFloat
//    {
//        let ringWidth = ringWidth
//        let innerEdge = dialRadius - (ringWidth + ringMargin) * CGFloat(ringIndex + 1)
//        return innerEdge + ringWidth / 2
//    }

    var ringAngle: Angle
//    {
//        var degrees: Double = timeInterval / 10
//        if degrees < 1 { degrees = 1 }
//        if degrees > 360 { degrees = 360 }
//        return Angle(degrees: degrees)
//    }
    
    var body: some View {
        ZStack {
            RingGutter(radius: ringRadius).stroke(ringColor.opacity(0.3), lineWidth: ringWidth * 0.85)
                .opacity(ringOpacity)
                .animation(.linear, value: ringRadius)

            RingArc(radius: ringRadius, angle: ringAngle, direction: .clockwise).stroke(ringColor, lineWidth: ringWidth * 0.85)
                .opacity(ringOpacity)
                .animation(.linear, value: ringAngle)
                .animation(.linear, value: ringRadius)
            
            Text(ringSymbol)
                .font(.caption.bold())
                .padding(.horizontal, 5)
                .padding(.bottom, 5)
                .padding(.top, 2)
                .offset(x: 0, y: -ringRadius)
                .rotationEffect(-ringAngle + Angle(degrees: 2.5 * dialRadius * Double(ringSymbol.count) / ringRadius))
                .opacity(ringOpacity)
                .blur(radius: (1 - ringOpacity) * 20 )
        }
    }
}

struct RingGutter: Shape {
    let radius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()

        let ringRect = CGRect(x: rect.midX - radius, y: rect.midY - radius, width: 2 * radius, height: 2 * radius)
        
        path.addEllipse(in: ringRect)
        
        return path
    }
}

struct RingArc: Shape {
    let radius: CGFloat
    let angle: Angle
    let direction: Direction
    
    var startAngle: Angle {
        switch direction {
        case .counterClockwise: return Angle(degrees: -90) + angle
        case .clockwise: return Angle(degrees: -90)
        }
    }
    
    var endAngle: Angle {
        switch direction {
        case .counterClockwise: return Angle(degrees: -90)
        case .clockwise: return Angle(degrees: -90) - angle
        }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()

        path.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
        
        return path
    }
    
    enum Direction {
        case clockwise
        case counterClockwise
    }
}

struct Tag: Shape {
    let radius: CGFloat
    let pointHeight: CGFloat
    
    func path(in rect: CGRect) -> Path {
        
        let x1 = rect.minX + radius
        let x2 = rect.midX - pointHeight
        let x3 = rect.midX
        let x4 = rect.midX + pointHeight
        let x5 = rect.maxX - radius
        
        let y1 = rect.minY + radius
        let y2 = rect.maxY - pointHeight - radius
        let y3 = rect.maxY - pointHeight
        let y4 = rect.maxY
        
        var path = Path()
        
        path.addArc(center: CGPoint(x: x1, y: y2), radius: radius, startAngle: Angle(degrees:  90), endAngle: Angle(degrees: 180), clockwise: false)
        path.addArc(center: CGPoint(x: x1, y: y1), radius: radius, startAngle: Angle(degrees: 180), endAngle: Angle(degrees: 270), clockwise: false)
        path.addArc(center: CGPoint(x: x5, y: y1), radius: radius, startAngle: Angle(degrees: 270), endAngle: Angle(degrees: 360), clockwise: false)
        path.addArc(center: CGPoint(x: x5, y: y2), radius: radius, startAngle: Angle(degrees:   0), endAngle: Angle(degrees:  90), clockwise: false)

        path.addLine(to: CGPoint(x: x4, y: y3))
        path.addLine(to: CGPoint(x: x3, y: y4))
        path.addLine(to: CGPoint(x: x2, y: y3))
        path.addLine(to: CGPoint(x: x1, y: y3))
        
        return path
    }
}

struct ArrivalView: View {
    let arrival: Model.Arrival
    let currentDate: Date
    var body: some View {
        HStack {
            Label(arrival.route.symbol, systemImage: arrival.route.iconName)
                .padding(10)
                .background(Color(arrival.route.color), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            Text(arrival.displayName)
            Spacer()
            let formattedTime: String = {
                let timeInterval = arrival.scheduledDate.timeIntervalSince(currentDate)
                guard timeInterval > 60 else { return "Now" }
                let formatter = DateComponentsFormatter()
                formatter.unitsStyle = .abbreviated
                formatter.allowedUnits = [.minute]
                return formatter.string(from: timeInterval) ?? "--"
            }()
            Text(formattedTime)
        }
       // .padding([.top, .bottom], 10)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ContentView()
                .previewDevice("iPhone 12 Pro")
        }
    }
}

extension View {
    func measureFrame(in coordinateSpace: CoordinateSpace, key: String) -> some View {
        return modifier(MeasureFrameModifier(coordinateSpace: coordinateSpace, key: key))
    }
}

struct MeasureFramePreferenceKey: PreferenceKey {
    static var defaultValue: [String : CGRect] = [:]

    static func reduce(value: inout [String : CGRect], nextValue: () -> [String : CGRect]) {
        value = value.merging(nextValue(), uniquingKeysWith: { (_, last) in last })
    }
}

struct MeasureFrameModifier: ViewModifier {
    let coordinateSpace: CoordinateSpace
    let key: String

    func body(content: Content) -> some View {
        content.background(
            GeometryReader {
                Color.clear.preference(key: MeasureFramePreferenceKey.self, value: [key: $0.frame(in: coordinateSpace)])
            }
        )
    }
}
