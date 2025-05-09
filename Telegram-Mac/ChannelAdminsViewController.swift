//
//  GroupAdminsViewController.swift
//  Telegram
//
//  Created by keepcoder on 22/02/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import Postbox
import TelegramCore

import SwiftSignalKit

fileprivate final class ChannelAdminsControllerArguments {
    let context: AccountContext
    let addAdmin: () -> Void
    let openAdmin: (RenderedChannelParticipant) -> Void
    let removeAdmin: (PeerId) -> Void
    let eventLogs:() -> Void
    let toggleAntispam: (Bool)->Void
    let toggleSignaturesAndProfile:(Bool, Bool)->Void
    init(context: AccountContext, addAdmin:@escaping()->Void, openAdmin:@escaping(RenderedChannelParticipant) -> Void, removeAdmin:@escaping(PeerId)->Void, eventLogs: @escaping()->Void, toggleAntispam:@escaping(Bool)->Void, toggleSignaturesAndProfile:@escaping(Bool, Bool)->Void) {
        self.context = context
        self.addAdmin = addAdmin
        self.openAdmin = openAdmin
        self.removeAdmin = removeAdmin
        self.eventLogs = eventLogs
        self.toggleAntispam = toggleAntispam
        self.toggleSignaturesAndProfile = toggleSignaturesAndProfile
    }
}

fileprivate enum ChannelAdminsEntryStableId: Hashable {
    case index(Int32)
    case peer(PeerId)
    
    var index: Int32 {
        switch self {
        case let .index(index):
            return index
        case .peer:
            return 20
        }
    }
    
}


fileprivate enum ChannelAdminsEntry : Identifiable, Comparable {
    case eventLogs(sectionId:Int32, GeneralViewType)
    case antispam(sectionId:Int32, Bool, GeneralViewType)
    case antispamInfo(sectionId:Int32, GeneralViewType)
    case adminsHeader(sectionId:Int32, String, GeneralViewType)
    case adminPeerItem(sectionId:Int32, Int32, RenderedChannelParticipant, ShortPeerDeleting?, GeneralViewType)
    case addAdmin(sectionId:Int32, GeneralViewType)
    case adminsInfo(sectionId:Int32, String, GeneralViewType)
    case signMessages(sectionId: Int32, sign:Bool, show:Bool, viewType: GeneralViewType)
    case showAuthorProfiles(sectionId: Int32, sign:Bool, show:Bool, viewType: GeneralViewType)
    case signMessagesInfo(sectionId: Int32, sign: Bool, viewType: GeneralViewType)
    case section(Int32)
    case loading
    var stableId: ChannelAdminsEntryStableId {
        switch self {
        case .loading:
            return .index(0)
        case .eventLogs:
            return .index(1)
        case .antispam:
            return .index(2)
        case .antispamInfo:
            return .index(3)
        case .adminsHeader:
            return .index(4)
        case .addAdmin:
            return .index(5)
        case .adminsInfo:
            return .index(6)
        case .signMessages:
            return .index(7)
        case .showAuthorProfiles:
            return .index(8)
        case .signMessagesInfo:
            return .index(9)
        case let .section(sectionId):
            return .index((sectionId + 1) * 1000 - sectionId)
        case let .adminPeerItem(_, _, participant, _, _):
            return .peer(participant.peer.id)
        }
    }

    
    var index:Int32 {
        switch self {
        case .loading:
            return 0
        case let .eventLogs(sectionId, _):
            return (sectionId * 1000) + stableId.index
        case let .antispam(sectionId, _, _):
            return (sectionId * 1000) + stableId.index
        case let .antispamInfo(sectionId, _):
            return (sectionId * 1000) + stableId.index
        case let .adminsHeader(sectionId, _, _):
            return (sectionId * 1000) + stableId.index
        case let .addAdmin(sectionId, _):
            return (sectionId * 1000) + stableId.index
        case let .adminsInfo(sectionId, _, _):
            return (sectionId * 1000) + stableId.index
        case let .signMessages(sectionId, _, _, _):
            return (sectionId * 1000) + stableId.index
        case let .showAuthorProfiles(sectionId, _, _, _):
            return (sectionId * 1000) + stableId.index
        case let .signMessagesInfo(sectionId, _, _):
            return (sectionId * 1000) + stableId.index
        case let .adminPeerItem(sectionId, index, _, _, _):
            return (sectionId * 1000) + index + stableId.index
        case let .section(sectionId):
            return (sectionId + 1) * 1000 - sectionId
        }
    }
    
    static func <(lhs: ChannelAdminsEntry, rhs: ChannelAdminsEntry) -> Bool {
        return lhs.index < rhs.index
    }
}


fileprivate struct ChannelAdminsControllerState: Equatable {
    var editing: Bool = false
    var removingPeerId: PeerId?
    var removedPeerIds: Set<PeerId> = Set()
    var temporaryAdmins: [RenderedChannelParticipant] = []
    var signature: Bool?
    var showProfile: Bool?
    
    func withUpdatedEditing(_ editing: Bool) -> ChannelAdminsControllerState {
        return ChannelAdminsControllerState(editing: editing, removingPeerId: self.removingPeerId, removedPeerIds: self.removedPeerIds, temporaryAdmins: self.temporaryAdmins, signature: self.signature, showProfile: self.showProfile)
    }
    
    func withUpdatedPeerIdWithRevealedOptions(_ peerIdWithRevealedOptions: PeerId?) -> ChannelAdminsControllerState {
        return ChannelAdminsControllerState(editing: self.editing, removingPeerId: self.removingPeerId, removedPeerIds: self.removedPeerIds, temporaryAdmins: self.temporaryAdmins, signature: self.signature, showProfile: self.showProfile)
    }
    
    func withUpdatedRemovingPeerId(_ removingPeerId: PeerId?) -> ChannelAdminsControllerState {
        return ChannelAdminsControllerState(editing: self.editing, removingPeerId: removingPeerId, removedPeerIds: self.removedPeerIds, temporaryAdmins: self.temporaryAdmins, signature: self.signature, showProfile: self.showProfile)
    }
    
    func withUpdatedRemovedPeerIds(_ removedPeerIds: Set<PeerId>) -> ChannelAdminsControllerState {
        return ChannelAdminsControllerState(editing: self.editing, removingPeerId: self.removingPeerId, removedPeerIds: removedPeerIds, temporaryAdmins: self.temporaryAdmins, signature: self.signature, showProfile: self.showProfile)
    }
    
    func withUpdatedTemporaryAdmins(_ temporaryAdmins: [RenderedChannelParticipant]) -> ChannelAdminsControllerState {
        return ChannelAdminsControllerState(editing: self.editing, removingPeerId: self.removingPeerId, removedPeerIds: self.removedPeerIds, temporaryAdmins: temporaryAdmins, signature: self.signature, showProfile: self.showProfile)
    }
}

private func channelAdminsControllerEntries(context: AccountContext, accountPeerId: PeerId, view: PeerView, state: ChannelAdminsControllerState, participants: [RenderedChannelParticipant]?, isCreator: Bool) -> [ChannelAdminsEntry] {
    var entries: [ChannelAdminsEntry] = []
    
    let participants = participants ?? []
    

    var sectionId:Int32 = 1
    
    entries.append(.section(sectionId))
    sectionId += 1
    
    if let peer = view.peers[view.peerId] as? TelegramChannel, let cachedData = view.cachedData as? CachedChannelData {
        var isGroup = false
        if case .group = peer.info {
            isGroup = true
        }
        
        
        
        let configuration = AntiSpamBotConfiguration.with(appConfiguration: context.appConfiguration)
        
        let members = cachedData.participantsSummary.memberCount ?? 0
        
        if isGroup, peer.isForum, members >= configuration.group_size_min {
            entries.append(.eventLogs(sectionId: sectionId, .firstItem))
            entries.append(.antispam(sectionId: sectionId, cachedData.flags.contains(.antiSpamEnabled), .lastItem))
            entries.append(.antispamInfo(sectionId: sectionId, .textBottomItem))
        } else {
            entries.append(.eventLogs(sectionId: sectionId, .singleItem))
        }
        
        entries.append(.section(sectionId))
        sectionId += 1
        
        entries.append(.adminsHeader(sectionId: sectionId, isGroup ? strings().adminsGroupAdmins : strings().adminsChannelAdmins, .textTopItem))
        
        
        if peer.hasPermission(.addAdmins)  {
            entries.append(.addAdmin(sectionId: sectionId, .singleItem))
            entries.append(.adminsInfo(sectionId: sectionId, isGroup ? strings().adminsGroupDescription : strings().adminsChannelDescription, .textBottomItem))
            
            entries.append(.section(sectionId))
            sectionId += 1
        }
        
        
        var index: Int32 = 0
        for (i, participant) in participants.sorted(by: <).enumerated() {
            var editable = true
            switch participant.participant {
            case .creator:
                editable = false
            case let .member(id, _, adminInfo, _, _, _):
                if id == accountPeerId {
                    editable = false
                } else if let adminInfo = adminInfo {
                    if peer.flags.contains(.isCreator) || adminInfo.promotedBy == accountPeerId {
                        editable = true
                    } else {
                        editable = false
                    }
                } else {
                    editable = false
                }
            }
            
            let editing:ShortPeerDeleting?
            if state.editing {
                editing = ShortPeerDeleting(editable: editable)
            } else {
                editing = nil
            }
            
            entries.append(.adminPeerItem(sectionId: sectionId, index, participant, editing, bestGeneralViewType(participants, for: i)))
            index += 1
        }
        
        if index > 0 {
            entries.append(.section(sectionId))
            sectionId += 1
        }
        
        if !isGroup {
            
            let messagesShouldHaveSignatures:Bool
            switch peer.info {
            case let .broadcast(info):
                messagesShouldHaveSignatures = info.flags.contains(.messagesShouldHaveSignatures)
            default:
                messagesShouldHaveSignatures = false
            }
            
            let messagesShouldHaveAuthor:Bool
            switch peer.info {
            case let .broadcast(info):
                messagesShouldHaveAuthor = info.flags.contains(.messagesShouldHaveProfiles)
            default:
                messagesShouldHaveAuthor = false
            }
            
            if peer.hasPermission(.changeInfo) {        
                let sign = state.signature ?? messagesShouldHaveSignatures
                let show = state.showProfile ?? messagesShouldHaveAuthor
                entries.append(.signMessages(sectionId: sectionId, sign: sign, show: show, viewType: !sign ? .singleItem : .firstItem))
                if sign {
                    entries.append(.showAuthorProfiles(sectionId: sectionId, sign: sign, show: show, viewType: .lastItem))
                }
                entries.append(.signMessagesInfo(sectionId: sectionId, sign: !sign, viewType: .textBottomItem))

                entries.append(.section(sectionId))
                sectionId += 1

            }

        }
        
    } else  if let peer = view.peers[view.peerId] as? TelegramGroup {
        
        entries.append(.adminsHeader(sectionId: sectionId, strings().adminsGroupAdmins, .textTopItem))
        
        
        if case .creator = peer.role {
            entries.append(.addAdmin(sectionId: sectionId, .singleItem))
            entries.append(.adminsInfo(sectionId: sectionId, strings().adminsGroupDescription, .textBottomItem))
            
            entries.append(.section(sectionId))
            sectionId += 1
        }
        
        
        var combinedParticipants: [RenderedChannelParticipant] = participants
        var existingParticipantIds = Set<PeerId>()
        for participant in participants {
            existingParticipantIds.insert(participant.peer.id)
        }
        
        for participant in state.temporaryAdmins {
            if !existingParticipantIds.contains(participant.peer.id) {
                combinedParticipants.append(participant)
            }
        }
        
        var index: Int32 = 0
        let participants = combinedParticipants.sorted(by: <).filter {
            !state.removedPeerIds.contains($0.peer.id)
        }
        for (i, participant) in participants.enumerated() {
            var editable = true
            switch participant.participant {
            case .creator:
                editable = false
            case let .member(id, _, adminInfo, _, _, _):
                if id == accountPeerId {
                    editable = false
                } else if let adminInfo = adminInfo {
                    var creator: Bool = false
                    if case .creator = peer.role {
                        creator = true
                    }
                    if creator || adminInfo.promotedBy == accountPeerId {
                        editable = true
                    } else {
                        editable = false
                    }
                } else {
                    editable = false
                }
            }
            let editing:ShortPeerDeleting?
            if state.editing {
                editing = ShortPeerDeleting(editable: editable)
            } else {
                editing = nil
            }
            entries.append(.adminPeerItem(sectionId: sectionId, index, participant, editing, bestGeneralViewType(participants, for: i)))
            index += 1
        }
        if index > 0 {
            entries.append(.section(sectionId))
            sectionId += 1
        }
    }
    
    return entries.sorted(by: <)
}


fileprivate func prepareTransition(left:[AppearanceWrapperEntry<ChannelAdminsEntry>], right: [AppearanceWrapperEntry<ChannelAdminsEntry>], initialSize:NSSize, arguments:ChannelAdminsControllerArguments, isSupergroup:Bool) -> TableUpdateTransition {
    
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        switch entry.entry {
        case let .adminPeerItem(_, _, participant, editing, viewType):
            let peerText: String
            switch participant.participant {
            case .creator:
                peerText = strings().adminsOwner
            case let .member(_, _, adminInfo, _, _, _):
                if let adminInfo = adminInfo, let peer = participant.peers[adminInfo.promotedBy] {
                    peerText =  strings().channelAdminsPromotedBy(peer.displayTitle)
                } else {
                    peerText = strings().adminsAdmin
                }
            }
            
            let interactionType:ShortPeerItemInteractionType
            if let editing = editing {
                
                interactionType = .deletable(onRemove: { adminId in
                    arguments.removeAdmin(adminId)
                }, deletable: editing.editable)
            } else {
                interactionType = .plain
            }
            
            return ShortPeerRowItem(initialSize, peer: participant.peer, account: arguments.context.account, context: arguments.context, stableId: entry.stableId, status: peerText, inset: NSEdgeInsets(left: 20, right: 20), interactionType: interactionType, generalType: .none, viewType: viewType, action: {
                if editing == nil {
                    arguments.openAdmin(participant)
                }
            })

        case let .addAdmin(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: entry.stableId, name: strings().adminsAddAdmin,  nameStyle: blueActionButton, type: .next, viewType: viewType, action: arguments.addAdmin)
        case let .eventLogs(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: entry.stableId, name: strings().channelAdminsRecentActions, type: .next, viewType: viewType, action: arguments.eventLogs)
        case let .antispam(_, value, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: entry.stableId, name: strings().channelAdminsAggressiveAntiSpam, type: .switchable(value), viewType: viewType, action: {
                arguments.toggleAntispam(!value)
            })
        case let .antispamInfo(_, viewType):
            return GeneralTextRowItem(initialSize, stableId: entry.stableId, text: strings().channelAdminsAggressiveAntiSpamInfo, viewType: viewType)
        case .section:
            return GeneralRowItem(initialSize, height: 20, stableId: entry.stableId, viewType: .separator)
        case .loading:
            return SearchEmptyRowItem(initialSize, stableId: entry.stableId, isLoading: true)
        case let .adminsHeader(_, text, viewType):
        return GeneralTextRowItem(initialSize, stableId: entry.stableId, text: text, viewType: viewType)
        case let .adminsInfo(_, text, viewType):
            return GeneralTextRowItem(initialSize, stableId: entry.stableId, text: text, viewType: viewType)
        case let .signMessages(_, sign, show, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: entry.stableId, name: strings().peerInfoSignMessages, type: .switchable(sign), viewType: viewType, action: { [weak arguments] in
                arguments?.toggleSignaturesAndProfile(!sign, show)
            }, enabled: true)
        case let .showAuthorProfiles(_, sign, show, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: entry.stableId, name: strings().peerInfoShowAuthorProfiles, type: .switchable(show), viewType: viewType, action: { [weak arguments] in
                arguments?.toggleSignaturesAndProfile(sign, !show)
            }, enabled: true)
        case let .signMessagesInfo(_, sign, viewType):
            return GeneralTextRowItem(initialSize, stableId: entry.stableId, text: sign ? strings().peerInfoSignMessagesDesc : strings().peerInfoSignMessagesAndShowAuthorDesc, viewType: viewType)

        }
    }
    
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}


class ChannelAdminsViewController: EditableViewController<TableView> {
    fileprivate let statePromise = ValuePromise(ChannelAdminsControllerState(), ignoreRepeated: true)
    fileprivate let stateValue = Atomic(value: ChannelAdminsControllerState())

    private let peerId:PeerId
    
    private let addAdminDisposable:MetaDisposable = MetaDisposable()
    private let disposable:MetaDisposable = MetaDisposable()
    private let removeAdminDisposable:MetaDisposable = MetaDisposable()
    private let openPeerDisposable:MetaDisposable = MetaDisposable()
    init( _ context:AccountContext, peerId:PeerId) {
        self.peerId = peerId
        super.init(context)
    }
    
    let actionsDisposable = DisposableSet()
    
    let updateAdministrationDisposable = MetaDisposable()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        genericView.getBackgroundColor = {
            theme.colors.listBackground
        }
        
        let context = self.context
        let peerId = self.peerId
        
        
        let antiSpamBotConfiguration = AntiSpamBotConfiguration.with(appConfiguration: context.appConfiguration)
        
        let resolveAntiSpamPeerDisposable = MetaDisposable()
        if let antiSpamBotId = antiSpamBotConfiguration.antiSpamBotId {
            resolveAntiSpamPeerDisposable.set(
                (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: antiSpamBotId))
                |> mapToSignal { peer -> Signal<Never, NoError> in
                    if let _ = peer {
                        return .never()
                    } else {
                        return context.engine.peers.updatedRemotePeer(peer: .user(id: antiSpamBotId.id._internalGetInt64Value(), accessHash: 0))
                        |> ignoreValues
                        |> `catch` { _ -> Signal<Never, NoError> in
                            return .never()
                        }
                    }
                }).start()
            )
        }

        
        var upgradedToSupergroupImpl: ((PeerId, @escaping () -> Void) -> Void)?
        
        let upgradedToSupergroup: (PeerId, @escaping () -> Void) -> Void = { upgradedPeerId, f in
            upgradedToSupergroupImpl?(upgradedPeerId, f)
        }

        
        let adminsPromise = ValuePromise<[RenderedChannelParticipant]?>(nil)

        let updateState: ((ChannelAdminsControllerState) -> ChannelAdminsControllerState) -> Void = { [weak self] f in
            if let strongSelf = self {
                strongSelf.statePromise.set(strongSelf.stateValue.modify { f($0) })
            }
        }
        
        let viewValue:Atomic<PeerView?> = Atomic(value: nil)
        
        
        let arguments = ChannelAdminsControllerArguments(context: context, addAdmin: {
            let behavior = peerId.namespace == Namespaces.Peer.CloudGroup ? SelectGroupMembersBehavior(peerId: peerId, limit: 1) : SelectChannelMembersBehavior(peerId: peerId, peerChannelMemberContextsManager: context.peerChannelMemberCategoriesContextsManager, limit: 1)
            
            _ = (selectModalPeers(window: context.window, context: context, title: strings().adminsAddAdmin, limit: 1, behavior: behavior, confirmation: { peerIds in
                if let _ = behavior.participants[peerId] {
                     return .single(true)
                } else {
                    return .single(true)
                }
            }) |> map {$0.first}).start(next: { adminId in
                if let adminId = adminId {
                    showModal(with: ChannelAdminController(context, peerId: peerId, adminId: adminId, initialParticipant: behavior.participants[adminId]?.participant, updated: { _ in }, upgradedToSupergroup: upgradedToSupergroup), for: context.window)
                }
            })
        
        }, openAdmin: { participant in
            showModal(with: ChannelAdminController(context, peerId: peerId, adminId: participant.peer.id, initialParticipant: participant.participant, updated: { _ in }, upgradedToSupergroup: upgradedToSupergroup), for: context.window)
        }, removeAdmin: { [weak self] adminId in
            
            updateState {
                return $0.withUpdatedRemovingPeerId(adminId)
            }
            if peerId.namespace == Namespaces.Peer.CloudGroup {
                self?.removeAdminDisposable.set((context.engine.peers.removeGroupAdmin(peerId: peerId, adminId: adminId)
                    |> deliverOnMainQueue).start(completed: {
                        updateState {
                            return $0.withUpdatedRemovingPeerId(nil)
                        }
                    }))
            } else {
                self?.removeAdminDisposable.set((context.peerChannelMemberCategoriesContextsManager.updateMemberAdminRights(peerId: peerId, memberId: adminId, adminRights: nil, rank: nil)
                    |> deliverOnMainQueue).start(completed: {
                        updateState {
                            return $0.withUpdatedRemovingPeerId(nil)
                        }
                    }))
            }

        }, eventLogs: { [weak self] in
            let signal = context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)) |> deliverOnMainQueue
            _ = signal.startStandalone(next: { peer in
                if let peer {
                    self?.navigationController?.push(ChannelEventLogController(context, peer: peer))
                }
            })
        }, toggleAntispam: { value in
            _ = showModalProgress(signal: context.engine.peers.toggleAntiSpamProtection(peerId: peerId, enabled: value), for: context.window).start()
        }, toggleSignaturesAndProfile: { sign, show in
            updateState { current in
                var current = current
                current.signature = sign
                current.showProfile = show
                return current
            }
        })
        
       
        
        let peerView = Promise<PeerView>()
        peerView.set(context.account.viewTracker.peerView(peerId))
        
        let stateValue = self.stateValue

        self.onDeinit = {
            _ = (peerView.get() |> deliverOnMainQueue |> take(1)).start(next: { peerView in
                if let peer = peerViewMainPeer(peerView) as? TelegramChannel {
                    switch peer.info {
                    case .broadcast(let info):
                        let messagesShouldHaveSignatures = stateValue.with { $0.signature ?? info.flags.contains(.messagesShouldHaveSignatures) }
                        let messagesShouldHaveAuthor = stateValue.with { $0.showProfile ?? info.flags.contains(.messagesShouldHaveProfiles) }
                        if messagesShouldHaveSignatures != info.flags.contains(.messagesShouldHaveSignatures) || messagesShouldHaveAuthor != info.flags.contains(.messagesShouldHaveProfiles) {
                            _ = context.engine.peers.toggleShouldChannelMessagesSignatures(peerId: peerId, signaturesEnabled: messagesShouldHaveSignatures, profilesEnabled: messagesShouldHaveAuthor).startStandalone()
                        }
                    default:
                        break
                    }
                }
            })
        }

        let membersAndLoadMoreControl: (Disposable, PeerChannelMemberCategoryControl?)
        if peerId.namespace == Namespaces.Peer.CloudChannel {
            membersAndLoadMoreControl = context.peerChannelMemberCategoriesContextsManager.admins(peerId: peerId, updated: { membersState in
                if case .loading = membersState.loadingState, membersState.list.isEmpty {
                    adminsPromise.set(nil)
                } else {
                    adminsPromise.set(membersState.list)
                }
            })
        } else {
            let membersDisposable = (peerView.get()
                |> map { peerView -> [RenderedChannelParticipant]? in
                    guard let cachedData = peerView.cachedData as? CachedGroupData, let participants = cachedData.participants else {
                        return nil
                    }
                    var result: [RenderedChannelParticipant] = []
                    var creatorPeer: Peer?
                    for participant in participants.participants {
                        if let peer = peerView.peers[participant.peerId] {
                            switch participant {
                            case .creator:
                                creatorPeer = peer
                            default:
                                break
                            }
                        }
                    }
                    guard let creator = creatorPeer else {
                        return nil
                    }
                    for participant in participants.participants {
                        if let peer = peerView.peers[participant.peerId] {
                            switch participant {
                            case .creator:
                                result.append(RenderedChannelParticipant(participant: .creator(id: peer.id, adminInfo: nil, rank: nil), peer: peer))
                            case .admin:
                                var peers: [PeerId: Peer] = [:]
                                peers[creator.id] = creator
                                peers[peer.id] = peer
                                result.append(RenderedChannelParticipant(participant: .member(id: peer.id, invitedAt: 0, adminInfo: ChannelParticipantAdminInfo(rights: TelegramChatAdminRights(rights: .internal_groupSpecific), promotedBy: creator.id, canBeEditedByAccountPeer: creator.id == context.account.peerId), banInfo: nil, rank: nil, subscriptionUntilDate: nil), peer: peer, peers: peers))
                            case .member:
                                break
                            }
                        }
                    }
                    return result
                }).start(next: { members in
                    adminsPromise.set(members)
                })
            membersAndLoadMoreControl = (membersDisposable, nil)
        }
        
        let (membersDisposable, _) = membersAndLoadMoreControl
        actionsDisposable.add(membersDisposable)
        

        
        let initialSize = atomicSize
        
        let previousEntries:Atomic<[AppearanceWrapperEntry<ChannelAdminsEntry>]> = Atomic(value: [])
        
        let signal = combineLatest(statePromise.get(), peerView.get(), adminsPromise.get(), appearanceSignal)
            |> map { state, view, admins, appearance -> (TableUpdateTransition, Bool) in
                
                var isCreator = false
                var isSupergroup = false
                if let channel = peerViewMainPeer(view) as? TelegramChannel {
                    isCreator = channel.flags.contains(.isCreator)
                    isSupergroup = channel.isSupergroup
                }
                _ = viewValue.swap(view)
                let entries = channelAdminsControllerEntries(context: context, accountPeerId: context.peerId, view: view, state: state, participants: admins, isCreator: isCreator).map{AppearanceWrapperEntry(entry: $0, appearance: appearance)}
                return (prepareTransition(left: previousEntries.swap(entries), right: entries, initialSize: initialSize.modify{$0}, arguments: arguments, isSupergroup: isSupergroup), isCreator)
        }
        
        disposable.set((signal |> deliverOnMainQueue).start(next: { [weak self] transition, isCreator in
            self?.rightBarView.isHidden = !isCreator
            self?.genericView.merge(with: transition)
            self?.readyOnce()
        }))
        
        
        upgradedToSupergroupImpl = { [weak self] upgradedPeerId, f in
            guard let `self` = self, let navigationController = self.navigationController else {
                return
            }

            let chatController = ChatController(context: context, chatLocation: .peer(upgradedPeerId))
            
            navigationController.removeAll()
            navigationController.push(chatController, false, style: Optional.none)
            let signal = chatController.ready.get() |> filter {$0} |> take(1) |> deliverOnMainQueue |> ignoreValues
            
            _ = signal.start(completed: { [weak navigationController] in
                navigationController?.push(ChannelAdminsViewController(context, peerId: upgradedPeerId), false, style: Optional.none)
                f()
            })
            
        }

        
    }
    
    override func update(with state: ViewControllerState) {
        super.update(with: state)
        self.statePromise.set(stateValue.modify({$0.withUpdatedEditing(state == .Edit)}))
    }
    
    deinit {
        addAdminDisposable.dispose()
        disposable.dispose()
        removeAdminDisposable.dispose()
        updateAdministrationDisposable.dispose()
        openPeerDisposable.dispose()
        actionsDisposable.dispose()
    }
}
