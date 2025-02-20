//
//  Core.swift
//  TapToPay
//
//  Created by Viktor Charypar on 19/04/2023.
//

import Serde
import SharedTypes
import SwiftUI

@MainActor
class Core: ObservableObject {
    @Published var view = ViewModel(screen: .payment(Payment(amount: 0, status: .new)))

    func update(event: Event) {
        let reqs: [Request] = try! [Request].bincodeDeserialize(input: [UInt8](TapToPay.processEvent(Data(try! event.bincodeSerialize()))))

        for req in reqs {
            process_effect(request: req)
        }
    }

    func process_effect(request: Request) {
        switch request.effect {
        case .render:
            view = try! ViewModel.bincodeDeserialize(input: [UInt8](TapToPay.view()))
        case let .delay(.start(millis: ms)):
            Task.init {
                try? await Task.sleep(for: .milliseconds(Double(ms)))

                let effects = [UInt8](TapToPay.handleResponse(Data(request.uuid), Data([])))

                let reqs: [Request] = try! [Request].bincodeDeserialize(input: effects)
                for req in reqs {
                    process_effect(request: req)
                }
            }
        }
    }
}
