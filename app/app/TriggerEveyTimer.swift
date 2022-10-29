//
// Created by Emil Elton Nilsen on 29/10/2022.
//

import Combine
import Foundation

class TriggerEveryTimer {

    private let triggerEverySecs: Double
    private let updateEverySecs: Double
    private var lastTriggerTime: Date = Date()
    private var timerHandle: AnyCancellable? = nil
    private let onTrigger: (() -> Void)?
    private let onUpdate: ((Double) -> Void)?

    init(triggerEvery: Double, onTrigger: @escaping (() -> Void), updateEvery: Double, onUpdate: ((Double) -> Void)? = nil) {
        self.triggerEverySecs = triggerEvery
        self.updateEverySecs = updateEvery
        self.onTrigger = onTrigger
        self.onUpdate = onUpdate
    }

    var isRunning: Bool {
        timerHandle != nil
    }

    func start() {
        lastTriggerTime = Date()
        timerHandle = Timer.publish(every: updateEverySecs, on: .main, in: .common)
                .autoconnect()
                .sink(receiveValue: { date in
                    let timeToGoSecs = self.triggerEverySecs - date.timeIntervalSince(self.lastTriggerTime)
                    if timeToGoSecs <= 0 {
                        self.onTrigger?()
                        self.lastTriggerTime = date
                    }
                    self.onUpdate?(timeToGoSecs)
                })
    }

    func stop() {
        timerHandle?.cancel()
        timerHandle = nil
    }
}