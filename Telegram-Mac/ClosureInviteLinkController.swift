//
//  ClosureInviteLinkController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 14.01.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Cocoa
import Postbox
import TelegramCore
import TGUIKit
import SwiftSignalKit
import InputView
import Postbox

private final class InviteLinkArguments {
    let context: AccountContext
    let interactions: TextView_Interactions
    let usageLimit:(Int32)->Void
    let limitDate: (Int32)->Void
    let tempCount:(Int32?)->Void
    let tempDate:(Int32?)->Void
    let toggleRequestApproval: (Bool)->Void
    let requestMonthlyFee: (Updated_ChatTextInputState?)->Void
    let executeLink:(String)->Void
    init(context: AccountContext, interactions: TextView_Interactions, usageLimit: @escaping(Int32)->Void, limitDate: @escaping(Int32)->Void, tempCount:@escaping(Int32?)->Void, tempDate: @escaping(Int32?)->Void, toggleRequestApproval: @escaping(Bool)->Void, executeLink:@escaping(String)->Void, requestMonthlyFee: @escaping(Updated_ChatTextInputState?)->Void) {
        self.context = context
        self.interactions = interactions
        self.usageLimit = usageLimit
        self.limitDate = limitDate
        self.tempCount = tempCount
        self.tempDate = tempDate
        self.toggleRequestApproval = toggleRequestApproval
        self.executeLink = executeLink
        self.requestMonthlyFee = requestMonthlyFee
    }
}

struct ClosureInviteLinkState: Equatable {
    fileprivate var isEditing: Bool
    fileprivate(set) var date:Int32
    fileprivate(set) var count: Int32
    fileprivate var tempCount: Int32?
    fileprivate var tempDate: Int32?
    fileprivate(set) var requestApproval: Bool
    fileprivate(set) var title: String?
    fileprivate(set) var isPublic: Bool = false
    
    var pricing: StarsSubscriptionPricing? {
        if let requestMonthlyFee {
            return .init(period: star_sub_period, amount: .init(value: requestMonthlyFee, nanos: 0))
        } else {
            return nil
        }
    }
    
    
    fileprivate var requestMonthlyFeeState: Updated_ChatTextInputState?
    
    fileprivate var requestMonthlyFee: Int64? {
        if let state = self.requestMonthlyFeeState {
            return Int64(state.string)
        } else {
            return nil
        }
    }
}

//
private let _id_period = InputDataIdentifier("_id_period")
private let _id_period_precise = InputDataIdentifier("_id_period_precise")

private let _id_count = InputDataIdentifier("_id_count")
private let _id_count_precise = InputDataIdentifier("_id_count_precise")
private let _id_title = InputDataIdentifier("_id_title")

private let _id_request_approval = InputDataIdentifier("_id_request_approval")

private let _id_request_monthly_fee = InputDataIdentifier("_id_request_monthly_fee")
private let _id_monthly_fee_input = InputDataIdentifier("_id_monthly_fee_input")

private func inviteLinkEntries(state: ClosureInviteLinkState, arguments: InviteLinkArguments, isChannel: Bool) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId: Int32 = 0
    var index: Int32 = 0
    
    
    entries.append(.sectionId(sectionId, type: .customModern(10)))
    sectionId += 1
    
    
    entries.append(.input(sectionId: sectionId, index: index, value: .string(state.title), error: nil, identifier: _id_title, mode: .plain, data: .init(viewType: .singleItem), placeholder: nil, inputPlaceholder: strings().editInvitationTitlePlaceholder, filter: { $0 }, limit: 32))
    index += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().editInvitationTitleDesc), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
    index += 1
    
    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_request_monthly_fee, data: .init(name: strings().inviteLinkSubText, color: theme.colors.text, type: .switchable(state.requestMonthlyFeeState != nil), viewType: state.requestMonthlyFeeState != nil ? .firstItem : .singleItem, enabled: !state.isEditing, action: {
        arguments.requestMonthlyFee(state.requestMonthlyFeeState != nil ? nil : .init(inputText: .initialize(string: "500")))
    })))
    index += 1
    
    
    if let inputState = state.requestMonthlyFeeState {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_monthly_fee_input, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
            return InviteLinkMonthlyFeeRowItem(initialSize, stableId: stableId, context: arguments.context, interactions: arguments.interactions, enabled: !state.isEditing, state: inputState, usdRate: XTR_USD_RATE, viewType: .lastItem, updateState: arguments.requestMonthlyFee)
        }))
    }

    let text: String
    if state.isEditing {
        text = strings().inviteLinkSubInfoEditing
    } else {
        text = strings().inviteLinkSubInfo
    }
    entries.append(.desc(sectionId: sectionId, index: index, text: .markdown(text, linkHandler: arguments.executeLink), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
    index += 1
    
    
    if !state.isPublic {
        entries.append(.sectionId(sectionId, type: .customModern(20)))
        sectionId += 1
        
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_request_approval, data: .init(name: strings().editInvitationRequestApproval, color: theme.colors.text, type: .switchable(state.requestApproval && state.requestMonthlyFeeState == nil), viewType: .singleItem, enabled: state.requestMonthlyFeeState == nil, action: {
            arguments.toggleRequestApproval(state.requestApproval)
        })))
        index += 1
        
        let requestApprovalText: String
        if state.requestMonthlyFeeState == nil {
            if state.requestApproval {
                requestApprovalText = strings().editInvitationRequestApprovalChannelOn
            } else {
                requestApprovalText = strings().editInvitationRequestApprovalChannelOff
            }
        } else {
            requestApprovalText = strings().inviteLinkSubReqApproval
        }
       
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(requestApprovalText), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
        index += 1
    }
    
    
    entries.append(.sectionId(sectionId, type: .customModern(20)))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().editInvitationLimitedByPeriod), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_period, equatable: InputDataEquatable(state), comparable: nil, item: { initialSize, stableId in
        let hour: Int32 = 60 * 60
        let day: Int32 = hour * 24 * 1
        var sizes:[Int32] = [hour, day, day * 7, Int32.max]
        
        if let temp = state.tempDate {
            var bestIndex: Int = 0
            for (i, size) in sizes.enumerated() {
                if size < temp {
                    bestIndex = i
                }
            }
            sizes[bestIndex] = temp
        }
        
        let current = state.date
        if sizes.firstIndex(where: { $0 == current }) == nil {
            var bestIndex: Int = 0
            for (i, size) in sizes.enumerated() {
                if size < current {
                    bestIndex = i
                }
            }
            sizes[bestIndex] = current
        }
        let titles: [String] = sizes.map { value in
            if value == Int32.max {
                return "∞"
            } else {
                return autoremoveLocalized(Int(value))
            }
        }
        let viewType: GeneralViewType
        if state.requestApproval {
            viewType = .singleItem
        } else {
            viewType = .firstItem
        }

        return SelectSizeRowItem(initialSize, stableId: stableId, current: current, sizes: sizes, hasMarkers: false, titles: titles, viewType: viewType, selectAction: { index in
            arguments.limitDate(sizes[index])
        })
    }))
    index += 1
        
    if !state.requestApproval {
        let dateFormatter = makeNewDateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        let dateString = state.date == .max ? strings().editInvitationNever : dateFormatter.string(from: Date(timeIntervalSinceNow: TimeInterval(state.date)))
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_period_precise, data: .init(name: strings().editInvitationExpiryDate, color: theme.colors.text, type: .context(dateString), viewType: .lastItem, action: {
            showModal(with: DateSelectorModalController(context: arguments.context, defaultDate: Date(timeIntervalSinceNow: TimeInterval(state.date == .max ? Int32.secondsInWeek : state.date)), mode: .date(title: strings().editInvitationExpiryDate, doneTitle: strings().editInvitationSave), selectedAt: { date in
                arguments.limitDate(Int32(date.timeIntervalSinceNow))
                arguments.tempDate(Int32(date.timeIntervalSinceNow))
                
            }), for: arguments.context.window)
        })))
        index += 1
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().editInvitationExpiryDesc), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
        index += 1
        
        entries.append(.sectionId(sectionId, type: .customModern(20)))
        sectionId += 1
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().editInvitationLimitedByCount), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1
        
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_count, equatable: InputDataEquatable(state), comparable: nil, item: { initialSize, stableId in
            var sizes:[Int32] = [1, 10, 50, 100, Int32.max]
            
            if let temp = state.tempCount {
                var bestIndex: Int = 0
                for (i, size) in sizes.enumerated() {
                    if size < temp {
                        bestIndex = i
                    }
                }
                sizes[bestIndex] = temp
            }
            
            let current: Int32 = state.count
            if sizes.firstIndex(where: { $0 == current }) == nil {
                var bestIndex: Int = 0
                for (i, size) in sizes.enumerated() {
                    if size < current {
                        bestIndex = i
                    }
                }
                sizes[bestIndex] = current
            }
            let titles: [String] = sizes.map { value in
                if value == Int32.max {
                    return "∞"
                } else {
                    return Int(value).prettyNumber
                }
            }
                        
            return SelectSizeRowItem(initialSize, stableId: stableId, current: current, sizes: sizes, hasMarkers: false, titles: titles, viewType: .firstItem, selectAction: { index in
                arguments.usageLimit(sizes[index])
            })
        }))
        index += 1
        
        let value = state.count == .max ? strings().editInvitationUnlimited : Int(state.count).prettyNumber
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_count_precise, data: .init(name: strings().editInvitationNumberOfUsers, color: theme.colors.text, type: .context(value), viewType: .lastItem, action: {
            showModal(with: NumberSelectorController(base: state.count == .max ? nil : Int(state.count), title: strings().editInvitationNumberOfUsers, placeholder: strings().editInvitationEnterNumber, okTitle: strings().editInvitationSave, updated: { updated in
                if let updated = updated {
                    arguments.usageLimit(Int32(updated))
                } else {
                    arguments.usageLimit(.max)
                }
                arguments.tempCount(updated != nil ? Int32(updated!) : nil)
            }), for: arguments.context.window)
        })))
        index += 1
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().editInvitationLimitDesc), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
        index += 1
        
    }
    
   
    
    
    entries.append(.sectionId(sectionId, type: .customModern(20)))
    sectionId += 1
    
    return entries
}

enum InviteLinkClosureMode : Equatable {
    case new
    case edit(_ExportedInvitation)
    
    var title: String {
        switch self {
        case .new:
            return strings().editInvitationNewTitle
        case .edit:
            return strings().editInvitationEditTitle
        }
    }
    var done: String {
        switch self {
        case .new:
            return strings().editInvitationOKCreate
        case .edit:
            return strings().editInvitationOKSave
        }
    }
    var doneColor: NSColor {
        switch self {
        case .new:
            return theme.colors.accent
        case .edit:
            return theme.colors.redUI
        }
    }
}

func ClosureInviteLinkController(context: AccountContext, peerId: PeerId, mode: InviteLinkClosureMode, isChannel: Bool, save:@escaping(ClosureInviteLinkState)->Void) -> InputDataModalController {
    var initialState = ClosureInviteLinkState(isEditing: mode != .new, date: 0, count: 0, requestApproval: false)
    let week: Int32 = 60 * 60 * 24 * 1 * 7
    switch mode {
    case .new:
        initialState.date = .max
        initialState.count = .max
    case let .edit(invitation):
        if let expireDate = invitation.expireDate {
            initialState.date = invitation.isExpired ? week : Int32(TimeInterval(expireDate) - Date().timeIntervalSince1970)
        } else {
            initialState.date = week
        }
        initialState.requestApproval = invitation.requestApproval
        initialState.tempDate = initialState.date
        initialState.title = invitation.title
        if let alreadyCount = invitation.count, let usageLimit = invitation.usageLimit {
            initialState.count = usageLimit - alreadyCount
        } else if let usageLimit = invitation.usageLimit {
            initialState.count = usageLimit
        } else {
            initialState.count = .max
        }
        if initialState.count != .max {
            initialState.tempCount = initialState.count
        }
        
        if let pricing = invitation.pricing {
            initialState.requestMonthlyFeeState = .init(inputText: .initialize(string: "\(pricing.amount)"))
        }
        
    }
    
    var getController:(()->InputDataController?)? = nil
    
    let state: ValuePromise<ClosureInviteLinkState> = ValuePromise(initialState)
    let stateValue: Atomic<ClosureInviteLinkState> = Atomic(value: initialState)
    
    let actionsDisposable = DisposableSet()
    
   
    
    let updateState:((ClosureInviteLinkState)->ClosureInviteLinkState) -> Void = { f in
        state.set(stateValue.modify(f))
    }
    
    actionsDisposable.add(getPeerView(peerId: peerId, postbox: context.account.postbox).start(next: { peer in
        updateState { current in
            var current = current
            current.isPublic = peer?.addressName != nil && !peer!.addressName!.isEmpty
            if current.isPublic {
                current.requestApproval = false
            }
            return current
        }
    }))
    
    let interactions = TextView_Interactions(presentation: initialState.requestMonthlyFeeState ?? .init())
    
    
    
    let max_monthly_fee = context.appConfiguration.getGeneralValue("stars_subscription_amount_max", orElse: 2500)

    let arguments = InviteLinkArguments(context: context, interactions: interactions, usageLimit: { value in
        updateState { current in
            var current = current
            current.count = value
            return current
        }
    }, limitDate: { value in
        updateState { current in
            var current = current
            current.date = value
            return current
        }
    }, tempCount: { value in
        updateState { current in
            var current = current
            current.tempCount = value
            return current
        }
    }, tempDate: { value in
        updateState { current in
            var current = current
            current.tempDate = value
            return current
        }
    }, toggleRequestApproval: { value in
        updateState { current in
            var current = current
            current.requestApproval = !value
            return current
        }
    }, executeLink: { link in
        execute(inapp: .external(link: link, false))
    }, requestMonthlyFee: { [weak interactions] value in
        
        if let value {
            
            let number = Int64(value.string) ?? 0
            
            var value = value
            if number > max_monthly_fee {
                let string = "\(max_monthly_fee)"
                value = .init(inputText: .initialize(string: string), selectionRange: string.length..<string.length)
                getController?()?.proccessValidation(.fail(.fields([_id_monthly_fee_input : .shake])))
            }
            
            
            interactions?.update { _ in
                return value
            }
            
            updateState { current in
                var current = current
                current.requestMonthlyFeeState = value
                return current
            }
        } else {
            updateState { current in
                var current = current
                current.requestMonthlyFeeState = nil
                return current
            }
        }
    })
    
    let dataSignal = state.get() |> deliverOnPrepareQueue |> map { state in
        return inviteLinkEntries(state: state, arguments: arguments, isChannel: isChannel)
    } |> map { entries in
        return InputDataSignalValue(entries: entries)
    }
    
    var getModalController:(()->InputDataModalController?)? = nil

    
    let controller = InputDataController(dataSignal: dataSignal, title: mode.title)
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: {
        getModalController?()?.close()
    })
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }
    
    controller.updateDatas = { data in
        updateState { current in
            var current = current
            current.title = data[_id_title]?.stringValue
            return current
        }
        return .none
    }
    
    getController = { [weak controller] in
        return controller
    }
    
    
    let modalInteractions = ModalInteractions(acceptTitle: mode.done, accept: { [weak controller] in
          controller?.validateInputValues()
    }, singleButton: true)
    
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions, closeHandler: { f in
        f()
    }, size: NSMakeSize(340, 350))
    
    getModalController = { [weak modalController] in
        return modalController
    }
    
    controller.validateData = { data in
        return .success(.custom {
            save(stateValue.with { $0 })
            getModalController?()?.close()
        })
    }
    
    
    return modalController
}
